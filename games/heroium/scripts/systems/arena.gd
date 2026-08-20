class_name Arena
extends Node2D

## Rularea in sine: camere una dupa alta, prin locatii, pana cazi.
##
## Arena orchestreaza, nu face treaba cu mainile ei: cine apare intr-o camera e
## treaba lui RoomWave, ce cameră vine dupa e treaba lui DungeonProgress. Aici
## ramane doar starea rularii (locatia, camera, monedele) si legatura dintre
## semnalele lor si ce vede jucatorul.
##
## Nimic din ce e aici nu stie ce fel de inamici exista - asta scrie in Location.

signal room_started(room: int, is_boss: bool)
signal room_cleared(room: int)
signal location_entered(location: Location)
signal run_ended(rooms_cleared: int, coins_earned: int)
## Campania a fost dusa pana la capat. Doar Campanie se poate castiga.
signal run_won(rooms_cleared: int, coins_earned: int)
## Un sef a intrat in camera. HUD-ul ii pune bara mare sus.
signal boss_spawned(enemy: Enemy)

@export var enemy_scene: PackedScene
@export var xp_orb_scene: PackedScene
## Cat de departe de erou pot aparea inamicii.
@export var spawn_radius: float = 420.0
## Cat de aproape de erou are voie sa apara un inamic.
@export var min_spawn_distance: float = 260.0
## Ragazul dintre doua camere, cat sa vezi ca ai scapat.
@export var breather: float = 1.3

var location: Location = null
var location_index: int = 0
## A cata camera din locatia curenta.
var room: int = 1
## Cate camere ai curatat in rularea asta - tot ea e treapta de dificultate.
var rooms_cleared: int = 0
var coins_earned: int = 0
var is_over: bool = false

var _wave: RoomWave = null
var _advancing: bool = false

@onready var _hero: Hero = $Hero
@onready var _world: Node2D = $World
@onready var _floor: ArenaFloor = $Floor
@onready var _camera: Camera2D = $Hero/Camera2D


func _ready() -> void:
	randomize()

	# Autoloadul supravietuieste reincarcarii scenei, dar nodurile spre care
	# arata nu: de aceea se leaga din nou la fiecare rulare.
	Fx.setup(_world, _camera)

	_hero.died.connect(_on_hero_died)
	_hero.set_projectile_container(_world)

	_wave = RoomWave.new()
	_wave.min_spawn_distance = min_spawn_distance
	_wave.spawn_radius = spawn_radius
	_wave.setup(enemy_scene, xp_orb_scene, _world, _hero, _floor.room_rect)
	_wave.enemy_died.connect(_on_enemy_died)
	_wave.cleared.connect(_on_room_cleared)

	_enter_location(0)


# ====================== LOCATII ======================

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


# ====================== CAMERE ======================

func build_room() -> void:
	if location == null or enemy_scene == null:
		return

	_wave.clear_leftovers()

	var is_boss := DungeonProgress.is_boss_room(location, room, GameState.selected_mode)
	if is_boss:
		var boss := _wave.spawn_boss_room(location, rooms_cleared)
		if boss != null:
			boss.phase_changed.connect(_on_boss_phase)
			boss_spawned.emit(boss)
		Fx.toast(location.boss.display_name)
		Fx.shake(6.0, 0.4)
	else:
		_wave.spawn_normal_room(location, room, rooms_cleared)

	room_started.emit(room, is_boss)


## Seful s-a infuriat. Ajutoarele le aduce arena, nu el: el n-are de unde sti
## unde e loc liber, iar RoomWave trebuie sa le numere ca sa nu se incheie
## camera cat inca misca ceva.
func _on_boss_phase(enemy: Enemy, phase: int) -> void:
	if phase < 2 or enemy.type == null:
		return

	Fx.toast("FAZA A II-A")
	var summons := enemy.type.summons
	if summons == null or enemy.type.summon_count <= 0:
		return
	for i in enemy.type.summon_count:
		_wave.spawn.call_deferred(summons, rooms_cleared, min_spawn_distance, spawn_radius)


# ====================== SFARSIT DE CAMERA ======================

func _on_enemy_died(enemy: Enemy) -> void:
	coins_earned += enemy.coin_reward
	GameState.add_coins(enemy.coin_reward)
	_drop_orb(enemy.global_position, enemy.xp_reward)


func _drop_orb(at: Vector2, xp: int) -> void:
	if xp_orb_scene == null:
		return

	var orb: XpOrb = xp_orb_scene.instantiate()
	orb.xp = xp
	orb.position = _world.to_local(at)
	# Inamicul moare in mijlocul unei interogari de fizica (l-a lovit o sageata),
	# iar acolo serverul nu accepta zone noi. Ciobul intra la capatul cadrului.
	_world.add_child.call_deferred(orb)


func _on_room_cleared() -> void:
	if _advancing or is_over:
		return
	_advancing = true
	_advance_room()


func _advance_room() -> void:
	rooms_cleared += 1
	GameState.register_room_cleared()
	room_cleared.emit(room)

	await get_tree().create_timer(breather).timeout
	if is_over or not is_inside_tree():
		return

	# Ce a ramas pe jos vine singur la tine. Altfel ultima treaba dintr-o camera
	# curatata ar fi sa maturi podeaua, exact opusul a ce cere jocul. Se face
	# dupa ragaz, nu in clipa ultimei morti, ca sa nu stearga zone din fizica
	# chiar in mijlocul pasului care le-a omorat.
	_collect_remaining_orbs()
	_advancing = false
	_go_to_next_room()


## Unde ajunge jucatorul dupa ce a curatat camera. DungeonProgress decide DUPA
## regimul ales; Arena doar executa decizia si emite ce trebuie.
func _go_to_next_room() -> void:
	var outcome := DungeonProgress.after_clear(location, location_index, room, GameState.selected_mode)
	match outcome:
		DungeonProgress.Outcome.NEXT_LOCATION:
			_enter_location(location_index + 1)
		DungeonProgress.Outcome.VICTORY:
			_win_run()
		_:
			room += 1
			build_room()


func _is_last_location() -> bool:
	return DungeonProgress.is_last_location(location_index)


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


# ====================== SFARSIT DE RULARE ======================

func _on_hero_died() -> void:
	if is_over:
		return
	is_over = true

	Fx.shake(9.0, 0.5)
	GameState.register_run_result(rooms_cleared)
	run_ended.emit(rooms_cleared, coins_earned)

	# Ingheata camera. Ecranele de interfata ruleaza mai departe
	# (process_mode "always") si preiau ce alege jucatorul.
	get_tree().paused = true
