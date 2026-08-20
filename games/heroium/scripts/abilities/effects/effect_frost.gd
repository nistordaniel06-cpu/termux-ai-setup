class_name EffectFrost
extends AbilityEffect

## La impact, tinta ingheata: arde incet si se misca mai greu.
##
## Separat de arsura obisnuita in Enemy (`apply_burn`), ca un inamic sa poata
## purta amandoua deodata - foc si gheata pe aceeasi tinta, de la doua abilitati
## diferite, fara ca una s-o stinga pe cealalta.

@export var dps: float = 4.0
@export_range(0.0, 0.9) var slow: float = 0.35
@export var duration: float = 2.0


func on_hit(info: HitInfo) -> void:
	if info.target != null and info.target.has_method(&"apply_frost"):
		info.target.apply_frost(dps, slow, duration)
