# Plan de Sesiones Blender MCP — El Agave y La Luna
**Versión:** 1.0  
**Fecha:** 2026-05-05  
**Referencia:** `docs/art/Plan de trabajo blender.md` (checklist detallado por zona)  
**Estado actual:** Z1 shell parcial (93 objetos). 2/17 materiales. Z2–Z6 vacías.

---

## Principios de sesión

Cada sesión:
- **1 objetivo, 1 resultado verificable** — se termina cuando puedes hacer screenshot y confirmar
- **Guardar `.blend` al final** con nombre `[zona]_[bloque]_v[N].blend`
- **No combinar zonas en una sesión** — si terminás antes, pará igual
- **Flat shading siempre activo** — si algo se ve smooth, es un error a corregir ahí mismo

---

## BLOQUE 0 — Configuración Base (BLOQUEANTE)

### S0 — Materiales de paleta global
**Input:** Proyecto Blender existente con Z1 parcial  
**Objetivo:** Crear los 15 materiales faltantes de la paleta canónica  
**Tareas:**
- Crear Principled BSDF para cada color del level design doc (ver tabla abajo)
- Flat shading en todos los materiales (Roughness alto, sin specular)
- Sin vertex colors — un material por mesh

| ID | Nombre | Hex | Uso |
|----|--------|-----|-----|
| M01 | panel_madera_oscura | `#2A1B0E` | Panelado Z1/Z2/barra |
| M02 | pared_enlucido | `#3A2A1A` | Paredes Z1 |
| M03 | suelo_hex_crema | `#E8DFC8` | Suelo Z1/Z2 |
| M04 | suelo_hex_negro | `#1E1810` | Suelo Z1/Z2 alternado |
| M05 | techo_lata | `#7A6040` | Techo Z1/Z2 |
| M06 | laton | `#C8A040` | Marcos puertas, ganchos |
| M07 | neon_verde | `#5A7A2E` | Neón exterior Z1, ventana Z4 |
| M08 | concreto_servicio | `#4A4035` | Paredes Z3/Z4 |
| M09 | cajas_madera_oscura | `#4A3020` | Cajas Z3 (variante A) |
| M10 | cajas_madera_media | `#6B4423` | Cajas Z3 (variante B) |
| M11 | metal_servicio | `#4A4538` | Estantería Z3, puerta servicio |
| M12 | tapiz_barry | `#2E4A1E` | Reservado Barry (Z2) |
| M13 | panelado_oficina | `#1E1A14` | Pared piso-techo Z5 |
| M14 | pared_interrogatorio | `#1E1810` | Paredes Z6 |
| M15 | espejo | `#0E0E0C` | Marco espejo Z6 (Metallic 0.3, Roughness 0.2) |
| M16 | alfombra_persa | `#4A2A1E` | Alfombra Z5 |
| M17 | vidrio_puerta | `#CCCCCC` | Puertas sur Z1 (Transmission 0.15) |

**Verificación:** `get_scene_info` muestra 17 materiales. Screenshot con algún objeto aplicando 3 materiales distintos.  
**Guardar:** `z0_materiales_v1.blend`

---

## BLOQUE 1 — Zona 1: Vestíbulo (~5m × 7m, techo 3.5m)

### S1 — Shell Z1 (paredes, suelo, techo)
**Input:** S0 completo  
**Objetivo:** Caja arquitectónica de Z1 con materiales aplicados  
**Tareas:**
- Paredes (enlucido `M02` arriba, panelado `M01` hasta 1.5m)
- Suelo hexagonal bicolor: tiles hex `M03`/`M04` (pattern geométrico en geometría — no textura)
- Techo lata prensada con patrón geométrico (`M05`)
**Verificación:** Screenshot desde el sur mirando al norte — caja visible, materiales distintos por zona, flat shading.  
**Guardar:** `z1_shell_v1.blend`

### S2 — Arco norte + Puertas sur
**Input:** S1 completo  
**Objetivo:** Las dos aperturas principales de Z1  
**Tareas:**
- Arco norte trapezoidal 4m × 3m (sin curvas — forma trapezoidal en geometría)
- Puertas dobles sur: vidrio emplomado `M17`, patrón rombo a 45° en geometría, marcos latón `M06`
**Verificación:** Screenshot desde centro de Z1 — arco norte deja ver Z2, puertas sur cierran el espacio al sur.  
**Guardar:** `z1_aberturas_v1.blend`

