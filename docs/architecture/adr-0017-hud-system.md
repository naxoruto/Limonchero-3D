# ADR-0017: Sistema HUD (HUD System)

## Estado
Propuesto

## Fecha
2026-05-02

## Compatibilidad de Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4 |
| **Dominio** | UI / Presentation |
| **Riesgo de Conocimiento** | LOW — CanvasLayer, Label, RichTextLabel, AnimationPlayer son APIs estables desde Godot 4.0 |
| **Referencias Consultadas** | ADR-0001 (señales), ADR-0009 (balbuceo), ADR-0013 (InteractionSystem), ADR-0014 (NPCDialogueManager), ADR-0015 (InventoryHUD), ADR-0016 (GajitoModule), TR-ui-001, TR-ui-002 |
| **APIs Post-Cutoff Usadas** | Ninguna |
| **Verificación Requerida** | Subtítulos legibles en 1280×720 y 1920×1080; indicador PTT visible en esquina con iluminación de neón oscura |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0013 (señal `interaction_prompt_requested`), ADR-0014 (señal `npc_response_ready`), ADR-0015 (señal `inventory_opened/closed`), ADR-0016 (señal `grammar_correction_ready`) |
| **Habilita** | Implementación completa de epic "Interrogatorio" y "Gajito pop-up" |
| **Bloquea** | Nada — el HUD es capa de presentación pura |
| **Nota de Orden** | HUD debe inicializarse después de GameManager (ADR-0001) y NPCDialogueManager (ADR-0014) |

---

## Contexto

El juego necesita un HUD 2D superpuesto al mundo 3D que presente:
1. Subtítulos en dos canales (jugador + NPC) durante interrogatorios
2. Indicador de estado PTT (micrófono activo / procesando)
3. Pop-up de corrección de Gajito (ADR-0016)
4. Prompt de interacción contextual ("Presiona E para interactuar")
5. Ajustes de accesibilidad: FOV slider y tamaño de fuente de subtítulos

El HUD no gestiona lógica — solo escucha señales y actualiza presentación.

---

### Declaración del Problema

El juego tiene múltiples módulos que necesitan mostrar texto o indicadores al jugador sin 3D: subtítulos de NPC, feedback de STT, correcciones de inglés, prompts de interacción. Sin un HUD centralizado, cada módulo crearía su propia UI, generando conflictos de capas y duplicación.

### Restricciones

- HUD en español (menus, labels, prompts) — NPCs responden en inglés, pero los labels del UI son ES
- Subtítulos de NPC en inglés (texto que manda el LLM)
- Pop-up Gajito en español
- HUD no debe bloquear la vista 3D cuando no hay contenido activo
- InventoryHUD (ADR-0015) se muestra en lugar del HUD durante Tab — el HUD base se oculta

---

## Decisión

**El HUD se implementa como autoload `HUDManager` en capa `CanvasLayer` con z_index alto. Escucha señales de módulos Foundation/Feature y actualiza nodos Label/AnimationPlayer. Sin lógica de juego — presentación pura.**

### Estructura de Nodos

```
HUDManager (CanvasLayer, layer=10)
  ├── SubtitlePanel (PanelContainer — parte inferior, 80% ancho centrado)
  │     ├── PlayerSubtitle (RichTextLabel — canal izquierdo, texto jugador)
  │     └── NPCSubtitle (RichTextLabel — canal derecho, texto NPC, typewriter)
  ├── PTTIndicator (HBoxContainer — esquina superior izquierda)
  │     ├── MicIcon (TextureRect — ícono micrófono)
  │     └── PTTLabel (Label — "Grabando..." / "Gajito pensando...")
  ├── InteractionPrompt (Label — centro inferior, sobre subtítulos)
  │     # Ej: "Presiona E para interrogar" / "Presiona E para inspeccionar"
  └── GajitoPopup (PanelContainer — esquina superior derecha, visible breve)
        └── GajitoLabel (RichTextLabel — corrección en español)
```

### Estados del PTT Indicator

```
IDLE     → MicIcon oculto, PTTLabel oculto
RECORDING → MicIcon visible (pulso animado), PTTLabel = "Grabando..."
PROCESSING → MicIcon visible (estático), PTTLabel = "Gajito pensando..."
```

### Subtítulos — Lógica Typewriter

```gdscript
# res://scripts/foundation/hud_manager.gd
const TYPEWRITER_SPEED := 0.03  # segundos por carácter

func _show_npc_subtitle(text: String) -> void:
    _npc_subtitle.visible_characters = 0
    _npc_subtitle.text = text
    _typewriter_tween = create_tween()
    _typewriter_tween.tween_property(
        _npc_subtitle, "visible_characters", len(text),
        len(text) * TYPEWRITER_SPEED
    )

func _show_player_subtitle(text: String) -> void:
    _player_subtitle.text = "[i]" + text + "[/i]"
    _player_subtitle.visible = true
    # Auto-ocultar tras 4 s
    get_tree().create_timer(4.0).timeout.connect(_player_subtitle.hide)
```

### Señales Escuchadas

