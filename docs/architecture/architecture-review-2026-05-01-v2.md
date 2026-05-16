# Reporte de Architecture Review — Limonchero 3D (v2)

**Fecha:** 2026-05-01
**Motor:** Godot 4.6 (CLAUDE.md + architecture.md — `.claude/docs/technical-preferences.md` aún `[TO BE CONFIGURED]`, ejecutar `/setup-engine`)
**GDDs revisados:** `gdd/gdd_detective_noir_vr.md` (v0.3), `levels/el_agave_y_la_luna.md`, `narrative/cast-bible.md`, `narrative/world-rules.md`, `registry/entities.yaml`
**ADRs revisados:** ADR-0001 → ADR-0016 (16 totales, todos status `Propuesto`)
**Línea base TR:** 27 requisitos (de `tr-registry.yaml` v1.0)
**Reviewer:** `/architecture-review full` (segunda corrida tras adopción de ADR-0011..0016)
**Review previa:** `architecture-review-2026-05-01.md`

---

## Resumen Trazabilidad

| Métrica | Anterior (v1) | Actual (v2) | Δ |
|---------|---------------|-------------|---|
| Total requisitos | 27 | 27 | 0 |
| ✅ Cubierto | 11 | **25** | +14 |
| ⚠️ Parcial | 7 | 1 | -6 |
| ❌ Gap | 9 | 1 | -8 |

Tasa de cobertura completa: **92.6%** (25/27).

---

## Matriz de Trazabilidad Completa

| TR-ID | Sistema | Requisito | Cobertura ADR | Status |
|-------|---------|-----------|---------------|--------|
| TR-jugador-001 | Player | FPS movement — CharacterBody3D + Camera3D, WASD/mouse + gamepad | ADR-0012 | ✅ |
| TR-jugador-002 | Player | Sprint (Shift / L3) | ADR-0012 | ✅ |
| TR-interact-001 | Interaction | Proximidad → tecla E, menú contextual | ADR-0013 | ✅ |
| TR-interact-002 | Interaction | Overlay inspección — Esc cierra | ADR-0013 | ✅ |
| TR-interact-003 | Interaction | Pickup → inventario + prompt "¿Agregar evidencia?" | ADR-0013 + ADR-0014 | ✅ |
| TR-pista-001 | Inventory | 8 slots, físicas vs testimonios | ADR-0015 | ✅ |
| TR-pista-002 | Inventory | Tablón diegético + Tab HUD | ADR-0010 + ADR-0015 | ✅ |
| TR-pista-003 | Inventory | Estados BUENA/NO_BUENA/SIN_REVISAR | ADR-0001 + ADR-0008 + ADR-0015 | ✅ |
| TR-npc-001 | NPC | 5 NPCs prompts únicos + historial | ADR-0006 + ADR-0014 | ✅ |
| TR-npc-002 | NPC | Balbuceo por NPC sincronizado con texto | ADR-0009 | ✅ |
| TR-voz-001 | Voice/STT | PTT V/LB → AudioEffectCapture → WAV → FastAPI | ADR-0004 | ✅ |
| TR-voz-002 | Voice/STT | Latencia ≤ 4s end-to-end, >85% precisión | ADR-0003 + ADR-0004 | ✅ |
| TR-llm-001 | LLM | HTTP POST localhost → FastAPI → LLM | ADR-0002 + ADR-0003 | ✅ |
| TR-llm-002 | LLM | Timeout 8s por respuesta NPC | ADR-0002 | ✅ |
| TR-llm-003 | LLM | Ollama exclusivo (todas las fases) | ADR-0002 | ✅ |
| TR-gajito-001 | Gajito | Evaluador gramatical → corrección español pop-up | ADR-0016 | ✅ |
| TR-gajito-002 | Gajito | Evaluación paralela a respuesta NPC | ADR-0016 | ✅ |
| TR-acus-001 | Accusation | Árbol Papolicia, hasta 3 evidencias | ADR-0014 | ✅ |
| TR-acus-002 | Accusation | Puerta confesión: F1+F2+F3 BUENAS + Barry | ADR-0008 + ADR-0014 | ✅ |
| TR-estado-001 | Game State | GameManager autoload | ADR-0001 | ✅ |
| TR-estado-002 | Anti-Stall | Hints L1/L2/L3 a 4/5/7 min | ADR-0011 | ✅ |
| TR-ui-001 | HUD | 2-canales subtítulos, indicador PTT, pop-up Gajito | ADR-0004 (PTT) + ADR-0010 (subt. NPC) + ADR-0016 (Gajito) | ⚠️ Parcial — sin ADR-0017 que coordine |
| TR-ui-002 | HUD | Slider FOV 70–110°, tamaño subtítulos | — | ❌ GAP |
| TR-backend-001 | Backend | FastAPI /stt /npc/{id} /grammar; offline detection | ADR-0003 | ✅ |
| TR-nivel-001 | Level Selector | Selector menú principal | ADR-0006 | ✅ |
| TR-nivel-002 | NPC Dialogue | Prompt condicionado por nivel inglés | ADR-0006 + ADR-0014 | ✅ |
| TR-telemetria-001 | Session Log | GameManager registra eventos | ADR-0001 + ADR-0007 | ✅ |
| TR-telemetria-002 | Session Log | Export JSON automático | ADR-0007 | ✅ |
| TR-telemetria-003 | Session Log | Campos JSON completos | ADR-0007 | ✅ |

