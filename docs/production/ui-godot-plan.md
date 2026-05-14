# Plan de Implementación UI — Godot

> **Empieza:** ahora  
> **Prioridad:** Sprint 1 (entrega domingo)  
> **Dependencia global:** Story 110 → todo lo demás

---

## Fase G1 — Fundación (prerequisito, ~1h)

| Orden | Story | Archivo | Qué hacer | Depende de |
|-------|-------|---------|-----------|------------|
| **G1.1** | **110 — UI Theme** | `story-110-ui-theme.md` | Cargar Special Elite .ttf en Godot, aplicar theme.tres en Project Settings | — |
| **G1.2** | **Main Menu** | `cargador-escena/story-001` | Crear `main_menu.tscn` con session_id input, health check, botón Iniciar | 110 |
| **G1.3** | **101 — HUDManager** | `story-101-hud-manager.md` | Crear HUDManager.tscn como Autoload + nodos base + crosshair | 110 |

---

## Fase G2 — HUD Core (Sprint 2-3, ~5h)

| Orden | Story | Archivo | Qué hacer |
|-------|-------|---------|-----------|
| G2.1 | **Interacción 001 — Prompt E** | `sistema-interaccion/story-001` | InteractionPrompt label en HUD, texto contextual `[E] Examinar` |
| G2.2 | ~~102 — Subtítulos~~ ✅ **HECHO** | `story-102-subtitles-typewriter.md` | **Subtítulos descartados** (chat ya cubre el diálogo). Efecto typewriter aplicado al `DialogueUI` (`game/scripts/ui/dialogue.gd`) — 40 cps configurable, status "Pensando..." durante espera LLM + animación. |
| G2.3 | **103 — PTT Indicator** | `story-103-ptt-indicator.md` | 3 estados IDLE/RECORDING/PROCESSING + pulso ámbar |
| G2.4 | **104 — Gajito Popup** | `story-104-gajito-popup.md` | Popup verde lima, layer 15, queue prioridad |
| G2.5 | **105 — Notif. Inventario** | `story-105-inventory-notification.md` | "[pista] añadida" 1.5s center-top |

---

## Fase G3 — Overlays (Sprint 3, ~7h)

| Orden | Story | Archivo | Qué hacer |
|-------|-------|---------|-----------|
| G3.1 | **106 — Inventario Notebook** | `story-106-inventory-notebook.md` | Tab abre libreta diegética, grid 4×2, sellos, columnas |
| G3.2 | **113 — Inspect Overlay** | `story-113-inspect-overlay.md` | Objeto centrado, rotar/zoom, botón inventario |
| G3.3 | **107 — Pause + Settings** | `story-107-pause-settings.md` | ESC menu, FOV slider, font size, persistencia ConfigFile |
| G3.4 | **111 — Anti-Stall** | `story-111-anti-stall.md` | Hints contextuales de Gajito por tiempo |

---

## Fase G4 — Resolución (Sprint 4, ~5h)

| Orden | Story | Archivo | Qué hacer |
|-------|-------|---------|-----------|
| G4.1 | **108 — Árbol Acusación** | `story-108-accusation-tree.md` | Checkboxes evidencias, campo nombre, acusar |
| G4.2 | **109 — Case Resolution** | `story-109-case-resolution.md` | BUENA/MALA sellos, session_id, volver menú |
| G4.3 | **112 — Accesibilidad** | `story-112-accessibility.md` | Contraste, daltonismo, navegación teclado |

---

## Grafo de implementación

```
G1.1 (Theme) ──────────────────────────────────────┐
    │                                               │
    ├── G1.2 (Main Menu) ─── listo para entregar ──┤
    │                                               │
    └── G1.3 (HUDManager) ─────────────────────────┤
            │                                      │
            ├── G2.1 (Prompt E) ─────┐             │
            ├── G2.2 (Subtítulos) ───┤             │
            ├── G2.3 (PTT) ──────────┤             │
            ├── G2.4 (Gajito) ───────┤ ← Sprint 3 │
            ├── G2.5 (Notif) ────────┘             │
            │                                      │
            ├── G3.1 (Inventario) ───┐             │
            ├── G3.2 (Inspect) ──────┤             │
            ├── G3.3 (Pausa) ────────┤ ← Sprint 3 │
            └── G3.4 (AntiStall) ────┘             │
                                                   │
G3.1 ─── G4.1 (Acusación) ─── G4.2 (Resolución) ──┤ ← Sprint 4
                              G4.3 (Accesibilidad) ─┘
```

---

## Para la entrega del domingo

Con ~6h de trabajo alcanzas:

| Si haces | Resultado |
|----------|-----------|
| **G1.1 + G1.2** (~3h) | Main menu funcional con fuente, theme, health check, y botón Iniciar |
| **+ G1.3 + G2.1** (~5h) | + HUDManager con crosshair y prompt de interacción en el nivel |
| **+ G2.2 + G2.3** (~8h) | + Subtítulos NPC y PTT indicator — demo de diálogo funcional |

¿Por dónde empiezo? G1.1 (Theme) es el prerequisito de literalmente todo — 5 minutos de trabajo.
