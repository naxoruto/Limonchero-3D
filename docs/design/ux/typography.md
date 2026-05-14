# Typography Specification

> **Fuente única:** Special Elite (Apache 2.0 / OFL)  
> **Fallback:** Courier Prime (OFL) si Special Elite no está disponible  
> **Propósito:** Toda la UI del juego usa una única familia tipográfica monospace serif (tipo máquina de escribir)

---

## 1. Selección de Fuente

### Special Elite
```
URL: https://fonts.google.com/specimen/Special+Elite
Licencia: Apache 2.0
Características: Monospace, serif, desgastada (distressed),
                mayúsculas con peso consistente,
                glifos con variación intencional (no perfecta)
```

**Por qué Special Elite:**
- Es la recomendación del Art Bible §7.4.2
- Tiene el "desgaste" visual (distressed) que encaja con la estética noir
- Es monospace con serif — la máquina de escribir de los 50
- Licencia Apache 2.0 permite uso comercial sin atribución
- Disponible en Google Fonts para descarga directa .ttf

### Fallback: Courier Prime
```
URL: https://quoteunquoteapps.com/courierprime/
Licencia: OFL (SIL Open Font License)
Características: Diseñada para guiones de cine, monospace serif
                más legible que Courier New, sin el desgaste de Special Elite
```

---

## 2. Tamaños y Usos

| Contexto | Tamaño | Peso | Color | Tracking |
|----------|--------|------|-------|----------|
| Título de pantalla (menú, pausa) | 24pt | Bold (700) | `#E8D5A3` | +2px |
| Header de sección (inventario, settings) | 18pt | Regular (400) | `#E8D5A3` | +1px |
| Cuerpo de texto (descripciones, diálogo) | 14pt | Regular (400) | `#FFFFFF` / `#E8D5A3` | 0 |
| Subtítulos (HUD) | 14pt | Regular (400) | `#FFFFFF` | 0 |
| Texto secundario (labels, metadata) | 12pt | Regular (400) | `#7A6A50` | 0 |
| Texto pequeño (session_id, timestamps) | 10pt | Regular (400) | `#7A6A50` | 0 |
| Nombre NPC en subtítulos | 14pt | Bold (700) | Por personaje (GDD §8.4) | +1px |
| Código de evidencia | 11pt | Bold (700) | `#E8D5A3` | +1px |
| Sello BUENA/MALA | 16pt | Bold (700) | `#2A5A20` / `#6A1520` | +3px |
| Botón de acción | 14pt | Regular (400) | `#E8D5A3` | +1px |
| Texto de Gajito popup | 10pt | Regular (400) | `#1E1810` | 0 |

---

## 3. Jerarquía Visual

```
H1 — Título de pantalla
  Special Elite Bold 24pt, tracking +2px
  (#E8D5A3 sobre fondo oscuro)

H2 — Header de sección
  Special Elite Regular 18pt, tracking +1px
  (#E8D5A3 sobre fondo oscuro)

Body — Cuerpo de texto / Subtítulos
  Special Elite Regular 14pt
  (#FFFFFF para subtítulos, #E8D5A3 para texto de UI)

Caption — Texto secundario
  Special Elite Regular 12pt
  (#7A6A50 para metadata)

Small — Texto auxiliar
  Special Elite Regular 10pt
  (#7A6A50 para session_id, timestamps)
```

---

## 4. Reglas de Estilo

| Propiedad | Regla |
|-----------|-------|
| **Font family** | `"Special Elite", "Courier Prime", monospace` |
| **Font smoothing** | Activado (Godot default) |
| **Ligaduras** | Desactivadas (no hay ligaduras en monospace) |
| **Kerning** | Estándar (sin optical kerning) |
| **Bold** | Solo para títulos y nombres NPC. Noir usa Regular como default. El bold es excepción, no regla |
| **Italic** | Texto de Gajito (para diferenciar su voz). Ocasional para énfasis en descripciones |
| **Underline** | No usar. En su lugar, usar color o bold |
| **All caps** | Solo para títulos de pantalla (menú, pausa, resolución) |
| **Color blocks** | Texto siempre sobre fondo oscuro (≥70% opacidad) para contraste |

---

## 5. Integración en Godot

### DynamicFont
```gdscript
# Configuración en theme.tres
var font = DynamicFont.new()
font.font_data = preload("res://assets/fonts/SpecialElite-Regular.ttf")
font.size = 14  # Default body size
font.outline_size = 0  # Sin outline
font.outline_color = Color(0, 0, 0, 0)
```

### Theme Resource
Crear `theme.tres` en `game/assets/fonts/theme.tres`:
```gdscript
# Theme configuración base
Theme theme = Theme.new()
theme.default_font = font_data
theme.set_color("font_color", "Label", Color("#E8D5A3"))
theme.set_color("font_color", "Button", Color("#E8D5A3"))
theme.set_constant("outline_size", "Label", 0)
```

### Variaciones por Contexto
| Nodo Godot | Font Size | Font Color |
|-----------|-----------|------------|
| `Label` (título) | 24 | `#E8D5A3` |
| `Label` (body) | 14 | `#E8D5A3` |
| `RichTextLabel` (subtítulos) | 14 | `#FFFFFF` |
| `Button` | 14 | `#E8D5A3` |
| `LineEdit` (input) | 14 | `#E8D5A3` |

---

## 6. Archivos Necesarios

| Archivo | Fuente | Ruta en Godot |
|---------|--------|---------------|
| `SpecialElite-Regular.ttf` | Google Fonts (Apache 2.0) | `assets/fonts/SpecialElite-Regular.ttf` |
| `SpecialElite-Bold.ttf` | Derivado de Regular (simulado con weight en Godot si no existe) | `assets/fonts/SpecialElite-Bold.ttf` (opcional) |
| `theme.tres` | Creado en Godot | `assets/fonts/theme.tres` |