---

## Coverage Gaps

| TR-ID | Sistema | Requisito | ADR sugerido | Capa | Riesgo motor |
|-------|---------|-----------|--------------|------|--------------|
| TR-ui-002 | HUD | Slider FOV + tamaño subtítulos | `/architecture-decision hud-system` (ADR-0017) | Presentation | LOW |
| TR-ui-001 | HUD | Coordinación 2 canales + PTT + Gajito | mismo ADR-0017 | Presentation | LOW |

---

## Conflictos Cross-ADR (rerun)

### 🟡 T1 — Nombres campo telemetría: ADR-0001 obsoleto vs ADR-0007 canónico

**Tipo:** Integration Contract / State Schema
**Documentos:** ADR-0001 vs ADR-0007 vs architecture.md vs ADR-0011 vs ADR-0014

| Fuente | npc count | anti-stall counter |
|--------|-----------|--------------------|
| ADR-0001 (líneas 85, 88) | `npc_interrogation_counts: Dictionary` | `antistall_hints_fired: int` |
| ADR-0001 línea 104 | — | `register_antistall_hint(level: int)` |
| ADR-0007 (líneas 103, 105, 117–119) | `npcs_interrogated: Dictionary` | `anti_stall_triggers: Dictionary {L1,L2,L3}` |
| architecture.md (líneas 330, 333) | `npcs_interrogated` | `anti_stall_triggers: Dictionary` |
| architecture.md línea 345 | — | `register_antistall_hint(level: int)` (obsoleto, debe removerse) |
| ADR-0011 (líneas 49, 84, 115) | — | `anti_stall_triggers["L1"|"L2"|"L3"] += 1` (string keys) |
| ADR-0014 línea 245 | `npc_interrogation_counts["lola"]` | — |

**Impacto:** Runtime — ADR-0011 escribe a `anti_stall_triggers["L1"]` que ADR-0001 no declara. ADR-0014 incrementa `npc_interrogation_counts` mientras export JSON serializa `npcs_interrogated`. Telemetría rota en ambos casos.

**Resolución (ADR-0007 como canónico):**
1. ADR-0001 línea 85 → cambiar `npc_interrogation_counts` a `npcs_interrogated`.
2. ADR-0001 líneas 88 + 104 → eliminar `antistall_hints_fired: int` y `register_antistall_hint`. Reemplazar con `anti_stall_triggers: Dictionary = {"L1":0,"L2":0,"L3":0}` (declaración) — incremento se hace desde ADR-0011 directamente.
3. architecture.md línea 345 → eliminar `register_antistall_hint(level: int) -> void`.
4. ADR-0014 línea 245 → cambiar `npc_interrogation_counts` a `npcs_interrogated`.

---

### 🟡 T2 — ID culpable Barry: `barry_peel` vs `barry`

**Tipo:** Naming (Identifier)
**Documentos:** ADR-0008 vs ADR-0007/0009/0014/CLAUDE.md

