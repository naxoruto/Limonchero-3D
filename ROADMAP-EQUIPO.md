# ROADMAP — Limonchero 3D
**Fecha:** 2026-05-03 | **Deadline:** 2026-06-30 | **Tiempo restante:** ~28 días  
**Estado actual:** Motor Godot montado ✓ | LLM Ollama listo ✓ | STT funcionando ✓ | Mundo creado ✓ | GameManager Story 001 ✓

---

## 🗺️ TIMELINE GENERAL

| Sprint | Fechas | Foco |
|--------|--------|------|
| Sprint 0 | May 3–5 | Design: cerrar specs de arte y audio |
| Sprint 1 | May 5–12 | Backend Python + GameManager Godot |
| Sprint 2 | May 12–19 | Player controller, LLM client, Voice/PTT |
| Sprint 3 | May 19–26 | Arte pistas físicas, audio final, NPC prompts |
| Sprint 4 | May 26–Jun 2 | Integración, primer playtest, smoke test |
| Sprint 5 | Jun 2–9 | Bug fixes, balance audio, QA |
| Release | Jun 9–30 | Build Windows/Linux, docs entrega |

---

## 🎨 DISEÑO (Sprint 0 — urgente esta semana)

> Estado del GDD: 95% completo. Solo cerrar gaps de arte/audio y traducir a specs para el equipo.

### Diego — Docs

- [ ] Crear `art/art-style-definition.md` con:
  - Paleta de colores canónica (negro `#0A0A0A`, ámbar `#D4A017`, neón verde `#8BC34A`, burdeos `#6B0F1A`)
  - Estilo visual: low-poly facetado, cartoon-noir, claroscuro, neones
  - Referencias: L.A. Noire, Blade Runner, Sin City, Disco Elysium
  - Reglas de iluminación (ver Level Design — Zones 1-6 tienen specs detalladas)
- [ ] Crear `art/audio-design.md` con:
  - Música: 2 tracks (ambient jazz + briefing/intro)
  - SFX lista (ver abajo §Audio)
  - Balbuceos NPC: specs por personaje (ver abajo §Audio)
- [ ] Crear `art/npc-llm-prompts.md` — prompts LLM canónicos de los 6 NPCs (para Martín)
  - Copiar prompts exactos del GDD §3.3
  - Incluir: idioma obligatorio (ENGLISH ONLY), tono, restricciones, confesión gate de Barry
- [ ] Corregir `CLAUDE.md`: remover "LLM demo: OpenAI GPT-4o-mini o Gemini Flash" → reemplazar por "Ollama exclusivo (llama3.2) — ver ADR-0002"
- [ ] Crear historias épicas sin historias:
  - `/create-stories cargador-escena`
  - `/create-stories controlador-jugador`
  - `/create-stories sistema-interaccion`

---

## 🖥️ BACKEND (Sprint 1 — Martín)

> ⚠️ BLOQUEANTE GLOBAL: todo desarrollo en Godot que usa LLM o STT espera este Sprint.

### Martín — Backend / LLM

#### Setup inicial (si no está hecho)
- [ ] Crear directorio `backend/` en raíz
- [ ] Crear `backend/requirements.txt`:
  ```
  fastapi
  uvicorn[standard]
  httpx
  ollama
  faster-whisper
  pytest
  pytest-asyncio
  ```
- [ ] `python -m venv venv && pip install -r backend/requirements.txt`
- [ ] Verificar Ollama: `ollama run llama3.2 "Say hello in one sentence"`

#### Stories (en orden — cada una tiene su archivo en `production/epics/proxy-backend/`)
- [ ] **Story 001:** FastAPI base + `/health` endpoint
  - Validar: `curl http://localhost:8000/health` retorna `{"status": "ok"}`
- [ ] **Story 003:** `/npc/{id}` proxy a Ollama
  - Input: `{"npc_id": "barry", "history": [...], "message": "..."}`
  - Output: `{"response": "...", "timestamp": "..."}`
  - **CRÍTICO:** Cada NPC tiene su system prompt hardcoded (ver `art/npc-llm-prompts.md`)
  - **CRÍTICO:** Barry solo confiesa si historial incluye F1+F2+F3 presentados
- [ ] **Story 004:** `/grammar` endpoint para Gajito
  - Input: `{"transcript": "...", "language": "english"}`
  - Output: `{"is_correct": bool, "correction": "...", "explanation_es": "..."}`
- [ ] **Story 002:** `/stt` endpoint (faster-whisper, modelo `medium`)
  - Input: WAV binary
  - Output: `{"transcript": "...", "duration_ms": 0}`
  - Coordinar con Sofía para test de latencia

