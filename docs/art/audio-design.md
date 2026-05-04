# Audio Design — Limonchero 3D
**Responsable:** Sofía Meza  
**Fecha:** 2026-05-03  
**Todos los archivos:** `assets/audio/` — exportar como `.ogg` para Godot

---

## Filosofía de Audio

Sin TTS (texto-a-voz). Los NPCs responden como texto en pantalla + balbuceo local sincronizado (estilo Animal Crossing). El audio construye atmósfera, no narración.

**Regla:** El silencio es intencional. Pasillo de servicio (Zona 4) = silencio total excepto goteo. La sala de interrogatorio = sin ambient, solo balbuceo del NPC.

---

## Música

Dos tracks. Jazz noir instrumental. Sin letra.

### `assets/audio/music/ambient_jazz_loop.ogg`
- **Uso:** Loop continuo durante exploración del club (Zonas 1-3, 5, 6)
- **Estilo:** Jazz noir 1950s — piano melancólico + contrabajo + saxofón suave
- **Duración:** 3-5 minutos, loop seamless (inicio y fin en el mismo beat/chord)
- **BPM:** 70-90 bpm (tempo lento, languidez)
- **Nivel:** -6 dB en mezcla final
- **Se corta:** Al iniciar secuencia de acusación final → silencio total (solo lluvia)
- **Fuentes sugeridas:**
  - Kevin MacLeod / Incompetech — buscar "noir", "jazz", "detective" (CC BY)
  - YouTube Audio Library — filtro "jazz", "1950s"
  - Freesound.org — tags: `jazz noir instrumental loop`

### `assets/audio/music/intro_briefing.ogg`
- **Uso:** Escena de apertura (Barry habla) + briefing de Spud
- **Estilo:** Mismo jazz pero con más tensión — cuerdas o piano staccato
- **Duración:** 60-90 segundos (no necesita loop)
- **Nivel:** -8 dB (más bajo que ambient — Spud debe sentirse sobre la música)

---

## SFX

Directorio: `assets/audio/sfx/`

### Pasos

| Archivo | Superficie | Notas |
|---------|-----------|-------|
| `footsteps_marble.ogg` | Mármol/tile vestíbulo | Claro, resonante, levemente reverb |
| `footsteps_wood.ogg` | Madera salón/escenario | Más sordo, cruje levemente |
| `footsteps_concrete.ogg` | Concreto pasillo servicio | Seco, sin reverb, industrial |
| `footsteps_carpet.ogg` | Alfombra corredor interior | Casi silencioso, amortiguado |

Implementación Godot: 1 clip por superficie, reproducir en cada footstep del CharacterBody3D. Variar pitch ±5% aleatoriamente para evitar repetición robótica.

### Ambiente

| Archivo | Uso | Loop |
|---------|-----|------|
| `rain_exterior_loop.ogg` | Fondo constante en Zonas 1-2 (ventanales) | Sí |
| `drip_pipes_loop.ogg` | Solo en Zona 4 (pasillo servicio) — único audio de esa zona | Sí |

### Interacciones

| Archivo | Trigger |
|---------|---------|
| `inventory_pickup.ogg` | Al añadir pista al inventario |
| `inventory_open.ogg` | Al abrir Tab |
| `interact_prompt.ogg` | Al aparecer "Presiona E" sobre objeto |
| `door_creak.ogg` | Puerta oficina Cornelius (Zona 5) |
| `lighter_click.ogg` | Inspeccionar el encendedor de Barry (F3) |
| `glass_clink.ogg` | Inspeccionar copa de bourbon (D5) |
| `paper_rustle.ogg` | Inspeccionar acuerdo fideicomiso (F1) o documentos |
| `evidence_add.ogg` | Al confirmar "¿Agregar como evidencia? [E]" durante diálogo |

**Fuente:** Freesound.org (filtrar CC0). Tags por archivo:
- Pasos: `footstep marble`, `footstep wood`, `footstep concrete`
- Lluvia: `rain interior ambience loop`
- Interacciones: `door creak old`, `lighter click`, `glass clink`, `paper rustle`

---

## Balbuceos NPC

Directorio: `assets/audio/voices/`

Cada clip: 1-3 segundos, loop mientras aparece texto del NPC. Estilo Animal Crossing — no palabras, solo sonido que comunica personalidad.

### Tabla de specs

| NPC | Archivo | Personalidad | Técnica |
|-----|---------|-------------|---------|
| Commissioner Spud | `babble_spud.ogg` | Grave, seco, interrumpe | Voz masculina grabada / Freesound "deep male voice" → pitch -4 semitones → corte abrupto al final |
| Moni Graná Fert | `babble_moni.ogg` | Suave, cadencioso, pausa larga | Voz femenina suave → reverb corto (0.3s) → pitch +2 → fade lento |
| Gerry Broccolini | `babble_gerry.ogg` | Monosilábico, gruñido | Grunt masculino corto → bass boost +6dB → pitch -6 → clip muy corto (~0.8s) |
| Dolores "Lola" Persimmon | `babble_lola.ogg` | Parlanchín, nervioso, rápido | Voz femenina → speed x1.3 → ligero pitch +1 → sin pausa entre loops |
| Bartholomew "Barry" Peel | `babble_barry.ogg` | Sereno, claro, controlado | Voz masculina neutral → mínimo procesado → pausa larga entre ciclos |
| Gajito | `babble_gajito.ogg` | Energético, variable | Voz aguda → pitch +6 semitones → o generar con Audacity tone generator (440-880 Hz, variaciones breves) |

### Cómo crear balbuceos con Audacity (gratis)

1. Grabar voz o descargar clip de Freesound
2. Cortar a 1-2 segundos en el segmento más expresivo
3. Aplicar pitch shift (semitones según tabla)
4. Aplicar efectos indicados
5. Normalizar a -3 dB
6. Export → `.ogg` (Ogg Vorbis, calidad 5)

**Herramientas alternativas:** GarageBand, LMMS, o contratar a compañero con experiencia audio.

---

## Mezcla Final

| Canal | Nivel |
|-------|-------|
| Música ambient | -6 dB |
| Música briefing | -8 dB |
| SFX ambiente (lluvia, goteo) | -12 dB |
| SFX interacciones | 0 dB |
| Balbuceos NPC | -9 dB |

**Regla:** En sala de interrogatorio, música baja a -18 dB (casi inaudible) automáticamente.

---

## Implementación en Godot

```
AudioStreamPlayer  → música (loop, volumen variable por zona)
AudioStreamPlayer3D → SFX en world-space (pasos, ambient por zona)
AudioStreamPlayer  → balbuceos NPC (loop mientras text_speed > 0)
AudioStreamPlayer  → interacciones (one-shot)
```

Balbuceo sincronizado con texto: iniciar audio cuando comienza el typewriter effect del texto del NPC. Detener cuando texto termina.
