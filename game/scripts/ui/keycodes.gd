class_name KeyCodes
extends RefCounted
## Godot physical keys -> DOM KeyboardEvent.code names used by the layouts.

static func code_of(e: InputEventKey) -> String:
	var k = e.physical_keycode if e.physical_keycode != 0 else e.keycode
	var right = e.location == KEY_LOCATION_RIGHT
	if k >= KEY_A and k <= KEY_Z: return "Key" + char(k)
	if k >= KEY_0 and k <= KEY_9: return "Digit" + char(k)
	if k >= KEY_F1 and k <= KEY_F12: return "F%d" % (k - KEY_F1 + 1)
	if k >= KEY_KP_0 and k <= KEY_KP_9: return "Numpad%d" % (k - KEY_KP_0)
	match k:
		KEY_ESCAPE: return "Escape"
		KEY_TAB: return "Tab"
		KEY_CAPSLOCK: return "CapsLock"
		KEY_SHIFT: return "ShiftRight" if right else "ShiftLeft"
		KEY_CTRL: return "ControlRight" if right else "ControlLeft"
		KEY_ALT: return "AltRight" if right else "AltLeft"
		KEY_META: return "MetaRight" if right else "MetaLeft"
		KEY_SPACE: return "Space"
		KEY_ENTER: return "Enter"
		KEY_KP_ENTER: return "NumpadEnter"
		KEY_BACKSPACE: return "Backspace"
		KEY_MINUS: return "Minus"
		KEY_EQUAL: return "Equal"
		KEY_BRACKETLEFT: return "BracketLeft"
		KEY_BRACKETRIGHT: return "BracketRight"
		KEY_BACKSLASH: return "Backslash"
		KEY_SEMICOLON: return "Semicolon"
		KEY_APOSTROPHE: return "Quote"
		KEY_COMMA: return "Comma"
		KEY_PERIOD: return "Period"
		KEY_SLASH: return "Slash"
		KEY_QUOTELEFT: return "Backquote"
		KEY_UP: return "ArrowUp"
		KEY_DOWN: return "ArrowDown"
		KEY_LEFT: return "ArrowLeft"
		KEY_RIGHT: return "ArrowRight"
		KEY_DELETE: return "Delete"
		KEY_INSERT: return "Insert"
		KEY_HOME: return "Home"
		KEY_END: return "End"
		KEY_PAGEUP: return "PageUp"
		KEY_PAGEDOWN: return "PageDown"
		KEY_PRINT: return "PrintScreen"
		KEY_SCROLLLOCK: return "ScrollLock"
		KEY_PAUSE: return "Pause"
		KEY_NUMLOCK: return "NumLock"
		KEY_MENU: return "ContextMenu"
		KEY_KP_ADD: return "NumpadAdd"
		KEY_KP_SUBTRACT: return "NumpadSubtract"
		KEY_KP_MULTIPLY: return "NumpadMultiply"
		KEY_KP_DIVIDE: return "NumpadDivide"
		KEY_KP_PERIOD: return "NumpadDecimal"
	return ""
