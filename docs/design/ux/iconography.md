# Iconography Specification

> **Estilo:** Outline geométrico monocromático  
> **Color base:** `#E8D5A3` (blanco cálido) — mismo que texto primario  
> **Tamaño base:** 16×16px, 24×24px, 32×32px  
> **Propósito:** Set mínimo de iconos para la UI. Todos son outline de 1px.

---

## 1. Principios de Diseño

1. **Outline geométrico:** Todos los iconos son trazos (stroke) de 1px, sin relleno. Sin gradientes, sin sombras.
2. **Monocromáticos:** Un solo color (`#E8D5A3`) para todos los iconos. Excepción: indicador PTT en `#D4A030`.
3. **Sin texto en iconos:** Los iconos no contienen letras ni números. El texto va aparte (Caption o Label en UI).
4. **Simetría cuando sea posible:** Los iconos prefieren simetría horizontal/vertical para lectura rápida.
5. **Tamaño consistente:** La caja del icono es siempre cuadrada (1:1). 16px para inline, 24px para botones, 32px para header.
6. **Backup textual:** Todo icono crítico tiene una etiqueta de texto al lado (accessibility-first).

---

## 2. Set de Iconos

### 2.1 Navegación / Acción

```
Ícono          Forma                           Tamaño  Uso
─────          ────                            ──────  ───
[ESC]          Rectángulo con flecha ←         16×16   Botón cerrar (overlays)

[E]            Letra "E" en rectángulo         16×16   Indicador de tecla interactuar

[Tab]          Dos rectángulos superpuestos    16×16   Indicador de tecla inventario

← Flecha izq.  Punta de flecha (outline)       16×16   Volver (settings → pause)

X Cerrar       "X" con brazos iguales          24×24   Cerrar panel / overlay
─ ─ ─          ────                              
               ┌─┐                              
               │X│                              
               └─┘                              
```

### 2.2 Indicadores de Estado

```
Ícono          Forma                           Tamaño  Uso
─────          ────                            ──────  ───
Mic IDLE       Tres barras estáticas          32×16   PTTIndicator estado IDLE
               ▁▂▃

Mic REC        Tres barras animadas (onda)    32×16   PTTIndicator estado RECORDING
               ▃▂▁▂▃

Mic PROC       Tres barras estáticas +        32×16   PTTIndicator estado PROCESSING
               "..." pulse

● Online       Círculo lleno                   12×12   Health check OK
                                                      (verde #2A5A20, no #E8D5A3)

✖ Error        "X" en círculo                 12×12   Health check FAIL
                                                      (rojo #6A1520, no #E8D5A3)

◌ Loading      8-frame spinner animado        24×24   Carga / procesando
```

### 2.3 Elementos de Evidencia

```
Ícono          Forma                           Tamaño  Uso
─────          ────                            ──────  ───
📷 Foto        Rectángulo con círculo          24×24   Pista física (slot vacío)
               (lente de cámara)

💬 Testimonio  Burbuja de diálogo              24×24   Evidencia tipo testimonio
               (rectángulo con punta)

❓ Distractor  Signo de interrogación          24×24   Pista distractora (red herring)
               en hexágono

✔ Check       Checkmark √                     16×16   Selección checkbox
                                                      (verde #2A5A20 en contexto)

✖ Cross        Aspa ×                         16×16   Deseleccionado / cancelar
                                                      (rojo #6A1520 en contexto)
```

### 2.4 Acciones

```
Ícono          Forma                           Tamaño  Uso
─────          ────                            ──────  ───
▶ Play         Triángulo hacia la derecha      24×24   Continuar (pause menu)

📓 Notebook    Rectángulo con línea central    24×24   Revisar notas (pause menu)

⚙ Settings     Engranaje (círculo con dientes) 24×24   Configuración (pause menu)

🚪 Exit        Rectángulo con flecha →         24×24   Salir (pause menu)
               (puerta vista desde arriba)

🔍 Inspect     Lupa (círculo + línea)          24×24   Inspeccionar objeto

🎤 Voice       Micrófono outline               24×24   Voice/PTT icon
```

### 2.5 Sellos (excepción: son rellenos, no outline)

```
Ícono          Forma                           Tamaño  Uso
─────          ────                            ──────  ───
BUENA          Círculo lleno con borde         ~80×80  Pista evaluada como buena
               Texto "BUENA" en arco           (área)  (verde #2A5A20)
               ┌───────────┐                          
               │   BUENA   │                          
               └───────────┘                          

MALA           Círculo lleno con borde         ~80×80  Pista evaluada como mala
               + "X" central                    (área)  (rojo #6A1520)
               Texto "MALA" en arco                   
               ┌───────────┐                          
               │  ┌─┐      │                          
               │  │X│      │                          
               │  └─┘      │                          
               │   MALA    │                          
               └───────────┘                          
```

