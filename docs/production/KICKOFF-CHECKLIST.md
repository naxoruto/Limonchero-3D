# Checklist de Arranque — Limonchero 3D

**Fecha:** 2026-05-02
**Deadline:** Fin de junio 2026
**Estado:** 3 épicas con historias listas (GameManager, Proxy Backend, Cliente LLM) — 4 épicas sin historias aún

---

## Prerequisitos de Setup — TODOS

- [ ] Sincronizar repo y verificar que `production/epics/` es visible
- [ ] Instalar Godot 4.6 *(Ignacio, Sofía)*
- [ ] Instalar Python 3.10+ con pip *(Martín, Sofía)*
- [ ] Instalar Ollama + descargar modelo: `ollama pull llama3.2` *(Martín — verificar en el hardware más lento del equipo)*

---

## Ignacio — Tech Lead / Godot

### Esta semana
- [ ] Crear proyecto Godot 4.6 en directorio raíz del repo
- [ ] Registrar `scripts/foundation/game_manager.gd` como Autoload `GameManager` en `project.godot`
- [ ] Instalar GUT (Godot Unit Tests) como addon del proyecto
- [ ] Code review de `scripts/foundation/game_manager.gd` (ya implementado)
- [ ] Cerrar Story 001 GameManager → `/story-done production/epics/gamemanager/story-001-inicializacion-sesion.md`
- [ ] Implementar Story 002 GameManager (ciclo de vida de pistas) → `production/epics/gamemanager/story-002-ciclo-vida-pistas.md`
- [ ] Implementar Story 004 GameManager (registro de telemetría) → `production/epics/gamemanager/story-004-registro-telemetria.md`
- [ ] Implementar Story 003 GameManager (puerta de confesión) → `production/epics/gamemanager/story-003-puerta-confesion.md`
- [ ] Implementar Story 005 GameManager (exportación JSON) → `production/epics/gamemanager/story-005-exportacion-json.md`

### Próxima semana
- [ ] Implementar épica `cliente-llm` (3 historias) → `production/epics/cliente-llm/`
- [ ] Crear historias épicas Core faltantes → `/create-stories controlador-jugador`, `/create-stories sistema-interaccion`, `/create-stories cargador-escena`
- [ ] Implementar `cargador-escena` (menú principal + transición al nivel)

---

## Martín — Backend / LLM

### Setup inmediato
- [ ] Crear directorio `backend/` en raíz del repo
- [ ] Crear `backend/requirements.txt`:
  ```
  fastapi
  uvicorn[standard]
  httpx
  ollama
  faster-whisper
  pytest
  pytest-asyncio
  httpx[asyncio]
  ```
- [ ] `python -m venv venv && pip install -r backend/requirements.txt`
- [ ] Verificar Ollama: `ollama run llama3.2 "Respond in one sentence: who are you?"`

### Historias en orden
- [ ] Story 001 Proxy Backend — FastAPI base + `/health` → `production/epics/proxy-backend/story-001-estructura-base-health.md`
- [ ] Story 003 Proxy Backend — `/npc/{id}` proxy a Ollama → `production/epics/proxy-backend/story-003-endpoint-npc.md`
- [ ] Story 004 Proxy Backend — `/grammar` Gajito → `production/epics/proxy-backend/story-004-endpoint-grammar.md`
- [ ] Story 002 Proxy Backend — `/stt` faster-whisper → `production/epics/proxy-backend/story-002-endpoint-stt.md` *(coordinar con Sofía para prueba de audio)*

### Flujo por historia
```
/story-readiness [path] → /dev-story [path] → /code-review → /story-done [path]
```

---

## Sofía — Audio / STT

### Setup inmediato
- [ ] Verificar faster-whisper modelo `medium`:
  ```bash
  python -c "from faster_whisper import WhisperModel; m = WhisperModel('medium'); print('OK')"
  ```
- [ ] Crear historias épica `voz-ptt` ��� `/create-stories voz-ptt`

### Historias
- [ ] Implementar épica `voz-ptt` (Godot) una vez Martín tenga Story 001 proxy-backend done → `production/epics/voz-ptt/`
- [ ] Prueba de latencia STT end-to-end: grabar frase de 8 palabras en inglés → medir tiempo hasta texto transcrito
  - Meta: **≤ 3s** (deja 1s de margen para LLM — total ≤ 4s per TR-voz-002)
- [ ] Documentar resultado en `production/qa/evidence/stt-latency-evidence.md`
- [ ] Verificar precisión STT con acento latino: 5 frases de prueba → meta **>85% palabras correctas**

---

## Diego — Docs / Design

### Inmediato
- [ ] Crear historias épicas sin historias:
  - `/create-stories cargador-escena`
  - `/create-stories controlador-jugador`
  - `/create-stories sistema-interaccion`
- [ ] Corregir `CLAUDE.md` línea "LLM demo: OpenAI GPT-4o-mini o Gemini Flash" → reemplazar por "LLM: Ollama exclusivo (llama3.2) — ver ADR-0002"
- [ ] Ejecutar `/setup-engine` para registrar Godot 4.6 en `technical-preferences.md`

### Ongoing
- [ ] Actualizar `registry/entities.yaml` cuando cambien valores de diseño en cualquier GDD
- [ ] Crear sprint plan una vez todas las épicas tengan historias → `/sprint-plan`
- [ ] Mantener `production/epics/index.md` actualizado con estado de historias

---

## Dependencias Críticas (orden de desbloqueo)

```
GameManager (Ignacio) ──────────────────► TODO lo demás en Godot
Proxy Backend Story 001 (Martín) ────────► Voz/PTT (Sofía), Cliente LLM (Ignacio)
Proxy Backend Story 003 /npc (Martín) ───► Diálogo NPC (Feature layer)
Proxy Backend Story 004 /grammar (Martín) ► Gajito (Feature layer)
Cliente LLM Story 001 (Ignacio) ─────────► Cliente LLM Stories 002 + 003
Voz/PTT (Sofía) ─────────────────────────► Diálogo NPC end-to-end
```

---

## Referencias rápidas

| Doc | Path |
|-----|------|
| Épicas Foundation | `production/epics/{gamemanager,proxy-backend,cliente-llm,cargador-escena}/` |
| Épicas Core | `production/epics/{controlador-jugador,sistema-interaccion,voz-ptt}/` |
| Arquitectura | `docs/architecture/architecture.md` |
| ADRs | `docs/architecture/adr-000*.md` |
| GDD principal | `gdd/gdd_detective_noir_vr.md` |
| Entidades canónicas | `registry/entities.yaml` |
