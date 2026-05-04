# Epic: Proxy Backend (FastAPI)

> **Capa**: Foundation* (proceso externo Python)
> **GDD**: gdd/gdd_detective_noir_vr.md
> **Módulo Arquitectónico**: Proxy Backend (Python/FastAPI — proceso separado)
> **Estado**: Ready
> **Historias**: 4 historias — ver tabla abajo

## Visión General

Implementa el servidor Python/FastAPI que actúa como proxy entre Godot y los servicios de IA. Expone tres endpoints: `/stt` (faster-whisper), `/npc/{id}` (Ollama llama3.2), `/grammar` (Gajito vía LLM), y `/health` para verificación de disponibilidad. Proceso separado — no corre dentro de Godot. Verifica conexión con Ollama en `/health` y retorna error descriptivo si no está disponible. Es un contrato: el código Godot no cambia si se intercambia Ollama por GPT-4o-mini.

## ADRs Gobernantes

| ADR | Resumen de Decisión | Riesgo Motor |
|-----|---------------------|--------------|
| ADR-0002 | LLM: Ollama + llama3.2 local; `num_predict: 150`; fallback a gemma2:2b si timeout | LOW |
| ADR-0003 | FastAPI proceso separado; lanzado por `BackendLauncher` con `OS.create_process()`; lifecycle gestionado por Godot | LOW |

## Requisitos GDD

| TR-ID | Requisito | Cobertura ADR |
|-------|-----------|---------------|
| TR-backend-001 | FastAPI: `/stt` `/npc/{id}` `/grammar`; detección sin conexión al arrancar | ADR-0003 ✅ |

## Contrato de Endpoints

```
POST /stt
  Body: { audio: <base64 WAV> }
  Response: { text: string }

POST /npc/{npc_id}
  Body: { history: Array, system_prompt: string }
  Response: { response: string }

POST /grammar
  Body: { text: string }
  Response: { error: bool, correction: string }

GET /health
  Response: { status: "ok" | "ollama_unavailable" }
```

## Definición de Hecho

Esta épica está completa cuando:
- Todas las historias están implementadas, revisadas y cerradas vía `/story-done`
- Los 4 endpoints responden correctamente con Ollama corriendo
- `/health` retorna `ollama_unavailable` si Ollama no está disponible (no crash)
- faster-whisper modelo `medium` carga sin error en Linux y Windows
- Latencia `/stt` + `/npc/{id}` combinada ≤ 4s en hardware de prueba (TR-voz-002)
- Instrucciones de setup documentadas en README

## Historias

| # | Historia | Tipo | Estado | ADR |
|---|----------|------|--------|-----|
| 001 | [Estructura Base + /health](story-001-estructura-base-health.md) | Logic | Ready | ADR-0003 |
| 002 | [Endpoint /stt](story-002-endpoint-stt.md) | Integration | Ready | ADR-0003 |
| 003 | [Endpoint /npc/{id}](story-003-endpoint-npc.md) | Integration | Ready | ADR-0002, ADR-0003 |
| 004 | [Endpoint /grammar](story-004-endpoint-grammar.md) | Integration | Ready | ADR-0002, ADR-0003 |

## Siguiente Paso

Ejecutar `/story-readiness production/epics/proxy-backend/story-001-estructura-base-health.md` para comenzar implementación.
