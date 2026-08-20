class_name Arena
extends Node2D

## Rularea in sine: camere una dupa alta, prin locatii, pana cazi.
##
## O camera se incheie cand ultimul inamic a murit. Cand se termina camerele unei
## locatii vine seful ei, iar dupa el urmatoarea locatie. Dupa ultima locatie
## campania nu se opreste: se reia ultima, dar treapta de dificultate creste mai
## departe, deci "endless" nu inseamna "la nesfarsit la fel de usor".
##
## Nimic din ce e aici nu stie ce fel de inamici exista - asta scrie in Location.

signal room_started(room: int, is_boss: bool)
signal room_cleared(room: int)
signal location_entered(location: Location)
signal run_ended(rooms_cleared: int, coins_earned: int)

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

var _alive: int = 0
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

	_clear_leftovers()
	_alive = 0

	var is_boss := location.is_boss_room(room)
	if is_boss:
		_spawn_enemy(location.boss)
		Fx.toast("%s" % location.boss.display_name)
		Fx.shake(6.0, 0.4)
	else:
		for i in location.enemy_count_for(room):
			_spawn_enemy(_pick_type())

	room_started.emit(room, is_boss)


## Un fel de inamic din cei pe care camera asta ii poate aduce.
func _pick_type() -> EnemyType:
	var pool := location.available_types(room)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


func _spawn_enemy(type: EnemyType) -> void:
	if type == null:
		return

	var enemy: Enemy = enemy_scene.instantiate()
	# Datele intra inainte de intrarea in arbore, ca `_ready` sa le gaseasca gata.
	enemy.setup(type, rooms_cleared)
	_world.add_child(enemy)
	enemy.global_position = _pick_spawn_point()
	enemy.died.connect(_on_enemy_died)
	_alive += 1


## Punct la distanta de erou, dar tot inauntrul camerei - altfel inamicii ar
## aparea dincolo de pereti si n-ar mai avea cum sa ajunga la el.
func _pick_spawn_point() -> Vector2:
	var bounds := _floor.room_rect().grow(-60.0)

	for attempt in 24:
		var angle := randf() * TAU
		var distance := randf_range(min_spawn_distance, spawn_radius)
		var point := _hero.global_position + Vector2.RIGHT.rotated(angle) * distance
		if bounds.has_point(point):
			return point

	# Camera e prea stramta pentru inelul cerut: pune-l oriunde inauntru.
	return Vector2(
		randf_range(bounds.position.x, bounds.end.x),
		randf_range(bounds.position.y, bounds.end.y),
	)


## Goleste camera inainte sa fie construita cea noua.
##
## In mersul normal al jocului n-a mai ramas niciun inamic aici - camera se
## incheie tocmai cand moare ultimul. Ii stergem oricum, ca o camera "noua" sa
## fie mereu chiar noua: altfel un salt de locatie s-ar aseza peste ce era si
## numaratoarea `_alive` n-ar mai corespunde cu ce e pe ecran.
##
## Cioburile de experienta NU se sterg aici - pe acelea le culege eroul.
func _clear_leftovers() -> void:
	for node in _world.get_children():
		if node is Enemy or node is Projectile or node is EnemyProjectile or node is Telegraph:
			node.queue_free()


# ====================== SFARSIT DE CAMERA ======================

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
	# Inamicul moare in mijlocul unei interogari de fizica (l-a lovit o sageata),
	# iar acolo serverul nu accepta zone noi. Ciobul intra la capatul cadrului.
	_world.add_child.call_deferred(orb)


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

	room += 1
	if room > location.rooms:
		_enter_location(location_index + 1)
	else:
		build_room()

	_advancing = false


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
