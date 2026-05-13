# Epic: Cargador de Escena

> **Capa**: Foundation
> **GDD**: gdd/gdd_detective_noir_vr.md
> **Módulo Arquitectónico**: Cargador de Escena
> **Estado**: Ready
> **Historias**: No creadas aún — ejecutar `/create-stories cargador-escena`

## Visión General

Implementa el módulo `SceneLoader` que gestiona las transiciones de escena del juego: `main_menu.tscn` → `el_agave_y_la_luna.tscn` → escena final. Garantiza que el estado de GameManager persista entre escenas y que la transición al nivel de juego solo ocurra después de que el backend esté disponible (`backend_ready`). Sin TR-IDs directos — módulo de infraestructura requerido por el orden de inicialización definido en `architecture.md`.

## ADRs Gobernantes

| ADR | Resumen de Decisión | Riesgo Motor |
|-----|---------------------|--------------|
| ADR-0001 | GameManager autoload persiste entre escenas; SceneLoader consume su estado | LOW |
| ADR-0003 | Transición al nivel bloqueada hasta `backend_ready`; BackendLauncher en menú principal | LOW |

## Orden de Inicialización (de architecture.md)

```
1. Godot arranca → Autoload: GameManager (primero)
2. SceneLoader carga main_menu.tscn
3. Menú: jugador ingresa session_id + selecciona nivel de inglés
4. BackendLauncher.launch_backend() → health check con 3 reintentos
   → Si falla: panel de error, botón "Iniciar" deshabilitado
   → Si OK: botón "Iniciar" habilitado
5. Jugador confirma → SceneLoader carga el_agave_y_la_luna.tscn
6. Al resolver caso → SceneLoader carga escena final
```

## Contrato de API (de architecture.md)

```gdscript
func load_scene(path: String) -> void
# Consume: GameManager (estado persistido entre escenas)
# Usa: SceneTree.change_scene_to_file()
```

## Definición de Hecho

Esta épica está completa cuando:
- Todas las historias están implementadas, revisadas y cerradas vía `/story-done`
- Transición `main_menu → el_agave_y_la_luna` solo ocurre con backend `200 OK`
- GameManager mantiene estado completo después de cambio de escena
- Botón "Iniciar" deshabilitado mientras backend no responde
- Escena final carga correctamente tras `case_resolved`

## Siguiente Paso

Ejecutar `/create-stories cargador-escena`
