class_name ArenaFloor
extends Node2D

## Podeaua camerei: o deseneaza si tot din aceleasi masuri ii ridica peretii,
## ca desenul si coliziunile sa nu poata ajunge niciodata sa nu se potriveasca.
##
## Fara nodul asta scena nu avea nimic de desenat sub personaje (de unde
## ecranul gri) si nimic pe stratul "world", deci eroul pleca la nesfarsit in gol.

## Cat de mare e camera jucabila, in pixeli.
@export var room_size: Vector2 = Vector2(900.0, 1440.0)
## Latura unei celule din grila de podea.
@export var cell: float = 90.0
@export var floor_color: Color = Color("1b1726")
@export var grid_color: Color = Color("272138")
@export var border_color: Color = Color("f0b45a")

## Peretii sunt grosi ca eroul sa nu-i poata traversa la viteza mare.
const WALL_THICKNESS := 64.0


func _ready() -> void:
	_build_walls()


## Dreptunghiul jucabil, in coordonate globale.
func room_rect() -> Rect2:
	return Rect2(global_position - room_size * 0.5, room_size)


func _draw() -> void:
	var rect := Rect2(-room_size * 0.5, room_size)
	draw_rect(rect, floor_color)

	# Grila da simtul deplasarii: fara ea, mersul pe un fond plat nu se citeste.
	var x := rect.position.x + cell
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), grid_color, 1.0)
		x += cell
	var y := rect.position.y + cell
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), grid_color, 1.0)
		y += cell

	draw_rect(rect, border_color, false, 4.0)


## Ridica cei patru pereti pe stratul "world" (1), pe care eroul il are in masca.
func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)

	var half := room_size * 0.5
	var t := WALL_THICKNESS
	var plan := {
		Vector2(0.0, -half.y - t * 0.5): Vector2(room_size.x + t * 2.0, t),
		Vector2(0.0, half.y + t * 0.5): Vector2(room_size.x + t * 2.0, t),
		Vector2(-half.x - t * 0.5, 0.0): Vector2(t, room_size.y + t * 2.0),
		Vector2(half.x + t * 0.5, 0.0): Vector2(t, room_size.y + t * 2.0),
	}

	for offset: Vector2 in plan:
		var shape := RectangleShape2D.new()
		shape.size = plan[offset]
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = offset
		walls.add_child(collider)
