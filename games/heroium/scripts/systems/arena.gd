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


func _ready() -> void:
	randomize()
	_hero.died.connect(_on_hero_died)
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


## Punct la distanta de erou, ca sa nu apara inamici direct in fata lui.
func _pick_spawn_point() -> Vector2:
	for attempt in 20:
		var angle := randf() * TAU
		var distance := randf_range(min_spawn_distance, spawn_radius)
		var point := _hero.global_position + Vector2.RIGHT.rotated(angle) * distance
		if point.distance_to(_hero.global_position) >= min_spawn_distance:
			return point
	return _hero.global_position + Vector2.RIGHT * spawn_radius


func _on_enemy_died(_enemy: Node) -> void:
	_alive -= 1
	if _alive <= 0:
		GameState.register_room_cleared()
		room_cleared.emit(room_index)
		room_index += 1
		build_room()


func _on_hero_died() -> void:
	set_process(false)
	print("Eroul a căzut în camera %d." % room_index)
