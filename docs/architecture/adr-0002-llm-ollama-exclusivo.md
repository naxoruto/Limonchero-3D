# ADR-0002: Ollama como LLM Exclusivo — llama3.2 Local

## Estado
Aceptado

## Fecha
2026-05-01

## Compatibilidad con el Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4.6 (lado cliente) + Python 3.x (lado backend) |
| **Dominio** | Núcleo / Integración externa |
| **Riesgo de Conocimiento** | BAJO — esta decisión es independiente del motor; Godot solo hace HTTP POST |
| **Referencias Consultadas** | Conocimiento directo de Ollama, FastAPI, llama3.2 |
| **APIs Post-Corte Usadas** | Ninguna del lado Godot |
| **Verificación Requerida** | Confirmar latencia de llama3.2 en hardware del equipo ≤ 8s por respuesta |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | Ninguna |
| **Habilita** | ADR-0003 (backend FastAPI — define el servidor que ejecuta Ollama) |
| **Bloquea** | Epic de sistema de interrogatorio — no puede implementarse sin LLM confirmado |
| **Nota de Orden** | ADR-0003 debe documentarse a continuación; juntos definen el contrato backend completo |

## Contexto

### Declaración del Problema
El juego necesita un LLM para tres funciones: respuestas de NPCs en inglés con personalidad, evaluación gramatical del jugador (Gajito), y condicionamiento por nivel de inglés. Se debe elegir qué modelo usar, con qué restricciones de costo y conectividad, y cómo abstraerlo para que el código Godot no dependa del proveedor.

### Restricciones
- Proyecto académico: presupuesto cero para APIs de pago
- Las pruebas de usuario se realizarán en sala sin garantía de internet estable
- Hardware del equipo: PCs consumer (aprox. 8–16 GB RAM, GPU integrada o discreta básica)
- Latencia requerida: ≤ 8s por respuesta NPC (TR-llm-002)
- El modelo debe responder en inglés con buena fluidez

### Requisitos
- Sin costo en desarrollo ni en demo
- Funcionar completamente offline durante sesiones de prueba
- Calidad de inglés suficiente para simular NPCs con personalidad definida
- Compatible con instrucciones de system prompt (rol, restricciones, tono)
- Tiempo de respuesta ≤ 8s en hardware del equipo

## Decisión

**Se usa Ollama con modelo llama3.2 como único proveedor LLM para todo el proyecto.**

No existe modo "demo con GPT-4o-mini". Todo el proyecto — desarrollo, pruebas de usuario y entrega final — usa Ollama local con llama3.2. El modelo corre en la misma máquina que el juego, servido por Ollama en `http://localhost:11434`.

El backend FastAPI actúa como proxy entre Godot y Ollama. Godot nunca llama a Ollama directamente — solo conoce el endpoint FastAPI (`http://localhost:8000`). Cambiar el modelo en el futuro requiere solo modificar configuración del backend, sin tocar código Godot.

### Diagrama de Arquitectura

```
Godot 4.6
  └── LLM Client (llm_client.gd)
        └── POST http://localhost:8000/npc/{npc_id}
                    {history, system_prompt, english_level}
              └── FastAPI Backend (Python)
                    └── ollama.chat(model="llama3.2", messages=[...])
                          └── Ollama (http://localhost:11434)
                                └── llama3.2 (modelo local)
```

### Interfaces Clave

**Contrato Godot → FastAPI (sin cambios respecto a arquitectura maestra):**
```
POST /npc/{npc_id}
Body: {
  "history": [...],
  "system_prompt": "You are Barry Peel...",
  "english_level": "intermediate"
}
Response: { "text": "I was in my booth all night." }
```

**Configuración backend (backend/config.py):**
```python
OLLAMA_MODEL = "llama3.2"
OLLAMA_BASE_URL = "http://localhost:11434"
LLM_TIMEOUT_SEC = 8
```

**Llamada interna FastAPI → Ollama:**
```python
import ollama

response = ollama.chat(
    model=config.OLLAMA_MODEL,
    messages=messages,  # system_prompt + history convertidos
    options={"num_predict": 150}  # limitar longitud de respuesta
)
return {"text": response["message"]["content"]}
```

## Alternativas Consideradas

