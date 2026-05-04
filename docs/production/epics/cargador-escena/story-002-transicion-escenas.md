# Story 002: SceneLoader — Transiciones con Fade

> **Epic**: Cargador de Escena
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 horas

## Context

**ADR Governing Implementation**: ADR-0001 (GameManager persiste entre escenas), ADR-0003  
**Engine**: Godot 4.6 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `SceneLoader` registrado como Autoload en `project.godot`
- [ ] `SceneLoader.load_scene(path: String)` cambia escena con fade-out (0.3s) → change → fade-in (0.3s)
- [ ] `GameManager` mantiene todo su estado después del cambio de escena (clues, session_id, etc.)
- [ ] Si `path` no existe → push_error, sin crash
- [ ] Usado por: main_menu (Story 001) y escena final cuando `GameManager.completed == true`

## Implementation Notes

```gdscript
# scripts/foundation/scene_loader.gd
extends Node

@onready var anim: AnimationPlayer = $AnimationPlayer

func load_scene(path: String) -> void:
    if not ResourceLoader.exists(path):
        push_error("SceneLoader: scene not found — " + path)
        return
    anim.play("fade_out")
    await anim.animation_finished
    get_tree().change_scene_to_file(path)
    anim.play("fade_in")
```

Crear `AnimationPlayer` con dos animaciones:
- `fade_out`: ColorRect negro opacity 0→1 en 0.3s
- `fade_in`: ColorRect negro opacity 1→0 en 0.3s

## Test File

`tests/unit/foundation/scene_loader_transition_test.gd`  
- Test: path inválido → push_error, sin crash  
- Test: GameManager.session_id persiste después de llamar load_scene
