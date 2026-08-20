class_name Arena
extends Node2D

signal room_started(room: int, is_boss: bool)
signal room_cleared(room: int)
signal location_entered(location: Location)
signal run_ended(rooms_cleared: int, coins_earned: int)
signal run_won(rooms_cleared: int, coins_earned: int)
signal boss_spawned(enemy: Enemy)

@export var enemy_scene: PackedScene
@export var xp_orb_scene: PackedScene
@export var spawn_radius: float = 420.0
@export var min_spawn_distance: float = 260.0
@export var breather: float = 1.3

var location: Location = null
var location_index: int = 0
var room: int = 1
var rooms_cleared: int = 0
var coins_earned: int = 0
var is_over: bool = false

var _alive: int = 0
var _advancing: bool = false

@onready var _hero: Hero = $Hero
@onready var _world: Node2D = $World
@onready var _floor: ArenaFloor = $Floor
@onready var _camera: Camera2D = $Hero/Camera2D

func _ready() -> void:
	randomize()
	Fx.setup(_world, _camera)
	_hero.died.connect(_on_hero_died)
	_hero.set_projectile_container(_world)
	_enter_location(0)

func _enter_location(index: int) -> void:
	location_index = index
	location = GameState.location_at(index)
	room = 1

	if location == null:
		push_warning("Nicio locatie incarcata - arena ramane goala.")
		return

	_floor.apply_location(location)
	GameState.best_location = maxi(GameState.best_location, index + 1)
	location_entered.emit(location)
	Fx.toast(location.display_name)
	build_room()

func build_room() -> void:
	if location == null or enemy_scene == null:
		return

	_clear_leftovers()
	_alive = 0

	var is_boss := _is_boss_room()
	if is_boss:
		_spawn_enemy(location.boss)
		Fx.toast(location.boss.display_name)
		Fx.shake(6.0, 0.4)
	else:
		for i in location.enemy_count_for(room):
			_spawn_enemy(_pick_type())

	room_started.emit(room, is_boss)

func _is_boss_room() -> bool:
	if location == null or location.boss == null:
		return false
	if GameState.selected_mode == GameState.Mode.BOSS_RUSH:
		return true
	return location.is_boss_room(room)

func _pick_type() -> EnemyType:
	var pool := location.available_types(room)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func _spawn_enemy(type: EnemyType) -> void:
	if type == null:
		return

	var enemy: Enemy = enemy_scene.instantiate()
	enemy.setup(type, rooms_cleared)

	# Controlul ales de jucator devine parte din risc/recompensa:
	# cu cat jocul este mai automatizat, cu atat adversarii primesc mai multa putere.
	# Nu aplicam tot multiplicatorul la fiecare atribut, pentru a evita spike-uri
	# nedrepte. HP primeste full scaling, damage 75%, viteza 35%.
	var difficulty := clampf(_hero.get_enemy_difficulty_multiplier(), 1.0, 1.50)
	enemy.max_health *= difficulty
	enemy.health = enemy.max_health
	enemy.contact_damage *= lerpf(1.0, difficulty, 0.75)
	enemy.move_speed *= lerpf(1.0, difficulty, 0.35)

	_world.add_child(enemy)
	enemy.global_position = _pick_spawn_point()
	enemy.died.connect(_on_enemy_died)
	_alive += 1

	if type.is_boss:
		enemy.phase_changed.connect(_on_boss_phase)
		boss_spawned.emit(enemy)

func _on_boss_phase(enemy: Enemy, phase: int) -> void:
	if phase < 2 or enemy.type == null:
		return

	Fx.toast("FAZA A II-A")
	var summons := enemy.type.summons
	if summons == null or enemy.type.summon_count <= 0:
		return
	for i in enemy.type.summon_count:
		_spawn_enemy.call_deferred(summons)

func _pick_spawn_point() -> Vector2:
	var bounds := _floor.room_rect().grow(-60.0)

	for attempt in 24:
		var angle := randf() * TAU
		var distance := randf_range(min_spawn_distance, spawn_radius)
		var point := _hero.global_position + Vector2.RIGHT.rotated(angle) * distance
		if bounds.has_point(point):
			return point

	return Vector2(
		randf_range(bounds.position.x, bounds.end.x),
		randf_range(bounds.position.y, bounds.end.y),
	)

func _clear_leftovers() -> void:
	for node in _world.get_children():
		if node is Enemy or node is Projectile or node is EnemyProjectile or node is Telegraph:
			node.queue_free()

func _on_enemy_died(enemy: Enemy) -> void:
	coins_earned += enemy.coin_reward
	GameState.add_coins(enemy.coin_reward)
	_drop_orb(enemy.global_position, enemy.xp_reward)

	_alive -= 1
	if _alive > 0 or _advancing or is_over:
		return

	_advancing = true
	_advance_room()

func _drop_orb(at: Vector2, xp: int) -> void:
	if xp_orb_scene == null:
		return

	var orb: XpOrb = xp_orb_scene.instantiate()
	orb.xp = xp
	orb.position = _world.to_local(at)
	_world.add_child.call_deferred(orb)

func _advance_room() -> void:
	rooms_cleared += 1
	GameState.register_room_cleared()
	room_cleared.emit(room)

	await get_tree().create_timer(breather).timeout
	if is_over or not is_inside_tree():
		return

	_collect_remaining_orbs()
	_advancing = false
	_go_to_next_room()

func _go_to_next_room() -> void:
	if GameState.selected_mode == GameState.Mode.BOSS_RUSH:
		_enter_location(location_index + 1)
		return

	if room < location.rooms:
		room += 1
		build_room()
		return

	if GameState.selected_mode == GameState.Mode.CAMPAIGN and _is_last_location():
		_win_run()
		return

	_enter_location(location_index + 1)

func _is_last_location() -> bool:
	return location_index >= GameState.locations.size() - 1

func _win_run() -> void:
	if is_over:
		return
	is_over = true

	Fx.toast("VICTORIE")
	Fx.shake(8.0, 0.6)
	GameState.register_run_result(rooms_cleared)
	run_won.emit(rooms_cleared, coins_earned)
	get_tree().paused = true

func _collect_remaining_orbs() -> void:
	for node in _world.get_children():
		if node is XpOrb:
			_hero.gain_xp(node.xp)
			Fx.burst(node.global_position, Color("5ef0b6"), 4, 90.0)
			node.queue_free()

func _on_hero_died() -> void:
	if is_over:
		return
	is_over = true

	Fx.shake(9.0, 0.5)
	GameState.register_run_result(rooms_cleared)
	run_ended.emit(rooms_cleared, coins_earned)
	get_tree().paused = true
