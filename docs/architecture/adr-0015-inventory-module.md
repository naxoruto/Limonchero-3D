# ADR-0015: Módulo de Inventario (Inventory Module)

## Estado
Propuesto

## Date
2026-05-01

## Engine Compatibility

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4 |
| **Dominio** | UI / Feature |
| **Riesgo de Conocimiento** | LOW — CanvasLayer, Control nodes y GridContainer son APIs estables desde Godot 4.0 |
| **Referencias Consultadas** | ADR-0001 (clue_added, clue_state_changed, get_clue_state), ADR-0010 (tablón diegético), TR-pista-001/002/003 |
| **APIs Post-Cutoff Usadas** | Ninguna |
| **Verificación Requerida** | GridContainer en resoluciones 1280×720 y 1920×1080; texto de descripción no desborda slot a 8 pistas simultáneas |

## ADR Dependencies

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0001 (señales clue_added / clue_state_changed; método get_clue_state — estado canónico de pistas) |
| **Habilita** | ADR-0017 HUD System (el HUD necesita saber cuándo el inventario está abierto para ocultar otros elementos) |
| **Bloquea** | Epic "Vista de Inventario" — no puede implementarse sin este ADR |
| **Nota de Orden** | InventoryHUD debe estar en la escena antes de que el jugador pueda recoger su primera pista |

---

## Contexto

### Problema
No existe un ADR que documente cómo se implementa la vista de inventario Tab: qué nodos usa, cómo distingue pistas físicas de testimonios, cómo muestra los tres estados (BUENA/NO_BUENA/SIN_REVISAR), y cómo se abre/cierra. El tablón diegético 3D (ADR-0010) muestra las pistas en el mundo; el inventario Tab es su complemento legible en pantalla plana, esencial para el flujo de acusación.

### Restricciones
- El estado de las pistas vive en `GameManager.clues` (ADR-0001) — este módulo **solo lee**, nunca escribe.
- `inventory_slots` = 8 (rango seguro 6–10, CLAUDE.md). La vista debe funcionar con 0 a 8 pistas.
- UI en español (labels, estados, descripciones de UI).
- Contenido de las pistas en inglés (texto de la pista en sí — ej. "A master key for the upstairs office").
- La vista de inventario bloquea el movimiento del jugador mientras está abierta — debe llamar `enable_input(false)` (ADR-0012).
- Tecla Tab (teclado) / Select/View (mando) abre y cierra. Mismo toggle.

### Requisitos
- Mostrar hasta 8 slots de pistas en una cuadrícula
- Distinguir tipo: pista física (borde dorado + icono lupa) vs testimonio (borde azul + icono diálogo)
- Mostrar estado por pista: BUENA (fondo verde oscuro), NO_BUENA (fondo rojo oscuro), SIN_REVISAR (fondo gris)
- Actualizar en tiempo real cuando `clue_state_changed` se emite (sin recargar la vista)
- Abrir/cerrar con Tab; congelar movimiento mientras está abierto
- Slots vacíos visibles como placeholders (8 siempre presentes, vacíos antes de recoger)

---

## Decisión

`InventoryHUD` es una escena `CanvasLayer` (`inventory_hud.tscn`) instanciada en el nivel. Al presionar Tab, `PlayerController` emite `inventory_toggled(open: bool)` o `InventoryHUD` escucha directamente la acción `open_inventory` del Input Map. La vista usa un `GridContainer` de 4×2 slots (4 columnas, 2 filas), cada slot es un `PanelContainer` con un `Label` (nombre de pista) y un `TextureRect` (icono tipo). El estilo visual usa `StyleBoxFlat` con colores noir.

`InventoryHUD` conecta `GameManager.clue_added` y `GameManager.clue_state_changed` en su `_ready()` para actualizar la cuadrícula de forma reactiva. No sondea GameManager — solo responde a señales.

### Diagrama de Arquitectura

```
InventoryHUD (CanvasLayer — layer 10)
└── PanelContainer "inventory_panel"
    ├── VBoxContainer
    │   ├── Label "Inventario de Pistas" (título)
    │   └── GridContainer (columns=4)
    │       ├── ClueSlot [×8]  (PanelContainer)
    │       │   ├── TextureRect "icon"        (lupa o diálogo)
    │       │   ├── Label "clue_name"
    │       │   ├── Label "clue_state_label"  (BUENA / NO_BUENA / SIN_REVISAR)
    │       │   └── StyleBoxFlat aplicado según estado + tipo
    │       └── (slots 6-8: vacíos / placeholder gris)
    └── Label "Tab para cerrar"

Flujo apertura:
  Input Map "open_inventory" (Tab / Select)
    └── InventoryHUD._on_toggle()
          ├── visible = !visible
          ├── PlayerController.enable_input(!visible)
          └── _refresh_all_slots()  ← lee GameManager.clues completo en apertura

Flujo actualización reactiva:
  GameManager.clue_added(clue_id)         → _add_slot(clue_id)
  GameManager.clue_state_changed(clue_id, state) → _update_slot(clue_id, state)
```