| Fuente | ID usado |
|--------|----------|
| CLAUDE.md (canónico) | `barry` |
| ADR-0007 línea 65, 75 | `barry` |
| ADR-0009 línea 55 | `barry/` (audio path) |
| ADR-0014 línea 114 | `barry` |
| ADR-0014 línea 162 | `barry_peel` (inconsistente intra-doc) |
| ADR-0014 línea 243 | `"barry peel"` (con espacio) |
| ADR-0008 (líneas 35, 57, 74, 80, 86, 119, 121) | `barry_peel` (CULPRIT_ID constant) |

**Impacto:** Comparación `npc_id != "barry_peel"` falla si InteractionSystem.npc_menu_requested pasa `"barry"` (canónico de cast bible). Caso A de acusación dispara fallo cuando el jugador acusa correctamente.

**Resolución:** Unificar a `"barry"` (canónico CLAUDE.md). Patch:
- ADR-0008 línea 57: `const CULPRIT_ID := "barry"`. Reemplazar todas las ocurrencias de `"barry_peel"` por `"barry"` en líneas 35, 74, 80, 86.
- ADR-0014 línea 162: cambiar `"barry_peel"` → `"barry"`.
- ADR-0014 línea 243: cambiar `"barry peel"` → `"barry"`.

---

### 🟢 M1 — Mapeo testimonios incorrecto en ADR-0014

**Tipo:** Narrative/Identifier mapping
**Documento:** ADR-0014 línea 120

ADR-0014 mapea `TESTIMONY_TRIGGERS["moni"] = [{"keywords": ["yellow suit", "yellow coat", "upstairs"], "clue_id": "F3"}]`.

Según GDD §3.4 + cast-bible:
- **R3** = encendedor de oro. Confirmado por Moni: *"That's Barry's lighter..."* — esta confirmación marca F3=GOOD.
- **R4** = testimonio Moni "yellow suit upstairs" → distinto de R3.
- **F3** según ADR-0008 línea 37 = `"lighter_barry"` (encendedor).

Las keywords `yellow suit / coat / upstairs` corresponden a R4, no a F3. Si "yellow suit" dispara `add_clue("F3")` en ADR-0014, F3 (lighter_barry) recibe estado UNCHECKED por testimonio equivocado, no por la frase del lighter.

**Resolución:** Decisión narrativa — ¿F3 debe mapearse al lighter o al testimonio "yellow suit"? Sugerencia: mantener F3=lighter; añadir entrada separada `R4` en TESTIMONY_TRIGGERS para "yellow suit"; el reconocimiento del lighter por Moni dispara `set_clue_state("F3","good")` desde un trigger separado (frase diferente).

---

### 🟢 M2 — Header section idioma mixto

ADRs 1-10: `## Estado` (español).
ADRs 11-16: `## Status` (inglés).

Cosmético, sin impacto runtime. Recomendación: unificar a `## Estado` para alinear con resto del repo + scripts grep.

---

### 🟢 M3 — ADR-0011 redactado en inglés

ADR-0011 entero en inglés mientras ADRs 12-16 + 1-10 en español. Inconsistencia para equipo hispanohablante.

**Resolución:** traducir ADR-0011 a español o explicitar política bilingüe en CLAUDE.md.

---

### Conflictos resueltos desde review v1

| # v1 | Tema | Estado v2 |
|------|------|-----------|
| 🔴 #1 | Clue state nested + lowercase | ✅ Resuelto (ADR-0001/0007/0008/arch.md alineados) |
| 🔴 #2 | accusation_attempts Array vs int | ✅ Resuelto (Array en ADR-0001 + ADR-0007) |
| 🔴 #3 | Nombres campos telemetría | ⚠️ Parcial — ADR-0007 + arch.md alineados; ADR-0001 quedó stale → T1 |
| 🔴 #4 | LLM Ollama-only vs dual-stack | ✅ Resuelto (ADR-0002 canónico, GDD/arch.md actualizados) |
| 🔴 #5 | Backend lifecycle init order | ✅ Resuelto (arch.md step 4 referencia ADR-0003) |
| 🔴 #6 | Plataforma Linux/Windows | ✅ Resuelto (ADR-0003 línea 92 `python3` cond Linux/macOS) |
| 🟡 #7 | Confession gate split | ✅ Resuelto (ADR-0008 mantiene split, arch.md alineado) |
| 🟡 #8 | NPC ID convention | ⚠️ Parcial — ADR-0007/0009 canónico; ADR-0008 + parts of ADR-0014 stale → T2 |
| 🟡 Minor TR refs | ADR-0009/0010 wrong TR | (no re-verificado en v2 — flagged para auditor) |

