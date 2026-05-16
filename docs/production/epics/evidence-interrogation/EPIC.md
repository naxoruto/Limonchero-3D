# Epic: Evidence Interrogation

> **Capa**: Core Gameplay (cross-layer: Interaction + LLM + UI)
> **GDD**: `design/gdd/gdd_detective_noir_vr.md` §4 (Loop), §6 (NPCs), §7 (Evidence)
> **Level**: `design/levels/el_agave_y_la_luna.md` §5 (Acquisition + Stamps)
> **Estado**: Planning
> **Responsable**: Ignacio Cuevas
> **Dependencia de**: GameManager (clues, set_clue_state), Cliente LLM (NPC prompt), Dialogue UI, Inventory Notebook

## Visión General

Cierra el loop principal de detective: el jugador presenta pruebas a NPCs durante el interrogatorio, el NPC reacciona contextualmente, y el sello BUENA/MALA se decide por la respuesta del NPC en lugar de marca manual a ciegas. Convierte testimonios en pistas tipo `testimony` paralelas a las físicas.

Reemplaza el diseño GDD original (NPC con "conciencia implícita" del inventario vía system prompt) por una mecánica **explícita y diegética**: el jugador elige qué mostrar, el NPC lo nombra, el sello se justifica narrativamente.

## Problema actual

1. Sellos BUENA/MALA no tienen forma natural de decidirse — player debe marcar manualmente sin información clara.
2. Hablar con NPCs no afecta inventario — diálogo es flujo paralelo desconectado de evidencia.
3. Testimonios mencionados en GDD (T1–T5) no existen como entidad — solo F1–F5 físicas en el código.
4. Confirmación F3 (Moni confirma encendedor de Barry) no implementada — F3 nunca sale de SIN_REVISAR.

## Mecánica Propuesta

### Flujo durante diálogo NPC

```
1. Player entra en diálogo con NPC (interact E)
2. Player presiona TAB → mini-notebook lateral
3. Player click/Enter en clue (físical o testimony)
4. Sistema envía al backend LLM:
     prompt: "<NPC persona> ... Player presents [clue_name] ([clue_description]).
              React naturally — recognize, deny, or evade."
     contexto: clue_id, clue_type, NPC's relation to clue (from cast bible)
5. NPC responde texto (subtitulado normal)
6. Sistema parsea respuesta + matchea contra tabla de reconocimiento por NPC×clue
7. Auto-stamp:
   - NPC reconoce + clue valida F1/F2/F3 → set_clue_state(clue, BUENA)
   - NPC niega/desmiente + clue es red herring F4/F5 → set_clue_state(clue, MALA)
   - Caso ambiguo → permanece SIN_REVISAR; player puede marcar manualmente
8. Gajito popup confirma stamp: "Moni confirmó. F3 marcado BUENA."
```

### Captura de testimonios

```
1. NPC dice algo informativo (LLM marca turn-output con flag testimony_worthy)
2. HUD muestra prompt "¿Agregar como evidencia? [X]" durante 4s
3. Player presiona X → add_clue("T<n>", {type: "testimony", ...})
4. Notebook diferencia físicas (foto) vs testimonios (texto entrecomillado)
5. Testimonios también se pueden presentar a OTROS NPCs:
   - Mostrar T2 (Moni dice "traje amarillo") a Gerry → Gerry reacciona
```

### Tabla de reconocimiento NPC × clue (cast-bible derived)

| Clue | Moni | Gerry | Lola | Barry | Spud |
|------|------|-------|------|-------|------|
| F1 acuerdo | "no sé nada" | "no me involucres" | curiosa | nervioso | "buena prueba" |
| F2 llave | "raro" | reacción si tiene F2 → T3 | indiferente | tenso | "interesante" |
| F3 encendedor | **reconoce → BUENA** | "no es mío" | "se ve caro" | niega | "anótalo" |
| F4 maleta Moni | **confiesa escape** | indiferente | sorpresa | aprovecha | "no es del crimen" → MALA |
| F5 sobre quemado | "no es mío" | indiferente | **confiesa demanda** | indiferente | "civil, no penal" → MALA |
| T2 (traje amarillo) | "se lo dije" | reacción | — | tenso | "lead útil" |

