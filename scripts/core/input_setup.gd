extends RefCounted
## Registers input actions in code so project.godot stays readable.

## Small, so the touch stick stays analog all the way (it applies its own deadzone).
const DEADZONE := 0.05

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_C, KEY_CTRL],
	"item_parachute": [KEY_1],
	"item_bandage": [KEY_2],
	"item_hook": [KEY_3],
	"use": [KEY_E],
	"follow": [KEY_F],
	"emote": [KEY_G],
	"photo": [KEY_P],
	"camera": [KEY_V],
}
## Gamepad: left stick moves (via the same actions), A jumps, B crouches, the
## left stick press sprints, X uses/enters, shoulder buttons fire items; the
## right stick looks (read in player.gd).
const PAD_BUTTONS := {
	"jump": JOY_BUTTON_A,
	"crouch": JOY_BUTTON_B,
	"sprint": JOY_BUTTON_LEFT_STICK,
	"use": JOY_BUTTON_X,
	"follow": JOY_BUTTON_Y,
	"item_parachute": JOY_BUTTON_LEFT_SHOULDER,
	"item_bandage": JOY_BUTTON_RIGHT_SHOULDER,
	"item_hook": JOY_BUTTON_DPAD_UP,
	"emote": JOY_BUTTON_DPAD_DOWN,
	"camera": JOY_BUTTON_RIGHT_STICK,
}
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
}


static func register() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, DEADZONE)
		for key: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		if PAD_BUTTONS.has(action):
			var button := InputEventJoypadButton.new()
			button.button_index = PAD_BUTTONS[action]
			InputMap.action_add_event(action, button)
		if PAD_AXES.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.axis = PAD_AXES[action][0]
			motion.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, motion)
