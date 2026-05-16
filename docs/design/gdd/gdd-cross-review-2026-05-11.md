# Cross-GDD Review Report
**Date:** 2026-05-11  
**GDDs Reviewed:** 4  
**Systems Covered:** GDD Principal, Level Design (El Agave y La Luna), Cast Bible, World Rules  
**Entity Registry:** Present (264 lines, used as baseline)

---

### Phase 1 Completion Report
Loaded 4 system documents covering 4 systems. Pillars extracted from concept: **Investigation as Process**, **Language Learning through Immersion**, **Noir Atmosphere and Character**. Anti-pillars: not explicitly documented. The project uses a master GDD + supporting docs pattern, not per-system GDDs — adapted accordingly.

---

### Consistency Issues

#### Blocking (must resolve before architecture begins)

🔴 **Barry's confession condition: "pólvora en muñeca" vs "encendedor de oro"**
`gdd_detective_noir_vr.md:201` still says `evidencia de pólvora en muñeca`. Barry's LLM prompt at line 202 says `gunpowder residue`. All three other docs agree on `encendedor de oro` (F3). v0.3 changed this — the GDD was only partially updated. Cast-bible:264, Level doc:231, Entity registry:47 all agree on F3.

🔴 **STT→LLM pipeline latency: three conflicting values**
GDD RNF-02 (`gdd_detective_noir_vr.md:482`): `< 4s end-to-end`. Entity registry:258: `< 5s end-to-end`. Level doc NPC-06 (`el_agave_y_la_luna.md:382`): `< 5s`. Pick one authoritative value.

🔴 **"Piso de arriba" references stale after v1.2 single-floor change**
Cast-bible:9 (`oficina del dueño en el piso de arriba`), :54 (`oficina del piso de arriba`), :245 (`cerca del piso superior`). Entity registry:117 (`disparo en la oficina del piso de arriba`). Both GDD:144 and cast-bible:202 say `Crime scene's upstairs`. Level doc v1.2 eliminated the second floor.

🔴 **F5 location: "baño de damas" vs "baño de empleados"**
Cast-bible:239 places F5 in `Lavabo del baño de damas`. GDD:219, Level doc:137, and Entity registry:184 all say `baño de empleados`. Cast-bible is the outlier.

🔴 **GDD concept still says "Realidad Virtual"**
`gdd_detective_noir_vr.md:18`: `Un juego de detectives en primera persona en Realidad Virtual`. Despite v0.3 migration note on line 11. Also line 522 says `Build APK final` — game targets PC, not Android.

🔴 **GDD classifies burned documents (R6) as real clue; level doc and cast-bible classify same evidence (F5) as red herring**
`gdd_detective_noir_vr.md:219` lists R6 under **Pistas Reales** (🟡 Media relevance). Level doc §5.1 and Cast-bible:239 both classify F5 as ❌ Mala (red herring). Mutually exclusive classifications.

🔴 **UV wand, VR, and Quest 2 references persist in level doc**
Level doc:276 defines acquisition as `completar un escaneo UV`. Tuning knobs :331-336 have `Hold UV estado 1/3` and `Ángulo del UV cone`. Accessibility :386-388 references `controladores VR`, `build de Quest 2`, `capturas de Quest 2`. Cast-bible has 3 `libreta VR` references. `Stain state progression` at level doc:318. All removed systems.

🔴 **Cast-bible references broken section `§5.3 del level doc`**
`cast-bible.md:236`: `(ver §5.3 del level doc)` for F2 chain. Level doc has §5.1, §5.2, §5.4 — no §5.3. Target is §5.2.

#### Warnings (should resolve, but won't block architecture)

⚠️ **Lola's time gap arithmetic is wrong**
Both GDD:186 and cast-bible:166-168: `9:47–10:12 PM` = 25 minutes, but labeled `28 minutos`.

⚠️ **F1 description detail inconsistency**
GDD:214: `rasgado y re-doblado`. Cast-bible:235: `rasgado, sin firmar`. Different attributes emphasized.

