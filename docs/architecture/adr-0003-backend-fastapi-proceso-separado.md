# ADR-0003: Backend FastAPI como Proceso Separado — Auto-lanzamiento y Health Check

## Estado
Aceptado

## Fecha
2026-05-01

## Compatibilidad con el Motor

| Campo | Valor |
|-------|-------|
| **Motor** | Godot 4.6 (lado cliente) + Python 3.x / FastAPI (lado servidor) |
| **Dominio** | Núcleo / Integración externa |
| **Riesgo de Conocimiento** | BAJO — `OS.create_process()` estable en Godot 4.x; FastAPI es independiente del motor |
| **Referencias Consultadas** | Conocimiento directo de Godot 4.6, FastAPI, Windows |
| **APIs Post-Corte Usadas** | Ninguna |
| **Verificación Requerida** | Confirmar que `OS.create_process("python", [...])` lanza correctamente en Windows con Python en PATH; verificar que el proceso hijo se cierra al cerrar Godot |

## Dependencias ADR

| Campo | Valor |
|-------|-------|
| **Depende De** | ADR-0002 (define qué corre en el backend: Ollama/llama3.2) |
| **Habilita** | ADR-0004 (AudioEffectCapture/PTT — necesita el endpoint /stt activo) |
| **Bloquea** | Epic de sistema de interrogatorio — no puede probarse sin backend corriendo |
| **Nota de Orden** | Implementar GameManager (ADR-0001) y este ADR antes de cualquier prueba de interrogatorio |

## Contexto

### Declaración del Problema
El juego requiere un servidor Python/FastAPI para STT (faster-whisper), LLM (Ollama) y evaluación gramatical (Gajito). Este servidor debe estar corriendo antes de que el jugador pueda iniciar la partida. Si el jugador tiene que iniciar el servidor manualmente, aumenta la fricción operacional durante las pruebas de usuario. Se necesita decidir cómo gestionar el ciclo de vida del backend desde el propio juego.

### Restricciones
- Plataforma: Windows y Linux (proyecto target PC Windows/Linux — ver CLAUDE.md)
- Python debe estar instalado en el sistema con `python` en PATH
- El backend corre en localhost — no hay red involucrada
- Puerto fijo: 8000 (sin configuración adicional)
- El backend tarda ~1–2s en inicializarse antes de poder recibir requests

### Requisitos
- El juego debe lanzar el backend automáticamente al iniciarse (sin intervención manual del usuario)
- Verificar disponibilidad del backend antes de habilitar "Iniciar partida"
- Mostrar error accionable si el backend no responde (instrucciones claras)
- El puerto es fijo en 8000 — no requiere configuración

## Decisión

**El juego lanza el backend automáticamente usando `OS.create_process()` al cargar el menú principal, seguido de un health check con reintentos.**

### Flujo de inicialización

```
main_menu._ready()
  → Mostrar spinner "Iniciando sistema de IA..."
  → Lanzar backend: OS.create_process("python3"|"python", [ruta_main_py])  # python3 en Linux/macOS
  → Esperar 2 segundos (Timer)
  → Health check: GET http://localhost:8000/health
      → Si 200 OK: ocultar spinner, habilitar botón "Iniciar partida"
      → Si falla: reintentar hasta 3 veces (cada 1s)
          → Si sigue fallando: mostrar panel de error con instrucciones manuales
```

### Diagrama de Arquitectura

```
Arranque del juego (main_menu.tscn)
  │
  ├── OS.create_process("python", ["C:/ruta/backend/main.py"])
  │     └── Proceso Python separado (PID guardado)
  │           └── FastAPI en localhost:8000
  │                 ├── GET  /health        → {"status": "ok"}
  │                 ├── POST /stt           → texto STT
  │                 ├── POST /npc/{id}      → respuesta NPC
  │                 └── POST /grammar       → corrección gramatical
  │
  └── Timer 2s → HTTPRequest GET /health
        ├── 200 OK → botón "Iniciar partida" habilitado
        └── Error → reintento × 3 → panel de error
```

### Interfaces Clave

**Godot — lanzamiento del backend:**
```gdscript
# res://scripts/core/backend_launcher.gd
var _backend_pid: int = -1

func launch_backend() -> void:
    var backend_dir := OS.get_executable_path().get_base_dir().path_join("backend")
    var main_py := backend_dir.path_join("main.py")
    var python_cmd := "python3" if OS.get_name() in ["Linux", "macOS"] else "python"
    _backend_pid = OS.create_process(python_cmd, [main_py])

func stop_backend() -> void:
    if _backend_pid > 0:
        OS.kill(_backend_pid)
        _backend_pid = -1
```

**Godot — health check con reintentos:**
```gdscript
# res://scripts/core/backend_launcher.gd
const HEALTH_URL := "http://localhost:8000/health"
const MAX_RETRIES := 3
const RETRY_INTERVAL_SEC := 1.0

signal backend_ready()
signal backend_unavailable(reason: String)

func check_health(attempt: int = 1) -> void:
    var http := HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_health_response.bind(attempt, http))
    http.request(HEALTH_URL)

func _on_health_response(result, code, _headers, _body, attempt: int, http: HTTPRequest) -> void:
    http.queue_free()
    if result == HTTPRequest.RESULT_SUCCESS and code == 200:
        emit_signal("backend_ready")
    elif attempt < MAX_RETRIES:
        await get_tree().create_timer(RETRY_INTERVAL_SEC).timeout
        check_health(attempt + 1)
    else:
        emit_signal("backend_unavailable", "No se pudo conectar al servidor de IA.")
```