#### NPC Prompts hardcoding (Story 003)
Prompts base desde GDD §3.3 — copiar EXACTO:

| NPC | System prompt |
|-----|--------------|
| Commissioner Spud | `You are Commissioner Spud. ONLY IN ENGLISH. Impatient and condescending. Want quick arrest. Accept evidence if correct suspect presented.` |
| Moni Graná Fert | `You are Moni Graná Fert. ONLY IN ENGLISH. Femme fatale — magnetic, deflects hard questions with flirtation. Deny conflict with Cornelius.` |
| Gerry Broccolini | `You are Gerry Broccolini. ONLY IN ENGLISH. Answer in one or two words when possible. Claim you were in the bathroom. Never explain the 22 missing minutes.` |
| Lola Persimmon | `You are Lola Persimmon. ONLY IN ENGLISH. Helpful and detailed. Precise about your evening except 9:47–10:12 PM. Never mention documents or lawsuit.` |
| Barry Peel | `You are Barry Peel. ONLY IN ENGLISH. Calm, polite, well-dressed. Describe relationship with Cornelius as "business." ONLY crack if presented with trust agreement + master key + gunpowder evidence simultaneously.` |
| Gajito | `Eres Gajito. Hablas con Limonchero en ESPAÑOL. Corriges errores gramaticales del jugador en inglés de forma irónica pero constructiva. Nunca reveles al culpable directamente.` |

---

## 🎮 GODOT — PROGRAMACIÓN (Sprints 1-3 — Ignacio)

### Sprint 1 — Foundation (Completar GameManager)
- [ ] Registrar `scripts/foundation/game_manager.gd` como Autoload `GameManager` en `project.godot`
- [ ] Instalar GUT (Godot Unit Tests) como addon
- [ ] **Story 002 GameManager:** Ciclo de vida de pistas
- [ ] **Story 003 GameManager:** Puerta de confesión
  - Gate: F1 + F2 + F3 marcados `GOOD` + Barry nombrado como acusado
- [ ] **Story 004 GameManager:** Registro de telemetría
- [ ] **Story 005 GameManager:** Exportación JSON
- [ ] **Scene Loader:** Main menu → carga `el_agave_y_la_luna.tscn`

### Sprint 2 — Feature Core (después de Backend Story 001 ✓)
- [ ] **Player Controller** (`scripts/player/player_controller.gd`)
  - [ ] CharacterBody3D + Camera3D
  - [ ] WASD + mouse look (+ joystick support)
  - [ ] Sprint (Shift / L3)
  - [ ] FOV slider 70-110° en menú opciones
- [ ] **LLM Client** (`scripts/ai/llm_client.gd`)
  - [ ] HTTP non-blocking requests a `localhost:8000/npc/{id}`
  - [ ] Timeout de 8s (per GDD §5.2)
  - [ ] Historial conversación por NPC (últimos N mensajes)
  - [ ] Detección servidor caído → error accionable al startup
- [ ] **Interaction System** (`scripts/player/interaction_system.gd`)
  - [ ] Area3D para detectar NPCs/pistas en rango
  - [ ] Press E → menú contextual "Interrogar / Examinar"
  - [ ] Press E en pista → pickup → inventario actualizado
  - [ ] Prompt visual "Presiona E" encima de objetos en rango

### Sprint 3 — Features Restantes
- [ ] **Inventory System** (`scripts/clues/inventory_system.gd`)
  - [ ] Tab abre inventario
  - [ ] Distinguir pistas físicas vs testimonios
  - [ ] 8 slots máximo (GDD canónico)
- [ ] **HUD** (`scripts/ui/hud.gd`)
  - [ ] Subtítulos doble canal (NPC izq. / Jugador der.)
  - [ ] Indicador PTT (pulso + color mientras graba)
  - [ ] "Gajito está pensando…" mientras espera respuesta LLM
  - [ ] Pop-up esquina inf. izq. para correcciones Gajito
- [ ] **NPC Controller** (`scripts/npc/npc_controller.gd`)
  - [ ] Registry de 6 NPCs con sus datos, balbuceo audio path, LLM prompt ID
  - [ ] Balbuceo sincronizado con velocidad de aparición de texto
  - [ ] Confesión gate Barry (verificar F1+F2+F3 en GameManager antes de enviar)
- [ ] **English Assistant** (`scripts/ai/english_assistant.gd`)
  - [ ] POST a `/grammar` con transcript
  - [ ] Si `is_correct == false` → disparar pop-up Gajito con `explanation_es`

---

## 🎤 VOICE / STT (Sprint 2 — Sofía)

> Espera: Backend Story 001 + 002 deben estar live.

- [ ] Verificar faster-whisper modelo `medium`:
  ```bash
  python -c "from faster_whisper import WhisperModel; m = WhisperModel('medium'); print('OK')"
  ```
