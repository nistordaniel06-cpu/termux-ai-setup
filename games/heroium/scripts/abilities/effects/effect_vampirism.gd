class_name EffectVampirism
extends AbilityEffect

## O fractiune din dauna data se intoarce ca viata.
##
## Se aplica pe dauna deja rostogolita (dupa apărarea tintei si critice), nu pe
## atacul de baza - altfel un erou cu multa perforare ar vindeca disproportionat
## fata de cat a lovit cu adevarat.

@export_range(0.0, 1.0) var heal_fraction: float = 0.12


func on_hit(info: HitInfo) -> void:
	if info.attacker != null and info.attacker.has_method(&"heal"):
		info.attacker.heal(info.damage * heal_fraction)
