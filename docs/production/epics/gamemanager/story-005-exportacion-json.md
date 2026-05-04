# Story 005: Exportación JSON al Disco

> **Epic**: GameManager
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: N/A (control-manifest.md no generado aún)

## Context

**GDD**: `gdd/gdd_detective_noir_vr.md`
**Requirements**: `TR-telemetria-002`, `TR-telemetria-003`

**ADR Governing Implementation**: [ADR-0007: Telemetría de Sesión](../../../docs/architecture/adr-0007-telemetria-sesion.md)
**ADR Decision Summary**: `export_session_json()` escribe `user://sesion_{session_id}_{timestamp}.json` al disco. Flag `_session_exported` previene doble escritura. Conectado a `tree_exiting` (cierre de juego) y a la señal `case_resolved` del módulo Acusación. Verifica permisos de escritura en `_ready()`.

**Engine**: Godot 4.6 GDScript | **Risk**: LOW
**Engine Notes**: `FileAccess.open()` con `user://` — verificar que resuelve correctamente en Windows (AppData/Roaming) y Linux (~/.local/share/godot). No requiere permisos especiales en builds normales. Confirmar en build exportado, no solo en editor.

---

## Acceptance Criteria

- [ ] `export_session_json()` crea un archivo `user://sesion_{session_id}_{timestamp}.json` con todos los campos de `TR-telemetria-003`
- [ ] Si `export_session_json()` se llama dos veces (ej. `case_resolved` + `tree_exiting`), el archivo se escribe solo una vez (flag `_session_exported`)
- [ ] El JSON resultante es parseable (válido según `JSON.parse_string()`)
- [ ] `duration_seconds` refleja correctamente el tiempo transcurrido entre `initialize_session()` y la exportación
- [ ] En `_ready()` de GameManager, se verifica que `user://` tiene permisos de escritura; si falla, se loggea `push_error()` con mensaje descriptivo (no crash)
- [ ] Al conectar a `get_tree().tree_exiting`, `export_session_json()` se llama automáticamente al cerrar el juego sin pasar por el flujo normal

---

## Implementation Notes

*Derivado de ADR-0007:*

```gdscript
func _ready() -> void:
    get_tree().tree_exiting.connect(export_session_json)
    # Verificar permisos user://
    var test_file := FileAccess.open("user://.write_test", FileAccess.WRITE)
    if test_file == null:
        push_error("GameManager: user:// no tiene permisos de escritura. Telemetría no se guardará.")
    else:
        test_file.close()
        DirAccess.remove_absolute(OS.get_user_data_dir() + "/.write_test")

func export_session_json() -> void:
    if _session_exported:
        return
    _session_exported = true
    var ts_end := Time.get_datetime_string_from_system()
    var ts_start_unix := Time.get_unix_time_from_datetime_string(_timestamp_start)
    var ts_end_unix := Time.get_unix_time_from_datetime_string(ts_end)
    var data := {
        "session_id": session_id,
        "timestamp_start": _timestamp_start,
        "timestamp_end": ts_end,
        "duration_seconds": int(ts_end_unix - ts_start_unix),
        "english_level": english_level,
        "completed": completed,
        "correct_accusation": correct_accusation,
        "accusation_attempts": accusation_attempts,
        "clues": clues,
        "npcs_interrogated": npcs_interrogated,
        "grammar_errors_count": grammar_errors_count,
        "anti_stall_triggers": anti_stall_triggers
    }
    var safe_ts := ts_end.replace(":", "-").replace(" ", "_")
    var filename := "user://sesion_%s_%s.json" % [session_id, safe_ts]
    var file := FileAccess.open(filename, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
    else:
        push_error("GameManager: no se pudo escribir %s" % filename)
```

Nota: `tree_exiting` se conecta en `_ready()` — no en `initialize_session()` — para cubrir cierre antes de que el jugador inicie sesión.

---

## Out of Scope

- Stories 001–004: los datos que se exportan (prerequisitos)
- La pantalla de cierre que muestra `session_id` al jugador — pertenece a épica Presentation: HUD/UI

---

## QA Test Cases

- **AC-1**: Archivo JSON creado con campos completos
  - Given: sesión inicializada con datos conocidos (1 pista F1 "good", 1 interrogatorio "barry", 1 acusación correcta)
  - When: `export_session_json()` llamado
  - Then: archivo `user://sesion_*.json` existe; `JSON.parse_string(contenido)` no retorna error; todos los campos de TR-telemetria-003 presentes

- **AC-2**: Doble llamada no duplica archivo
  - Given: `export_session_json()` ya fue llamado una vez
  - When: `export_session_json()` llamado de nuevo
  - Then: solo existe un archivo de sesión (no dos); `_session_exported == true`

- **AC-3**: `duration_seconds` correcto
  - Given: sesión inicializada; 10 segundos transcurridos (real o mock)
  - When: `export_session_json()` llamado
  - Then: `data["duration_seconds"]` entre 9 y 11

- **AC-4**: Conexión a `tree_exiting` funciona
  - Given: sesión activa con datos
  - When: `get_tree().quit()` llamado (simulado en test con `tree_exiting.emit()`)
  - Then: archivo JSON escrito automáticamente

- **AC-5**: JSON parseable por Python
  - Given: archivo exportado
  - When: `python3 -c "import json; json.load(open('sesion_*.json'))"` ejecutado
  - Then: sin error (test manual post-build)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/foundation/gamemanager_export_test.gd` — debe existir y pasar

**Status**: [ ] No creado aún

---

## Dependencies

- Depends on: Stories 001–004 deben estar DONE — todos los datos deben existir antes de exportar
- Unlocks: Épica Feature: Acusación/Final puede conectar `case_resolved` a `export_session_json()`
