# Story 102: Subtítulos Dual-Channel + Typewriter

> **Epic**: Presentation: HUD/UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Feature
> **Estimate**: 3-4 horas

## Context

**ADR Governing Implementation**: [ADR-0017: HUD System](../../../docs/architecture/adr-0017-hud-system.md)
**ADR Decision Summary**: SubtitlePanel como Control en HUDManager. NPCSubtitle (canal izquierdo, colores de identidad) + PlayerSubtitle (canal derecho, lightblue). Typewriter 0.03s/car.

**GDD**: §8.3.2 — Subtítulos dual-channel
**UX Spec**: `design/ux/hud.md` §3
**Art Bible**: §7.3.2 — Subtítulos de Diálogo

**Engine**: Godot 4 GDScript | **Risk**: LOW

---

## Acceptance Criteria

- [ ] `SubtitlePanel` como Control dentro de HUDManager (bottom-center, 80% ancho)
- [ ] Fondo `#000000` 70% opacidad, bordes rectos
- [ ] NPCSubtitle: nombre en color de identidad + texto blanco, effecto typewriter 0.03s/car
- [ ] PlayerSubtitle: `[Tú]` en `#87CEEB` + texto blanco, sin typewriter (aparece completo)
- [ ] `show_npc_subtitle(npc_id: String, text: String)` — inicia typewriter
- [ ] `show_player_subtitle(text: String)` — muestra texto completo
- [ ] `clear_subtitles()` — fade out 0.3s
- [ ] Máx 2 líneas por canal, 50 caracteres por línea
- [ ] Colores de NPC del Art Bible §7.3.2: Gajito `#8BC34A`, Papolicia `#6B4423`, Moni `#8B2332`, Gerry `#4A6B30`, Lola `#C4703A`, Barry `#D4C840`

## Implementation Notes

```gdscript
# Dentro de HUDManager.gd
func show_npc_subtitle(npc_id: String, text: String) -> void:
    var color = _npc_colors.get(npc_id, Color.WHITE)
    subtitle_panel.npc_name.text = "[%s]" % npc_id.capitalize()
    subtitle_panel.npc_name.modulate = color
    subtitle_panel.npc_text.start_typewriter(text, 0.03)

func show_player_subtitle(text: String) -> void:
    subtitle_panel.player_text.text = "[Tú] %s" % text
    subtitle_panel.player_text.modulate = Color("#87CEEB")

var _npc_colors = {
    "gajito": Color("#8BC34A"),
    "papolicia": Color("#6B4423"),
    "moni": Color("#8B2332"),
    "gerry": Color("#4A6B30"),
    "lola": Color("#C4703A"),
    "barry": Color("#D4C840")
}
```

## Dependencies

- Story 101 (HUDManager)
- LLM Client Story 002 (npc_response_received signal)
