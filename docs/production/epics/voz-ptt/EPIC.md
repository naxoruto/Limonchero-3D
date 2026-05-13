# Epic: Voz/PTT

> **Capa**: Core
> **GDD**: gdd/gdd_detective_noir_vr.md
> **Módulo Arquitectónico**: Voz/PTT
> **Estado**: Ready
> **Historias**: No creadas aún — ejecutar `/create-stories voz-ptt`

## Visión General

Implementa el módulo `VoicePTT` que captura audio del micrófono mientras el jugador mantiene V (o LB en mando), empaqueta el buffer en WAV, y lo envía al Cliente LLM para transcripción STT. Verifica en `_ready()` que el sample rate sea 16000 Hz y que haya dispositivo de entrada disponible. Si no hay micrófono, muestra advertencia en menú principal (no bloquea el juego). Riesgo MEDIO por variabilidad de `AudioEffectCapture` entre plataformas.

## ADRs Gobernantes

| ADR | Resumen de Decisión | Riesgo Motor |
|-----|---------------------|--------------|
| ADR-0004 | `AudioEffectCapture` + `AudioStreamMicrophone`; verificar sample rate 16000 Hz en `_ready()`; empaquetar WAV y enviar vía LLMClient | MEDIUM |
| ADR-0003 | Endpoint `/stt` en FastAPI recibe el WAV | LOW |
| ADR-0005 | Señales para comunicar audio capturado — sin llamadas directas cross-layer | LOW |

## Requisitos GDD

| TR-ID | Requisito | Cobertura ADR |
|-------|-----------|---------------|
| TR-voz-001 | PTT — mantener V/LB → AudioEffectCapture → WAV → FastAPI | ADR-0004 ✅ |
| TR-voz-002 | Latencia STT ≤ 4s extremo a extremo, inglés con acento latino, >85% precisión | ADR-0004 ✅ |

## Contrato de API (de architecture.md)

```gdscript
func start_recording() -> void
func stop_recording() -> void

signal recording_started()
signal recording_stopped()
signal audio_captured(wav_bytes: PackedByteArray)
```

## Riesgos Técnicos

| Riesgo | Mitigación |
|--------|-----------|
| Sample rate ≠ 16000 Hz en algunos sistemas | Verificar `AudioServer.get_mix_rate()` en `_ready()`; si falla, resample o documentar como requisito |
| Sin micrófono / sin permisos | Verificar `AudioServer.get_input_device_list()`; si vacío, advertencia en menú — no bloquea |
| Latencia >4s en hardware lento | Medir en hardware más débil del equipo antes de pruebas de usuario |

## Definición de Hecho

Esta épica está completa cuando:
- Todas las historias están implementadas, revisadas y cerradas vía `/story-done`
- Mantener V inicia grabación; soltar V emite `audio_captured(wav_bytes)`
- WAV llega a `/stt` y retorna texto en ≤4s en hardware de prueba
- Verificación de sample rate y micrófono en `_ready()` funciona en Linux y Windows
- Advertencia de sin-micrófono visible en menú principal si aplica
- Indicador PTT visible en HUD durante grabación (coordinado con HUD epic)

## Siguiente Paso

Ejecutar `/create-stories voz-ptt`
