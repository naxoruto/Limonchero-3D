# Epic: Sistema de Interacción

> **Capa**: Core
> **GDD**: gdd/gdd_detective_noir_vr.md
> **Módulo Arquitectónico**: Sistema de Interacción
> **Estado**: Ready
> **Historias**: No creadas aún — ejecutar `/create-stories sistema-interaccion`

## Visión General

Implementa el `InteractionSystem` que detecta objetos interactuables en proximidad (RayCast3D / Area3D), muestra prompts contextuales en HUD, y gestiona las acciones de tecla E: abrir menú contextual (Interrogar/Examinar), recoger pistas, y abrir el overlay de inspección. Único caller de `GameManager.add_clue()`. Usa capa de física dedicada (capa 3) para interactuables. Gestiona correctamente el cursor cuando el overlay está abierto.

## ADRs Gobernantes

| ADR | Resumen de Decisión | Riesgo Motor |
|-----|---------------------|--------------|
| ADR-0013 | RayCast3D + Area3D; capa física 3 para interactuables; señales `clue_picked`, `npc_context_opened`, `inspect_opened` | LOW |
| ADR-0001 | `add_clue()` es el único escritor de pistas en GameManager | LOW |
| ADR-0005 | Comunicación por señales — sin `get_node()` cross-layer | LOW |

## Requisitos GDD

| TR-ID | Requisito | Cobertura ADR |
|-------|-----------|---------------|
| TR-interact-001 | Detección de proximidad → tecla E, menú contextual (Interrogar/Examinar) | ADR-0013 ✅ |
| TR-interact-002 | Modo inspección de objeto — overlay centrado, Esc para cerrar | ADR-0013 ✅ |
| TR-interact-003 | Recogida de pista → inventario + prompt "¿Agregar como evidencia?" durante diálogo | ADR-0013 ✅ |

## Contrato de API (de architecture.md)

```gdscript
func register_interactable(node: Node3D, type: String) -> void
# type: "clue" | "npc" | "object"

signal clue_picked(clue_id: String)
signal npc_context_opened(npc_id: String)
signal inspect_opened(object_id: String)
```

## Cadena de Recogida de Pista (de architecture.md)

```
Jugador tecla-E sobre objeto pista
  → InteractionSystem emite clue_picked(clue_id)
  → GameManager.add_clue(clue_id)
  → Evidencias/Inventario emite inventory_changed
  → HUD actualiza vista Tab
  → Tablón Diegético actualiza 3D
  → Anti-Estancamiento reinicia temporizadores
  → Overlay de Inspección muestra objeto
```

## Definición de Hecho

Esta épica está completa cuando:
- Todas las historias están implementadas, revisadas y cerradas vía `/story-done`
- RayCast3D detecta interactuables en capa física 3 en build exportado (no solo editor)
- Tecla E abre menú contextual con opciones Interrogar/Examinar según tipo
- Overlay de inspección abre con Esc funcional para cerrar
- `clue_picked` dispara correctamente `GameManager.add_clue()`
- Cursor se libera al abrir overlay y se restaura al cerrar
- Historias de lógica tienen archivos de test en `tests/`

## Siguiente Paso

Ejecutar `/create-stories sistema-interaccion`