### S3 — Mostrador guardarropa
**Input:** S2 completo  
**Objetivo:** Mostrador oeste completo con espejo y ganchos  
**Tareas:**
- Mostrador de madera oscura `M01`, pared oeste
- Espejo de cuerpo entero detrás del mostrador
- 12+ ganchos de latón `M06` numerados (prismas cúbicos pequeños — no detail alto)
- Abrigos como prismas trapezoidales (~1.4m, sin mangas individuales), colores neutros
**Verificación:** Screenshot lateral — ganchos numerados legibles a "4 metros" (1.6m cámara, ~2.5m distancia), silueta del mostrador clara.  
**Guardar:** `z1_guardarropa_v1.blend`

### S4 — Props narrativos Z1
**Input:** S3 completo  
**Objetivo:** Objetos de la cadena F2 en posición correcta  
**Tareas:**
- Abrigo #14: separado ~5cm del gancho anterior, etiqueta de latón `M06` visible
- Cenicero de vidrio centrado sobre el mostrador (cubre el talón)
- Candelabro asimétrico desplazado hacia el norte (lado Papolicia)
**Verificación:** Screenshot cenital del mostrador — cenicero cubre el talón, abrigo #14 distinguible del resto por separación.  
**Guardar:** `z1_props_v1.blend`

### S5 — Iluminación Z1
**Input:** S4 completo  
**Objetivo:** L1 (neón exterior) + L2 (candelabro)  
**Tareas:**
- **L1**: Area Light verde neón `#5A7A2E`, 5500K, 0.4 int — entra por puertas sur. **Restricción crítica: solo toca superficies verticales, NUNCA el suelo**
- **L2**: Point Light candelabro `#F5DFA0`, 2400K, 1.2 int + Emission 0.4 en geometría del candelabro
- Materiales finales: panelado Roughness 0.85, suelo crema Roughness 0.9, vidrio puerta Transmission 0.15
**Verificación:** Screenshot desde el sur — neón verde en paredes, NO en suelo. Candelabro emite luz. Ningún `#000000` puro.  
**Guardar:** `z1_iluminacion_v1.blend` → **Exportar `z1_v1.glb`**

---

## BLOQUE 2 — Zona 2: Salón Principal (~18m × 14m, techo 4.5m)

### S6 — Shell Z2 (paredes, pilastras, techo, pista)
**Input:** S5 completo  
**Objetivo:** Caja arquitectónica del salón  
**Tareas:**
- Paredes con 3 pilastras falsas por lado (altura completa 4.5m, capitel a 45°, `M01`)
- Molduras de techo en 3 niveles descendentes hacia pista central
- Pista de baile 8m × 8m — suelo hexagonal igual que Z1, **sin props en la pista**
- Puerta a bodega: detrás del mostrador del bar en pared posterior (no visible desde pista)
**Verificación:** Screenshot desde el centro de la pista — 360° libres, pilastras visibles en las 4 paredes.  
**Guardar:** `z2_shell_v1.blend`

### S7 — Escenario jazz
**Input:** S6 completo  
**Objetivo:** Escenario norte elevado con instrumentos  
**Tareas:**
- Plataforma escenario (+0.4m elevación), fondo terciopelo teal-negro `#0D2020`
- Piano de cola: 150–200 polys total, **todo angulado** (sin curvas)
- Micrófono de pie, 2 sillas músico, atril, contrabajo apoyado en pared
- Silla vacía con partituras abiertas (punto de interés visual)
**Verificación:** Screenshot desde centro pista — escenario legible como espacio performativo, piano identificable como piano.  
**Guardar:** `z2_escenario_v1.blend`

### S8 — Barra oeste
**Input:** S7 completo  
**Objetivo:** Barra de caoba con estanterías retroiluminadas  
**Tareas:**
- Mostrador de caoba 7m, frente con curva suave en planta (**único elemento curvo en entornos**)
- Estanterías retroiluminadas: 3 filas (5 + 8 + 4 botellas), 3–4 modelos base con variación escala 0.9×–1.1×
- 4 taburetes barra (8 lados en asiento, ~50–70 polys c/u)
- Suelo detrás de barra en madera `M01` (diferente del tile del salón)
**Verificación:** Screenshot lateral desde la barra — silueta de Gerry tendría rim light desde las estanterías. Taburetes legibles.  
**Guardar:** `z2_barra_v1.blend`