### Interfaces Clave

```gdscript
# res://scripts/ui/inventory_hud.gd
extends CanvasLayer

# ── Constantes visuales ───────────────────────────────────────────────────────
const MAX_SLOTS: int = 8

const STATE_COLORS: Dictionary = {
    "good":      Color(0.1, 0.3, 0.1),   # verde oscuro noir
    "not_good":  Color(0.3, 0.1, 0.1),   # rojo oscuro noir
    "unchecked": Color(0.2, 0.2, 0.2)    # gris oscuro
}

const STATE_LABELS: Dictionary = {
    "good":      "BUENA",
    "not_good":  "NO_BUENA",
    "unchecked": "SIN_REVISAR"
}

# Tipos de pista (determinados por prefijo de clue_id)
# F1-F5 = física, R1-R5 = testimony, D1-D2 = red herring
const TESTIMONY_PREFIXES: Array[String] = ["R"]

# ── Nodos ─────────────────────────────────────────────────────────────────────
@onready var grid: GridContainer = $Panel/VBox/GridContainer
@onready var slot_nodes: Array = []  # Array[PanelContainer] — 8 elementos pre-instanciados

# ── Señales ───────────────────────────────────────────────────────────────────
signal inventory_opened()
signal inventory_closed()

# ── API pública ───────────────────────────────────────────────────────────────
func _ready() -> void:
    visible = false
    GameManager.clue_added.connect(_on_clue_added)
    GameManager.clue_state_changed.connect(_on_clue_state_changed)

func _on_toggle() -> void:
    visible = !visible
    get_node("/root/Player").enable_input(!visible)
    if visible:
        _refresh_all_slots()
    if visible: inventory_opened.emit() else: inventory_closed.emit()

func _on_clue_added(clue_id: String) -> void:
    _update_slot_data(clue_id, GameManager.get_clue_state(clue_id))

func _on_clue_state_changed(clue_id: String, state: String) -> void:
    _update_slot_data(clue_id, state)

func _refresh_all_slots() -> void:
    for clue_id in GameManager.clues.keys():
        _update_slot_data(clue_id, GameManager.get_clue_state(clue_id))
```

### Esquema Visual de Slot

```
┌──────────────────────────┐
│ [🔍]  Master Key         │  ← icono lupa (física) | icono 💬 (testimonio)
│       NO_BUENA           │  ← estado en español
│  borde dorado / azul     │  ← color según tipo
│  fondo rojo oscuro       │  ← color según estado
└──────────────────────────┘
```

---

## Alternativas Consideradas

### Alternativa A: SubViewport renderizado como textura
- **Descripción**: El inventario se renderiza en un SubViewport y se muestra como textura sobre el mundo 3D.
- **Pros**: Aspecto diegético — aparece como si fuera un panel físico en el mundo.
- **Contras**: Overhead de renderizado innecesario para una UI de información estática. `CanvasLayer` es el patrón estándar de Godot 4 para UI de pantalla completa.
- **Razón de Rechazo**: Complejidad injustificada. El tablón diegético 3D (ADR-0010) ya cubre el aspecto inmersivo.

### Alternativa B: Lista vertical scrollable en lugar de grid
- **Descripción**: Un `ScrollContainer` + `VBoxContainer` con una fila por pista.
- **Pros**: Escalable a más de 8 pistas sin rediseñar la vista.
- **Contras**: `inventory_slots = 8` es un límite fijo del diseño — no habrá más de 8 pistas. Un grid de 4×2 es más compacto y permite comparar visualmente todas las pistas a la vez.
- **Razón de Rechazo**: El grid de slots fijos comunica mejor el límite del inventario y facilita la comparación durante la acusación.

---

## Consecuencias

### Positivas
- `InventoryHUD` solo lee — nunca escribe en GameManager. Separación limpia de responsabilidades.
- Actualización reactiva via señales — sin polling. La vista siempre está sincronizada sin overhead.
- 8 slots siempre visibles (vacíos o llenos) comunican visualmente el límite del inventario al jugador.
- `STATE_LABELS` en español y `STATE_COLORS` como constantes — fácil de ajustar sin tocar lógica.

