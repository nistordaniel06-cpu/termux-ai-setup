class_name Enemy
extends CharacterBody2D

## Inamic de baza: schelete, lilieci, demoni. Bosii mostenesc de aici.
##
## Trebuie sa fie in grupul "enemy" - dupa el isi cauta eroul tinta si tot dupa
## el se orienteaza proiectilele.

signal died(enemy: Enemy)

@export var max_health: float = 60.0
@export var defense: float = 0.0
@export var move_speed: float = 90.0
@export var contact_damage: float = 12.0
@export var coin_reward: int = 1
@export var xp_reward: int = 2

var health: float = 0.0

var _burn_dps: float = 0.0
var _burn_time: float = 0.0
var _contact_cooldown: float = 0.0
var _hero: Node2D = null

@onready var _body: Blob = $Body


func _ready() -> void:
	add_to_group(&"enemy")
	health = max_health
	_hero = get_tree().get_first_node_in_group(&"hero")


func _physics_process(delta: float) -> void:
	_tick_burn(delta)
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)

	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group(&"hero")
		return

	var to_hero := _hero.global_position - global_position
	velocity = to_hero.normalized() * move_speed
	move_and_slide()

	if to_hero.length() < 34.0 and _contact_cooldown <= 0.0:
		_contact_cooldown = 0.6
		if _hero.has_method(&"take_damage"):
			_hero.take_damage(contact_damage)


func get_defense() -> float:
	return defense


func take_damage(amount: float, _is_crit: bool = false) -> void:
	if health <= 0.0:
		return
	health -= amount
	_body.flash()
	queue_redraw()
	if health <= 0.0:
		_die()


## Bara de viata apare abia dupa prima lovitura, ca o camera plina de inamici
## nedeteriorati sa nu fie un zid de bare.
func _draw() -> void:
	if health >= max_health or health <= 0.0:
		return

	var width := 34.0
	var corner := Vector2(-width * 0.5, -30.0)
	var fraction := clampf(health / max_health, 0.0, 1.0)
	draw_rect(Rect2(corner, Vector2(width, 5.0)), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(Rect2(corner, Vector2(width * fraction, 5.0)), Color(0.95, 0.34, 0.34))


func apply_burn(dps: float, duration: float) -> void:
	# Arsura nu se aduna la infinit: ramane cea mai puternica sursa.
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)


func _tick_burn(delta: float) -> void:
	if _burn_time <= 0.0:
		return
	_burn_time -= delta
	take_damage(_burn_dps * delta)
	if _burn_time <= 0.0:
		_burn_dps = 0.0


func _die() -> void:
	GameState.add_coins(coin_reward)
	died.emit(self)
	queue_free()