- [ ] Crear historias épica `voz-ptt`: `/create-stories voz-ptt`
- [ ] **Voice Manager Godot** (`scripts/ai/voice_manager.gd`)
  - [ ] Mantener V (teclado) / LB (mando) activa micrófono
  - [ ] AudioEffectCapture → encode WAV
  - [ ] HTTP POST a `localhost:8000/stt`
  - [ ] Mostrar transcript en HUD canal derecho
- [ ] **Test de latencia STT end-to-end:**
  - Grabar 5 frases de 8 palabras en inglés con acento latino
  - Meta: **≤ 3s** promedio (deja 1s margen para LLM — total ≤ 4s)
  - Documentar en `production/qa/evidence/stt-latency-evidence.md`
- [ ] Verificar precisión STT: **>85% palabras correctas**

---

## 🎵 AUDIO (Sprints 2-3 — Sofía + Diego)

> Todos los archivos van a `assets/audio/`. Exportar como `.ogg` para Godot.

### Música
- [ ] `assets/audio/music/ambient_jazz_loop.ogg` — jazz noir, 3-5 min, loop seamless
  - Fuente sugerida: Incompetech (Kevin MacLeod), YouTube Audio Library, Freesound.org
  - Tags búsqueda: "noir jazz instrumental", "1950s detective", "jazz piano saxophone"
- [ ] `assets/audio/music/intro_briefing.ogg` — tono urgente/presión para escena con Spud