---

## Orden de Implementación ADRs (Topológico)

Sin ciclos detectados. Todas las dependencias `Depende De` resueltas.

```
Capa Fundación (sin dependencias):
  1. ADR-0001  GameManager singleton
  2. ADR-0002  Ollama LLM exclusivo

Fundación+ (← 0001/0002):
  3. ADR-0003  Backend FastAPI               ← 0002
  4. ADR-0005  Arquitectura señales          ← 0001
  5. ADR-0007  Telemetría sesión             ← 0001
  6. ADR-0008  Puerta confesión              ← 0001

Capa Núcleo:
  7. ADR-0004  PTT/AudioCapture              ← 0003
  8. ADR-0006  Nivel inglés                  ← 0001 + 0002
  9. ADR-0011  Anti-stall                    ← 0001
 10. ADR-0012  Player Controller             ← 0001
 11. ADR-0013  Interaction System            ← 0001 + 0012

Capa Característica:
 12. ADR-0014  NPC Dialogue                  ← 0001 + 0002 + 0003 + 0006 + 0008 + 0013
 13. ADR-0015  Inventory                     ← 0001 + 0010
 14. ADR-0016  Gajito                        ← 0001 + 0003 + 0004 + 0011 + 0014

Capa Presentación:
 15. ADR-0009  Balbuceo NPC                  ← 0004
 16. ADR-0010  Tablón diegético              ← 0005
 — ADR-0017 (HUD) faltante                  ← 0014 + 0015 + 0016 (esperado)
```

⚠️ Todos los ADRs siguen status `Propuesto`. Sign-off formal pendiente. Implementación no debería comenzar hasta que sus ADRs upstream estén `Aceptado`.

---

## Compatibilidad Motor

| Check | Resultado |
|-------|-----------|
| `docs/engine-reference/godot/` | ❌ AÚN AUSENTE — ejecutar `/setup-engine` |
| `.claude/docs/technical-preferences.md` Engine | `[TO BE CONFIGURED]` (asumido sin cambios desde v1) |
| Versión motor coherente entre ADRs | ✅ todos Godot 4 / 4.6 |
| APIs Post-Cutoff declaradas | ✅ todos los 16 ADRs declaran "Ninguna" |
| APIs deprecadas grep'd | ✅ ninguna encontrada |
| Sección Engine Compat presente | ✅ 16/16 ADRs |

**Consulta a especialista de motor — omitida** (no engine configurado en `technical-preferences.md`).

### Verificaciones manuales pendientes (heredadas de v1)

| ADR | API | Flag |
|-----|-----|------|
| ADR-0004 | `AudioEffectCapture.get_buffer()` → `PackedVector2Array` | Confirmar estable en 4.6 |
| ADR-0004 | WAV hardcoded 16kHz pero `AudioServer.get_mix_rate()` típicamente 44100Hz — falta resampling | **VERIFICAR** — bug runtime probable |
| ADR-0010 | `ViewportTexture.viewport_path` asignado en código | Frágil en algunas 4.x — confirmar editor test |
| ADR-0009 | `AudioStreamRandomizer.add_stream(index, stream)` signature | Confirmar en docs 4.6 |
| ADR-0001 | `FileAccess.open("user://...", WRITE)` en build exportado | Verificar Windows + Linux |
| ADR-0003 | `OS.create_process` Linux/Windows split | ✅ corregido v1→v2 |
| ADR-0011 (nuevo) | Timer one-shot reset behavior con `clue_added` race | Verificar (declarado en ADR como mitigado) |
| ADR-0013 (nuevo) | RayCast3D `collision_mask` vs interactable layer | Verificar build exportado |
| ADR-0014 (nuevo) | HTTPRequest paralelo NPC + grammar sin `ERR_IN_USE` | Verificar |
| ADR-0016 (nuevo) | Pop-up CanvasLayer layer 15 sobre tablón 3D + HUD | Verificar visibilidad z-order |

---

## GDD Revision Flags (pendientes de v1)

Los siguientes flags del review v1 **no han sido aplicados al GDD**:

