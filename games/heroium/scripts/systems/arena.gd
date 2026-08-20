class_name Arena
extends Node2D

## Arena unei camere: aduce inamicii, numara cat au mai ramas si deschide iesirea.
##
## Schela minima cat sa poti apasa Play si sa vezi eroul mișcându-se și trăgând.
## Locațiile din concept (Pădurea Blestemată, Castelul Întunecat, Deșertul Pierdut,
## Tărâmul Umbrelor) vor inlocui valorile de aici cu propriile lor date.

signal room_cleared(room_index: int)

@export var enemy_scene: PackedScene
@export var enemies_per_room: int = 5
@export var spawn_radius: float = 420.0
## Cat de aproape de erou are voie sa apara un inamic.
@export var min_spawn_distance: float = 260.0

var room_index: int = 1
var _alive: int = 0

@onready var _hero: Hero = $Hero
@onready var _arena: Node2D = $Arena
@onready var _floor: ArenaFloor = $Floor


func _ready() -> void:
	randomize()
	_hero.died.connect(_on_hero_died)
	_hero.set_projectile_container(_arena)
	build_room()


func build_room() -> void:
	if enemy_scene == null:
		push_warning("Arena fara enemy_scene - camera ramane goala. Setează-l în Inspector.")
		return

	_alive = 0
	for i in enemies_per_room + room_index:
		_spawn_enemy()


func _spawn_enemy() -> void:
	var enemy := enemy_scene.instantiate()
	_arena.add_child(enemy)
	enemy.global_position = _pick_spawn_point()

	if enemy.has_signal(&"died"):
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


func _on_enemy_died(_enemy: Node) -> void:
	_alive -= 1
	if _alive > 0:
		return

	GameState.register_room_cleared()
	room_cleared.emit(room_index)
	room_index += 1

	# O clipa de respiro: fara ea valul urmator apare peste ultima lovitura.
	await get_tree().create_timer(1.2).timeout
	build_room()


func _on_hero_died() -> void:
	# Ingheata camera. HUD-ul ruleaza mai departe (process_mode "always") si
	# preia atingerea care reia jocul.
	get_tree().paused = true
