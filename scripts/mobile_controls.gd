extends CanvasLayer

# Mobile on-screen control panel.
# Simulates keyboard input actions so the rest of the game needs no changes.
# Visibility is driven by touchscreen availability so the overlay is hidden on
# desktop browsers / non-touch devices.

func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()


# --- D-pad ---

func _on_btn_up_button_down() -> void:
	Input.action_press("move_up")

func _on_btn_up_button_up() -> void:
	Input.action_release("move_up")


func _on_btn_down_button_down() -> void:
	Input.action_press("move_down")

func _on_btn_down_button_up() -> void:
	Input.action_release("move_down")


func _on_btn_left_button_down() -> void:
	Input.action_press("move_left")

func _on_btn_left_button_up() -> void:
	Input.action_release("move_left")


func _on_btn_right_button_down() -> void:
	Input.action_press("move_right")

func _on_btn_right_button_up() -> void:
	Input.action_release("move_right")


# --- Action buttons ---

func _on_btn_melee_button_down() -> void:
	Input.action_press("melee_attack")

func _on_btn_melee_button_up() -> void:
	Input.action_release("melee_attack")


func _on_btn_ranged_button_down() -> void:
	Input.action_press("ranged_attack")

func _on_btn_ranged_button_up() -> void:
	Input.action_release("ranged_attack")
