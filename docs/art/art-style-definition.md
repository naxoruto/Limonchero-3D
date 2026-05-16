# Art Style Definition — Limonchero 3D
**Referencia rápida para implementación. Doc completo:** `art/art-bible.md`  
**Fecha:** 2026-05-03

---

## Estilo en una frase

**Low-poly facetado, cartoon-noir, años 50 art deco. Frutas atrapadas en una noche que no terminará.**

Flat shading. Sin smooth shading. Cada cara del mesh debe verse intencionada.

---

## Paleta de Colores Canónica

| ID | Nombre | Hex | Dónde |
|----|--------|-----|-------|
| C1 | Bourbon | `#D4A030` | Lámparas, marcos, herrería art deco |
| C2 | Caoba | `#2A1B0E` | Suelos de madera, paredes |
| C3 | Crema Tile | `#E8DFC8` | Baldosas vestíbulo, papel |
| C4 | Verde Neón | `#8BC34A` | Solo exterior + señal Barry en pasillo |
| C5 | Rojo Granada | `#8B2332` | Solo Moni y sus objetos |
| C6 | Amarillo Barry | `#F5D020` | Solo Barry — el más saturado del juego |
| C7 | Tinta Noir | `#1E1810` | Negro cálido base — NUNCA usar #000000 |

**Regla:** Frutas son los únicos portadores de color saturado. Entorno siempre desaturado.

---

## Temperatura de Iluminación por Zona

| Zona | Temperatura | Hex dominantes |
|------|-------------|----------------|
| Vestíbulo + Salón | 2700K–3200K (ámbar cálido) | `#2A1B0E` + `#D4A030` |
| Almacén + Pasillo servicio | 3500K–4000K (industrial) | `#4A5040`–`#6A7060` |
| Barra + Reservados | 2700K (caoba/cuero cálido) | `#2A1B0E` + `#5A3020` |
| Sala interrogatorio + Oficina | 4000K–5000K (neutra/fría) | `#3A3830` — sin ámbar |

**Implementar en Godot:** Interpolación de `WorldEnvironment` según posición Z del jugador. No cortes bruscos.

---

## Siluetas por Personaje

| Personaje | Fruta | Geometría base | Regla crítica |
|-----------|-------|----------------|---------------|
| Limonchero | Limón amarillo | Elipsoide alargado vertical | Fedora + gabardina obligatorios |
| Gajito | Key lime | Esfera achatada, compacta | Más pequeño y bajo que Limonchero |
| Commissioner Papolicia | Papa | Elipsoide irregular, base plana | Ancho, bajo, asimétrico — un hombro más alto |
| Barry Peel | Plátano | Arco cóncavo elongado | Traje impecable, sin arrugas, silueta contenida |
| Moni Graná Fert | Granada | Esfera + corona geométrica angular | La corona identifica a Moni incluso en deuteranopia |
| Gerry Broccolini | Brócoli | Triángulo invertido, cabeza ramificada | Ancho en hombros, cabeza que expande hacia arriba |
| Lola Persimmon | Caqui | Tomate achatado con pico inferior | El pico crea inestabilidad visual — lectura de ansiedad |

**Prueba obligatoria:** Renderiza todos en silhouette shader negro. Cada silueta debe identificarse en 2 segundos sin color.

---

## Polígonos por Asset

| Tipo | Budget |
|------|--------|
| Personaje principal (Limonchero, Barry) | ~1200–1800 tris |
| NPC secundario (Gerry, Lola) | ~800–1200 tris |
| NPC minor (Gajito, Papolicia) | ~600–1000 tris |
| Prop interactuable (pista física) | ~200–400 tris |
| Mobiliario (mesa, silla) | ~100–300 tris |
| Crowd siluetas (fondo) | ~50–80 tris — `MultiMeshInstance3D` obligatorio |

**Total draw calls escena:** < 150 (budget conservador para PC).

---

## UI — Colores

| Elemento | Hex |
|----------|-----|
| Fondo libreta | `#F5F0E8` |
| Texto libreta | `#2A1A08` |
| Sello BUENA | `#2A5A20` + forma círculo completo |
| Sello MALA | `#6A1520` + forma círculo con X interior |
| Rim light pista (interactiva) | `#E8F0F8` pulsante a 0.5Hz |
| Indicador PTT activo | `#D4A030` pulsante |
| Pop-up Gajito | `#7ABE30` |
| Fondo menú pausa | `#1A1208` |

---

## Reglas de Importación a Godot

1. Exportar desde Blender como `.glb` (no `.fbx`)
2. Flat shading aplicado en Blender antes de exportar
3. Un material por mesh, no vertex colors
4. Nombre de archivo: `[personaje]_[versión].glb` → ej. `barry_v1.glb`, `llave_maestra_v1.glb`
5. Origin point en la base del modelo (no centroid)
6. Escala: 1 unidad Blender = 1 metro Godot

---

## Referencias Visuales

- L.A. Noire (iluminación, acting NPC, atmósfera jazz)
- Blade Runner (neones en oscuridad, lluvia, aislamiento)
- Sin City (contraste extremo, blanco/negro + color selectivo)
- Disco Elysium (texto en pantalla, tono filosófico)
- Animal Crossing / Los Sims (sistema de balbuceo NPC — solo audio, no estética)

---

*Para preguntas de decisión artística, aplicar siempre la regla fundacional: elige la tensión, no la resolución.*