### S9 — Mobiliario de sala
**Input:** S8 completo  
**Objetivo:** Mesas, sillas, reservado Barry  
**Tareas:**
- 8–10 mesas de gala (Ø0.9m): mantel + 2–3 vasos + cenicero + lámpara mesa + florero mínimo
- Mesas de fondo: solo mantel + silueta de prop (sin detalle — más lejos del jugador)
- Reservado Barry NW: alcoba recesada 0.6m, papel tapiz `M12` (patrón rombo en geometría, canal 2mm), mesa rectangular, 2 sillas, copa bourbon, cenicero limpio
- Mesa de Moni: segunda desde el escenario, lámpara ámbar, cenicero con boquilla
- Mesa de Lola: centro-sur, más cercana a la pista
**Verificación:** Screenshot desde centro pista — confirmar visibilidad: escenario (N), Moni (E), barra (W), arco vestíbulo (NW). 5+ NPCs colocables sin bloqueo visual.  
**Guardar:** `z2_mobiliario_v1.blend`

### S10 — Crowd (siluetas de gala)
**Input:** S9 completo  
**Objetivo:** Crowd implementado como MultiMesh-ready  
**Tareas:**
- Modelar 1 silueta humanoide base (40–60 polys total — prisma cabeza + tronco + piernas)
- 5 variaciones de escala (0.9×–1.1×) y 2–3 variaciones de postura (sentado, de pie)
- Colocar en mesas del fondo (no en el área de NPC principales)
- **Nombrar como `crowd_base_v1` — en Godot se importará como MultiMeshInstance3D**
**Verificación:** Screenshot desde el sur — crowd da sensación de gala sin competir visualmente con los NPCs. Escala de grises: crowd más oscuro que zona de NPCs.  
**Guardar:** `z2_crowd_v1.blend`

### S11 — Props narrativos Z2
**Input:** S10 completo  
**Objetivo:** F1 y objetos de testimonio en posición  
**Tareas:**
- **F1** (acuerdo fideicomiso): boca abajo bajo la copa de Barry en reservado NW
- Copa de bourbon: a medio tomar, sin condensación
- Cenicero de Moni: cigarrillo a medio fumar y apagado (no aplastado), boquilla con marca carmesí (color en geometría)
- Reloj art-deco noreste
**Verificación:** Screenshot del reservado de Barry — F1 semioculto bajo la copa, papel tapiz verde oscuro contrasta con el amarillo del NPC Barry.  
**Guardar:** `z2_props_v1.blend`

### S12 — Iluminación Z2
**Input:** S11 completo  
**Objetivo:** L3 (estanterías), L4 (lámparas mesa), L5 (escenario)  
**Tareas:**
- **L3**: Area Light detrás estanterías `#C88030`, 2200K, 0.8 int — botellas como oclusores
- **L4**: Point Light por lámpara de mesa `#D4A050`, 2700K, 0.4–0.6 int, falloff agresivo
- **L5**: Spot Light escenario `#FFE8B0`, 3200K, 2.0 int, ángulo 35°, blend 0.1 (borde duro)
**Verificación:** Screenshot escala de grises — personajes en sus posiciones serían más brillantes/contraste que el entorno.  
**Guardar:** `z2_iluminacion_v1.blend` → **Exportar `z2_v1.glb`**

---

## BLOQUE 3 — Zona 3: Bodega (~9m × 7m)

### S13 — Shell Z3
**Input:** S12 completo  
**Objetivo:** Caja arquitectónica de bodega  
**Tareas:**
- Paredes bloque de concreto `#4A5040` → `#4A4035` en esquinas (variación de color en geometría)
- Vigas de acero expuestas en techo `#3A3530` (sin lata prensada)
- Suelo de concreto con marcas de humedad `#3A3028`
- Media puerta batiente a cocina: interior parcialmente legible (olla, superficies acero)
**Verificación:** Screenshot desde la puerta — transición visual clara de club → zona de servicio. Sin ámbar en las paredes.  
**Guardar:** `z3_shell_v1.blend`