| GDD | Línea | Asunción obsoleta | Realidad (ADR/CLAUDE.md) | Acción |
|-----|-------|-------------------|--------------------------|--------|
| gdd_detective_noir_vr.md | §5.3 paso 7-8 | "STT → LLM → TTS" pipeline | TTS removido v0.3 | Revisar GDD |
| gdd_detective_noir_vr.md | §5.2 stack | "Comunicación HTTP/WebSocket (WiFi local) Quest 2 ↔ PC" | localhost mismo PC | Revisar GDD |
| gdd_detective_noir_vr.md | §11/§12 | Riesgo "OpenXR Quest 2", "WiFi inestable", "Motion sickness" | VR removido v0.3 | Revisar tabla riesgos |
| gdd_detective_noir_vr.md | §10.4 | "Equipo necesario (Quest 2 + PC)" | sólo PC | Revisar protocolo prueba |
| gdd_detective_noir_vr.md | §1 v0.3 nota | "migración Meta Quest 2 VR a PC desktop" — OK pero línea 5 dice "Realidad Virtual" en concepto | Concepto debe decir PC FPS | Revisar §1.1 |

Recomendación: única pasada de revisión del GDD para limpiar todas las referencias VR/TTS/Quest 2 antes de Pre-Production gate.

---

## Cobertura `architecture.md`

`docs/architecture/architecture.md` cubre los 27 TRs de la Línea Base. No hay módulos huérfanos.

**Stale areas residuales:**
- Línea 9: `**ADRs referenciados:** Ninguno aún — ver sección Decisiones Arquitectónicas Requeridas` — desactualizado, ya hay 16 ADRs.
- Líneas 477–498 sección "Decisiones Arquitectónicas Requeridas" — todos esos ADRs existen ya. Reformular a "Decisiones Arquitectónicas Implementadas" con referencias.
- Línea 345: `register_antistall_hint(level: int)` obsoleto (ver Conflicto T1).

---

## Veredicto: **CONCERNS** (cerca de PASS)

**No FAIL:** sin ciclos de dependencia, sin conflictos irrecuperables. Foundation + Core + Feature ADRs cubren 25/27 TRs.

**No PASS:**
- 1 gap (TR-ui-002 / ADR-0017 HUD inexistente, referenciado 11 veces).
- 2 conflictos schema/naming activos (T1, T2) que romperán telemetría y acusación en runtime si se implementa el código tal cual.
- `architecture.md` sección "Decisiones Requeridas" stale.

### Issues bloqueantes (resolver antes de PASS)

| # | Issue | Tipo | Esfuerzo |
|---|-------|------|----------|
| B1 | ADR-0001 alinear con ADR-0007 (`npcs_interrogated`, `anti_stall_triggers: Dictionary`, eliminar `antistall_hints_fired` + `register_antistall_hint`) | Schema | 15 min |
| B2 | architecture.md eliminar `register_antistall_hint(level: int)` línea 345 + actualizar sección "Decisiones Requeridas" | Doc | 10 min |
| B3 | ADR-0008 + ADR-0014 unificar `barry_peel` → `barry` | Naming | 5 min |
| B4 | ADR-0014 corregir mapeo `TESTIMONY_TRIGGERS["moni"]` (F3 vs R4) | Narrative | requiere decisión narrativa |
| B5 | Crear ADR-0017 HUD System | Gap | 1-2h |

### ADRs a crear

| Prioridad | ADR | Sistemas | Cubre |
|-----------|-----|----------|-------|
| P1 | **ADR-0017 HUD System** | Subtítulos 2 canales, indicador PTT, slider FOV, tamaño subtítulos, coordinación con InventoryHUD/GajitoPopup | TR-ui-001, TR-ui-002 |

---

## Próximos pasos

1. Aplicar parches B1–B4 en sesión de revisión ADRs (touch ADR-0001, ADR-0008, ADR-0014, architecture.md).
2. Ejecutar `/architecture-decision hud-system` para crear ADR-0017.
3. Pasada de cleanup GDD (TTS/VR/Quest 2 stale refs).
4. Re-correr `/architecture-review` tras ADR-0017 + parches → esperado PASS.
5. Ejecutar `/setup-engine` para configurar Godot 4.6 en `technical-preferences.md`.
6. Sign-off formal de los 16 ADRs `Propuesto` → `Aceptado`.
7. `/gate-check pre-production` cuando B1–B5 + sign-off resueltos.
