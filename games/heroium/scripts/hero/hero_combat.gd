class_name HeroCombat
extends Node2D

## Tintirea automata si tragerea eroului.
##
## Nu decide singur DACA are voie sa traga - Hero ii spune prin `set_can_attack()`,
## dupa regula "te misti sau ataci". Aici se rezolva doar pe cine si cu ce.

signal fired(target: Node2D)
signal ability_gained(ability: Ability)
signal abilities_fused(a: Ability, b: Ability, result: Ability)

@export var projectile_scene: PackedScene

var abilities: Array[Ability] = []

var _hero: Hero
var _stats: HeroStats
var _can_attack: bool = false
var _cooldown: float = 0.0


func setup(hero: Hero, stats: HeroStats) -> void:
	_hero = hero
	_stats = stats


func set_can_attack(value: bool) -> void:
	_can_attack = value


func _physics_process(delta: float) -> void:
	if _stats == null:
		return

	_cooldown = maxf(0.0, _cooldown - delta)

	if not _can_attack or _cooldown > 0.0:
		return

	var target := find_nearest_enemy()
	if target == null:
		return

	_fire_at(target)
	_cooldown = _stats.attack_interval()


## Cel mai apropiat inamic aflat in raza de atac, sau null.
## Compar distantele la patrat: acelasi rezultat, fara radical pe fiecare inamic.
func find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := _stats.attack_range * _stats.attack_range

	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy

	return best


func _fire_at(target: Node2D) -> void:
	if projectile_scene == null:
		push_warning("HeroCombat fara projectile_scene - nu am ce trage.")
		return

	var base_angle := global_position.angle_to_point(target.global_position)
	var count := maxi(1, _stats.projectile_count)
	var spread := 0.14

	for i in count:
		var offset := 0.0 if count == 1 else (float(i) - (count - 1) * 0.5) * spread
		var projectile := projectile_scene.instantiate()
		# Proiectilele stau in arena, nu sub erou - altfel s-ar misca odata cu el.
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = global_position
		projectile.launch(Vector2.RIGHT.rotated(base_angle + offset), _stats, _collect_hit_effects())

	fired.emit(target)


## Efectele care se aplica la impact, stranse din abilitatile luate.
func _collect_hit_effects() -> Dictionary:
	var effects := {"burn_dps": 0.0, "explosion_radius": 0.0}
	for ability in abilities:
		effects["burn_dps"] += ability.burn_dps
		effects["explosion_radius"] = maxf(effects["explosion_radius"], ability.explosion_radius)
	return effects


## Adauga o abilitate. Daca formeaza o pereche cu una deja detinuta, cele doua
## se transforma in evolutia lor (Perforantă + Meteor = Săgeată Explozivă).
func add_ability(ability: Ability) -> void:
	if ability == null:
		return

	for i in abilities.size():
		var owned := abilities[i]
		var result: Ability = null
		if owned.can_fuse_with(ability):
			result = owned.fusion_result
		elif ability.can_fuse_with(owned):
			result = ability.fusion_result

		if result != null:
			abilities.remove_at(i)
			abilities.append(result)
			result.apply_to(_stats)
			abilities_fused.emit(owned, ability, result)
			return

	abilities.append(ability)
	ability.apply_to(_stats)
	ability_gained.emit(ability)
