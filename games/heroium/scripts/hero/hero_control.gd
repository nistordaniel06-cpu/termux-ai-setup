class_name HeroControl
extends RefCounted

enum Mode {
	AUTO,
	STOP_TO_FIRE,
	HOLD_TO_FIRE,
	TAP_TO_FIRE,
	DUAL_STICK,
}

const DEFAULT_MODE := Mode.STOP_TO_FIRE

static func name_for(mode: Mode) -> String:
	match mode:
		Mode.AUTO: return "AUTO"
		Mode.STOP_TO_FIRE: return "STOP & FIRE"
		Mode.HOLD_TO_FIRE: return "HOLD TO FIRE"
		Mode.TAP_TO_FIRE: return "TAP TO FIRE"
		Mode.DUAL_STICK: return "DUAL STICK"
	return "STOP & FIRE"

static func description_for(mode: Mode) -> String:
	match mode:
		Mode.AUTO: return "Țintește și trage automat, chiar în timp ce te miști."
		Mode.STOP_TO_FIRE: return "Te oprești ca să tragi automat către cea mai apropiată țintă."
		Mode.HOLD_TO_FIRE: return "Ține apăsat pentru foc continuu."
		Mode.TAP_TO_FIRE: return "Apasă pentru un atac; țintește automat."
		Mode.DUAL_STICK: return "Mișcare și direcție de atac controlate manual."
	return ""

static func difficulty_multiplier(mode: Mode) -> float:
	match mode:
		Mode.AUTO: return 1.45
		Mode.STOP_TO_FIRE: return 1.28
		Mode.HOLD_TO_FIRE: return 1.14
		Mode.TAP_TO_FIRE: return 1.06
		Mode.DUAL_STICK: return 1.00
	return 1.28

static func rating(mode: Mode) -> int:
	match mode:
		Mode.AUTO: return 1
		Mode.STOP_TO_FIRE: return 2
		Mode.HOLD_TO_FIRE: return 3
		Mode.TAP_TO_FIRE: return 4
		Mode.DUAL_STICK: return 5
	return 2
