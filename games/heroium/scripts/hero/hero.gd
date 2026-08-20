class_name Hero
extends CharacterBody2D

signal died
signal stats_changed(stats: HeroStats)
signal moving_changed(is_moving: bool)
signal health_changed(current: float, maximum: float)
signal xp_changed(level: int, current: float, needed: float)
signal leveled_up(level: int)
signal ability_gained(ability: Ability)
signal abilities_fused(a: Ability, b: Ability, result: Ability)
signal control_mode_changed(mode: HeroControl.Mode)

const MOVE_DEADZONE := 0.15
const SETTLE_TIME := 0.12
const RING_RADIUS := 27.0

@export var hero_class: HeroClass
@export var joystick_path: NodePath
@export var attack_joystick_path: NodePath
@export var control_mode: HeroControl.Mode = HeroControl.DEFAULT_MODE

var stats: HeroStats
var is_moving: bool = false
var can_attack: bool = false

var _settle_timer: float = 0.0
var _joystick: Node = null
var _attack_joystick: Node = null
var _manual_attack_held: bool = false
var _facing: Vector2 = Vector2.DOWN
var _attack_facing: Vector2 = Vector2.RIGHT
var _accent: Color = Color("f0b45a")

@onready var _combat: HeroCombat = $Combat
@onready var _health: HeroHealth = $Health
@onready var _xp: HeroXp = $Xp
@onready var _body: CharacterBodyView = $Body

func _ready() -> void:
	add_to_group(&"hero")

	if joystick_path != NodePath():
		_joystick = get_node_or_null(joystick_path)
	if attack_joystick_path != NodePath():
		_attack_joystick = get_node_or_null(attack_joystick_path)

	var chosen := GameState.selected_hero_class()
	if chosen != null:
		hero_class = chosen

	_setup_stats()

	_health.died.connect(func() -> void: died.emit())
	_health.health_changed.connect(
		func(current: float, maximum: float) -> void: health_changed.emit(current, maximum)
	)
	_health.setup(stats.max_health)

	_xp.changed.connect(
		func(level: int, current: float, needed: float) -> void:
			xp_changed.emit(level, current, needed)
	)
	_xp.leveled_up.connect(func(level: int) -> void: leveled_up.emit(level))

	_combat.setup(self, stats)
	_combat.ability_gained.connect(_absorb_vitality)
	_combat.ability_gained.connect(func(a: Ability) -> void: ability_gained.emit(a))
	_combat.abilities_fused.connect(
		func(a: Ability, b: Ability, result: Ability) -> void:
			_absorb_vitality(result)
			abilities_fused.emit(a, b, result)
	)

	if hero_class != null:
		_accent = hero_class.accent_color
		if hero_class.starting_ability != null:
			grant_ability(hero_class.starting_ability)

	var skin := GameState.selected_skin_resource()
	if skin != null:
		_accent = skin.color

	var look: CharacterVisual = hero_class.visual if hero_class != null else null
	if look == null:
		push_warning("HeroClass fara CharacterVisual - eroul ar ramane nevazut.")
		look = CharacterVisual.new()
		look.silhouette = CharacterArt.Silhouette.HERO
	# Copie, ca schimbarea de culoare sa nu se scrie in resursa comuna a clasei.
	look = look.duplicate()
	look.tint = _accent
	_body.apply(look, RING_RADIUS - 9.0)

func _physics_process(delta: float) -> void:
	var direction := _read_input()
	var wants_to_move := direction.length() > MOVE_DEADZONE

	if wants_to_move != is_moving:
		is_moving = wants_to_move
		_body.set_moving(is_moving)
		moving_changed.emit(is_moving)

	if is_moving:
		velocity = direction * stats.move_speed
		_settle_timer = SETTLE_TIME
		_face(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, stats.move_speed * 8.0 * delta)
		_settle_timer = maxf(0.0, _settle_timer - delta)

	move_and_slide()

	var stationary := not is_moving and is_zero_approx(_settle_timer)
	var attack_direction := _read_attack_input()

	match control_mode:
		HeroControl.Mode.AUTO:
			can_attack = true
			_combat.set_manual_aim(Vector2.ZERO)
		HeroControl.Mode.STOP_TO_FIRE:
			can_attack = stationary
			_combat.set_manual_aim(Vector2.ZERO)
		HeroControl.Mode.HOLD_TO_FIRE:
			can_attack = _manual_attack_held
			_combat.set_manual_aim(Vector2.ZERO)
		HeroControl.Mode.TAP_TO_FIRE:
			can_attack = false
			_combat.set_manual_aim(Vector2.ZERO)
		HeroControl.Mode.DUAL_STICK:
			can_attack = attack_direction.length() > MOVE_DEADZONE
			_combat.set_manual_aim(attack_direction)

	_combat.set_can_attack(can_attack)
	queue_redraw()