### S14 — Estantería, cajas y ángulo muerto
**Input:** S13 completo  
**Objetivo:** Almacenamiento y verificación del ángulo muerto NE  
**Tareas:**
- Estantería piso-techo pared oeste: metal `M11`, baldas de madera
- 12–15 cajas de madera (2–3 modelos base, escala variada, `M09`/`M10`), 3 columnas
- 3–4 sacos de arpillera `#8A7A5A`
- **Columna ángulo muerto NE (1.6m–1.9m)**: verificar con cámara FPS desde la puerta que la maleta de Moni NO es visible
- Maleta de Moni: colocada en ángulo muerto NE, semioculta
**Verificación CRÍTICA:** Screenshot desde la puerta de entrada (cámara a 1.6m de altura) — maleta de Moni invisible. Screenshot al rodear los sacos — maleta visible.  
**Guardar:** `z3_almacenamiento_v1.blend`

### S15 — Props narrativos Z3 + Iluminación
**Input:** S14 completo  
**Objetivo:** Props narrativos y luz de bodega  
**Tareas:**
- Silla plegable junto a puerta trasera (puesto vacío de Gerry)
- Puerta de servicio metálica este: semiabierta ~15–20°, herrumbre `#6A4030`
- Caja ligeramente fuera de alineación en columna NE (movida y mal recolocada)
- Candado colgante en estantería
- **L6**: Point Light central colgante `#D4903A`, 2500K, 1.5 int, sombras duras máximas
- Bloqueador de luz en costado NE para sombra narrativa del ángulo muerto
**Verificación:** Screenshot desde el centro — sombra del ángulo muerto NE visible, foco colgante como única fuente de luz.  
**Guardar:** `z3_final_v1.blend` → **Exportar `z3_v1.glb`**

---

## BLOQUE 4 — Zona 4: Pasillo de Servicio (~12m × 2.2m)

### S16 — Shell Z4 + Iluminación
**Input:** S15 completo  
**Objetivo:** Pasillo completo (estructura + iluminación + props narrativos)  
**Tareas:**
- Paredes concreto `#4A4035`, suelo concreto con juntas marcadas
- Tubería de cobre norte-sur en techo (línea recta, sin ramas)
- Ventana alta 1m × 0.4m en pared este (a 2.2m) con tira de neón verde `M07` — **único lugar donde el neón toca el suelo**
- Huella de barro de Barry: suela ~28cm, `#3A2820`, entre 2° y 3° pool de luz
- Colilla de palillo de canela en base de puerta norte
- Puerta norte (madera maciza, cerradura visible)
- **L7**: 3 Point Lights equidistantes `#C88030`, 2600K, 1.0 int, falloff muy agresivo — oscuridad efectiva entre pools
**Verificación:** Screenshot del pasillo completo — 3 pools de luz visibles, oscuridad entre ellos, neón verde en el suelo (intencional aquí), huella de barro en pool 2-3.  
**Guardar:** `z4_final_v1.blend` → **Exportar `z4_v1.glb`**

---

## BLOQUE 5 — Zona 5: Oficina (~8m × 6m)

### S17 — Shell Z5
**Input:** S16 completo  
**Objetivo:** Caja arquitectónica de la oficina  
**Tareas:**
- Panelado madera piso-techo `M13` (a diferencia del club donde solo llega a 1.5m — aquí es total)
- Ventana oeste: abierta, pestillo en posición "cerrado desde dentro" (detalle visible)
- **Puerta secundaria oeste**: empotrada en el panelado, junta de 5mm en perímetro + cerrojo latón visible, **sin manija exterior**
- Periódico enmarcado pared este (caja plana — texto ilegible intencional)
**Verificación:** Screenshot desde la puerta de entrada — panelado total visible, puerta secundaria casi camuflada, ventana con pestillo.  
**Guardar:** `z5_shell_v1.blend`

### S18 — Escritorio + archivadores + caja fuerte
**Input:** S17 completo  
**Objetivo:** Muebles principales de la oficina  
**Tareas:**
- Escritorio mahogany `#1A1208` pared norte, orientado sur (la cara larga mira al jugador al entrar)
- Caja fuerte pared este: puerta completamente abierta, documentos desordenados parcialmente sacados
- 2 archivadores verde gobierno `#2A3A2A`, un cajón ligeramente abierto con documentos visibles
- Alfombra persa `M16` (patrón geométrico bajo en geometría), borde NE levantado ~2cm (loop edge elevado)
**Verificación:** Screenshot desde la puerta — lámpara volcada y escritorio legibles desde el umbral (primera lectura al entrar).  
**Guardar:** `z5_mobiliario_v1.blend`