⚠️ **GDD evidence taxonomy (R1-R6/D1-D5) vs cast-bible/level doc (F1-F5/T1-T5)**
Two different naming systems with no cross-reference table. R5 ("Puerta Trasera" as physical evidence) corresponds to T3 (Gerry's testimony). D2, D3, D5 have no equivalent in the newer system.

⚠️ **GDD appendix prompt template contradicts language rules**
`gdd_detective_noir_vr.md:549`: example template says `Responde siempre en español`. All NPCs must speak English.

⚠️ **UV wand tuning knobs orphaned in level doc**
Three tuning knobs govern a removed system.

⚠️ **Entity registry duplicates parameters already owned by level doc**
`inventory_slots`, `anti_stall_L1/L2/L3`, `llm_timeout` defined in both.

⚠️ **GDD's Lola timeline end-time "10:47" probable typo**
GDD:186 says `Oficina contable 9:45–10:47 PM`. Cast-bible:168 says `desde las 10:15 PM`.

---

### Game Design Issues

#### Blocking

🔴 **Gajito grammar correction pop-up collides with NPC text reading**
`gdd_detective_noir_vr.md` §5.3 steps 8-9: Gajito's Spanish grammar corrections fire in parallel with NPC English response text. The player must read NPC English subtitles while simultaneously processing a Spanish pop-up — the game's most technically complex pipeline produces output the player cannot process without losing one stream. Zero spatial/pacing mitigation in any document.

🔴 **Testimony evidence system has no mechanical sink**
The STT→LLM interrogation pipeline — the core USP (`gdd_detective_noir_vr.md` §1.5) — feeds into a testimony log (level doc §5.1: `log ilimitado`). But the accusation gate (cast-bible `Reglas de resolución`, level doc §5.1) only checks F1+F2+F3 (physical evidence). Testimonies T2, T3 are collected, classified, and never mechanically referenced again. The game's most expensive system feeds a resource pool with zero consumption.

#### Warnings

⚠️ **English-learning loop competes with investigation loop as co-primary driver**
GDD §1.5 presents both language learning and detective work as co-primary. Level doc §3.1 says NPC interrogation is optional for the good ending. A player optimizing for language learning exhausts NPCs; a player optimizing for case resolution skips them. These two loops don't feed each other.

⚠️ **Cognitive load: 8+ active systems during core gameplay**
Navigation, environmental scanning, PTT voice input (in English), reading NPC English text, processing Spanish correction pop-ups, inventory management, evidence classification, NPC proximity detection, anti-stall time pressure, midnight deadline. For a 15-20 minute playtest, this is high.

⚠️ **60%+ of designed content is mechanically optional**
The optimal path (F1+F2+F3 GOOD → accuse Barry) skips all NPC interrogation, the back door route, Lola's documents, Moni's escape plan, and easter eggs. The LLM-powered NPC interactions — the richest content — are the most skippable.

⚠️ **Evidence classification skill only tested on 3 of 5 items**
F4/F5 status doesn't affect the good ending gate (level doc §5.1: `F1+F2+F3 GOOD se comprueba primero`). The "detective's discernment" skill is only tested on the three objectively-incriminating items.

⚠️ **The game is a procedural drama, not a mystery — undocumented expectation**
Barry's opening line is a confession (cast-bible `Eco narrativo`), delivered before Papolicia's briefing (level doc Zona 2 `Frase de apertura`). Level doc §2: `Barry Peel es culpable desde el primer momento`. Players expecting a whodunit will feel misled. This structural choice isn't documented for users, testers, or marketing.

⚠️ **Language mechanic creates ludonarrative dissonance**
The player mechanically speaks English to NPCs via STT. Limonchero's character fiction: `No habla ni una palabra de inglés` (cast-bible §Limonchero). Gajito is fictionally the translator, but technically the player bypasses him.

⚠️ **Level doc serves zero Language Learning (P2) mechanics**
The educational USP is implemented entirely through Gajito's pop-ups, which operate independently of level design. No language-based puzzles, vocabulary challenges, or English-environmental-text interactions exist in the level.

⚠️ **GDD §6 (Art Direction) and §7 (Audio) are entirely `[TODO]`**
The Noir Atmosphere pillar has no governing art direction framework. Level doc compensates with zone-specific specs but there's no overall vision.

⚠️ **Difficulty curve: F2 chain is the only cognitively demanding puzzle, and the anti-stall system auto-solves it at L3**
`el_agave_y_la_luna.md` §5.5 L3: `"Revisa su abrigo. El guardarropa tiene un número."` — this directly solves the 5-step chain.

⚠️ **Hardcoded gate produces outcomes the LLM-driven Papolicia is not prompted to express**
Player accuses wrong suspect → gate evaluates → produces B2/B3/B4 → Papolicia's LLM prompt says "you accept without much scrutiny" → Papolicia says generic acceptance text. LLM response won't reflect the specific ending's narrative.

---

### Cross-System Scenario Issues

**Scenarios walked:** 5 — (1) F3 acquisition → Moni identification, (2) F2 chain during anti-stall, (3) Barry confrontation, (4) Papolicia accusation, (5) Zone 6 early visit

#### Blockers

🔴 **S1: No "show evidence to NPC" mechanic exists** — Interaction/GDD/Lore boundary
Level doc Zona 5 requires *"mostrar el encendedor a Moni"*. Cast-bible Evidence Log requires *"mostrar a Moni → prompt."* GDD §2.2 defines no "select inventory item and present to NPC" action. The entire F3 confirmation chain has an undefined entry point. **Must design and document the show-evidence interaction.**

🔴 **S1: Moni's LLM prompt has no lighter-identification instructions** — LLM/Lore boundary
Level doc §5.4 says NPCs receive inventory state in system prompt. Moni's actual LLM prompt (GDD:159, cast-bible:121-132) contains zero instructions to recognize the lighter, reference Barry lighting her cigarette, or trigger identification dialogue. **All lighter-identification facts exist only in lore — never reach the LLM.**

🔴 **S1: Contradictory F3 re-acquisition rules** — Inventory/Gate boundary
Level doc §6: `F1 and F4 are physical objects recoverable; F3 and F5 require re-scan` — but F3 was migrated from UV-scan to press-X in v1.1. Preceding sentence says `not re-acquirable if already picked up`. **Cannot determine if discarded F3 respawns or is permanently lost.**

🔴 **S4: B1 ending is logically contradictory** — Narrative/Gate boundary
Level doc §5.1: player names Barry with insufficient evidence → `Papolicia acepta → final malo B1 (Barry queda libre, caso cerrado)`. Papolicia accepts the accusation yet Barry goes free. No narrative framing explains this. **Reads as a bug, not an intended ending.**

🔴 **S4: GDD R6 vs level doc F5 — same evidence, opposite classification**
GDD §3.4 lists burned documents as real clue (🟡 Media). Level doc §5.1 and cast-bible classify same evidence as red herring (Mala). **The game cannot ship with both classifications.**

🔴 **Cross-cutting: F5 acquisition mechanic undefined**
F5 (burned envelope) appears in cast-bible Evidence Log, level doc Zona 3, and gate table. No document specifies how the player acquires it — press-X on sink? Automatic on entering? Triggered by Lola conversation?

#### Warnings

⚠️ **S1: Player can stamp F3 GOOD without Moni identification, bypassing intended flow**
Gate checks only stamps (level doc §5.4), not `f3_confirmed_by_moni` flag. Cast-bible:264 requires Moni identification.

⚠️ **S2: Anti-stall L3 hint can fire during active NPC interrogation**
No condition prevents Gajito interrupting mid-conversation. Could cause player to release PTT or misread hint source.

⚠️ **S2: Anti-stall timer doesn't pause during text reading — only during network latency**
Player actively reading NPC response gets timed as "stalled."

⚠️ **S3: Discarding GOOD-stamped F1 from inventory may be irreversible softlock**
Level doc §6 says F1 is "recoverable if still in the world" — but standard pickup consumes the object. Ambiguous whether object persists in world after pickup.

⚠️ **S4: LLM-driven Papolicia not informed of gate's specific ending**
Papolicia always says some variant of acceptance regardless of which B-ending triggers. Player sees Papolicia accept, then receives ending card contradicting what he just said.

⚠️ **S5: T1 (Informe Preliminar, delivered at start) may permanently prevent Zone 6 early-access gate**
Gate checks `ninguna pista en la libreta` — T1 is always present. The intended distinction between "physical clue" and "testimonial evidence" for this check is undocumented.

⚠️ **Cross-cutting: Gajito L1 "walks toward zone" contradicts "always beside player" rule**
Level doc Zona 2: Gajito `Siempre junto al jugador`. Level doc §5.5 L1: `Camina hacia la zona menos explorada`. Undefined visual behavior.

#### Info

ℹ️ **S1: F3 name-label transition after Moni unidentified** — CP-04 says "F3 BUENA después" conflating name-label change and GOOD stamp.

ℹ️ **S2: Wall-clock anti-stall unpredictability due to LLM latency pauses** — QA timing expectations need documentation.

ℹ️ **S3: Conversation history persistence across NPC sessions undefined** — `dialogue_history.gd` has no behavioral spec.

ℹ️ **S4: B2-B4 endings have zero narrative content** — Undefined ending scenes.

ℹ️ **S5: Zone 6 early visit resets anti-stall with no player benefit** — "Fake progress" event.

---

### GDDs Flagged for Revision

| Document | Reason | Type | Priority |
|----------|--------|------|----------|
| `gdd_detective_noir_vr.md` | Barry confession condition (pólvora→encendedor), concept says VR, STT latency mismatch, R6/F5 classification, stale APK reference, appendix language error | Consistency | 🔴 Blocking |
| `cast-bible.md` | "Piso de arriba" (3 refs), F5 location (baño de damas→empleados), Lola gap time arithmetic, broken §5.3 reference, "libreta VR" (3 refs) | Consistency | 🔴 Blocking |
| `el_agave_y_la_luna.md` | UV wand refs (6+), Quest 2 refs (4), VR accessibility criteria, stain progression, F3 re-acquisition contradiction, Gajito visual contradiction, F5 acquisition missing | Consistency | 🔴 Blocking |
| `entities.yaml` | "Piso de arriba" in Cornelius attributes, STT latency value | Consistency | 🔴 Blocking |
| `gdd_detective_noir_vr.md` | Art/Audio sections entirely TODO, no architecture-ready art direction | Design Theory | ⚠️ Warning |
| `el_agave_y_la_luna.md` | Zero P2 (Language Learning) mechanics integrated into level design | Design Theory | ⚠️ Warning |

---

### Verdict: **FAIL**

**17 unique blocking issues** across consistency, design theory, and cross-system scenarios must be resolved before architecture begins.

### Required actions before re-running:
1. Update `gdd_detective_noir_vr.md` §3.3 Barry confession condition and LLM prompt: replace `pólvora en muñeca`/`gunpowder residue` with `encendedor de oro`/`gold lighter`
2. Standardize STT→LLM pipeline latency to a single value across all documents
3. Update all "piso de arriba"/"upstairs" references in cast-bible, GDD, and entity registry to reflect single-floor layout (v1.2)
4. Fix F5 location in cast-bible from `baño de damas` to `baño de empleados`
5. Design and document the "show evidence to NPC" interaction mechanic
6. Add lighter-identification instructions to Moni's LLM system prompt
7. Resolve F3 re-acquisition contradiction in level doc §6
8. Add narrative framing or fix logic for B1 ending
9. Reconcile GDD R6 (real clue) with level doc F5 (red herring) classification
10. Specify F5 acquisition mechanic
11. Strip all UV wand, VR, Quest 2, "libreta VR", and stain progression references from level doc and cast-bible
12. Fix Lola's time gap arithmetic and broken cast-bible §5.3 reference
13. Design mitigation for Gajito grammar pop-up vs NPC text collision (timing, spatial separation, or deferred delivery)
14. Integrate testimony evidence into the accusation gate or explicitly document why it's informational-only
