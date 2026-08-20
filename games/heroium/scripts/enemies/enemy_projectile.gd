class_name EnemyProjectile
extends Area2D

## Ce trag arcasii. Merge drept, loveste o singura data si dispare.
##
## Tine dauna copiata la plecare, nu o referinta la cel care a tras: arcasul
## poate muri intre timp, dar sageata lui tot trebuie sa ajunga.

@export var speed: float = 300.0
@export var lifetime: float = 3.0

var damage: float = 10.0
var color: Color = Color("c86bf0")

var _direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Chemat de Pool cand o sageata lasata deoparte e data din nou.
func pool_activate() -> void:
	monitoring = true
	monitorable = true


## Chemat de Pool cand sageata e lasata deoparte, in loc sa fie stearsa.
func pool_deactivate() -> void:
	monitoring = false
	monitorable = false


func launch(direction: Vector2, hit_damage: float, tint: Color) -> void:
	_direction = direction.normalized()
	rotation = _direction.angle()
	damage = hit_damage
	color = tint
	# O sageata refolosita din bazin poarta varsta rulării ei de dinainte -
	# fara resetul asta, ar putea disparea imediat (varsta veche > lifetime).
	_age = 0.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta
	_age += delta
	if _age >= lifetime:
		Pool.release(self)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"hero"):
		return
	if body.has_method(&"take_damage"):
		body.take_damage(damage)
	Fx.burst(global_position, color, 6, 120.0)
	Pool.release(self)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color(color.r, color.g, color.b, 0.35))
	draw_circle(Vector2.ZERO, 4.0, color)
	draw_circle(Vector2.ZERO, 1.8, Color(1, 1, 1, 0.9))
