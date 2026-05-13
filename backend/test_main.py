"""
Limonchero 3D — Backend Tests
Tests for all backend stories (001–004).

Run:
  cd backend && pytest test_main.py -v
"""

import json
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest
from fastapi.testclient import TestClient

# Ensure backend directory is on the path
sys.path.insert(0, str(Path(__file__).parent))

from main import app


client = TestClient(app)


# ═══════════════════════════════════════════════════════
#  Story 001 — Health Check
# ═══════════════════════════════════════════════════════

class TestHealth:
    """Tests for GET /health."""

    def test_health_returns_200(self):
        """Health endpoint should always return 200 with status ok."""
        with patch("main.ollama.list"):
            response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "model" in data
        assert "timestamp" in data

    def test_health_reports_ollama_status(self):
        """Health endpoint should report whether Ollama is reachable."""
        # Ollama available
        with patch("main.ollama.list"):
            response = client.get("/health")
        assert response.json()["ollama_available"] is True

        # Ollama unavailable
        with patch("main.ollama.list", side_effect=Exception("Connection refused")):
            response = client.get("/health")
        assert response.status_code == 200  # still 200
        assert response.json()["ollama_available"] is False


# ═══════════════════════════════════════════════════════
#  Story 003 — NPC Dialogue
# ═══════════════════════════════════════════════════════

class TestNPCDialogue:
    """Tests for POST /npc/{npc_id}."""

    def _mock_ollama_chat(self, **kwargs):
        """Mock ollama.chat to return a canned response."""
        return {"message": {"content": "I'm a test NPC response."}}

    def test_valid_npc_returns_response(self):
        """Valid NPC ID should return a 200 response with text."""
        with patch("main.ollama.chat", side_effect=self._mock_ollama_chat):
            response = client.post("/npc/spud", json={
                "npc_id": "spud",
                "history": [],
                "message": "Hello Commissioner",
            })
        assert response.status_code == 200
        data = response.json()
        assert "response" in data
        assert "timestamp" in data
        assert len(data["response"]) > 0

    def test_invalid_npc_returns_404(self):
        """Unknown NPC ID should return 404."""
        response = client.post("/npc/unknown_npc", json={
            "npc_id": "unknown_npc",
            "history": [],
            "message": "Hello",
        })
        assert response.status_code == 404

    def test_all_valid_npcs(self):
        """All 6 NPCs from the GDD should be reachable."""
        valid_npcs = ["spud", "moni", "gerry", "lola", "barry", "gajito"]
        with patch("main.ollama.chat", side_effect=self._mock_ollama_chat):
            for npc in valid_npcs:
                response = client.post(f"/npc/{npc}", json={
                    "npc_id": npc,
                    "history": [],
                    "message": "Test message",
                })
                assert response.status_code == 200, f"NPC '{npc}' failed"

    def test_barry_locked_without_evidence(self):
        """Barry should NOT confess without F1+F2+F3."""
        with patch("main.ollama.chat", side_effect=self._mock_ollama_chat) as mock_chat:
            response = client.post("/npc/barry", json={
                "npc_id": "barry",
                "history": [],
                "message": "Did you kill Cornelius?",
            })
        assert response.status_code == 200
        # Verify the system prompt included the LOCKED addendum
        call_args = mock_chat.call_args
        system_msg = call_args[1]["messages"][0]["content"]
        assert "NOT yet presented" in system_msg

    def test_barry_unlocked_with_all_evidence(self):
        """Barry SHOULD confess when F1+F2+F3 are all presented."""
        history = [
            {"role": "user", "content": "Look at this. [EVIDENCE_PRESENTED:F1]"},
            {"role": "assistant", "content": "That's just a document..."},
            {"role": "user", "content": "And this key. [EVIDENCE_PRESENTED:F2]"},
            {"role": "assistant", "content": "Where did you find that?"},
            {"role": "user", "content": "And your lighter. [EVIDENCE_PRESENTED:F3]"},
            {"role": "assistant", "content": "That could be anyone's..."},
        ]
        with patch("main.ollama.chat", side_effect=self._mock_ollama_chat) as mock_chat:
            response = client.post("/npc/barry", json={
                "npc_id": "barry",
                "history": history,
                "message": "It's over, Barry.",
            })
        assert response.status_code == 200
        # Verify the system prompt included the UNLOCKED addendum
        call_args = mock_chat.call_args
        system_msg = call_args[1]["messages"][0]["content"]
        assert "Reluctantly confess" in system_msg

    def test_barry_partial_evidence_stays_locked(self):
        """Barry should stay locked with only F1+F2 (missing F3)."""
        history = [
            {"role": "user", "content": "[EVIDENCE_PRESENTED:F1]"},
            {"role": "user", "content": "[EVIDENCE_PRESENTED:F2]"},
        ]
        with patch("main.ollama.chat", side_effect=self._mock_ollama_chat) as mock_chat:
            response = client.post("/npc/barry", json={
                "npc_id": "barry",
                "history": history,
                "message": "Confess!",
            })
        assert response.status_code == 200
        call_args = mock_chat.call_args
        system_msg = call_args[1]["messages"][0]["content"]
        assert "NOT yet presented" in system_msg

    def test_ollama_down_returns_503(self):
        """If Ollama is unreachable, NPC endpoint should return 503."""
        with patch("main.ollama.chat", side_effect=Exception("Connection refused")):
            response = client.post("/npc/spud", json={
                "npc_id": "spud",
                "history": [],
                "message": "Hello",
            })
        assert response.status_code == 503


