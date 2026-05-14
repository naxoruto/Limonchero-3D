# Épicas e Historias — Limonchero 3D
**Actualizado:** 2026-05-14  
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
| **Presentation: HUD/UI** | **Presentation** | **Ignacio** | **13** **(5 refs + 8 nuevas)** | **~28-37 h** | **3-4** |

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

## 🖥️ Presentation: HUD/UI — Presentation
**Archivo:** `production/epics/presentation-hud-ui/EPIC.md`  
**Responsable:** Ignacio Cuevas  
**Filosofía:** Diegética adaptada a PC — notebook en mano, HUD mínimo, menús como umbral.

### Stories referenciadas (existentes en otros epics)

| # | Epic origen | Story | Estado | Resumen UI |
|---|-------------|-------|--------|------------|
| R1 | Cargador de Escena | 001 — Menú Principal | ⬜ Ready | Pantalla inicio + health check backend |
| R2 | Controlador del Jugador | 002 — FOV Settings | ⬜ Ready | Slider FOV en panel de configuración |
| R3 | Sistema de Interacción | 001 — Prompt E | ⬜ Ready | HUD texto contextual `[E] Examinar` |
| R4 | Sistema de Interacción | 002 — Notif. Inventario | ⬜ Ready | HUD notificación 1.5s al recoger pista |
| R5 | Sistema de Interacción | 003 — Overlay Inspección | ⬜ Ready | CanvasLayer centrado con objeto |

### Stories nuevas (dentro de este epic)

| # | Story | Archivo | Estimado | Depende de | Descripción |
|---|-------|---------|----------|------------|-------------|
| 101 | HUDManager Autoload | `story-101-hud-manager.md` | 3-4h | Interacción 001 | Singleton CanvasLayer, estructura base, señales |
| 102 | Subtítulos Dual-Channel | `story-102-subtitles-typewriter.md` | 3-4h | 101 | NPC/Player subtítulos, typewriter 0.03s/car |
| 103 | Indicador PTT (3 estados) | `story-103-ptt-indicator.md` | 2-3h | 101 + Voz/PTT | IDLE/RECORDING/PROCESSING |
| 104 | Popup Gajito | `story-104-gajito-popup.md` | 2h | 101 + LLM Client 003 | Layer 15, auto-dismiss 5s |
| 105 | Notificación Inventario | `story-105-inventory-notification.md` | 1h | 101 + R4 | "[pista] añadida" center-top, 1.5s |
| 106 | Inventario Notebook (Tab) | `story-106-inventory-notebook.md` | 4-5h | GameManager 002 | Grid 4×2, 8 slots, estados BUENA/MALA |
| 107 | Pause Menu + Settings | `story-107-pause-settings.md` | 3-4h | 101 + R2 | ESC menu, FOV slider, font size, volumen |
| 108 | Árbol de Acusación | `story-108-accusation-tree.md` | 3-4h | GameManager 003 | Checkboxes, nombrar acusado, confirmar |
| 109 | Pantallas Resolución | `story-109-case-resolution.md` | 2h | 108 | Caso resuelto/fallido + session_id |
| 110 | UI Theme + Fuentes | `story-110-ui-theme.md` | 1-2h | — | theme.tres con Special Elite + art bible colors |
| 111 | Anti-Stall Hints | `story-111-anti-stall.md` | 1-2h | GameManager 003 | Hints contextuales de Gajito por tiempo |
| 112 | Accesibilidad | `story-112-accessibility.md` | 2-3h | 107 | Contraste, daltonismo, font scaling |
| 113 | Overlay Inspección (refinar) | `story-113-inspect-overlay.md` | 2h | R5 | Zoom mouse, rotación, botón inventario |

> 📝 **Nota:** Las stories R1-R5 se implementan dentro de sus epics originales. Este epic las referencia para trazabilidad. Las stories 101-113 son implementación directa de este epic.

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

Presentation HUD/UI 101 (HUDManager)
    ├── Interacción 001 (prompt + crosshair)
    ├── 102 → 103 → 104 → 105 (capa HUD)
    ├── 110 (theme) → todas las demás
    └── GameManager 003 (confession gate) → 108 (acusación) → 109 (resolución)
```

---

## Semanas próximas

| Semana | Foco | Demo al cierre |
|--------|------|----------------|
| May 5–12 | Backend 001-004 + GameManager 002-005 + Cargador 001-002 | `curl /health` vivo + todos los tests GameManager pasan |
| May 12–19 | Cliente LLM + Player Controller + Interacción 001 + Iniciar Voz/PTT | Jugador se mueve, NPC responde por HTTP |
| May 19–26 | **HUD/UI Epic (pesado)** + Interacción 002-003 + Voz/PTT + Arte pistas | HUD funcional, pickup pista, inventario Tab, subtítulos NPC |
| May 26–Jun 2 | Integración + completar UI + playtest | Demo completa: pistas → interrogatorio → acusación con UI |

---

*Al iniciar story: cambiar estado a `🔵 In Progress`.*  
*Al cerrar story: `/story-done production/epics/{epic}/{story}.md` → cambiar a `✅ Done`.*