func _draw() -> void:
	var ring := _accent
	ring.a = 0.85 if can_attack else 0.16
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 32, ring, 2.5, true)

	if not can_attack:
		draw_line(_facing * 20.0, _facing * 27.0, Color(1, 1, 1, 0.35), 3.0, true)
		return

	var target := _combat.current_target
	if control_mode == HeroControl.Mode.DUAL_STICK:
		if _attack_facing.length() > MOVE_DEADZONE:
			draw_line(_attack_facing * (RING_RADIUS + 3.0), _attack_facing * (RING_RADIUS + 18.0), ring, 3.0, true)
		return

	if target == null or not is_instance_valid(target):
		return

	var aim := global_position.direction_to(target.global_position)
	draw_line(aim * (RING_RADIUS + 3.0), aim * (RING_RADIUS + 14.0), ring, 3.0, true)

func _read_input() -> Vector2:
	if _joystick != null and _joystick.get(&"is_pressed"):
		var output: Vector2 = _joystick.get(&"output")
		if output.length() > MOVE_DEADZONE:
			return output.limit_length(1.0)
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

func _read_attack_input() -> Vector2:
	if _attack_joystick != null and _attack_joystick.get(&"is_pressed"):
		var output: Vector2 = _attack_joystick.get(&"output")
		if output.length() > MOVE_DEADZONE:
			_attack_facing = output.normalized()
			return output.limit_length(1.0)
	return Vector2.ZERO

func _face(direction: Vector2) -> void:
	_facing = direction.normalized()

func set_control_mode(mode: HeroControl.Mode) -> void:
	if control_mode == mode:
		return
	control_mode = mode
	_manual_attack_held = false
	_combat.set_manual_aim(Vector2.ZERO)
	_combat.set_can_attack(false)
	control_mode_changed.emit(control_mode)
	queue_redraw()

func cycle_control_mode() -> void:
	var next := int(control_mode) + 1
	if next > int(HeroControl.Mode.DUAL_STICK):
		next = int(HeroControl.Mode.AUTO)
	set_control_mode(next as HeroControl.Mode)

func get_control_mode_name() -> String:
	return HeroControl.name_for(control_mode)

func get_control_description() -> String:
	return HeroControl.description_for(control_mode)

func get_enemy_difficulty_multiplier() -> float:
	return HeroControl.difficulty_multiplier(control_mode)

func set_attack_button_down(value: bool) -> void:
	_manual_attack_held = value

func tap_attack() -> void:
	if control_mode != HeroControl.Mode.TAP_TO_FIRE:
		return
	_combat.request_attack_once()

func _setup_stats() -> void:
	var base: HeroStats = null
	if hero_class != null and hero_class.stats != null:
		base = hero_class.stats
	else:
		push_warning("Hero fara HeroClass - pornesc pe statistici implicite.")
		base = HeroStats.new()

	stats = base.duplicate_for_run()

	if Engine.has_singleton(&"GameState") or GameState != null:
		GameState.apply_talents(stats)

	stats.recalculate()
	stats.changed.connect(func() -> void: stats_changed.emit(stats))
	stats_changed.emit(stats)

func set_projectile_container(node: Node) -> void:
	_combat.projectile_container = node

func grant_ability(ability: Ability) -> void:
	_combat.add_ability(ability)

func get_abilities() -> Array[Ability]:
	return _combat.abilities

func _absorb_vitality(ability: Ability) -> void:
	if ability == null:
		return
	if ability.bonus_max_health > 0.0:
		_health.increase_maximum(ability.bonus_max_health)
	if ability.heal_fraction > 0.0:
		_health.heal(_health.maximum * ability.heal_fraction)

func gain_xp(amount: float) -> void:
	_xp.add(amount)

func get_level() -> int:
	return _xp.level

func take_damage(amount: float) -> void:
	_health.take_damage(amount)

func heal(amount: float) -> void:
	_health.heal(amount)

func get_health() -> float:
	return _health.current

func get_max_health() -> float:
	return _health.maximum