### SFX (`assets/audio/sfx/`)
- [ ] `footsteps_marble.ogg` — pasos en tiles del vestíbulo
- [ ] `footsteps_wood.ogg` — pasos en escenario y bar
- [ ] `footsteps_concrete.ogg` — pasos en pasillo de servicio
- [ ] `footsteps_carpet.ogg` — pasos en corredor interior
- [ ] `rain_exterior_loop.ogg` — lluvia constante en ventanales (loop, volumen bajo)
- [ ] `door_creak.ogg` — puerta de oficina Cornelius
- [ ] `lighter_click.ogg` — encendedor (clic + llama breve)
- [ ] `glass_clink.ogg` — vasos/ceniceros
- [ ] `inventory_pickup.ogg` — al recoger pista
- [ ] `menu_open.ogg` — abrir inventario Tab
- [ ] `interaction_prompt.ogg` — aparecer prompt "Presiona E"
- Fuente: [freesound.org](https://freesound.org) (filtro: CC0)

### Balbuceos NPC (`assets/audio/voices/`)
> Clips cortos 1-3 seg, loop mientras aparece texto (estilo Animal Crossing).

| NPC | Archivo | Descripción | Técnica |
|-----|---------|-------------|---------|
| Commissioner Spud | `babble_spud.ogg` | Grave, seco, interrumpe | Voz masculina grave + pitch -4 semitones |
| Moni Graná Fert | `babble_moni.ogg` | Suave, cadencioso, pausa larga | Voz femenina + reverb corto + pitch +2 |
| Gerry Broccolini | `babble_gerry.ogg` | Monosilábico, gruñido | Grunt masculino + bass boost + pitch -6 |
| Lola Persimmon | `babble_lola.ogg` | Parlanchín, nervioso | Voz femenina rápida + speed x1.3 |
| Barry Peel | `babble_barry.ogg` | Sereno, claro | Voz masculina neutral + mínimo procesado |
| Gajito | `babble_gajito.ogg` | Energético, variable | Voz aguda + pitch +6 o synth beep |

---

## 🗿 ARTE 3D (Sprints 2-3 — Art Team)

> Todos los modelos van a `assets/models/`. Exportar como `.glb` desde Blender.

### Modelos Faltantes

#### Personajes
- [ ] **Cisne Negro** — *clarificar rol antes de modelar:*
  - ¿Es NPC interactivo con diálogo? → necesita rigging + balbuceo
  - ¿Es figura decorativa del escenario (estatua/póster)? → static mesh sin rigging
  - Revisar `narrative/cast-bible.md` — si no está definido, preguntar al equipo de narrativa
- [ ] **Agave** — planta decorativa (vestíbulo/barra, static mesh low-poly)
  - Referencia: agave azul estilizado, tono gris-verde `#5A7A4E`, low-poly facetado

#### Pistas Físicas (10 objetos)

| # | Pista | Descripción modelo | Tamaño aprox. | Prioridad |
|---|-------|-------------------|---------------|-----------|
| R1 | Acuerdo del Fideicomiso | Papel doblado con sello rojo, texto parcialmente legible | 20cm × 15cm | 🔴 Alta |
| R2 | Llave Maestra | Llave latón dorada, corte victoriano | 8cm | 🔴 Alta |
| R3 | Encendedor de Oro | Zippo dorado, grabado en tapa | 6cm | 🔴 CRÍTICA |
| R5 | Puerta Trasera | Ya existe en nivel (marcar interactuable) | — | 🟡 Media |
| R6 | Documentos Quemados | Ceniza y fragmentos de papel en plato metálico | 15cm | 🟡 Media |
| D1 | Maleta de Moni | Maletín vintage años 50, marrón oscuro `#3A1F0A` | 50cm × 30cm | 🟠 Alta |
| D2 | Abrigo Oscuro | Gabardina colgada en perchero, negro `#1A1A1A` | — | 🟡 Media |
| D5 | Copa de Bourbon | Copa baja con líquido ámbar a medio tomar | 8cm | 🟡 Media |
| D3 | Registros Contables | Carpeta manila con papeles, algunos marcados | 25cm | 🟡 Media |

> ⚠️ **R3 el encendedor es CRÍTICO** — Moni lo reconoce como de Barry. Es el testimonio R4 que confirma F3. Sin modelo visible y claro en escena, el jugador no puede completar el caso.

---

## 🔬 TESTING (Sprint 4-5)

### Smoke Test (critical path)
- [ ] Juego carga → menú principal visible
- [ ] Cargar nivel → El Agave y La Luna renderiza ≥ 60 FPS
- [ ] Spud da briefing al inicio
- [ ] Jugador puede moverse WASD + mouse en todas las zonas
- [ ] Press E en pista → pickup → aparece en inventario (Tab)
- [ ] Press E en NPC → menú "Interrogar / Examinar"
- [ ] Mantener V → graba micrófono → transcript aparece en HUD
- [ ] NPC responde en texto (vía LLM) con balbuceo simultáneo
- [ ] Gajito corrige error gramatical (test con frase incorrecta deliberada)
- [ ] Barry confiesa **solo** con F1+F2+F3 + acusación
- [ ] Barry **no** confiesa con menos pruebas
- [ ] Servidor caído → error accionable (no crash)

### Latencia y Precisión
- [ ] STT latencia: ≤ 3s promedio (5 muestras, documentar)
- [ ] LLM latencia: ≤ 8s respuesta NPC (timeout definido en GDD)
- [ ] End-to-end total: ≤ 4s (STT + LLM)
- [ ] STT precisión inglés (acento latino): > 85% palabras correctas

### Build Final
- [ ] Export Windows (`builds/limonchero-win.exe`)
- [ ] Export Linux (`builds/limonchero-linux.x86_64`)
- [ ] Verificar que el servidor Python corre con un script de arranque simple
- [ ] README de instalación para el profesor / evaluador

---

## 🚨 RUTA CRÍTICA (sin esto el juego no funciona)

```
Backend /health (Martín)
    └── Backend /npc/{id} + prompts NPC hardcoded
            └── LLM Client Godot (Ignacio)
                    └── NPC Controller + Diálogo
                            └── Confesión Gate Barry

Backend /stt (Martín) + Voice Manager Godot (Sofía)
    └── Pipeline STT end-to-end

GameManager v2 (Ignacio)
    └── Clue lifecycle → Inventory → Confesión gate check

Physical clues modelados (Art)
    └── Interaction System QA completo
```

**Si falta alguno de estos:** el juego no se puede demostrar funcionalmente.

---

## 👥 RESPONSABILIDADES POR PERSONA

| Persona | Rol | Prioridad inmediata |
|---------|-----|---------------------|
| **Ignacio** | Tech Lead / Godot | GameManager 002-005 → Scene Loader → Player Controller |
| **Martín** | Backend / LLM | Backend Stories 001 → 003 → 004 → 002 (en ese orden) |
| **Sofía** | Audio / STT | Voice/PTT epic Godot + test latencia + producción audio |
| **Diego** | Docs / Design | art-style-definition.md + audio-design.md + NPC prompts spec + crear historias épicas |

---

## 📁 REFERENCIAS RÁPIDAS

| Doc | Path |
|-----|------|
| GDD principal | `gdd/gdd_detective_noir_vr.md` |
| Level Design | `levels/el_agave_y_la_luna.md` |
| Cast Bible | `narrative/cast-bible.md` |
| Art Bible | `art/art-bible.md` |
| Prompts personajes | `art/character-prompts.md` |
| Entity Registry | `registry/entities.yaml` |
| Épicas | `production/epics/` |
| ADRs | `docs/architecture/` |
| Kickoff checklist | `production/KICKOFF-CHECKLIST.md` |

---

*Generado por Claude Code — 2026-05-03. Actualizar al cierre de cada sprint.*
