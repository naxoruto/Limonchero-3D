# Moodboard: UI Noir para Limonchero 3D

> **Propósito:** Referencia visual para mantener coherencia estética en toda la UI.  
> **Fecha:** 2026-05-14 | **Fase:** Pre-producción

---

## 1. Referencias Primarias (Juegos)

### Disco Elysium (2019) — Referencia principal de UI narrativa
```
┌──────────────────────────────────────┐
│                                      │
│ En la pantalla: texto sobre fondo    │
│ oscuro, tipografía serif, paleta de  │
│ color desaturada con acentos         │
│ estratégicos. La UI es parte de la   │
│ narrativa, no un adorno.             │
│                                      │
│ Aplicación en Limonchero:            │
│ • Notebook con dos columnas          │
│ • Texto typewriter como elemento     │
│   central de interfaz                │
│ • Paleta desaturada con acentos de   │
│   color por personaje                │
│ • Fondos de UI siempre oscuros       │
└──────────────────────────────────────┘

Paleta extraída: #2A2A2A (fondos), #C8B88A (texto primario),
#7A6A50 (texto secundario), #4A3A2A (bordes)
```

### L.A. Noire (2011) — Referencia de UI diegética en mundo abierto
```
┌──────────────────────────────────────┐
│                                      │
│ La libreta de casos como objeto      │
│ físico. Fotos de evidencia como      │
│ elementos coleccionables. El HUD     │
│ mínimo se integra al mundo.          │
│                                      │
│ Aplicación en Limonchero:            │
│ • Notebook como objeto diegético     │
│ • Fotos de pistas con borde blanco   │
│ • Sin barras de vida ni minimapa     │
│ • Indicadores contextuales sutiles   │
└──────────────────────────────────────┘

Paleta extraída: #1A1208 (cuero), #F5ECC8 (papel),
#8B1A1A (marcadores), #E8D5A3 (anotaciones)
```

### Pentiment (2022) — Referencia de tipografía manuscrita
```
┌──────────────────────────────────────┐
│                                      │
│ La tipografía como vehículo          │
│ narrativo. Diferentes estilos de     │
│ letra para diferentes personajes.    │
│ El texto es la UI.                   │
│                                      │
│ Aplicación en Limonchero:            │
│ • Special Elite como fuente única    │
│ • Variación por peso (regular/italic)│
│ • Colores de identidad por NPC       │
│ • Efecto typewriter como estilo      │
└──────────────────────────────────────┘
```

### Return of the Obra Dinn (2018) — Referencia de restricción visual
```
┌──────────────────────────────────────┐
│                                      │
│ Paleta monocromática + acentos       │
│ estratégicos. Cada elemento en        │
│ pantalla tiene un propósito.          │
│                                      │
│ Aplicación en Limonchero:            │
│ • UI mínima — solo lo esencial       │
│ • Sin decoración visual superflua    │
│ • Cada color tiene significado       │
│   narrativo (ver §4.4 Art Bible)     │
└──────────────────────────────────────┘
```

---

## 2. Referencias Secundarias (Cine + Diseño Gráfico)

### Blade Runner (1982) — Iluminación y contraste
- Neón en oscuridad como lenguaje visual
- Humo/bruma que suaviza bordes
- Temperaturas de color contrastantes (ámbar vs frío)

### Sin City (2005) — Alto contraste + color selectivo
- Blanco y negro con acentos de color específicos
- Siluetas sobre fondos claros
- Texto sobre panel como elemento gráfico

### Carteles de Cine Noir (1940s) — Tipografía y composición
- Tipografía display sans-serif condensada para títulos
- Capas (texto sobre texto, desalineación intencional)
- Paletas: sepia, crema, negro, rojo acento

---

## 3. Paleta de Color UI (resumen ejecutivo)

```
┌──────────────────────────────────────────────────────────┐
│                                                           │
│  Fondo libreta     #F5F0E8  ████████  (crema cálido)     │
│  Texto libreta     #2A1A08  ████████  (tinta sepia)      │
│  Sello BUENA       #2A5A20  ████████  (verde botella)    │
│  Sello MALA        #6A1520  ████████  (rojo sello)       │
│  PTT activo        #D4A030  ████████  (ámbar Bourbon)    │
│  Gajito popup      #7ABE30  ████████  (verde lima)       │
│  Pausa fondo       #1A1208  ████████  (cuero oscuro)     │
│  Pausa texto       #D8DCE0  ████████  (blanco frío)      │
│  Texto primario    #E8D5A3  ████████  (blanco cálido)    │
│  Texto secundario  #7A6A50  ████████  (gris sepia)       │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## 4. Referencias de Layout

### Main Menu
Referencia: **Títulos de HBO / True Detective (2014)**
- Texto centrado sobre fondo oscuro
- Tipografía display en caps
- Indicador de estado minimalista

### HUD In-Game
Referencia: **Dead Space (2008)** — HUD integrado al personaje
- Sin HUD flotante persistente
- Información contextual aparece solo cuando es relevante
- Indicadores mínimos (línea, punto, barra pequeña)

### Subtitle System
Referencia: **Disco Elysium** — 2 canales de diálogo
- Canal izquierdo: NPC (nombre en color + texto)
- Canal derecho: Player (texto en color diferente)

### Inventory / Notebook
Referencia: **L.A. Noire notebook** + **The Last of Us craft menu**
- Objeto diédico con textura de papel/cuero
- Fotos en blanco y negro pegadas
- Anotaciones manuscritas

### Accusation Tree
Referencia: **Phoenix Wright: Ace Attorney** — Presentar evidencias
- Checkboxes de evidencias seleccionables
- Confirmación antes de presentar
- Feedback inmediato del juez/Spud

---

## 5. Reglas de Consistencia Visual

1. **Temperatura de color:** UI usa blanco frío (`#D8DCE0`) donde el mundo usa ámbar (`#D4A030`). Esto señala "fuera del mundo" (menús) vs "dentro del mundo" (diegético)

2. **Tipografía única:** Special Elite para todo. Sin variación de fuente — la variación viene de tamaño, peso e italic

3. **Sin sombras paralaje:** La UI es plana (2D). Sin sombras 3D, sin gradientes, sin glassmorphism

4. **Sin redondeos:** Todos los bordes son rectos. El redondeo no existe en la UI de Limonchero 3D

5. **Iconos outline:** Todos los iconos son outline geométrico en `#E8D5A3`. Sin iconos rellenos, sin color en iconos

6. **Texto como UI:** Preferir texto sobre iconos. Siempre que sea posible, la información se comunica con texto en vez de símbolos

---

## 6. Búsquedas de Referencia (para Google/Pinterest)

```
"noir detective video game UI"
"disco elysium UI design"
"la noire notebook evidence board"
"typewriter font UI retro"
"art deco interface design 1920s"
"film noir title cards typography"
"minimalist HUD first person game"
"pentiment manuscript UI"
"obra dinn 1-bit UI"
"1940s police evidence board"
```
