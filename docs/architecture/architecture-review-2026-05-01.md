# Architecture Review Report — Limonchero 3D

**Date:** 2026-05-01
**Engine:** Godot 4.6 (CLAUDE.md + architecture.md — `.claude/docs/technical-preferences.md` still `[TO BE CONFIGURED]` → run `/setup-engine`)
**GDDs Reviewed:** gdd/gdd_detective_noir_vr.md, levels/el_agave_y_la_luna.md, narrative/cast-bible.md, narrative/world-rules.md, registry/entities.yaml
**ADRs Reviewed:** ADR-0001 → ADR-0010 (10 total, all status `Propuesto`)
**TR Baseline:** 27 requirements (source: docs/architecture/architecture.md)
**Reviewer:** /architecture-review full

---

## Traceability Summary

| Metric | Count |
|--------|-------|
| Total requirements | 27 |
| ✅ Covered | 11 |
| ⚠️ Partial | 7 |
| ❌ Gaps | 9 |

---

## Full Traceability Matrix

| TR-ID | System | Requirement | ADR Coverage | Status |
|-------|--------|-------------|--------------|--------|
| TR-jugador-001 | Player | FPS movement — CharacterBody3D + Camera3D, WASD/mouse + gamepad | — | ❌ GAP |
| TR-jugador-002 | Player | Sprint (Shift/L3) | — | ❌ GAP |
| TR-interact-001 | Interaction | Proximity detection → E key, contextual menu (Interrogar/Examinar) | — | ❌ GAP |
| TR-interact-002 | Interaction | Inspection overlay — centred, Esc to close | — | ❌ GAP |
| TR-interact-003 | Interaction | Pickup → inventory + "¿Agregar como evidencia?" prompt | — | ❌ GAP |
| TR-pista-001 | Inventory | 8 slots, physical vs testimony distinction | ADR-0001 (state only, no module ADR) | ⚠️ Partial |
| TR-pista-002 | Inventory | Tablón diegético (3D wall) + Tab-view legible in HUD | ADR-0010 (tablón only; ADR-0010 cites wrong TR: `TR-ui-002`) | ⚠️ Partial |
| TR-pista-003 | Inventory | Clue states: BUENA / NO_BUENA / SIN_REVISAR | ADR-0001 + ADR-0008 | ⚠️ Partial (state-value conflict — see Conflict #1) |
| TR-npc-001 | NPC | 5 NPCs, unique system prompts + per-session history | ADR-0006 (prompt suffix only) | ⚠️ Partial (no NPC Dialogue module ADR) |
| TR-npc-002 | NPC | Per-NPC balbuceo synced with text display | ADR-0009 | ✅ |
| TR-voz-001 | Voice/STT | PTT hold V / LB → AudioEffectCapture → WAV → FastAPI | ADR-0004 | ⚠️ Partial (LB gamepad binding not in implementation) |
| TR-voz-002 | Voice/STT | Latency ≤ 4s end-to-end, English accent, >85% accuracy | ADR-0003 + ADR-0004 | ✅ |
| TR-llm-001 | LLM | HTTP POST localhost → FastAPI → LLM | ADR-0002 + ADR-0003 | ✅ |
| TR-llm-002 | LLM | 8s timeout per NPC response | ADR-0002 | ✅ |
| TR-llm-003 | LLM | Dev = Ollama, Demo = GPT-4o-mini / Gemini Flash | ADR-0002 (rejects demo path — conflict) | ⚠️ Conflict — GDD revision flag |
| TR-gajito-001 | Gajito | Grammar evaluator → Spanish correction pop-up | ADR-0003 (/grammar endpoint only) | ⚠️ Partial (no Gajito module ADR) |
| TR-gajito-002 | Gajito | Evaluation in parallel to NPC response | — | ❌ GAP |
| TR-acus-001 | Accusation | Spud dialogue tree, up to 3 evidences | ADR-0008 (logic only; UI tree absent) | ⚠️ Partial |
| TR-acus-002 | Accusation | Confession gate: F1+F2+F3 GOOD + Barry named | ADR-0008 | ✅ (state-value conflict) |
| TR-estado-001 | Game State | GameManager autoload: clues, progress, flags | ADR-0001 | ✅ |
| TR-estado-002 | Game State | Anti-stall L1/L2/L3 at 4/5/7 min without new evidence | — | ❌ GAP |
| TR-ui-001 | HUD | 2-channel subtitles, PTT indicator, Gajito pop-up | ADR-0004 (PTT signal only) + ADR-0010 | ⚠️ Partial (no HUD ADR) |
| TR-ui-002 | HUD | FOV slider 70–110°, subtitle size adjustable | — | ❌ GAP |
| TR-backend-001 | Backend | FastAPI /stt /npc/{id} /grammar; offline detection at startup | ADR-0003 | ✅ |
| TR-nivel-001 | Level Selector | Main menu selector (Beginner/Intermediate/Advanced) | ADR-0006 | ✅ |
| TR-nivel-002 | NPC Dialogue | System prompt conditioned by English level | ADR-0006 | ✅ |
| TR-telemetria-001 | Session Log | GameManager records timestamped events | ADR-0001 + ADR-0007 | ⚠️ Field-name conflict (see Conflict #3) |
| TR-telemetria-002 | Session Log | JSON export on game end or quit | ADR-0007 | ✅ |
| TR-telemetria-003 | Session Log | Full field set in JSON | ADR-0007 | ⚠️ Schema conflict with ADR-0001/architecture.md |

---

## Coverage Gaps (no ADR exists)

| TR-ID | System | Requirement | Suggested ADR | Layer | Engine Risk |
|-------|--------|-------------|---------------|-------|-------------|
| TR-jugador-001 | Player | FPS movement | `/architecture-decision player-controller` | Core | LOW |
| TR-jugador-002 | Player | Sprint | included in player-controller ADR | Core | LOW |
| TR-interact-001 | Interaction | Proximity + E key menu | `/architecture-decision interaction-system` | Core | LOW |
| TR-interact-002 | Interaction | Inspection overlay | included in interaction ADR | Core | LOW |
| TR-interact-003 | Interaction | Pickup + testimony prompt | included in interaction ADR | Core | LOW |
| TR-gajito-002 | Gajito | Parallel grammar evaluation | `/architecture-decision gajito-module` | Feature | LOW |
| TR-estado-002 | Anti-Stall | Timer system L1/L2/L3 | `/architecture-decision anti-stall-system` | Foundation | LOW |
| TR-ui-002 | HUD | FOV slider + sub-size | `/architecture-decision hud-system` | Presentation | LOW |

---

## Cross-ADR Conflicts

### 🔴 Conflict #1 — Clue State Representation
**Type:** State Management / Data Ownership
**Documents:** ADR-0001 vs ADR-0007 vs ADR-0008 vs architecture.md vs entities.yaml vs GDD

| Source | Clue storage format | State values |
|--------|--------------------|----|
| ADR-0001 + architecture.md | `{state: String, timestamp: float}` (nested Dict) | `"GOOD"` / `"NOT_GOOD"` / `"UNCHECKED"` (uppercase) |
| ADR-0007 JSON example | `"F1": "good"` (flat String value) | `"good"` (lowercase) |
| ADR-0008 code | `clues.get(clue_id, "") != "good"` (reads String) | `"good"` (lowercase) |
| entities.yaml | `F1+F2+F3 GOOD` | UPPERCASE |
| GDD | "BUENA / NO_BUENA / SIN_REVISAR" | Spanish |

**Impact:** ADR-0008 `is_confession_gate_open()` will always return false because `clues["F1"]` is a Dict `{state, timestamp}`, not a String. Confession mechanic broken at runtime.

**Resolution:** Pin one canonical form. Recommended: `clues: { F1: { state: "good"|"not_good"|"unchecked", timestamp: float } }` (nested, lowercase ASCII). Update ADR-0001, ADR-0007, ADR-0008, architecture.md, entities.yaml.

---

### 🔴 Conflict #2 — `accusation_attempts` Type
**Type:** State Management
**Documents:** ADR-0001 / architecture.md vs ADR-0007 / ADR-0008

- **ADR-0001 + architecture.md:** `accusation_attempts: Array` of `{suspect, evidence, correct, timestamp}`; method `register_accusation(suspect: String, evidence: Array, correct: bool)`
- **ADR-0007 + ADR-0008:** `accusation_attempts: int` (`GameManager.accusation_attempts += 1`)

**Impact:** Telemetry loses per-attempt detail OR ADR-0008 corrupts Array by doing `+= 1`.

**Resolution:** Keep Array (richer telemetry). ADR-0008 must call `GameManager.register_accusation(npc_id, evidence, is_correct)` not mutate the counter directly. ADR-0007 JSON should serialize as Array.

---

### 🔴 Conflict #3 — Telemetry Field Names
**Type:** Integration Contract
**Documents:** ADR-0001 / architecture.md vs ADR-0007

| Architecture.md / ADR-0001 field | ADR-0007 field |
|---|---|
| `grammar_errors_count: int` | `gajito_corrections: int` |
| `antistall_hints_fired: int` | `anti_stall_triggers: {L1, L2, L3}` Dict |
| `npcs_interrogated` | `npc_interrogation_counts` |
| `correct_accusation: bool` | (absent — only `case_resolved`) |
| `clues_collected: Array<{id, timestamp}>` | `clues: Dict<id, state>` |
| `completed: bool` | (absent) |

**Impact:** Analysis scripts cannot be written reliably. `export_session_json()` in ADR-0007 omits fields that architecture.md TR-telemetria-003 requires.

**Resolution:** Designate ADR-0007 as authoritative for field names. Revise architecture.md `Formato JSON de Sesión` to match. Decision needed: prefer flat `clues: Dict<state>` or nested `clues_collected: Array<{id, timestamp}>`.

---

### 🔴 Conflict #4 — LLM Strategy
**Type:** Integration Contract
**Documents:** GDD (line 328, 337) / CLAUDE.md / architecture.md TR-llm-003 vs ADR-0002

- **GDD/CLAUDE.md/architecture.md:** dual-stack — dev = Ollama, demo = GPT-4o-mini / Gemini Flash
- **ADR-0002:** Ollama exclusively for all phases. Explicitly rejects demo path.

**Impact:** TR-llm-003 states a capability that ADR-0002 removes. GDD revision needed, or ADR-0002 must be revised.

**Resolution:** Either update GDD (and arch.md TR-llm-003 + CLAUDE.md Tech Stack row) to "Ollama only"; or add demo-path back to ADR-0002 with a backend config flag. ADR-0002 reasoning is sound for academic context — recommend updating GDD.

---

### 🔴 Conflict #5 — Backend Lifecycle vs Architecture Doc
**Type:** Integration Contract / Init Ordering
**Documents:** architecture.md "Orden de Inicialización" vs ADR-0003

- **architecture.md step 4:** "health check — if backend OFF → show error + instructions → Iniciar disabled" (implies manual launch)
- **ADR-0003:** `OS.create_process()` auto-launches backend at `main_menu._ready()`

**Impact:** architecture.md is stale; no implementation conflict, but doc drift will confuse contributors.

**Resolution:** Update architecture.md "Orden de Inicialización" step 3–4 to reference ADR-0003 auto-launch flow.

---

### 🔴 Conflict #6 — Platform Scope
**Type:** Platform
**Documents:** CLAUDE.md / GDD vs ADR-0003

- **CLAUDE.md + GDD:** "PC (Windows / Linux)"
- **ADR-0003 Restricciones:** "Plataforma: Windows exclusivamente"; launch code uses `"python"` (Windows PATH assumption)

**Impact:** Linux build — the primary dev OS per this session (CachyOS detected) — cannot auto-launch backend. `OS.create_process("python", ...)` on Linux likely needs `"python3"`. Path resolution also differs.

**Resolution:** ADR-0003 must support both:
```gdscript
var python_cmd := "python3" if OS.get_name() == "Linux" else "python"
_backend_pid = OS.create_process(python_cmd, [main_py])
```
Also test `OS.kill()` on Linux (should work cross-platform in Godot 4.6).

---

### 🟡 Conflict #7 — Confession Gate Semantics Split
**Type:** Integration Contract
**Documents:** ADR-0001 vs ADR-0008

- **ADR-0001 + CLAUDE.md:** `is_confession_gate_open()` = F1+F2+F3 GOOD + Barry named (combined)
- **ADR-0008:** `is_confession_gate_open()` = clues only; "Barry named" check inside `accuse()`

**Impact:** Any UI that polls `is_confession_gate_open()` to show "ready to accuse" button gets wrong answer if the function only checks clues.

**Resolution:** ADR-0008's split design is architecturally cleaner. Update ADR-0001 contract docs and architecture.md table to reflect split semantics.

---

### 🟡 Conflict #8 — NPC ID Convention
**Type:** Integration Contract (Identifier)
**Documents:** ADR-0007 / ADR-0009 vs registry/entities.yaml / CLAUDE.md / architecture.md

| Source | IDs used |
|--------|---------|
| CLAUDE.md / architecture.md | `barry, moni, gerry, lola, spud` |
| ADR-0007 npc_interrogation_counts | `barry_peel, moni_salazar, lola_vidal, barman, portero` |
| ADR-0009 audio paths | `barry_peel/, moni_salazar/, lola_vidal/, barman/, portero/` |
| entities.yaml | Moni **Graná Fert** (not Salazar), Dolores **Persimmon** (not Vidal), Gerald Broccolini = Gerry, Wallace Spud |

**Problems:**
1. `moni_salazar` and `lola_vidal` are **wrong surnames** — Moni's last name is Graná Fert, Lola's is Persimmon.
2. `barman` / `portero` are roles, not NPC IDs. The barman NPC does not appear in the cast bible as an interrogable character; Gerry (Broccolini) is Security, not portero.
3. Canonical IDs in CLAUDE.md (`barry, moni, gerry, lola, spud`) are the project standard.

**Impact:** ADR-0009 audio asset paths will point to wrong directories. ADR-0007 telemetry cannot be cross-referenced with cast bible.

**Resolution:** Adopt `barry, moni, gerry, lola, spud` as canonical NPC IDs project-wide. Update ADR-0007 + ADR-0009 examples. Confirm cast: is there a 5th interrogable NPC beyond barry/moni/gerry/lola/spud? (Cast bible has Cornelius Maize as victim, not interrogable.)

---

### 🟡 Minor — Wrong TR References in ADRs

- **ADR-0009** cites `TR-audio-001` (does not exist) → correct to `TR-npc-002`
- **ADR-0010** cites `TR-ui-002` (FOV slider) → correct to `TR-pista-002` (tablón diegético)

---

## ADR Dependency Order (Topological Sort)

No cycles detected.

```
Foundation — no dependencies:
  1. ADR-0001  GameManager singleton
  2. ADR-0002  Ollama LLM strategy

Depends on Foundation:
  3. ADR-0003  FastAPI backend          ← ADR-0002
  4. ADR-0005  Signal architecture      ← ADR-0001
  5. ADR-0007  Session telemetry        ← ADR-0001
  6. ADR-0008  Confession gate          ← ADR-0001

Feature layer:
  7. ADR-0004  PTT / AudioEffectCapture ← ADR-0003
  8. ADR-0006  English level            ← ADR-0001 + ADR-0002

Presentation layer:
  9. ADR-0010  Tablón diegético         ← ADR-0005
  10. ADR-0009  NPC balbuceo            ← ADR-0004
```

⚠️ All 10 ADRs are status `Propuesto` — none `Accepted`. Formal sign-off pending. Implementation should not begin until upstream ADRs for each epic are accepted.

---

## Engine Compatibility

| Check | Result |
|-------|--------|
| Engine reference docs (`docs/engine-reference/godot/`) | ❌ MISSING — directory does not exist |
| `.claude/docs/technical-preferences.md` Engine field | `[TO BE CONFIGURED]` — run `/setup-engine` |
| Engine version consistency across all ADRs | ✅ All say Godot 4.6 |
| Post-Cutoff APIs across all ADRs | ✅ All declare "Ninguna" |
| Deprecated APIs grep'd in ADRs | ✅ None found |
| ADRs missing Engine Compatibility section | 0 / 10 |

**Engine specialist consultation skipped** — no engine configured in `technical-preferences.md`.

### Verification flags requiring manual confirmation on Godot 4.6

| ADR | API | Flag |
|-----|-----|------|
| ADR-0004 | `AudioEffectCapture.get_buffer()` → `PackedVector2Array` | Confirmed stable in 4.6 |
| ADR-0004 | `AudioServer.get_mix_rate()` | **Typically 44100 Hz — `_build_wav()` hardcodes 16000 Hz but does no resampling. WAV sent to faster-whisper will be at wrong speed. Verify / add resampling.** |
| ADR-0010 | `ViewportTexture.viewport_path` assigned in code | Fragile in some 4.x versions. ADR notes this. Confirm in editor test. |
| ADR-0009 | `AudioStreamRandomizer.add_stream(index, stream)` | Confirm signature in 4.6 docs. |
| ADR-0001 | `FileAccess.open("user://...", WRITE)` in exported build | Must verify on Windows + Linux export. |
| ADR-0003 | `OS.create_process("python", [...])` | Windows PATH — AND Linux requires `python3`. Fix needed (Conflict #6). |

---

## GDD Revision Flags (Architecture → Design Feedback)

| GDD | Line | Assumption | Reality (ADR/CLAUDE.md) | Action |
|-----|------|-----------|------------------------|--------|
| gdd/gdd_detective_noir_vr.md | 302 | "STT → LLM → TTS" | TTS removed in v0.3 | Revise GDD |
| gdd/gdd_detective_noir_vr.md | 321 | Piper TTS in arch diagram | TTS removed | Revise GDD |
| gdd/gdd_detective_noir_vr.md | 337 | `LLM producción: GPT-4o-mini o Gemini Flash` | ADR-0002: Ollama only | Revise GDD |
| gdd/gdd_detective_noir_vr.md | 328 | "En demo final, Ollama puede reemplazarse..." | ADR-0002 explicitly rejects | Revise GDD |
| gdd/gdd_detective_noir_vr.md | 534 | Risk row: "Alta latencia LLM+STT+TTS" | TTS gone | Revise risk row |
| docs/architecture/architecture.md | Init. step 4 | Manual backend launch + verify | ADR-0003 auto-launches | Update arch.md |
| docs/architecture/architecture.md | TR-llm-003 | "Desarrollo = Ollama, Demo = GPT-4o-mini" | ADR-0002 supersedes | Update arch.md |

---

## Architecture Document Coverage

`docs/architecture/architecture.md` covers all 27 TRs in Línea Base. No orphaned modules relative to systems-index. Document is internally consistent but **stale in three areas** (see GDD Revision Flags). Sync pass required after Conflicts #4, #5 are resolved.

---

## Verdict: CONCERNS

**Not FAIL:** No dependency cycles. No irrecoverable design conflicts. Engine version consistent across all ADRs. Foundation ADRs (0001–0008) provide solid base.

**Not PASS:** 9 TR gaps (Core + Feature layer not yet spec'd). Three blocking schema conflicts (clue state format, accusation type, telemetry fields) will cause runtime bugs if implementation begins now. Linux platform gap affects dev team.

### Blocking Issues (resolve before PASS)

| # | Issue | Type |
|---|-------|------|
| 1 | Clue-state representation — pick one canonical form | Schema conflict |
| 2 | `accusation_attempts` — Array vs int | Schema conflict |
| 3 | Telemetry field names — ADR-0007 vs architecture.md | Schema conflict |
| 4 | ADR-0003 Linux support | Platform gap |
| 5 | TR-llm-003 — decide GDD revision or restore demo path | Strategy conflict |

### Required New ADRs (priority order)

| Priority | ADR | Systems | Covers |
|----------|-----|---------|--------|
| P1 | ADR-0011 Anti-Stall System | Timer L1/L2/L3, hint payload, reset on clue_added | TR-estado-002 |
| P1 | ADR-0012 Player Controller | CharacterBody3D, WASD/mouse, sprint, gamepad binding | TR-jugador-001/002 |
| P1 | ADR-0013 Interaction System | RayCast3D, contextual menu, pickup, inspection overlay | TR-interact-001/002/003 |
| P2 | ADR-0014 NPC Dialogue Module | History mgmt, prompt assembly, Spud accusation tree | TR-npc-001, TR-acus-001 |
| P2 | ADR-0015 Inventory Module | 8 slots, types, Tab HUD view, state display | TR-pista-001/002 |
| P2 | ADR-0016 Gajito Module | Parallel request, pop-up timing, error accumulation | TR-gajito-001/002 |
| P3 | ADR-0017 HUD System | 2-channel subtitles, PTT indicator, FOV slider, sub-size | TR-ui-001/002 |

---

## Next Steps

1. Run `/architecture-decision anti-stall-system` — highest-impact Foundation gap.
2. Fix schema conflicts #1/2/3 in a single ADR-revision session (touch ADR-0001, ADR-0007, ADR-0008).
3. Patch ADR-0003 for Linux.
4. Run `/gate-check pre-production` when all 5 blocking issues resolved.
5. Run `/setup-engine` to configure Godot 4.6 in `technical-preferences.md`.
6. Re-run `/architecture-review` after each new ADR.
