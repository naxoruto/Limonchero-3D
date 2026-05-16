extends StaticBody3D

## Interactable genérico. Si `clue_id` no está vacío, al presionar E agrega la
## pista a GameManager y muestra notificación. Soporta cadenas via `requires_clue`.
##
## Para usar como decoración/sandbox: dejar `clue_id` vacío → `interact()` solo imprime.

@export var interaction_label: String = "Interact"

@export_group("Clue")
@export var clue_id: String = ""                       # vacío = no es pista
@export var clue_name: String = ""
@export_multiline var clue_description: String = ""
@export var clue_type: String = "physical"             # "physical" | "testimony" | "marker"
@export var clue_implies: String = ""
@export var initial_state: String = "SIN_REVISAR"      # "BUENA" | "MALA" | "SIN_REVISAR"
@export var remove_on_pickup: bool = true
@export_multiline var gajito_hint: String = ""         # popup tras pickup

@export_group("Chain")
@export var requires_clue: String = ""                 # bloqueado hasta tener este clue
@export var enabled: bool = true


func interact() -> void:
	if not enabled:
		return
	if requires_clue != "" and not GameManager.has_clue(requires_clue):
		return
	if clue_id == "":
		print("Interacted with: %s" % name)
		return
	if GameManager.has_clue(clue_id):
		return
	var data := {
		"name": clue_name if clue_name != "" else clue_id,
		"description": clue_description,
		"type": clue_type,
		"state": initial_state,
		"implica_a": clue_implies,
	}
	if not GameManager.add_clue(clue_id, data):
		return
	if clue_type == "physical" and clue_name != "":
		HUDManager.show_inventory_notification(clue_name)
	if gajito_hint != "":
		GajitoPopup.show_message(gajito_hint, "low")
	if remove_on_pickup:
		queue_free()
