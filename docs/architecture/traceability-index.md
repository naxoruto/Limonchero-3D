# Architecture Traceability Index

**Last Updated:** 2026-05-02 (v3)
**Engine:** Godot 4.6
**Source review:** `docs/architecture/architecture-review-2026-05-01-v2.md` + patches 2026-05-02

---

## Coverage Summary

| Metric | Count | % |
|--------|-------|---|
| Total requirements | 27 | 100% |
| ✅ Covered | 27 | 100% |
| ⚠️ Partial | 0 | 0% |
| ❌ Gaps | 0 | 0% |

---

## Full Traceability Matrix

| TR-ID | Layer | System | Requirement (short) | ADR(s) | Status | Notes |
|-------|-------|--------|---------------------|--------|--------|-------|
| TR-jugador-001 | Core | Player | FPS movement, WASD/mouse/gamepad | ADR-0012 | ✅ | |
| TR-jugador-002 | Core | Player | Sprint Shift/L3 | ADR-0012 | ✅ | |
| TR-interact-001 | Core | Interaction | Proximity E key, contextual menu | ADR-0013 | ✅ | |
| TR-interact-002 | Core | Interaction | Inspection overlay | ADR-0013 | ✅ | |
| TR-interact-003 | Core | Interaction | Pickup → inventory, testimony prompt | ADR-0013, ADR-0014 | ✅ | |
| TR-pista-001 | Feature | Inventory | 8 slots, types | ADR-0015 | ✅ | |
| TR-pista-002 | Feature | Inventory | Tablón diegético + Tab HUD | ADR-0010, ADR-0015 | ✅ | |
| TR-pista-003 | Feature | Inventory | Clue states good/not_good/unchecked | ADR-0001, ADR-0008, ADR-0015 | ✅ | Resolved 2026-05-01 — nested {state, timestamp}, lowercase |
| TR-npc-001 | Feature | NPC | 5 NPCs + history | ADR-0006, ADR-0014 | ✅ | |
| TR-npc-002 | Presentation | NPC | Balbuceo | ADR-0009 | ✅ | |
| TR-voz-001 | Core | Voice/STT | PTT V/LB → WAV | ADR-0004 | ✅ | |
| TR-voz-002 | Core | Voice/STT | ≤4s latency | ADR-0003, ADR-0004 | ✅ | |
| TR-llm-001 | Foundation | LLM Client | HTTP POST → FastAPI | ADR-0002, ADR-0003 | ✅ | |
| TR-llm-002 | Foundation | LLM Client | 8s timeout | ADR-0002 | ✅ | |
| TR-llm-003 | Foundation | LLM Client | Ollama exclusive | ADR-0002 | ✅ | Resolved — Ollama-only canonical |
| TR-gajito-001 | Feature | Gajito | Grammar evaluator pop-up | ADR-0016 | ✅ | |
| TR-gajito-002 | Feature | Gajito | Parallel evaluation | ADR-0016 | ✅ | |
| TR-acus-001 | Feature | Accusation | Spud tree, 3 evidences | ADR-0014 | ✅ | |
| TR-acus-002 | Feature | Accusation | Confession gate | ADR-0008, ADR-0014 | ✅ | |
| TR-estado-001 | Foundation | Game State | GameManager autoload | ADR-0001 | ✅ | |
| TR-estado-002 | Foundation | Game State | Anti-stall L1/L2/L3 timers | ADR-0011 | ✅ | New in v2 |
| TR-ui-001 | Presentation | HUD | Subtitles 2-channel, PTT, Gajito pop-up | ADR-0017 | ✅ | HUDManager autoload: SubtitlePanel + PTTIndicator + GajitoPopup |
| TR-ui-002 | Presentation | HUD | FOV slider, sub-size | ADR-0017 | ✅ | `apply_settings(font_size, fov)` en HUDManager |
| TR-backend-001 | Foundation | Backend | FastAPI endpoints + offline | ADR-0003 | ✅ | |
| TR-nivel-001 | Feature | Level Selector | Menu selector | ADR-0006 | ✅ | |
| TR-nivel-002 | Feature | NPC Dialogue | Prompt conditioned by level | ADR-0006, ADR-0014 | ✅ | |
| TR-telemetria-001 | Foundation | Session Log | Timestamped events | ADR-0001, ADR-0007 | ✅ | Subject to T1 ADR-0001 field-name fix |
| TR-telemetria-002 | Foundation | Session Log | JSON export trigger | ADR-0007 | ✅ | |
| TR-telemetria-003 | Foundation | Session Log | Full field set | ADR-0007 | ✅ | Subject to T1 ADR-0001 field-name fix |

---

## Known Gaps (priority list)

### Presentation layer gaps (only remaining)

| TR-ID | Gap | Suggested Action |
|-------|-----|-----------------|
| TR-ui-001 / TR-ui-002 | HUD coordinator (subtítulos, PTT, FOV, sub-size, coord. Inventory/Gajito) | `/architecture-decision hud-system` → ADR-0017 |

---

## Open Schema/Naming Issues (review v2 — non-blocking but must fix)

| Issue | Affected ADRs | Status |
|-------|---------------|--------|
| T1 — `npcs_interrogated` vs `npc_interrogation_counts`; `anti_stall_triggers` Dict vs `antistall_hints_fired` int | ADR-0001 stale; ADR-0007 + ADR-0011 + arch.md canonical | ✅ RESUELTO — ADR-0001 ya tenía nombres canónicos; report v2 estaba desactualizado |
| T2 — `barry` vs `barry_peel` culprit ID | ADR-0008 + ADR-0014 stale; CLAUDE.md + ADR-0007/0009 canonical | ✅ RESUELTO 2026-05-02 — unificado a `"barry"` en ADR-0014 |
| M1 — `TESTIMONY_TRIGGERS["moni"]` keywords map to F3 but should be R4 | ADR-0014 line 120 | ✅ RESUELTO 2026-05-02 — "yellow suit/coat/upstairs" → R4; "lighter/gold lighter/shiny" → F3 (dos triggers separados) |
| M2 — `## Status` (EN) vs `## Estado` (ES) header | ADRs 11–16 EN; ADRs 1–10 ES | Cosmetic |
| M3 — ADR-0011 written entirely in English | ADR-0011 | Style |

---

## Superseded / Resolved

| TR-ID | Issue | Resolution |
|-------|-------|------------|
| TR-llm-003 | Dual-stack vs Ollama-only | Resolved 2026-05-01 — Ollama exclusive (ADR-0002) |
| TR-pista-003 | Clue state representation | Resolved 2026-05-01 — nested `{state, timestamp}`, lowercase |

---

## History

| Date | Covered | Partial | Gaps | Notes |
|------|---------|---------|------|-------|
| 2026-05-01 | 11 (41%) | 7 (26%) | 9 (33%) | Initial review — 10 ADRs, pre-implementation |
| 2026-05-01 (v2) | 25 (92.6%) | 1 (3.7%) | 1 (3.7%) | After ADR-0011..0016 added; 2 schema/naming conflicts (T1, T2) remain |