### S19 — Props narrativos Z5 + Iluminación
**Input:** S18 completo  
**Objetivo:** F3 y evidencias en posición + luz inusual  
**Tareas:**
- Lámpara volcada sobre escritorio, cable tenso hacia la izquierda
- Contorno rectangular de polvo en escritorio (~30cm × 20cm sin polvo donde estuvo F1)
- **F3** (encendedor de oro): en borde levantado de alfombra NE — semioculto, accesible con Press-X
- Huellas de Barry (dirección hacia caja fuerte y ventana)
- **L8**: Spot Light volcado diagonal ~35° del suelo, hacia pared NO, `#E8E4D8`, 4000K, 1.8 int — genera sombras ascendentes
- Luz ambiental muy baja y neutra `#1A1A18` — **sin ámbar aquí**
**Verificación CRÍTICA:** Screenshot con sombras — sombras van hacia ARRIBA en los objetos (efecto L8). Sin neón exterior visible.  
**Guardar:** `z5_final_v1.blend` → **Exportar `z5_v1.glb`**

---

## BLOQUE 6 — Zona 6: Sala de Interrogatorio (~5m × 4m)

### S20 — Shell + mobiliario + iluminación Z6
**Input:** S19 completo  
**Objetivo:** Zona 6 completa en una sesión (zona más simple)  
**Tareas:**
- Paredes oscuras `M14` (sin desgaste — únicas paredes "nuevas" del club)
- Mesa rectangular perfectamente centrada (**única geometría con simetría deliberada en el juego**)
- 2 sillas exactamente opuestas
- Espejo unidireccional pared sur: 3m × 1.8m, marco `M15` (Metallic 0.3, Roughness 0.2)
- Bloc de notas ligeramente fuera del eje (para que L9 revele indentaciones)
- Indentaciones en el bloc: depresión geométrica 0.5mm
- 2 vasos de agua vacíos, 1 cenicero limpio
- **L9**: Spot cenital sobre mesa `#F0E8D0`, 3200K, 2.5 int (**la más alta del juego**), ángulo 40°, blend 0.05
- Luz ambiental prácticamente nula `#100E0C`
**Verificación CRÍTICA:** Screenshot del bloc — iluminación oblicua revela las indentaciones. Contraste bloc `#E8E0C8` sobre mesa `#2A2218` → ratio ≥ 4.5:1.  
**Guardar:** `z6_final_v1.blend` → **Exportar `z6_v1.glb`**

---

## BLOQUE 7 — Conectores entre zonas

### S21 — Corredor este + conexiones
**Input:** S20 completo  
**Objetivo:** Pasillo de conexión Z2 → Z6 + puerta bodega → pasillo  
**Tareas:**
- Corredor este (desde salón hacia Z6): aplique de vidrio esmerilado arriba, paredes coherentes con Z2
- Puerta de servicio este de bodega (Z3 → Z4): alineada con el shell de ambas zonas
- Verificar que el corredor este NO es accesible desde la pista de baile sin rodear el mostrador
**Verificación:** Walk-through screenshot — ruta Z1→Z2→bodega→pasillo→Z5 y ruta Z2→corredor→Z6 coherentes visualmente.  
**Guardar:** `conectores_v1.blend`

---

## BLOQUE 8 — Verificación de siluetas

### S22 — Silhouette pass global
**Input:** S21 completo + todos los .glb exportados  
**Objetivo:** Confirmar legibilidad de todo antes de finalizar materiales  
**Tareas:**
- Renderizar con silhouette shader (negro plano sobre blanco) cada zona desde altura jugador (1.6m)
- Checklist por zona:
  - [ ] Objetos interactuables identificables a 4m sin color
  - [ ] F1 (bajo copa Barry) legible como objeto separado
  - [ ] F3 (encendedor bajo alfombra) semioculto pero con forma reconocible
  - [ ] Maleta Moni invisible desde puerta Z3
  - [ ] Abrigo #14 distinguible de los demás
- Si algún elemento falla: revisar masa geométrica primero, no añadir detalle
**Guardar:** Screenshots en `docs/art/silhouette-check/zona_[N].png`

---

## BLOQUE 9 — Interactuables finales

