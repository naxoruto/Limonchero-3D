# Epic: Cliente LLM

> **Capa**: Foundation
> **GDD**: gdd/gdd_detective_noir_vr.md
> **Módulo Arquitectónico**: Cliente LLM
> **Estado**: Ready
> **Historias**: 3 historias — ver tabla abajo

## Visión General

Implementa el nodo `LLMClient` que encapsula toda comunicación HTTP con el Proxy Backend (FastAPI en localhost). Expone métodos para peticiones NPC, verificación gramatical (Gajito) y health check. Nunca lanza excepciones — errores y timeouts siempre se emiten como señales. El backend es un contrato: cambiar Ollama por GPT-4o-mini no requiere cambios en código Godot.

## ADRs Gobernantes

| ADR | Resumen de Decisión | Riesgo Motor |
|-----|---------------------|--------------|
| ADR-0002 | LLM exclusivo Ollama + llama3.2; timeout 8s; `num_predict: 150` para hardware lento | LOW |
| ADR-0003 | Backend FastAPI proceso separado; `check_backend_health()` con 3 reintentos en menú principal | LOW |

## Requisitos GDD

| TR-ID | Requisito | Cobertura ADR |
|-------|-----------|---------------|
| TR-llm-001 | HTTP POST localhost → FastAPI → Ollama/GPT-4o-mini | ADR-0002 ✅ |
| TR-llm-002 | Timeout 8s por respuesta de NPC | ADR-0002 ✅ |
| TR-llm-003 | Ollama + llama3.2 para todas las fases (Ollama exclusivo) | ADR-0002 ✅ |

## Contrato de API (de architecture.md)

```gdscript
var base_url: String = "http://localhost:8000"
var timeout_sec: float = 8.0

func send_npc_request(npc_id: String, history: Array, player_text: String) -> void
func send_grammar_check(player_text: String) -> void
func check_backend_health() -> bool

signal npc_response_received(npc_id: String, response_text: String)
signal grammar_response_received(has_error: bool, correction: String)
signal backend_offline()
signal request_timeout(request_type: String)
```

## Definición de Hecho

Esta épica está completa cuando:
- Todas las historias están implementadas, revisadas y cerradas vía `/story-done`
- `send_npc_request()` emite `npc_response_received` o `request_timeout` — nunca bloquea
- Timeout 8s funciona correctamente con `Timer` o `OS.get_ticks_msec()`
- `check_backend_health()` hace hasta 3 reintentos antes de emitir `backend_offline`
- Ningún método lanza excepción — todos los errores van a señales
- Historias de lógica tienen archivos de test en `tests/`

## Historias

| # | Historia | Tipo | Estado | ADR |
|---|----------|------|--------|-----|
| 001 | [Estructura Base + Health Check](story-001-estructura-base-health-check.md) | Logic | Ready | ADR-0003 |
| 002 | [Petición NPC con Timeout](story-002-peticion-npc-timeout.md) | Integration | Ready | ADR-0002, ADR-0003 |
| 003 | [Verificación Gramatical](story-003-verificacion-gramatical.md) | Integration | Ready | ADR-0002, ADR-0003 |

## Siguiente Paso

Ejecutar `/story-readiness production/epics/cliente-llm/story-001-estructura-base-health-check.md`
