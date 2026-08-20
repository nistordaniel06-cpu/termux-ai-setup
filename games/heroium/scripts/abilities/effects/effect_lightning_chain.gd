class_name EffectLightningChain
extends AbilityEffect

## La impact, fulgerul sare la inca cativa inamici din apropiere.
##
## Sare o singura data de la lovitura originala, nu in lant recursiv - un lant
## care se lungeste singur ar putea curata o camera dintr-o sageata, si atunci
## restul abilitatilor n-ar mai conta. `jumps` e limita explicita, nu un accident.
##
## Nu deseneaza nimic direct: un Resource care ar referi Fx la nivel de script
## risca sa nu compileze daca e incarcat inainte ca autoloadurile sa fie gata (o
## cursa reala, vazuta chiar in acest proiect). Efectele descriu ce se schimba in
## joc; scanteia de impact e treaba lui Projectile, care e deja pe scena.

@export var jumps: int = 2
@export_range(0.0, 1.0) var damage_fraction: float = 0.6
@export var radius: float = 170.0


func on_hit(info: HitInfo) -> void:
	if info.target == null or not is_instance_valid(info.target):
		return

	var candidates: Array[Node] = []
	for node in info.target.get_tree().get_nodes_in_group(&"enemy"):
		if node == info.target or not (node is Node2D):
			continue
		if (node as Node2D).global_position.distance_to(info.position) <= radius:
			candidates.append(node)

	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(info.position) \
			< b.global_position.distance_squared_to(info.position))

	var jump_damage := info.damage * damage_fraction
	for i in mini(jumps, candidates.size()):
		var enemy: Node = candidates[i]
		if enemy.has_method(&"take_damage"):
			enemy.take_damage(jump_damage, false)
