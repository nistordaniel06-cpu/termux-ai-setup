class_name Ability
extends Resource

## O abilitate luata in timpul unei rulari (Săgeată Perforantă, Meteor Infernal...).
##
## Abilitatile au stele (1-5) si se pot combina: doua abilitati compatibile
## fuzioneaza intr-una evoluata, exact ca in ecranul "Abilități & Evoluții".
## Fuziunea e descrisa aici, in date - nu in cod - ca sa poti adauga combinatii
## noi doar cu fisiere .tres.

enum Kind {
	PROJECTILE,   ## modifica sagetile trase
	ON_HIT,       ## se declanseaza la lovire (foc, otrava)
	AREA,         ## dauna in zona (meteor)
	PASSIVE,      ## doar statistici
}

enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MYTHIC }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var kind: Kind = Kind.PROJECTILE
@export var rarity: Rarity = Rarity.COMMON
@export_range(1, 5) var stars: int = 3

@export_group("Efect")
## Modificari aditive aplicate statisticilor eroului cand abilitatea e luata.
@export var bonus_projectiles: int = 0
@export var bonus_pierce: int = 0
@export var bonus_bounces: int = 0
@export var damage_multiplier: float = 1.0
@export var attack_speed_multiplier: float = 1.0
@export var move_speed_multiplier: float = 1.0
## Dauna pe secunda aplicata ca arsura, daca e cazul.
@export var burn_dps: float = 0.0
## Raza exploziei la impact; 0 inseamna fara explozie.
@export var explosion_radius: float = 0.0

@export_group("Vitalitate")
## Viata maxima adaugata. Vine plina, ca bonusul sa se simta imediat.
@export var bonus_max_health: float = 0.0
## Vindecare pe loc, ca fractiune din viata maxima (0.5 = jumatate).
@export_range(0.0, 1.0) var heal_fraction: float = 0.0

@export_group("Efecte compozabile")
## Ce nu incape intr-un camp simplu: Frost, Lightning Chain, Vampirism, marimea
## si viteza proiectilului. Doua abilitati luate impreuna isi aduna toate
## efectele - fara sa fi fost scris vreodata cazul acelei perechi anume.
@export var effects: Array[AbilityEffect] = []

@export_group("Fuziune")
## Abilitatea cu care se combina. Gol = nu fuzioneaza.
@export var fuses_with: Ability
## Rezultatul fuziunii (ex. Perforantă + Meteor = Săgeată Explozivă).
@export var fusion_result: Ability

@export_group("Deblocare")
## Cate camere trebuie curatate in total ca sa apara in pachetul de alegeri.
@export var unlock_at_total_rooms: int = 0
## Evolutiile nu se ofera niciodata direct: rostul lor e sa fie descoperite
## combinand doua abilitati, nu trase la carti ca oricare alta.
@export var only_from_fusion: bool = false


## Poate fi oferita ca alegere la ridicarea unui nivel?
func is_draftable(total_rooms_cleared: int) -> bool:
	return not only_from_fusion and total_rooms_cleared >= unlock_at_total_rooms


## Poate fuziona cu abilitatea data?
func can_fuse_with(other: Ability) -> bool:
	if other == null or fuses_with == null or fusion_result == null:
		return false
	return other.id == fuses_with.id


## Aplica peste statisticile rularii curente partea care tine de statistici.
## Viata (`bonus_max_health`, `heal_fraction`) nu se rezolva aici: ea nu e o
## statistica, ci starea componentei de viata, si o pune Hero la loc.
func apply_to(stats: HeroStats) -> void:
	stats.projectile_count += bonus_projectiles
	stats.pierce += bonus_pierce
	stats.bounces += bonus_bounces
	if not is_equal_approx(damage_multiplier, 1.0):
		stats.mult_attack *= damage_multiplier
	if not is_equal_approx(attack_speed_multiplier, 1.0):
		stats.mult_attack_speed *= attack_speed_multiplier
	if not is_equal_approx(move_speed_multiplier, 1.0):
		stats.mult_move_speed *= move_speed_multiplier
	for effect in effects:
		if effect != null:
			effect.apply_to_stats(stats)
	stats.recalculate()


## Efectele care se declanseaza la impact - Frost, Lightning Chain, Vampirism -
## din toate cele purtate de abilitatea asta. EffectStatMod n-are on_hit, deci
## filtrarea nu e nevoie: metoda lui goala pur si simplu nu face nimic.
func on_hit_effects() -> Array[AbilityEffect]:
	return effects