**FastAPI — endpoint health:**
```python
# backend/main.py
@app.get("/health")
async def health():
    return {"status": "ok", "model": config.OLLAMA_MODEL}
```

**Panel de error (si backend no disponible):**
```
⚠️ No se pudo iniciar el servidor de IA.

Solución manual:
1. Abre una terminal en la carpeta "backend/"
2. Ejecuta: python main.py
3. Espera a ver "Uvicorn running on http://localhost:8000"
4. Vuelve al juego y haz clic en "Reintentar"
```

### Puerto
Puerto **8000 fijo** en código. Definido como constante en ambos lados:
```gdscript
const BACKEND_URL := "http://localhost:8000"  # LLM Client y Backend Launcher
```
```python
PORT = 8000  # backend/config.py
```

## Alternativas Consideradas

### Alternativa 1: El usuario inicia el backend manualmente
- **Descripción:** README con instrucciones; el juego asume backend disponible o muestra error al primer request fallido
- **Pros:** Más simple de implementar
- **Contras:** Fricción operacional durante pruebas de usuario; los participantes no deben ver terminales ni ejecutar comandos
- **Razón de rechazo:** Las pruebas de usuario requieren una experiencia limpia. El participante no debe saber que existe un servidor Python.

### Alternativa 2: PyInstaller — backend empaquetado como .exe
- **Descripción:** Compilar backend a `backend.exe` con PyInstaller; lanzarlo desde Godot
- **Pros:** No requiere Python instalado; más portable
- **Contras:** Proceso de build complejo; archivos grandes; faster-whisper y Ollama tienen problemas conocidos con PyInstaller; tiempo de compilación alto
- **Razón de rechazo:** Complejidad desproporcionada para proyecto académico con hardware controlado.

### Alternativa 3: Backend siempre corriendo (proceso persistente del SO)
- **Descripción:** El backend corre como servicio de Windows o tarea de inicio
- **Pros:** Sin latencia de arranque
- **Contras:** Requiere configuración del SO; consume RAM cuando el juego no está activo
- **Razón de rechazo:** Innecesariamente complejo para uso en desarrollo y pruebas.

## Consecuencias

### Positivas
- Experiencia de usuario limpia — los participantes no ven terminales ni ejecutan comandos
- El juego es un único punto de entrada; el backend es transparente
- Health check protege contra errores difíciles de diagnosticar a mitad del interrogatorio
- Panel de error accionable para cuando algo falla

### Negativas
- Requiere Python en PATH en el PC de pruebas (documentar en setup)
- El proceso hijo (backend) puede quedar huérfano si Godot crashea antes de `stop_backend()`
- Latencia de ~2s en el arranque del menú principal mientras el backend inicializa

### Riesgos
- **Riesgo:** Python no está en PATH en Windows. **Mitigación:** Verificar antes de pruebas de usuario; documentar en README de setup; considerar ruta absoluta a Python si es necesario.
- **Riesgo:** Ollama no está corriendo cuando FastAPI arranca. **Mitigación:** FastAPI verifica conexión con Ollama en `/health` y retorna error descriptivo si no está disponible.
- **Riesgo:** Puerto 8000 ocupado por otro proceso. **Mitigación:** Documentar como requisito; agregar al panel de error si health check falla con "connection refused".
- **Riesgo:** Proceso backend huérfano tras crash de Godot. **Mitigación:** Conectar `stop_backend()` a `get_tree().connect("tree_exiting", stop_backend)`; el proceso muere igualmente cuando Godot termina en la mayoría de los casos.

## Requisitos GDD Abordados

| Sistema GDD | Requisito | Cómo lo aborda este ADR |
|-------------|-----------|-------------------------|
| gdd_detective_noir_vr.md | TR-backend-001: FastAPI con /stt /npc/{id} /grammar; detección offline en startup | Health check en main_menu con reintentos; endpoints definidos; panel de error accionable |
| gdd_detective_noir_vr.md | TR-voz-002: STT latencia ≤ 4s extremo a extremo | El backend estar disponible antes de la partida garantiza que no hay latencia adicional de arranque durante el juego |
| gdd_detective_noir_vr.md | RNF-03: El juego detecta servidor no disponible y muestra error accionable al inicio | Panel de error con instrucciones manuales de fallback |

## Implicaciones de Rendimiento
- **CPU:** Proceso Python separado — no compite con el render loop de Godot
- **Memoria:** FastAPI + faster-whisper + Ollama client: ~200–400 MB RAM adicionales (Ollama corre en proceso propio)
- **Tiempo de carga:** +2s en arranque del menú principal para health check
- **Red:** Solo localhost — latencia de red prácticamente cero

## Plan de Migración
Primera implementación — no hay código existente que migrar.

## Criterios de Validación
- Al lanzar el juego, el backend arranca automáticamente sin intervención del usuario
- Si `python` no está en PATH, el panel de error aparece con instrucciones correctas en ≤ 5s
- Si backend ya estaba corriendo (lanzado manualmente), el health check pasa sin error
- `stop_backend()` termina el proceso Python al cerrar el juego (verificar con Task Manager)
- El botón "Iniciar partida" está deshabilitado hasta que `/health` retorne 200

## Decisiones Relacionadas
- ADR-0001: GameManager — `initialize_session()` se llama solo después de `backend_ready`
- ADR-0002: Ollama llama3.2 — el backend que este ADR lanza es el que ejecuta Ollama
- ADR-0004 (pendiente): AudioEffectCapture/PTT — usa el endpoint `/stt` definido aquí
- Arquitectura maestra: `docs/architecture/architecture.md` sección "Orden de Inicialización"
