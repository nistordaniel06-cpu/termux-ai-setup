class_name HeroCombat
extends Node2D

signal fired(target: Node2D)
signal ability_gained(ability: Ability)
signal abilities_fused(a: Ability, b: Ability, result: Ability)

@export var projectile_scene: PackedScene

var abilities: Array[Ability] = []
var current_target: Node2D = null
var projectile_container: Node = null

var _hero: Hero
var _stats: HeroStats
var _can_attack: bool = false
var _cooldown: float = 0.0
var _manual_aim: Vector2 = Vector2.ZERO
var _attack_once: bool = false

func setup(hero: Hero, stats: HeroStats) -> void:
	_hero = hero
	_stats = stats

func set_can_attack(value: bool) -> void:
	_can_attack = value

func set_manual_aim(direction: Vector2) -> void:
	_manual_aim = direction

func request_attack_once() -> void:
	_attack_once = true

func _physics_process(delta: float) -> void:
	if _stats == null:
		return

	_cooldown = maxf(0.0, _cooldown - delta)
	current_target = find_nearest_enemy()

	if _attack_once:
		_attack_once = false
		if _cooldown <= 0.0 and current_target != null:
			_fire_at(current_target)
			_cooldown = _stats.attack_interval()
		return

	if not _can_attack or _cooldown > 0.0:
		return

	if _manual_aim.length() > 0.15:
		_fire_direction(_manual_aim.normalized(), current_target)
	else:
		if current_target == null:
			return
		_fire_at(current_target)

	_cooldown = _stats.attack_interval()

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
	if target == null or not is_instance_valid(target):
		return
	var direction := global_position.direction_to(target.global_position)
	_spawn_projectiles(direction, target)

func _fire_direction(direction: Vector2, target: Node2D = null) -> void:
	_spawn_projectiles(direction.normalized(), target)

func _spawn_projectiles(direction: Vector2, target: Node2D = null) -> void:
	if projectile_scene == null:
		push_warning("HeroCombat fara projectile_scene - nu am ce trage.")
		return

	var container := _projectile_container()
	if container == null:
		push_warning("HeroCombat fara loc unde sa lase proiectilele.")
		return

	var base_angle := direction.angle()
	var count := maxi(1, _stats.projectile_count)
	var spread := 0.14

	for i in count:
		var offset := 0.0 if count == 1 else (float(i) - (count - 1) * 0.5) * spread
		var projectile := projectile_scene.instantiate()
		container.add_child(projectile)
		projectile.global_position = global_position
		projectile.launch(Vector2.RIGHT.rotated(base_angle + offset), _stats, _collect_hit_effects())

	fired.emit(target)

func _projectile_container() -> Node:
	if projectile_container != null and is_instance_valid(projectile_container):
		return projectile_container
	return _hero.get_parent() if _hero != null else null

func _collect_hit_effects() -> Dictionary:
	var effects := {"burn_dps": 0.0, "explosion_radius": 0.0}
	for ability in abilities:
		effects["burn_dps"] += ability.burn_dps
		effects["explosion_radius"] = maxf(effects["explosion_radius"], ability.explosion_radius)
	return effects

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
