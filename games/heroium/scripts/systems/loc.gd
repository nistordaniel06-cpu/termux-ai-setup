extends Node

## Localizare simpla RO / EN cu toggle in meniu.
##
## Foloseste Loc.t("cheie") oriunde in UI. Cheia nu apare niciodata pe ecran
## - daca lipseste traducerea, se intoarce cheia cu majuscule ca placeholder
## vizibil, nu un crash ascuns.

signal language_changed

enum Lang { RO, EN }

var current: Lang = Lang.RO

const _STRINGS := {
	# --- Meniu principal ---
	"tagline": {
		Lang.RO: "Luptă. Adună. Evoluează. Devino legendar.",
		Lang.EN: "Fight. Collect. Evolve. Become legendary.",
	},
	"coins": {
		Lang.RO: "monede",
		Lang.EN: "coins",
	},
	"tab_heroes": {
		Lang.RO: "EROI",
		Lang.EN: "HEROES",
	},
	"tab_modes": {
		Lang.RO: "MOD",
		Lang.EN: "MODE",
	},
	"tab_camp": {
		Lang.RO: "TABĂRĂ",
		Lang.EN: "CAMP",
	},
	"btn_play": {
		Lang.RO: "PORNEȘTE",
		Lang.EN: "PLAY",
	},
	"btn_selected": {
		Lang.RO: "ales",
		Lang.EN: "selected",
	},
	"btn_worn": {
		Lang.RO: "purtat",
		Lang.EN: "worn",
	},
	"appearance_title": {
		Lang.RO: "ÎNFĂȚIȘARE",
		Lang.EN: "APPEARANCE",
	},
	"appearance_sub": {
		Lang.RO: "Doar culoare. Nicio statistică.",
		Lang.EN: "Cosmetic only. No stats.",
	},
	# --- Moduri ---
	"modes_intro": {
		Lang.RO: "Aceleași tărâmuri, alt fel de a le parcurge.",
		Lang.EN: "Same worlds, different way to explore them.",
	},
	"mode_campaign": {
		Lang.RO: "Campanie",
		Lang.EN: "Campaign",
	},
	"mode_campaign_about": {
		Lang.RO: "Patru tărâmuri, fiecare cu șeful lui. La capăt te așteaptă victoria.",
		Lang.EN: "Four realms, each with a boss. Victory awaits at the end.",
	},
	"mode_survival": {
		Lang.RO: "Supraviețuire",
		Lang.EN: "Survival",
	},
	"mode_survival_about": {
		Lang.RO: "Fără sfârșit. Vezi cât reziști — dificultatea nu se oprește din urcat.",
		Lang.EN: "Endless. See how long you last — difficulty never stops rising.",
	},
	"mode_bossrush": {
		Lang.RO: "Boss Rush",
		Lang.EN: "Boss Rush",
	},
	"mode_bossrush_about": {
		Lang.RO: "Numai șefi, unul după altul. Fără camere de încălzire.",
		Lang.EN: "Bosses only, one after another. No warm-up rooms.",
	},
	# --- Tabără ---
	"camp_intro": {
		Lang.RO: "Talentele rămân pentru totdeauna. Rularea se pierde, ele nu.",
		Lang.EN: "Talents are permanent. Runs end, they don't.",
	},
	"at_max": {
		Lang.RO: "La maxim.",
		Lang.EN: "Maxed out.",
	},
	"requires_first": {
		Lang.RO: "Necesită mai întâi: ",
		Lang.EN: "Requires first: ",
	},
	# --- Talente ---
	"talent_attack_power": {
		Lang.RO: "Putere Atac",
		Lang.EN: "Attack Power",
	},
	"talent_resistance": {
		Lang.RO: "Rezistență",
		Lang.EN: "Resistance",
	},
	"talent_max_health": {
		Lang.RO: "Sănătate Maximă",
		Lang.EN: "Max Health",
	},
	"talent_attack_speed": {
		Lang.RO: "Viteză Atac",
		Lang.EN: "Attack Speed",
	},
	"talent_crit_chance": {
		Lang.RO: "Șansă Critică",
		Lang.EN: "Crit Chance",
	},
	# --- HUD ---
	"hud_room": {
		Lang.RO: "Camera",
		Lang.EN: "Room",
	},
	"hud_wave": {
		Lang.RO: "Val",
		Lang.EN: "Wave",
	},
	# --- Game Over / Victory ---
	"game_over": {
		Lang.RO: "AI CĂZUT",
		Lang.EN: "DEFEATED",
	},
	"victory": {
		Lang.RO: "VICTORIE",
		Lang.EN: "VICTORY",
	},
	"rooms_cleared": {
		Lang.RO: "camere cucerite",
		Lang.EN: "rooms cleared",
	},
	"btn_retry": {
		Lang.RO: "ÎNCEARCĂ DIN NOU",
		Lang.EN: "TRY AGAIN",
	},
	"btn_menu": {
		Lang.RO: "MENIU",
		Lang.EN: "MENU",
	},
	# --- Pauză ---
	"paused": {
		Lang.RO: "PAUZĂ",
		Lang.EN: "PAUSED",
	},
	"btn_resume": {
		Lang.RO: "CONTINUĂ",
		Lang.EN: "RESUME",
	},
	"btn_quit": {
		Lang.RO: "RENUNȚĂ",
		Lang.EN: "QUIT",
	},
	# --- Level up ---
	"level_up": {
		Lang.RO: "NIVEL NOU",
		Lang.EN: "LEVEL UP",
	},
	"pick_ability": {
		Lang.RO: "Alege o abilitate",
		Lang.EN: "Choose an ability",
	},
}


func t(key: String) -> String:
	var entry: Dictionary = _STRINGS.get(key, {})
	if entry.is_empty():
		return key.to_upper()
	return entry.get(current, entry.values()[0])


func toggle() -> void:
	current = Lang.EN if current == Lang.RO else Lang.RO
	language_changed.emit()


func lang_label() -> String:
	return "EN" if current == Lang.RO else "RO"