## ADRs Gobernantes

| ADR | Resumen | Riesgo Motor |
|-----|---------|--------------|
| ADR-0014 | NPC Dialogue Module — extender prompt con `presented_evidence` slot | LOW |
| ADR-0015 | Inventory Module — agregar tipo `testimony` | LOW |
| ADR-0001 | GameManager — `set_clue_state` ya existe; agregar señal `evidence_presented` | LOW |
| ADR-0017 | HUD System — mini-notebook lateral en diálogo, prompt "Agregar testimonio" | LOW |
| ADR-NUEVO | **Evidence Interrogation Loop** — diseño de reconocimiento + stamp automático | MEDIUM |

## Requisitos GDD Nuevos / Modificados

| TR-ID | Requisito | Origen |
|-------|-----------|--------|
| TR-evi-001 | Player puede presentar clue a NPC durante diálogo via TAB | nuevo |
| TR-evi-002 | NPC responde contextualmente; LLM recibe slot `presented_evidence` | extiende ADR-0014 |
| TR-evi-003 | Auto-stamp BUENA/MALA basado en respuesta NPC + tabla de reconocimiento | nuevo |
| TR-evi-004 | Testimonios capturables como clues `type: testimony` | RF-08 (ya en GDD) |
| TR-evi-005 | Notebook diferencia físicas vs testimonios visualmente | RF-08 |
| TR-evi-006 | Presentar testimonio a NPC funciona igual que físico | nuevo |
| TR-evi-007 | Sello manual override sigue disponible (player tiene última palabra) | preserva GDD existing |

## Arquitectura Técnica

### Señales nuevas

```gdscript
# GameManager
signal evidence_presented(npc_id: String, clue_id: String)
signal testimony_captured(npc_id: String, testimony_id: String, text: String)

# DialogueUI (existing module extended)
signal clue_presentation_requested(clue_id: String)
signal testimony_capture_requested(text: String, npc_id: String)
```

### Backend LLM (extiende endpoint `/npc/{id}`)

```python
class NPCRequest(BaseModel):
    user_message: str
    presented_evidence: Optional[EvidenceContext] = None
    inventory_summary: List[str]  # already exists
    
class EvidenceContext(BaseModel):
    clue_id: str
    clue_name: str
    clue_type: str  # "physical" | "testimony"
    clue_description: str
```

Sistema prompt adicional:
```
The player has just shown you: [evidence_context].
React according to your persona. If you recognize it, acknowledge.
If it incriminates you, evade or confess based on resistance level.
End response with one of: <recognize/>, <deny/>, <evade/>, <confess/>.
```

### Parser de respuesta

```gdscript
# llm_client.gd
func _parse_npc_reaction(response: String) -> String:
    if "<recognize/>" in response: return "recognize"
    if "<deny/>" in response: return "deny"
    if "<evade/>" in response: return "evade"
    if "<confess/>" in response: return "confess"
    return "ambiguous"
```

### Auto-stamp logic

```gdscript
# evidence_interrogation_handler.gd (new)
const RECOGNITION_TABLE := {
    "moni": {"F3": "recognize_good", "F4": "self_confess_red"},
    "lola": {"F5": "self_confess_red"},
    "spud": {"F4": "dismiss_red", "F5": "dismiss_red"},
    # ...
}

func handle_npc_reaction(npc_id, clue_id, reaction):
    var rule = RECOGNITION_TABLE.get(npc_id, {}).get(clue_id, "none")
    match [rule, reaction]:
        ["recognize_good", "recognize"]:
            GameManager.set_clue_state(clue_id, GameManager.STATE_GOOD)
        ["self_confess_red", "confess"], ["dismiss_red", "deny"]:
            GameManager.set_clue_state(clue_id, GameManager.STATE_BAD)
        _:
            pass  # ambiguous → no auto-stamp
```

## Stories

