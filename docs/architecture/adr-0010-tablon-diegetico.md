# ADR-0010: Tablón Diegético — SubViewport sobre Sprite3D para Mostrar Texto NPC

## Estado
Propuesto

## Fecha
2026-05-01

## Compatibilidad con el Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4.6 |
| **Dominio** | Rendering / UI |
| **Riesgo de Conocimiento** | BAJO — SubViewport + Sprite3D es patrón documentado en Godot 4.x |
| **Referencias Consultadas** | Conocimiento directo de Godot 4.6 SubViewport, ViewportTexture, Sprite3D |
| **APIs Post-Corte Usadas** | Ninguna |
| **Verificación Requerida** | Confirmar que `ViewportTexture` sobre `Sprite3D` actualiza en tiempo real en Godot 4.6 sin necesitar llamada explícita de refresh |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0005 (señal npc_response_ready llega al módulo que actualiza el tablón) |
| **Habilita** | Sistema de diálogo NPC — el texto LLM necesita dónde mostrarse |
| **Bloquea** | Ninguno |
| **Nota de Orden** | Implementar junto con NPCDialogue (Feature Layer); el tablón es Presentation Layer |

## Contexto

### Declaración del Problema
Las respuestas de los NPCs deben aparecer en el mundo 3D como parte de la estética noir, no como UI superpuesta en pantalla. El jugador debe poder leer el texto mientras mira al NPC en el espacio del nightclub. Se necesita decidir cómo renderizar texto arbitrario (hasta ~150 palabras) en una superficie 3D de forma que se pueda estilizar y sea fácil de mantener.

### Restricciones
- Sin TTS — el texto es el único output del NPC; debe ser legible
- Godot 4.6 — sin plugins externos
- El texto puede tener hasta 150 palabras (límite `num_predict` del LLM)
- Estética noir: tipografía monoespaciada o serif, fondo oscuro, texto blanco/amarillo
- El tablón debe estar anclado cerca del NPC en el espacio 3D (flotante sobre su cabeza o en un panel físico)

### Requisitos
- Renderizar texto arbitrario en superficie 3D
- Soportar texto largo (scroll o wrapping automático)
- Estilizable con fuente y color propios del proyecto
- Actualizable en tiempo real (cada vez que llega npc_response_ready)
- Ocultable cuando no hay diálogo activo

## Decisión

**Un `SubViewport` contiene un `RichTextLabel` con el texto del NPC. El SubViewport se asigna como `ViewportTexture` a un `Sprite3D` posicionado en el mundo cerca del NPC. El Sprite3D se oculta cuando no hay respuesta activa.**

### Jerarquía de escena

```
NPCNode (CharacterBody3D)
  └── DialogueBoard (Node3D)          ← posicionado sobre el NPC
        ├── Sprite3D                  ← muestra la textura del SubViewport
        │     └── material: ViewportTexture → DialogueViewport
        └── DialogueViewport (SubViewport)
              └── DialoguePanel (PanelContainer)
                    └── ResponseLabel (RichTextLabel)
                          └── [texto NPC aquí]
```

### Implementación

```gdscript
# res://scripts/presentation/dialogue_board.gd
extends Node3D

@onready var _label: RichTextLabel = $DialogueViewport/DialoguePanel/ResponseLabel
@onready var _sprite: Sprite3D = $Sprite3D
@onready var _viewport: SubViewport = $DialogueViewport

func _ready() -> void:
    _sprite.visible = false
    # Asignar ViewportTexture al Sprite3D
    var vp_texture := ViewportTexture.new()
    vp_texture.viewport_path = _viewport.get_path()
    _sprite.texture = vp_texture

func show_response(text: String) -> void:
    _label.text = text
    _sprite.visible = true

func hide_response() -> void:
    _sprite.visible = false
    _label.text = ""
```

```gdscript
# res://scripts/features/npc_dialogue.gd
func _on_npc_response_ready(npc_id: String, text: String) -> void:
    _stop_babble()
    _dialogue_board.show_response(text)
```

### Configuración del SubViewport

```
DialogueViewport (SubViewport):
  - Size: 512 × 256 px (ajustable según tablón físico)
  - Transparent Background: true
  - Update Mode: Always (para que el RichTextLabel actualice en tiempo real)

Sprite3D:
  - Billboard: Disabled (el tablón es fijo en el espacio)
  - Double Sided: true
  - Pixel Size: 0.002 (escala mundo → píxeles)
  - Shaded: false (unlit — el texto siempre visible sin depender de luces)
```

