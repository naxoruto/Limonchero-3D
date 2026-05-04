# Story 002: Configuración de FOV en Menú de Opciones

> **Epic**: Controlador del Jugador
> **Status**: Ready
> **Layer**: Core
> **Type**: UI + Logic
> **Estimate**: 2 horas

## Context

**GDD Requirement**: RNF-05 — FOV ajustable 70–110° en menú de opciones (slider)  
**ADR Governing Implementation**: ADR-0012  
**Engine**: Godot 4.6 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] Menú de pausa (Escape) tiene slider de FOV con rango 70–110°
- [ ] Cambiar slider actualiza `Camera3D.fov` en tiempo real (sin necesidad de confirmar)
- [ ] Valor de FOV persiste en `ConfigFile` (`user://settings.cfg`) entre sesiones
- [ ] Al iniciar, `PlayerController` lee FOV guardado antes de mostrar primer frame
- [ ] Valor por defecto: 80°

## Implementation Notes

```gdscript
# scripts/ui/pause_menu.gd (fragmento)
const SETTINGS_PATH := "user://settings.cfg"

@onready var fov_slider: HSlider = $Panel/VBox/FovSlider

func _ready() -> void:
    fov_slider.min_value = 70
    fov_slider.max_value = 110
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS_PATH) == OK:
        fov_slider.value = cfg.get_value("video", "fov", 80)
    fov_slider.value_changed.connect(_on_fov_changed)

func _on_fov_changed(value: float) -> void:
    var player := get_tree().get_first_node_in_group("player")
    if player:
        player.camera.fov = value
    var cfg := ConfigFile.new()
    cfg.load(SETTINGS_PATH)
    cfg.set_value("video", "fov", value)
    cfg.save(SETTINGS_PATH)
```

## Test File

`tests/unit/core/fov_config_test.gd`  
- Test: slider cambio → camera.fov actualizado  
- Test: ConfigFile guarda y recupera valor correctamente
