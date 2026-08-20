class_name Enemy
extends CharacterBody2D

## Inamicul, in trei feluri: urmaritor, arcas si navalitor.
##
## Ce fel e vine dintr-un EnemyType (.tres), nu din cod - un schelet nou nu cere
## un script nou. Cei doi care nu se multumesc cu contactul isi anunta lovitura
## printr-un Telegraph inainte s-o dea: fara acea fractiune de secunda de
## avertizare jocul e greu in sensul prost, cel in care mori fara sa fi avut ce
## face.
##
## Trebuie sa fie in grupul "enemy": dupa el il cauta tintirea automata a eroului
## si tot dupa el numara arena cati au mai ramas.

signal died(enemy: Enemy)

## Distanta la care arcasul incearca sa se tina.
const SHOOTER_RANGE := 250.0
## Cat tine tintirea arcasului - atat ai la dispozitie ca sa te dai la o parte.
const AIM_TIME := 0.85
## Cat se incarca navalitorul inainte sa porneasca.
const WIND_TIME := 0.75
## De la ce distanta se hotaraste navalitorul sa porneasca.
const CHARGE_TRIGGER := 330.0
const DASH_SPEED := 520.0
const DASH_TIME := 0.42
## Cat asteapta intre doua lovituri prin contact.
const CONTACT_COOLDOWN := 0.6

@export var projectile_scene: PackedScene

var type: EnemyType = null
var max_health: float = 26.0
var health: float = 0.0
var move_speed: float = 74.0
var contact_damage: float = 9.0
var defense: float = 0.0
var xp_reward: int = 2
var coin_reward: int = 1
var radius: float = 16.0

var _phase: StringName = &"idle"
var _phase_time: float = 0.0
var _aim_point: Vector2 = Vector2.ZERO
var _dash_velocity: Vector2 = Vector2.ZERO
var _burn_dps: float = 0.0
var _burn_time: float = 0.0
var _contact_cooldown: float = 0.0
var _hero: Node2D = null

@onready var _body: Blob = $Body
@onready var _collider: CollisionShape2D = $CollisionShape2D


## De chemat inainte de add_child: aseaza doar datele, iar `_ready` le pune in
## practica. Asa ordinea e mereu aceeasi, indiferent cine creeaza inamicul.
func setup(enemy_type: EnemyType, tier: int) -> void:
	type = enemy_type
	max_health = enemy_type.health_at(tier)
	health = max_health
	move_speed = enemy_type.speed_at(tier)
	contact_damage = enemy_type.damage_at(tier)
	defense = enemy_type.defense
	xp_reward = enemy_type.xp_reward
	coin_reward = enemy_type.coin_reward
	radius = enemy_type.radius


func _ready() -> void:
	add_to_group(&"enemy")
	_hero = get_tree().get_first_node_in_group(&"hero")

	if type == null:
		push_warning("Enemy fara EnemyType - ramane pe valorile implicite.")
	else:
		_body.radius = radius
		_body.fill = type.color
		# Forma vine din scena, deci e aceeasi pentru toate instantele: fara
		# copie, un sef mare ar umfla si scheletele.
		var shape: CircleShape2D = _collider.shape.duplicate()
		shape.radius = radius
		_collider.shape = shape
		_phase = _initial_phase()

	health = max_health


func _initial_phase() -> StringName:
	match type.behavior:
		EnemyType.Behavior.SHOOTER:
			return &"reposition"
		EnemyType.Behavior.CHARGER:
			return &"stalk"
		_:
			return &"chase"


func _physics_process(delta: float) -> void:
	_tick_burn(delta)
	if health <= 0.0:
		return

	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)

	if _hero == null or not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group(&"hero")
		return

	var to_hero := _hero.global_position - global_position
	var distance := maxf(1.0, to_hero.length())
	var direction := to_hero / distance

	var behavior := EnemyType.Behavior.CHASER
	if type != null:
		behavior = type.behavior

	match behavior:
		EnemyType.Behavior.SHOOTER:
			_act_shooter(delta, direction, distance)
		EnemyType.Behavior.CHARGER:
			_act_charger(delta, direction, distance)
		_:
			# Urmaritorul vine drept, fara siretlicuri - presiunea lui e ca nu
			# se opreste niciodata.
			velocity = direction * move_speed

	move_and_slide()
	_try_contact(distance, direction)