# ═══════════════════════════════════════════════════════
#  Story 004 — Grammar Check (Gajito)
# ═══════════════════════════════════════════════════════

class TestGrammar:
    """Tests for POST /grammar."""

    def _mock_correct(self, **kwargs):
        return {"message": {"content": json.dumps({
            "is_correct": True,
            "correction": "",
            "explanation_es": "",
        })}}

    def _mock_incorrect(self, **kwargs):
        return {"message": {"content": json.dumps({
            "is_correct": False,
            "correction": "She goes to school.",
            "explanation_es": "El verbo debe concordar con el sujeto en tercera persona.",
        })}}

    def test_correct_grammar(self):
        """Correct sentence should return is_correct=True."""
        with patch("main.ollama.chat", side_effect=self._mock_correct):
            response = client.post("/grammar", json={
                "transcript": "She goes to school every day.",
                "language": "english",
            })
        assert response.status_code == 200
        data = response.json()
        assert data["is_correct"] is True

    def test_incorrect_grammar(self):
        """Incorrect sentence should return correction + explanation in Spanish."""
        with patch("main.ollama.chat", side_effect=self._mock_incorrect):
            response = client.post("/grammar", json={
                "transcript": "She go to school every day.",
                "language": "english",
            })
        assert response.status_code == 200
        data = response.json()
        assert data["is_correct"] is False
        assert len(data["correction"]) > 0
        assert len(data["explanation_es"]) > 0

    def test_empty_transcript(self):
        """Empty transcript should return is_correct=True without calling LLM."""
        response = client.post("/grammar", json={
            "transcript": "",
            "language": "english",
        })
        assert response.status_code == 200
        assert response.json()["is_correct"] is True

    def test_grammar_ollama_down(self):
        """If Ollama is down, grammar should return 503."""
        with patch("main.ollama.chat", side_effect=Exception("Connection refused")):
            response = client.post("/grammar", json={
                "transcript": "This is a test.",
                "language": "english",
            })
        assert response.status_code == 503


# ═══════════════════════════════════════════════════════
#  Story 002 — STT (tests with mock whisper)
# ═══════════════════════════════════════════════════════

class TestSTT:
    """Tests for POST /stt."""

    def test_empty_file_returns_400(self):
        """Empty audio file should return 400."""
        response = client.post(
            "/stt",
            files={"file": ("test.wav", b"", "audio/wav")},
        )
        assert response.status_code == 400

    def test_stt_returns_transcript(self):
        """Valid audio should return a transcript and duration."""
        # Create a mock segment
        mock_segment = MagicMock()
        mock_segment.text = "Hello detective"

        mock_info = MagicMock()
        mock_info.language = "en"

        mock_model = MagicMock()
        mock_model.transcribe.return_value = ([mock_segment], mock_info)

        # Fake WAV data (just bytes, mock won't actually process it)
        fake_wav = b"RIFF" + b"\x00" * 100

        with patch("main._get_whisper_model", return_value=mock_model):
            response = client.post(
                "/stt",
                files={"file": ("test.wav", fake_wav, "audio/wav")},
            )

        assert response.status_code == 200
        data = response.json()
        assert data["transcript"] == "Hello detective"
        assert data["duration_ms"] >= 0


# ═══════════════════════════════════════════════════════
#  NPC Prompts Unit Tests
# ═══════════════════════════════════════════════════════

class TestNPCPrompts:
    """Unit tests for npc_prompts module."""

    def test_all_npcs_have_prompts(self):
        """All 6 NPCs should have system prompts defined."""
        from npc_prompts import NPC_PROMPTS
        expected = {"spud", "moni", "gerry", "lola", "barry", "gajito"}
        assert set(NPC_PROMPTS.keys()) == expected

    def test_all_npcs_english_only_except_gajito(self):
        """NPCs (except Gajito) should have ENGLISH ONLY in their prompt."""
        from npc_prompts import NPC_PROMPTS
        for npc, prompt in NPC_PROMPTS.items():
            if npc == "gajito":
                assert "ESPAÑOL" in prompt
            else:
                assert "ENGLISH" in prompt, f"NPC '{npc}' missing ENGLISH directive"

    def test_confession_gate_no_evidence(self):
        """Confession gate should be False with no evidence."""
        from npc_prompts import check_barry_confession_gate
        assert check_barry_confession_gate([]) is False

    def test_confession_gate_partial(self):
        """Confession gate should be False with partial evidence."""
        from npc_prompts import check_barry_confession_gate
        history = [
            {"role": "user", "content": "[EVIDENCE_PRESENTED:F1]"},
            {"role": "user", "content": "[EVIDENCE_PRESENTED:F3]"},
        ]
        assert check_barry_confession_gate(history) is False

    def test_confession_gate_complete(self):
        """Confession gate should be True with F1+F2+F3."""
        from npc_prompts import check_barry_confession_gate
        history = [
            {"role": "user", "content": "[EVIDENCE_PRESENTED:F1]"},
            {"role": "user", "content": "[EVIDENCE_PRESENTED:F2]"},
            {"role": "user", "content": "[EVIDENCE_PRESENTED:F3]"},
        ]
        assert check_barry_confession_gate(history) is True