### Estilo visual (noir)

```gdscript
# En el tema del RichTextLabel:
# Fuente: Press Start 2P o Courier Prime (monoespaciada, noir)
# Color de texto: #F5E6C8 (crema envejecido)
# Fondo del panel: #1A1A1A con opacidad 0.85
# Padding: 12px en todos los lados
```

## Alternativas Consideradas

### Alternativa 1: Sprite3D con textura dinámica (Image.draw_string)
- **Descripción:** Generar una `ImageTexture` en código dibujando texto con `Image.draw_string()`
- **Pros:** Sin SubViewport; menor overhead de rendering
- **Contras:** `Image.draw_string()` en Godot 4 tiene soporte limitado de fuentes; sin wrapping automático; muy difícil de estilizar
- **Razón de rechazo:** SubViewport usa el sistema de UI de Godot completo — wrapping, scroll, Rich Text, temas — sin código manual.

### Alternativa 2: Panel 2D en CanvasLayer (no diegético)
- **Descripción:** UI clásica superpuesta en 2D, como subtítulos de videojuego
- **Pros:** Más simple de implementar; sin problemas de resolución 3D→2D
- **Contras:** Rompe la estética noir; el texto flota sobre la pantalla en lugar de existir en el mundo
- **Razón de rechazo:** El GDD especifica presentación diegética — el tablón debe ser parte del mundo del nightclub.

## Consecuencias

### Positivas
- RichTextLabel soporta BBCode — texto en negrita, color, efectos de tipeo si se desea
- El tablón puede posicionarse libremente en el espacio 3D sin depender de la posición de cámara
- El sistema de temas de Godot permite cambiar tipografía y colores sin tocar código
- SubViewport actualiza automáticamente cuando cambia el texto del RichTextLabel

### Negativas
- SubViewport tiene overhead de rendering (renderiza un "segundo frame" interno)
- Resolución fija del SubViewport (512×256) puede verse pixelada en tablones grandes
- Requiere configuración manual en el editor (ViewportTexture no se puede asignar 100% por código en todas las versiones)

### Riesgos
- **Riesgo:** `ViewportTexture.viewport_path` no resuelve correctamente si el SubViewport no está en el árbol en `_ready()`. **Mitigación:** Asignar la textura en `_ready()` después de `add_child()`; verificar que `_viewport.is_inside_tree()` es true.
- **Riesgo:** El texto largo (150 palabras) no cabe en 512×256 sin scroll. **Mitigación:** Aumentar el SubViewport a 512×512 o habilitar `scroll_active = true` en RichTextLabel; el LLM ya tiene `num_predict: 150` que limita la longitud.
- **Riesgo:** El Sprite3D se renderiza en dos caras pero la textura aparece al revés en una. **Mitigación:** Usar `flip_h = true` en el Sprite3D o ajustar la UV del material.

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|-------------------------|
| gdd_detective_noir_vr.md | TR-pista-002: Tablón diegético (3D wall) para mostrar texto NPC y estado de evidencias | SubViewport + Sprite3D posicionado en escena cerca del NPC |
| gdd_detective_noir_vr.md | Estética noir — presentación en el mundo del nightclub | Sprite3D es objeto físico del mundo; no UI superpuesta |

## Implicaciones de Rendimiento
- **CPU:** SubViewport añade un pase de UI adicional por frame mientras el texto es visible; impacto < 0.5ms
- **Memoria:** SubViewport 512×256 RGBA = ~512 KB de VRAM por tablón activo; con 5 NPCs máximo 1 activo simultáneo = despreciable
- **Tiempo de carga:** Sin impacto
- **Red:** Sin impacto

## Plan de Migración
Primera implementación — no hay código existente que migrar.

## Criterios de Validación
- Texto de respuesta NPC aparece en el mundo 3D dentro de 1 frame de recibir `npc_response_ready`
- El tablón es legible desde la distancia de interacción (~2m en el mundo)
- El tablón se oculta cuando el jugador se aleja del NPC o inicia una nueva pregunta
- Texto de 150 palabras no se corta ni desborda el panel
- El Sprite3D no depende de luces del mundo (unlit)

## Decisiones Relacionadas
- ADR-0005: Señales — `npc_response_ready(npc_id, text)` es la señal que dispara `show_response()`
- ADR-0009: Balbuceo — el balbuceo detiene exactamente cuando el tablón muestra el texto
