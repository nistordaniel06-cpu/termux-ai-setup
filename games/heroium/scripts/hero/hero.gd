class_name Hero
extends CharacterBody2D

## Eroul controlat de jucator.
##
## Regula centrala a genului: te MISTI sau ATACI, niciodata amandoua. Cand ridici
## degetul de pe joystick eroul se opreste, isi cauta singur cea mai apropiata
## tinta si incepe sa traga. Miscarea e deci mereu o alegere: eviti lovituri, dar
## renunti la dauna.
##
## Nodul asta nu contine si lupta si viata - le tine in componente-copil
## (HeroCombat, HeroHealth), ca fiecare bucata sa poata fi testata separat.

signal died
signal stats_changed(stats: HeroStats)
signal moving_changed(is_moving: bool)
signal health_changed(current: float, maximum: float)
signal xp_changed(level: int, current: float, needed: float)
signal leveled_up(level: int)
signal ability_gained(ability: Ability)
signal abilities_fused(a: Ability, b: Ability, result: Ability)

## Sub aceasta valoare joystick-ul e considerat neatins.
const MOVE_DEADZONE := 0.15
## Cat trebuie sa stea nemiscat inainte sa porneasca tragerea. Fara pauza asta
## jucatorul ar putea trage la fiecare pas ciupind joystick-ul.
const SETTLE_TIME := 0.12
## Raza inelului care arata daca eroul e in stare sa traga.
const RING_RADIUS := 27.0

@export var hero_class: HeroClass
## Joystick-ul virtual din HUD. Lasat gol, eroul merge doar pe taste.
@export var joystick_path: NodePath

var stats: HeroStats
var is_moving: bool = false
## Adevarat doar cand eroul chiar sta pe loc - atunci ii merg atacurile.
var can_attack: bool = false

var _settle_timer: float = 0.0
var _joystick: Node = null
var _facing: Vector2 = Vector2.DOWN
var _accent: Color = Color("f0b45a")

@onready var _combat: HeroCombat = $Combat
@onready var _health: HeroHealth = $Health
@onready var _xp: HeroXp = $Xp
@onready var _body: Blob = $Body


func _ready() -> void:
	add_to_group(&"hero")

	if joystick_path != NodePath():
		_joystick = get_node_or_null(joystick_path)

	# Clasa aleasa in meniu bate pe cea pusa in scena. Cea din scena ramane ca
	# rezerva, ca sa poti apasa Play direct pe scena de joc si sa functioneze.
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
	# Partea de viata a unei abilitati nu e o statistica, deci n-o rezolva
	# `apply_to`. O prindem aici, si la fel pentru rezultatul unei fuziuni.
	_combat.ability_gained.connect(_absorb_vitality)
	_combat.ability_gained.connect(func(a: Ability) -> void: ability_gained.emit(a))
	_combat.abilities_fused.connect(
		func(a: Ability, b: Ability, result: Ability) -> void:
			_absorb_vitality(result)
			abilities_fused.emit(a, b, result)
	)

	if hero_class != null:
		_accent = hero_class.accent_color
		_body.fill = _accent
		if hero_class.starting_ability != null:
			grant_ability(hero_class.starting_ability)


func _physics_process(delta: float) -> void:
	var direction := _read_input()
	var wants_to_move := direction.length() > MOVE_DEADZONE

	if wants_to_move != is_moving:
		is_moving = wants_to_move
		moving_changed.emit(is_moving)

	if is_moving:
		velocity = direction * stats.move_speed
		_settle_timer = SETTLE_TIME
		_face(direction)
	else:
		# oprire scurta in loc de frana brusca, ca sa nu para lipit de podea
		velocity = velocity.move_toward(Vector2.ZERO, stats.move_speed * 8.0 * delta)
		_settle_timer = maxf(0.0, _settle_timer - delta)

	move_and_slide()

	# Aici se aplica regula: atacul merge doar cand chiar stai pe loc.
	can_attack = not is_moving and is_zero_approx(_settle_timer)
	_combat.set_can_attack(can_attack)
	queue_redraw()


## Inelul si sageata de tintire. Sunt singurul mod prin care jucatorul vede
## regula genului fara sa i-o explice cineva: aprins = stai si faci dauna,
## stins = te misti si nu faci.
func _draw() -> void:
	var ring := _accent
	ring.a = 0.85 if can_attack else 0.16
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 32, ring, 2.5, true)

	if not can_attack:
		# Cand se misca, un varf mic arata incotro merge.
		draw_line(_facing * 20.0, _facing * 27.0, Color(1, 1, 1, 0.35), 3.0, true)
		return

	var target := _combat.current_target
	if target == null or not is_instance_valid(target):
		return

	var aim := global_position.direction_to(target.global_position)
	draw_line(aim * (RING_RADIUS + 3.0), aim * (RING_RADIUS + 14.0), ring, 3.0, true)


## Citeste directia din joystick sau de la tastatura, oricare e activa.
## Addonul poate alimenta chiar el actiunile de input, deci `Input.get_vector`
## acopera de obicei ambele; joystick-ul e citit direct ca sa mearga si cand
## optiunea aceea e oprita.
func _read_input() -> Vector2:
	if _joystick != null and _joystick.get(&"is_pressed"):
		var output: Vector2 = _joystick.get(&"output")
		if output.length() > MOVE_DEADZONE:
			return output.limit_length(1.0)
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func _face(direction: Vector2) -> void:
	_facing = direction.normalized()


func _setup_stats() -> void:
	var base: HeroStats = null
	if hero_class != null and hero_class.stats != null:
		base = hero_class.stats
	else:
		push_warning("Hero fara HeroClass - pornesc pe statistici implicite.")
		base = HeroStats.new()

	stats = base.duplicate_for_run()

	# Talentele permanente (Calea Legendară) se aplica peste baza clasei.
	if Engine.has_singleton(&"GameState") or GameState != null:
		GameState.apply_talents(stats)

	stats.recalculate()
	stats.changed.connect(func() -> void: stats_changed.emit(stats))
	stats_changed.emit(stats)


## Unde sa astepte proiectilele plecate - un nod care nu se misca odata cu eroul.
func set_projectile_container(node: Node) -> void:
	_combat.projectile_container = node


## Adauga o abilitate rularii curente, fuzionand-o daca e cazul.
func grant_ability(ability: Ability) -> void:
	_combat.add_ability(ability)


## Abilitatile deja luate in rularea curenta.
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