### S23 — F1–F5 verificación + rim light
**Input:** S22 completo (sin BLOCKING en silhouette check)  
**Objetivo:** Posicionamiento final de evidencias y rim light de interacción  
**Tareas:**
- Verificar posición exacta de F1 (Z2 reservado Barry), F2 (Z1 guardarropa), F3 (Z5 alfombra NE)
- F4 (maleta Moni, Z3): invisible desde puerta — confirmar con screenshot FPS
- F5 (ceniza sobre quemado, baño empleados Z3): cenicero plano, resto de sobre visible
- Rim light pulsante: `#E8F0F8`, configurado para objetos interactuables activos (emisión cíclica 0.5Hz — en Godot se animará, en Blender solo verificar que el objeto tiene el material correcto)
**Verificación:** Screenshot de cada evidencia con su rim light aplicado.  
**Guardar:** `interactuables_final_v1.blend`

---

## BLOQUE 10 — Optimización

### S24 — Optimización y audit de performance
**Input:** S23 completo  
**Objetivo:** Verificar budget de draw calls antes de exportación final  
**Tareas:**
- Confirmar crowd como objeto único listo para MultiMeshInstance3D en Godot (single draw call)
- Simplificar geometrías de soporte: ningún prop de fondo tiene más polys que el personaje más cercano
- Confirmar flat shading en **toda** la geometría arquitectónica (ningún smooth shading en entornos)
- Contar instancias únicas — objetivo: < 100 draw calls por frame en escena completa
- Revisar que ningún material usa `#000000` puro — negro mínimo es `#1E1810`
**Verificación:** `get_scene_info` con conteo de mesh instances.  
**Guardar:** `optimizacion_v1.blend`

---

## BLOQUE 11 — Exportación final

### S25 — Export completo + validación
**Input:** S24 completo  
**Objetivo:** Assets listos para Godot 4  
**Tareas por zona:**
- Exportar cada zona como glTF 2.0 (`.glb`) con convención `[zona]_[elemento]_v[N].glb`
- Confirmar antes de cada export:
  - [ ] Flat shading aplicado en Blender
  - [ ] Un material por mesh
  - [ ] Sin vertex colors
  - [ ] Origin point en base de cada modelo
  - [ ] Escala 1u Blender = 1m Godot

**Lista final de exports:**

| Archivo | Zona | Contenido |
|---------|------|-----------|
| `z1_v1.glb` | Vestíbulo | Shell + props + iluminación baked |
| `z2_v1.glb` | Salón | Shell + barra + escenario + mobiliario |
| `z2_crowd_v1.glb` | Salón (crowd) | Silueta base para MultiMesh |
| `z3_v1.glb` | Bodega | Shell + almacenamiento + props |
| `z4_v1.glb` | Pasillo | Shell + iluminación |
| `z5_v1.glb` | Oficina | Shell + mobiliario + props narrativos |
| `z6_v1.glb` | Interrogatorio | Shell completo |
| `z0_materiales_v1.blend` | Global | Biblioteca de materiales (solo .blend, no .glb) |

**Destino en el repo:** `game/assets/models/environment/[zona]/`

**Verificación final:** Importar uno de los .glb en Godot 4 y confirmar escala, flat shading, y que los materiales se leen correctamente.

---

## Resumen de sesiones

| Bloque | Sesiones | Zonas | Estado |
|--------|----------|-------|--------|
| B0 Materiales | S0 | Global | ⏳ PRÓXIMA |
| B1 Vestíbulo | S1–S5 | Z1 | ⬜ Pendiente |
| B2 Salón | S6–S12 | Z2 | ⬜ Pendiente |
| B3 Bodega | S13–S15 | Z3 | ⬜ Pendiente |
| B4 Pasillo | S16 | Z4 | ⬜ Pendiente |
| B5 Oficina | S17–S19 | Z5 | ⬜ Pendiente |
| B6 Interrogatorio | S20 | Z6 | ⬜ Pendiente |
| B7 Conectores | S21 | Pasillos | ⬜ Pendiente |
| B8 Siluetas | S22 | Global | ⬜ Pendiente |
| B9 Interactuables | S23 | Global | ⬜ Pendiente |
| B10 Optimización | S24 | Global | ⬜ Pendiente |
| B11 Export | S25 | Global | ⬜ Pendiente |

**Total: 26 sesiones.** Cada una = 30–60 min con MCP.

---

*Referencia detallada por zona: `docs/art/Plan de trabajo blender.md`*  
*Level design doc: `docs/design/levels/el_agave_y_la_luna.md`*
