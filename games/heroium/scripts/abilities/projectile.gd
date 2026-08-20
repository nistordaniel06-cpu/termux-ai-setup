class_name Projectile
extends Area2D

## Sageata trasa de erou. Traieste in arena, nu sub erou.
##
## Se sterge in clipa in care nu mai are ce lovi (a iesit din arena, i-a expirat
## viata, si-a consumat perforarile). Pe telefon proiectilele uitate in memorie
## sunt prima cauza de lag intr-un joc de genul asta.

@export var speed: float = 900.0
@export var lifetime: float = 2.2

var damage: float = 10.0
var crit_multiplier: float = 2.0
var crit_chance: float = 0.05
var pierce_left: int = 0
var bounces_left: int = 0
var effects: Dictionary = {}

var _direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0
var _already_hit: Array[Node] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


## Porneste proiectilul. Copiaza din statistici doar ce-i trebuie, ca sa nu
## depinda de erou dupa ce a plecat din arc.
func launch(direction: Vector2, stats: HeroStats, hit_effects: Dictionary = {}) -> void:
	_direction = direction.normalized()
	rotation = _direction.angle()

	damage = stats.attack
	crit_chance = stats.crit_chance
	crit_multiplier = stats.crit_multiplier
	pierce_left = stats.pierce
	bounces_left = stats.bounces
	effects = hit_effects


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	_resolve_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_resolve_hit(area)


func _resolve_hit(node: Node) -> void:
	if node in _already_hit:
		return
	if not node.is_in_group(&"enemy"):
		return

	_already_hit.append(node)

	var target_defense := 0.0
	if node.has_method(&"get_defense"):
		target_defense = node.get_defense()

	var is_crit := randf() < crit_chance
	var mitigation := target_defense / (target_defense + 400.0)
	var final_damage: float = maxf(1.0, damage * (crit_multiplier if is_crit else 1.0) * (1.0 - mitigation))

	if node.has_method(&"take_damage"):
		node.take_damage(final_damage, is_crit)

	var burn: float = effects.get("burn_dps", 0.0)
	if burn > 0.0 and node.has_method(&"apply_burn"):
		node.apply_burn(burn, 2.5)

	var radius: float = effects.get("explosion_radius", 0.0)
	if radius > 0.0:
		_explode(radius, final_damage * 0.6)

	if pierce_left > 0:
		pierce_left -= 1
	else:
		queue_free()


func _explode(radius: float, splash: float) -> void:
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or enemy in _already_hit:
			continue
		if global_position.distance_to(enemy.global_position) <= radius and enemy.has_method(&"take_damage"):
			enemy.take_damage(splash, false)