| # | Story | Estimado | Depende de | Descripción |
|---|-------|----------|------------|-------------|
| 201 | **Mini-notebook lateral en diálogo** | 3-4h | Story 106 (Notebook) | TAB durante diálogo abre panel lateral con clues físicas + testimonios; click/Enter selecciona |
| 202 | **Backend NPC endpoint con presented_evidence** | 2-3h | Cliente LLM 002 | Extender `/npc/{id}` request con slot `presented_evidence`; system prompt agrega contexto |
| 203 | **Parser reacción NPC + auto-stamp** | 3-4h | Story 202 | Tags `<recognize/>` etc. en respuesta; tabla NPC×clue; llama `set_clue_state` |
| 204 | **Captura testimonio durante diálogo** | 2-3h | Story 201 | Prompt "[X] Agregar como evidencia" cuando LLM marca turn como testimony-worthy; agrega clue tipo `testimony` |
| 205 | **Notebook: visual físicas vs testimonios** | 1-2h | Story 204 | Foto/marco para físicas; bloque texto entrecomillado para testimonios; ambos seleccionables |
| 206 | **Gajito feedback post-stamp** | 1h | Story 203 | Popup "Moni confirmó. F3 BUENA." tras auto-stamp |
| 207 | **Tabla reconocimiento por NPC** | 2h | Cast bible | Diccionario `RECOGNITION_TABLE` con 5 NPC × 5+ clues + reacciones esperadas |
| 208 | **Override manual de sello** | 1h | Story 203 | Notebook: long-press / right-click slot → ciclar BUENA/MALA/SIN_REVISAR; respeta auto-stamp pero permite cambiarlo |

**Total estimado: 15-20 h**

## Contrato API extendido

```gdscript
# DialogueUI
func open_evidence_picker() -> void  # llama al notebook lateral
func close_evidence_picker() -> void
func present_clue_to_npc(clue_id: String) -> void  # envía a backend

# GameManager (existing, no breaking changes)
func set_clue_state(clue_id: String, state: String) -> void  # ya existe
func add_clue(clue_id: String, data: Dictionary) -> bool  # ya soporta type=testimony

# LLM Client extension
func send_npc_message_with_evidence(npc_id, user_msg, clue_data) -> Dictionary
```

## Cadena de Flujo Crítico

```
Player en diálogo con Moni
  → TAB → mini-notebook lateral
  → Click F3 (Encendedor de Oro, type=physical)
  → DialogueUI.present_clue_to_npc("F3")
  → LLMClient envía request:
       {user_message: "[showing F3]",
        presented_evidence: {id: "F3", name: "Encendedor de Oro", ...}}
  → Backend responde: "That's Barry's lighter. I'd know it anywhere. <recognize/>"
  → DialogueUI muestra subtítulo (sin la tag)
  → EvidenceHandler.handle_npc_reaction("moni", "F3", "recognize")
  → RECOGNITION_TABLE["moni"]["F3"] = "recognize_good"
  → GameManager.set_clue_state("F3", "BUENA")
  → GajitoPopup: "Moni confirmó. F3 marcado BUENA."
  → Notebook actualiza visual stamp
```

## Definición de Hecho

- Player puede presentar cualquier clue (física o testimonio) a cualquier NPC durante diálogo
- Cada NPC reacciona contextualmente — no respuesta genérica
- F3 puede confirmarse hablando con Moni (sale de SIN_REVISAR sin marca manual)
- F4 marcable MALA tras mostrarla a Spud
- F5 marcable MALA tras mostrarla a Lola/Spud
- Testimonios capturables durante diálogo y presentables a otros NPCs
- Notebook visualmente distingue físicas y testimonios
- Override manual sigue funcional (sello reversible)
- Auto-stamps emiten señal observable en telemetría
- E2E: jugador puede llegar al final bueno SOLO con presentación de evidencia (sin marcar manualmente nada)

## Siguiente Paso

1. Crear ADR-NUEVO `evidence-interrogation-loop` documentando la decisión arquitectónica
2. Ejecutar `/create-stories evidence-interrogation` para descomponer las 8 stories
3. Priorizar Story 201 (mini-notebook) + Story 202 (backend) como bloqueantes