## Pastreaza distanta, tinteste unde stai, apoi trage acolo.
func _act_shooter(delta: float, direction: Vector2, distance: float) -> void:
	_phase_time -= delta

	if _phase == &"reposition":
		# Se aseaza la distanta lui si taie lateral, ca sa nu fie o tinta fixa.
		var pull := 0.0
		if distance > SHOOTER_RANGE + 40.0:
			pull = 1.0
		elif distance < SHOOTER_RANGE - 40.0:
			pull = -1.0
		var strafe := Vector2(-direction.y, direction.x) * 0.45
		velocity = (direction * pull + strafe) * move_speed

		if _phase_time <= 0.0:
			_phase = &"aim"
			_phase_time = AIM_TIME
			# Tinteste unde esti ACUM, nu unde vei fi: statul pe loc se plateste.
			_aim_point = _hero.global_position
			_spawn(Telegraph.spot(_aim_point, 34.0, AIM_TIME))
		return

	# In timp ce tinteste sta locului, ca semnul sa insemne ceva.
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * 6.0 * delta)
	if _phase_time <= 0.0:
		_shoot_at(_aim_point)
		_phase = &"reposition"
		_phase_time = randf_range(1.1, 1.9)


## Te pandeste, se incarca vizibil, apoi navaleste in linie dreapta.
func _act_charger(delta: float, direction: Vector2, distance: float) -> void:
	_phase_time -= delta

	if _phase == &"stalk":
		velocity = direction * move_speed
		if _phase_time <= 0.0 and distance < CHARGE_TRIGGER:
			_phase = &"wind"
			_phase_time = WIND_TIME
			_aim_point = _hero.global_position
			_spawn(Telegraph.line(global_position, _aim_point, WIND_TIME))
		return

	if _phase == &"wind":
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 8.0 * delta)
		if _phase_time <= 0.0:
			_dash_velocity = global_position.direction_to(_aim_point) * DASH_SPEED
			_phase = &"dash"
			_phase_time = DASH_TIME
		return

	velocity = _dash_velocity
	# Franeaza pe parcurs, deci navala are un capat si nu te urmareste la
	# infinit. Exponentul tine franarea aceeasi si daca scade numarul de cadre.
	_dash_velocity *= pow(0.94, delta * 60.0)
	if randf() < 0.6:
		Fx.burst(global_position, type.color, 1, 60.0)
	if _phase_time <= 0.0:
		_phase = &"stalk"
		_phase_time = randf_range(1.2, 2.0)


func _shoot_at(point: Vector2) -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate()
	_spawn(projectile)
	projectile.global_position = global_position
	projectile.launch(global_position.direction_to(point), contact_damage, type.color)


## Inamicii, semnele si sagetile lor stau langa el, in lume - nu sub el, altfel
## s-ar misca odata cu el si ar disparea cand moare.
func _spawn(node: Node) -> void:
	var world := get_parent()
	if world != null:
		world.add_child(node)


func _try_contact(distance: float, direction: Vector2) -> void:
	if distance >= radius + 18.0 or _contact_cooldown > 0.0:
		return
	_contact_cooldown = CONTACT_COOLDOWN
	if _hero.has_method(&"take_damage"):
		_hero.take_damage(contact_damage)
	# Il impinge putin la o parte, ca sa nu ramana lipit intr-un colt si tocat.
	_hero.global_position += direction * 14.0


func get_defense() -> float:
	return defense


func take_damage(amount: float, is_crit: bool = false) -> void:
	if health <= 0.0:
		return
	health -= amount
	_body.flash()
	queue_redraw()
	Fx.burst(global_position, Color(1, 1, 1) if is_crit else type.color, 3 if is_crit else 2, 90.0)
	if health <= 0.0:
		_die()


func apply_burn(dps: float, duration: float) -> void:
	# Arsura nu se aduna la infinit: ramane cea mai puternica sursa.
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)


func _tick_burn(delta: float) -> void:
	if _burn_time <= 0.0:
		return
	_burn_time -= delta
	if randf() < 0.25:
		Fx.burst(global_position, Color("ff8c3c"), 1, 40.0)
	take_damage(_burn_dps * delta)
	if _burn_time <= 0.0:
		_burn_dps = 0.0


func _die() -> void:
	Fx.burst(global_position, type.color, 14, 190.0)
	Fx.shake(4.0 if type.is_boss else 2.5, 0.18 if type.is_boss else 0.1)
	died.emit(self)
	queue_free()


## Bara de viata. La inamicii obisnuiti apare abia dupa prima lovitura, ca o
## camera plina de necatati sa nu fie un gard de bare; sefii o au mereu.
func _draw() -> void:
	if health <= 0.0:
		return
	var is_boss: bool = type != null and type.is_boss
	if not is_boss and health >= max_health:
		return

	var width := radius * 2.4
	var height := 5.0 if not is_boss else 7.0
	var corner := Vector2(-width * 0.5, -radius - 14.0)
	var fraction := clampf(health / max_health, 0.0, 1.0)

	draw_rect(Rect2(corner, Vector2(width, height)), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(Rect2(corner, Vector2(width * fraction, height)), Color(0.95, 0.34, 0.34))
	if is_boss:
		draw_rect(Rect2(corner, Vector2(width, height)), Color(1, 1, 1, 0.35), false, 1.5)