### Negativas
- `get_node("/root/Player")` para llamar `enable_input` crea un acoplamiento por path. Mitigable con grupo Godot `"player"` o señal.
- Iconos de tipo requieren assets (texturas lupa/diálogo). Si los assets no están listos, usar `Label` con "[F]" / "[T]" como placeholder temporal.

### Riesgos
- **Riesgo**: `_refresh_all_slots()` en apertura recorre todas las pistas de `GameManager.clues` — si hay muchas llamadas rápidas de apertura/cierre, puede parpadear. **Mitigación**: La apertura con Tab tiene debounce natural del input. No es un problema práctico con ≤8 pistas.
- **Riesgo**: `get_node("/root/Player")` falla si la escena del jugador se renombra. **Mitigación**: Usar `get_tree().get_nodes_in_group("player")[0]` o emitir señal `inventory_opened/closed` que `PlayerController` escucha.
- **Riesgo**: `TESTIMONY_PREFIXES = ["R"]` es frágil si se añaden nuevos clue_ids con prefijo R que no sean testimonios. **Mitigación**: Definir tipo de pista en `entities.yaml` (registry de entidades) y leerlo desde allí en una iteración posterior.

---

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|------------------------|
| gdd_detective_noir_vr.md / TR-pista-001 | 8 slots, distingue pistas físicas de testimonios | GridContainer 4×2 con TESTIMONY_PREFIXES; iconos + bordes distintos por tipo |
| gdd_detective_noir_vr.md / TR-pista-002 | Tab para vista de inventario legible (complemento al tablón 3D) | CanvasLayer toggled con acción `open_inventory` (Tab / Select) |
| gdd_detective_noir_vr.md / TR-pista-003 | Estado por pista: BUENA / NO_BUENA / SIN_REVISAR | `STATE_LABELS` y `STATE_COLORS` aplicados por slot; actualización reactiva via `clue_state_changed` |
| gdd_detective_noir_vr.md / RF-08 | Inventario accesible con Tab que distingue tipos de pista | Tab toggle + GridContainer con iconos tipo + labels estado |
| CLAUDE.md / inventory_slots | Valor canónico 8 (rango 6–10) | `MAX_SLOTS = 8` en InventoryHUD |

---

## Implicaciones de Rendimiento
- **CPU**: Negligible — 8 slots, actualización por señal O(1). Sin animaciones complejas.
- **Memoria**: Una escena CanvasLayer ligera. Sin texturas grandes (iconos ≤ 64×64 px).
- **Tiempo de Carga**: Ninguno — InventoryHUD instanciado junto con el nivel.
- **Red**: Ninguno.

---

## Plan de Migración
ADR nuevo — no hay código existente que migrar.

Integración:
1. Instanciar `inventory_hud.tscn` en `el_agave_y_la_luna.tscn`.
2. Añadir acción `open_inventory` al Input Map (Tab + Select/View del mando).
3. `PlayerController` o `InventoryHUD` escucha la acción en `_input()` — preferible en `InventoryHUD` para mantener la lógica de UI dentro de su escena.
4. Reemplazar `get_node("/root/Player")` por grupo `"player"` si el path cambia.

---

## Criterios de Validación
- Al recoger F1 (cenicero), aparece un slot con nombre, icono lupa, borde dorado y estado "SIN_REVISAR".
- Al recoger R4 (testimonio Moni), aparece con icono diálogo y borde azul.
- Al cambiar estado de F1 a "good" con `GameManager.set_clue_state("F1", "good")`, el slot actualiza a fondo verde y label "BUENA" sin cerrar/abrir el inventario.
- Con 8 pistas recogidas, no aparece ningún slot extra.
- Al abrir con Tab, el jugador no puede moverse. Al cerrar con Tab, el movimiento se restaura.
- Los 8 slots siempre son visibles, los vacíos muestran placeholder gris.

---

## Decisiones Relacionadas
- [ADR-0001](adr-0001-gamemanager-singleton.md) — clue_added, clue_state_changed, get_clue_state — fuente de verdad
- [ADR-0010](adr-0010-tablon-diegetico.md) — Tablón diegético 3D complementario a esta vista Tab
- [ADR-0012](adr-0012-player-controller.md) — enable_input(false/true) para congelar movimiento al abrir
- [ADR-0013](adr-0013-interaction-system.md) — add_clue_sin_confirmacion forbidden pattern — pickup siempre via confirmación
- [ADR-0017](adr-0017-hud-system.md) — HUD System coordina visibilidad con InventoryHUD