---

## 3. Tamaños por Contexto

| Contexto | Tamaño | Ejemplos |
|----------|--------|----------|
| **Inline con texto** (junto a label) | 16×16 | Checkmark, cross, mic bar |
| **Botón de acción** (dentro de botón) | 24×24 | Play, notebook, settings, exit |
| **Header de sección** (título + icono) | 32×32 | — |
| **Slot de inventario** (thumbnail) | 64×64 | Foto, testimonio, distractor |
| **Sello** (sobre foto de pista) | ~40×40 | BUENA, MALA |
| **Health indicator** | 12×12 | Online, error |

---

## 4. Reglas de Implementación

| Propiedad | Regla |
|-----------|-------|
| **Formato** | SVG (vectorial) o PNG 2× (pixel-perfect a 1×) |
| **Borde** | 1px stroke, `#E8D5A3` (excepciones anotadas arriba) |
| **Padding** | 2px mínimo entre el borde del icono y la caja |
| **Caja** | Siempre cuadrada (width = height) |
| **Anti-aliasing** | Activado (Godot default) |
| **Hover** | Sin cambio de color en hover (la UI noir no reacciona al mouse) |
| **Disabled** | Opacidad 40% del color base |

---

## 5. Implementación en Godot

### TextureRect (icono estático)
```gdscript
# Ejemplo para mic icon
var mic_icon = TextureRect.new()
mic_icon.texture = preload("res://assets/ui/ico_mic_idle.png")
mic_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
mic_icon.expand = true
mic_icon.custom_minimum_size = Vector2(32, 16)
```

### AnimatedTexture (icono animado)
```gdscript
# Ejemplo para PTT recording animation (3 frames)
var mic_anim = AnimatedTexture.new()
mic_anim.frames = 3
mic_anim.set_frame_texture(0, preload("res://assets/ui/ico_mic_rec1.png"))
mic_anim.set_frame_texture(1, preload("res://assets/ui/ico_mic_rec2.png"))
mic_anim.set_frame_texture(2, preload("res://assets/ui/ico_mic_rec3.png"))
mic_anim.fps = 8  # Onda lenta
```

---

## 6. Archivos Necesarios

| Archivo | Tamaño | Contexto |
|---------|--------|----------|
| `ico_mic_idle.png` | 32×16 | PTTIndicator IDLE |
| `ico_mic_rec1.png` | 32×16 | PTTIndicator RECORDING frame 1 |
| `ico_mic_rec2.png` | 32×16 | PTTIndicator RECORDING frame 2 |
| `ico_mic_rec3.png` | 32×16 | PTTIndicator RECORDING frame 3 |
| `ico_mic_proc.png` | 32×16 | PTTIndicator PROCESSING |
| `ico_crosshair.png` | 4×4 | Crosshair HUD |
| `ico_health_ok.png` | 12×12 | Main menu health check |
| `ico_health_fail.png` | 12×12 | Main menu health fail |
| `ico_health_loading.png` | 12×12 | Main menu checking |
| `ico_check.png` | 16×16 | Checkbox active |
| `ico_uncheck.png` | 16×16 | Checkbox inactive |
| `ico_close.png` | 24×24 | Cerrar panel |
| `ico_back.png` | 16×16 | Volver |
| `ico_notebook.png` | 24×24 | Pause menu: revisar notas |
| `ico_settings.png` | 24×24 | Pause menu: configuración |
| `ico_exit.png` | 24×24 | Pause menu: salir |
| `ico_play.png` | 24×24 | Pause menu: continuar |
| `ico_stamp_good.png` | ~40×40 | Sello BUENA (relleno verde) |
| `ico_stamp_bad.png` | ~40×40 | Sello MALA (relleno rojo + X) |
| `ico_photo_placeholder.png` | 64×64 | Slot vacío de inventario |
| `ico_testimony.png` | 24×24 | Evidencia tipo testimonio |
| `ico_distractor.png` | 24×24 | Evidencia distractora |
| `ico_inspect.png` | 24×24 | Inspeccionar objeto |
| `ico_mic.png` | 24×24 | Voice/PTT icon (general) |
| `ico_lime.png` | 16×16 | Gajito icon (limón de pica) |
