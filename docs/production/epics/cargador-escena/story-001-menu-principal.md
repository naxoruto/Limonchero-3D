# Story 001: Menú Principal y Detección de Backend

> **Epic**: Cargador de Escena
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic + UI
> **Estimate**: 3-4 horas

## Context

**ADR Governing Implementation**: [ADR-0003: Inicialización del Backend](../../../docs/architecture/adr-0003-backend-init.md)  
**ADR Decision Summary**: Transición al nivel bloqueada hasta `backend_ready`. BackendLauncher hace health check con 3 reintentos. Si falla → error accionable, botón "Iniciar" deshabilitado.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `main_menu.tscn` carga al iniciar el juego
- [ ] Menú tiene campo de texto para `session_id` y botón "Iniciar Investigación"
- [ ] Al mostrar el menú, se intenta health check a `http://localhost:8000/health`
  - Si responde `200`: botón "Iniciar" habilitado, label verde "Backend listo"
  - Si falla tras 3 reintentos (timeout 2s c/u): botón deshabilitado, label rojo "Servidor no disponible — inicia `uvicorn backend.main:app`"
- [ ] Botón "Iniciar" llama `GameManager.initialize_session(session_id, "intermediate")` y carga `el_agave_y_la_luna.tscn`
- [ ] No hay crash si el backend no está disponible — solo UI bloqueada con mensaje

## Implementation Notes

```gdscript
# scenes/main_menu.tscn → scripts/ui/main_menu.gd
extends Control

@onready var start_button: Button = $VBox/StartButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var session_input: LineEdit = $VBox/SessionInput

func _ready() -> void:
    start_button.disabled = true
    _check_backend()

func _check_backend() -> void:
    var http := HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_health_response.bind(http))
    http.request("http://localhost:8000/health")

func _on_health_response(result, code, _headers, _body, http: HTTPRequest) -> void:
    http.queue_free()
    if result == HTTPRequest.RESULT_SUCCESS and code == 200:
        start_button.disabled = false
        status_label.text = "Backend listo"
        status_label.modulate = Color.GREEN
    else:
        status_label.text = "Servidor no disponible — inicia uvicorn backend.main:app"
        status_label.modulate = Color.RED

func _on_start_pressed() -> void:
    var sid := session_input.text.strip_edges()
    if sid.is_empty():
        sid = "session_" + str(Time.get_unix_time_from_system())
    GameManager.initialize_session(sid, "intermediate")
    get_tree().change_scene_to_file("res://scenes/el_agave_y_la_luna.tscn")
```

## Test File

`tests/unit/foundation/scene_loader_menu_test.gd`  
- Test: backend disponible → botón habilitado  
- Test: backend no disponible → botón deshabilitado, sin crash
