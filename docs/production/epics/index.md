# Épicas e Historias — Limonchero 3D
**Actualizado:** 2026-05-03  
**Sprint actual:** Sprint 1 (2026-05-05 → 2026-05-12)

**Leyenda:**
`⬜ Ready` — lista para implementar | `🔵 In Progress` — en desarrollo | `✅ Done` — cerrada | `🔴 Blocked` — bloqueada

---

## Resumen por Épica

| Épica | Capa | Responsable | Stories | Estimado total | Sprint |
|-------|------|-------------|---------|----------------|--------|
| GameManager | Foundation | Ignacio | 5 | ~12-15 h | 1 |
| Proxy Backend | Foundation | Martín | 4 | ~12-14 h | 1 |
| Cargador de Escena | Foundation | Ignacio | 2 | ~5-7 h | 1 |
| Cliente LLM | Foundation | Ignacio | 3 | ~7-10 h | 2 |
| Controlador del Jugador | Core | Ignacio | 2 | ~6-7 h | 2 |
| Sistema de Interacción | Core | Ignacio | 3 | ~9-11 h | 2-3 |
| Voz/PTT | Core | Sofía | ⚠️ sin stories | — | 2 |

---

## 📦 GameManager — Foundation
**Archivo:** `production/epics/gamemanager/EPIC.md`  
**Bloqueante para:** todo lo demás en Godot.

| # | Story | Estado | Estimado | Bloqueada por |
|---|-------|--------|----------|---------------|
| 001 | Inicialización de Sesión | ✅ Done | 2-3 h | — |
| 002 | Ciclo de Vida de Pistas y Señales | ⬜ Ready | 3-4 h | — |
| 003 | Puerta de Confesión | ⬜ Ready | 2-3 h | Story 002 |
| 004 | Registro de Eventos de Telemetría | ⬜ Ready | 2-3 h | — |
| 005 | Exportación JSON al Disco | ⬜ Ready | 2-3 h | Story 004 |

---

## 🐍 Proxy Backend — Foundation
**Archivo:** `production/epics/proxy-backend/EPIC.md`  
**Bloqueante para:** Cliente LLM (Ignacio), Voz/PTT (Sofía).

| # | Story | Estado | Estimado | Bloqueada por |
|---|-------|--------|----------|---------------|
| 001 | FastAPI Base + `/health` | ⬜ Ready | 2-3 h | — |
| 002 | `/stt` — faster-whisper | ⬜ Ready | 3-4 h | Story 001 |
| 003 | `/npc/{id}` — Proxy a Ollama | ⬜ Ready | 3-4 h | Story 001 |
| 004 | `/grammar` — Evaluación Gajito | ⬜ Ready | 2-3 h | Story 001 |

> ⚠️ **Orden de implementación obligatorio:** 001 → 003 → 004 → 002

---

## 🎬 Cargador de Escena — Foundation
**Archivo:** `production/epics/cargador-escena/EPIC.md`

| # | Story | Estado | Estimado | Bloqueada por |
|---|-------|--------|----------|---------------|
| 001 | Menú Principal + Detección de Backend | ⬜ Ready | 3-4 h | GameManager 001 ✅ |
| 002 | SceneLoader — Transiciones con Fade | ⬜ Ready | 2-3 h | — |

---

## 🤖 Cliente LLM — Foundation
**Archivo:** `production/epics/cliente-llm/EPIC.md`

| # | Story | Estado | Estimado | Bloqueada por |
|---|-------|--------|----------|---------------|
| 001 | Estructura Base LLMClient + Health Check | ⬜ Ready | 2-3 h | Backend Story 001 |
| 002 | Petición NPC con Timeout | ⬜ Ready | 3-4 h | Cliente LLM Story 001 |
| 003 | Verificación Gramatical (Gajito) | ⬜ Ready | 2-3 h | Backend Story 004 |

---

## 🕹️ Controlador del Jugador — Core
**Archivo:** `production/epics/controlador-jugador/EPIC.md`

| # | Story | Estado | Estimado | Bloqueada por |
|---|-------|--------|----------|---------------|
| 001 | Movimiento FPS — WASD + Mouse + Mando | ⬜ Ready | 4-5 h | — |
| 002 | Configuración de FOV en Menú de Opciones | ⬜ Ready | 2 h | Story 001 |

---

## 🔍 Sistema de Interacción — Core
**Archivo:** `production/epics/sistema-interaccion/EPIC.md`

| # | Story | Estado | Estimado | Bloqueada por |
|---|-------|--------|----------|---------------|
| 001 | Detección de Proximidad y Prompt "Presiona E" | ⬜ Ready | 3-4 h | Controlador del Jugador |
| 002 | Recogida de Pista → Inventario | ⬜ Ready | 3 h | Story 001 + GameManager 002 |
| 003 | Overlay de Inspección de Objeto | ⬜ Ready | 3-4 h | Story 001 |

---

## 🎤 Voz / PTT — Core
**Archivo:** `production/epics/voz-ptt/EPIC.md`  
**Responsable:** Sofía

| # | Story | Estado | Estimado | Bloqueada por |
|---|-------|--------|----------|---------------|
| — | ⚠️ Stories no creadas aún | — | — | Backend Stories 001+002 |

> **Acción Diego:** Ejecutar `/create-stories voz-ptt` una vez Martín tenga Backend Story 001 lista (~May 6-7).

---

## Grafo de dependencias

```
GameManager 001 ✅
    └── Cargador de Escena 001
    └── GameManager 002 → 003
                  └── 004 → 005

Backend 001
    ├── Backend 003 (/npc) → Cliente LLM 001 → 002
    ├── Backend 004 (/grammar) → Cliente LLM 003
    └── Backend 002 (/stt) → Voz/PTT epic

Controlador del Jugador 001
    └── Sistema de Interacción 001 → 002, 003

Sistema de Interacción 002
    └── GameManager 002 (necesita add_clue())
```

---

## Semanas próximas

| Semana | Foco | Demo al cierre |
|--------|------|----------------|
| May 5–12 | Backend 001-004 + GameManager 002-005 + Cargador 001-002 | `curl /health` vivo + todos los tests GameManager pasan |
| May 12–19 | Cliente LLM + Player Controller + Interacción 001 | Jugador se mueve, NPC responde por HTTP |
| May 19–26 | Interacción 002-003 + Voz/PTT + Arte pistas | Pickup pista funciona end-to-end |
| May 26–Jun 2 | Integración + playtest | Demo completa: pistas → interrogatorio → acusación |

---

*Al iniciar story: cambiar estado a `🔵 In Progress`.*  
*Al cerrar story: `/story-done production/epics/{epic}/{story}.md` → cambiar a `✅ Done`.*