### Alternativa 1: GPT-4o-mini (OpenAI API) para demo final
- **Descripción:** Ollama en desarrollo, GPT-4o-mini solo para la entrega académica
- **Pros:** Mayor calidad de respuestas en inglés; expresiones más naturales
- **Contras:** Requiere tarjeta de crédito; costo por token; requiere internet; riesgo de cortes durante pruebas de usuario
- **Razón de rechazo:** Costo, dependencia de internet y riesgo operacional no justificados para un proyecto académico. llama3.2 es suficiente para simular NPCs con personalidades definidas en system prompt.

### Alternativa 2: Gemini Flash (API gratuita con límites)
- **Descripción:** API de Gemini con tier gratuito
- **Pros:** Gratuito; buena calidad; mayor contexto
- **Contras:** Requiere internet; límites de rate; latencia impredecible; complejidad adicional de gestionar credenciales de Google
- **Razón de rechazo:** Dependencia de internet y complejidad operacional innecesaria.

### Alternativa 3: Modelo embebido en el ejecutable
- **Descripción:** Usar llama.cpp o similar directamente en el proceso Godot
- **Pros:** Sin servidor separado
- **Contras:** Enorme complejidad de integración; sin soporte nativo en Godot 4.6; tamaño del ejecutable inmanejable
- **Razón de rechazo:** Completamente fuera del alcance del proyecto.

## Consecuencias

### Positivas
- Costo cero en toda la vida del proyecto
- Funciona 100% offline — pruebas de usuario sin dependencia de red
- Cambiar el modelo (ej. a llama3.2:70b o mistral) requiere solo cambiar `OLLAMA_MODEL` en config
- Godot queda completamente desacoplado del proveedor LLM

### Negativas
- Calidad de inglés inferior a GPT-4o-mini para respuestas muy elaboradas
- Requiere que el profesor/evaluador tenga Ollama instalado si quiere correr el proyecto
- llama3.2 puede ser lento en máquinas sin GPU dedicada

### Riesgos
- **Riesgo:** llama3.2 supera los 8s en hardware antiguo. **Mitigación:** Usar `num_predict: 150` para limitar longitud; probar en el hardware más débil del equipo antes de pruebas de usuario. Si no alcanza, bajar a `gemma2:2b` como fallback.
- **Riesgo:** Ollama no está instalado en el PC de prueba. **Mitigación:** Documentar instalación en README; llevar el modelo descargado en USB.
- **Riesgo:** El modelo no respeta el system prompt y sale del personaje. **Mitigación:** Probar cada NPC con 10 turnos de conversación antes de las pruebas de usuario; ajustar el prompt si es necesario.

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|-------------------------|
| gdd_detective_noir_vr.md | TR-llm-001: HTTP POST localhost → LLM | FastAPI en localhost:8000 recibe el request de Godot y llama a Ollama |
| gdd_detective_noir_vr.md | TR-llm-002: Timeout 8s por respuesta NPC | Configurado en backend con `LLM_TIMEOUT_SEC = 8`; FastAPI retorna error si supera |
| gdd_detective_noir_vr.md | TR-llm-003: Desarrollo y demo con mismo stack | Un solo stack: Ollama + llama3.2 para ambos contextos |

## Implicaciones de Rendimiento
- **CPU:** llama3.2 usa ~4 núcleos durante inferencia; no interfiere con Godot (proceso separado)
- **Memoria:** llama3.2 requiere ~3–4 GB RAM; verificar disponibilidad en hardware de pruebas
- **Tiempo de carga:** Primera respuesta puede tardar ~2s extra si el modelo no está en cache de Ollama
- **Red:** Sin tráfico de red externo — todo en localhost

## Plan de Migración
Primera implementación — no hay código existente que migrar.
Si en el futuro se decide usar otro modelo: cambiar `OLLAMA_MODEL` en `backend/config.py`. Sin cambios en Godot.

## Criterios de Validación
- Tiempo de respuesta promedio de llama3.2 ≤ 8s en el hardware más lento del equipo
- Barry Peel responde en inglés consistente con su system prompt en 9/10 turnos de prueba
- Gajito detecta al menos 80% de errores gramaticales evidentes en frases de prueba
- El sistema funciona sin conexión a internet activa
- Cambiar `OLLAMA_MODEL = "mistral"` en config redirige todas las llamadas sin tocar Godot

## Decisiones Relacionadas
- ADR-0001: GameManager — no afecta este ADR directamente
- ADR-0003 (pendiente): Backend FastAPI — define el servidor que ejecuta Ollama
- ADR-0006 (pendiente): Condicionamiento por nivel de inglés — cómo english_level modifica el system prompt antes de enviarlo a Ollama
- Arquitectura maestra: `docs/architecture/architecture.md` sección "Cliente LLM"
