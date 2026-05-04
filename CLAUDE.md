# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**Detective Noir** — "Limonchero 3D" — is a PC first-person detective game (Windows/Linux) for the course ICI5442 – Tecnologías Emergentes (PUCV). Core academic requirement: integrate LLM + an emerging technology (originally VR, migrated to PC desktop in v0.3 per professor feedback).

**Team:** Ignacio Cuevas (tech lead), Martin Cevallos (backend/LLM), Sofia Meza (audio/STT), Diego Espinosa (docs/design)  
**Deadline:** End of June 2026

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Engine | Godot 4 |
| Platform | PC (Windows / Linux) |
| Backend | Python + FastAPI (proxy to LLM) |
| LLM | Ollama (llama3.2) — todas las fases: dev, pruebas, entrega. Ver ADR-0002 |
| STT | faster-whisper (local, model medium, English-focused) |
| TTS | Not used for NPCs — NPCs respond as text only |
| VR SDK | Removed in v0.3 — no OpenXR/XR Tools |

---

## Directory Structure

```
game/                   Godot project root (project.godot, scenes/, scripts/, assets/)
docs/                   Design + production docs (GDD, levels, narrative, architecture, registry)
tools/                  External tooling (CCGS agent framework)
tests/                  (Optional) out-of-project tests (disabled by default)

game/assets/            3D models, textures, fonts, materials
game/scripts/           GDScript code
game/scenes/            Godot scenes (.tscn)

docs/design/gdd/        Game design documents (GDD, ideas, reviews)
docs/design/levels/     Level design docs (El Agave y La Luna)
docs/design/narrative/  Cast bible, world rules
docs/architecture/      ADRs, architecture, traceability
docs/registry/          Authoritative cross-doc registry (entities.yaml)

tools/Claude-Code-Game-Studios/  CCGS agent framework (separate git repo inside this folder)
```

**Canonical document paths** (systems-index.md is the entry point):

| Doc | Path | Status |
|-----|------|--------|
| GDD | `docs/design/gdd/gdd_detective_noir_vr.md` | Active v0.3 |
| Level design | `docs/design/levels/el_agave_y_la_luna.md` | Active |
| Cast bible | `docs/design/narrative/cast-bible.md` | Established |
| World rules | `docs/design/narrative/world-rules.md` | Established |
| Entity registry | `docs/registry/entities.yaml` | Authoritative |

---

## Entity Registry

`docs/registry/entities.yaml` is the **single source of truth** for all cross-document values (character attributes, evidence locations, system constants). When a value changes in any GDD, update the registry first.

Key constants:

| Constant | Value |
|----------|-------|
| `confesion_gate` | F1 + F2 + F3 marked GOOD + Barry named as accused |
| `inventory_slots` | 8 (safe range 6–10) |
| `llm_timeout` | 8 seconds per NPC response |
| `stt_latency_budget` | 4 seconds end-to-end (STT→LLM, no TTS) |
| `anti_stall_L1/L2/L3` | 4 / 5 / 7 minutes without evidence acquisition |

---

## Core Gameplay Architecture

```
Mic (PTT: V key) → faster-whisper → FastAPI backend → LLM (NPC persona prompt) → text response in Godot world-space panel
                                  → Gajito LLM (grammar evaluator) → Spanish correction pop-up if error
```

**Single level:** El Agave y La Luna (noir nightclub, 1950s US). One investigation session resolves the case.

**Culprit (not secret — hardcoded):** Barry Peel (plátano, age 34). Confession unlocks only when F1+F2+F3 all collected AND Moni confirms F3 as Barry's lighter.

**Evidence chain for F2 (5-step):** Cenicero → talón → abrigo #14 → revisar bolsillos → F2 (llave maestra)

**Red herrings:** F4 (Moni's suitcase) implicates Moni (escape plan, not crime); F5 (burned envelope) implicates Lola (civil lawsuit).

---

## Language Rules

- **Game language:** English (all NPCs speak only English; player speaks English via STT)
- **UI + Gajito:** Spanish
- **Limonchero (player character):** speaks no English — Gajito translates
- **Godot scene text / menus:** Spanish
- **NPC prompts sent to LLM:** English

---

## Platform Migration Note (v0.3)

GDD was migrated from Meta Quest 2 VR → PC desktop. Any reference to OpenXR, XR Tools, Quest 2, or hand tracking in older documents is **obsolete**. Current controls: WASD + mouse, interact = E key, PTT = hold V.

---

## CCGS Agent Framework

`tools/Claude-Code-Game-Studios/` contains a separate git repo with 49 specialized Claude Code agents, 72 slash commands, and Godot-specialist agents. Use `/start` inside that directory to initialize project-aware agent workflows. The framework is a tool — this repo's design docs take precedence over framework defaults.