```gdscript
func _ready() -> void:
    NPCDialogueManager.npc_response_ready.connect(_on_npc_response)
    NPCDialogueManager.testimony_available.connect(_on_testimony_available)
    GajitoModule.grammar_correction_ready.connect(_on_grammar_correction)
    InteractionSystem.interaction_prompt_changed.connect(_on_prompt_changed)
    AudioCaptureManager.recording_started.connect(_on_recording_started)
    AudioCaptureManager.recording_stopped.connect(_on_recording_stopped)
    LLMClient.request_sent.connect(_on_processing_started)
    LLMClient.npc_response_ready.connect(_on_processing_done)
    InventoryHUD.inventory_opened.connect(_on_inventory_opened)
    InventoryHUD.inventory_closed.connect(_on_inventory_closed)
```

### Accesibilidad (TR-ui-002)

```gdscript
# Settings guardados en GameManager o ConfigFile
var subtitle_font_size: int = 16   # rango: 12–24
var fov: float = 90.0              # rango: 70.0–110.0

func apply_settings(font_size: int, p_fov: float) -> void:
    _player_subtitle.add_theme_font_size_override("normal_font_size", font_size)
    _npc_subtitle.add_theme_font_size_override("normal_font_size", font_size)
    get_viewport().get_camera_3d().fov = p_fov
```

Settings expuestos en menú de pausa — fuera del scope de este ADR.

---

## Alternativas Consideradas

### Alternativa A: HUD distribuido — cada módulo gestiona su UI
- **Pros:** Sin dependencia centralizada; cada módulo autocontenido.
- **Contras:** Conflictos de z_index entre capas; duplicación de nodos CanvasLayer; imposible coordinar cuándo ocultar elementos (ej. inventario abierto debe suprimir subtítulos).
- **Razón de rechazo:** La coordinación entre capas requiere un punto central.

### Alternativa B: HUD como nodo en la escena del nivel
- **Pros:** Sin autoload adicional.
- **Contras:** Se destruye si el nivel se recarga; acoplado a la jerarquía de `el_agave_y_la_luna.tscn`; más difícil de testear en aislamiento.
- **Razón de rechazo:** Patrón inconsistente con Foundation layer (ADR-0001, ADR-0014).

---

## Consecuencias

### Positivas
- Coordinación centralizada de capas UI — inventario abierto suprime subtítulos limpiamente.
- Typewriter sincronizado con balbuceo (ADR-0009) sin acoplamiento directo — ambos responden a `npc_response_ready`.
- Accesibilidad (font size, FOV) gestionada en un solo lugar.

### Negativas
- Un autoload más en Foundation layer. Aceptado — la capa de presentación justifica separación.
- `HUDManager` depende de señales de 5+ módulos. Si un módulo cambia su señal, HUD debe actualizarse. Mitigable documentando señales en este ADR.

### Riesgos
- **Riesgo:** Subtítulos NPC no limpian si `npc_response_ready` llega durante inventario abierto. **Mitigación:** `_on_inventory_opened` pone flag `_hud_suppressed = true`; `_show_npc_subtitle` retorna early si flag activo.
- **Riesgo:** Tween typewriter no cancela si llega segunda respuesta NPC antes de terminar primera. **Mitigación:** `_show_npc_subtitle` llama `_typewriter_tween.kill()` antes de crear nuevo tween.

---

## Requisitos GDD Abordados

| Requisito | Cómo lo aborda este ADR |
|-----------|------------------------|
| TR-ui-001 — Subtítulos 2 canales + PTT indicator + Gajito overlay | `SubtitlePanel` (PlayerSubtitle + NPCSubtitle) + `PTTIndicator` + `GajitoPopup` |
| TR-ui-002 — FOV slider 70–110°, subtitle font size ajustable | `apply_settings(font_size, fov)` en HUDManager |

---

## Criterios de Validación

- Al recibir respuesta NPC, `NPCSubtitle` muestra texto en typewriter y `PlayerSubtitle` muestra lo que dijo el jugador en cursiva.
- Al mantener V, `PTTIndicator` cambia a estado `RECORDING` con pulso animado.
- Al soltar V y esperar respuesta backend, `PTTIndicator` cambia a `PROCESSING` ("Gajito pensando...").
- Al recibir corrección de GajitoModule, `GajitoPopup` aparece en esquina superior derecha y se auto-oculta tras 5 s.
- Con inventario Tab abierto, subtítulos no aparecen aunque llegue `npc_response_ready`.
- Font size de subtítulos cambia en tiempo real al modificar el slider en menú de pausa.
- FOV cambia en tiempo real entre 70° y 110°.

---

## Decisiones Relacionadas

- [ADR-0009](adr-0009-balbuceo-npc.md) — Balbuceo se activa en paralelo con typewriter de subtítulos
- [ADR-0014](adr-0014-npc-dialogue-module.md) — Fuente de `npc_response_ready` y `testimony_available`
- [ADR-0015](adr-0015-inventory-module.md) — InventoryHUD suprime HUD base cuando está abierto
- [ADR-0016](adr-0016-gajito-module.md) — Fuente de `grammar_correction_ready`
