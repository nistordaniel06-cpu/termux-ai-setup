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

## Sub aceasta valoare joystick-ul e considerat neatins.
const MOVE_DEADZONE := 0.15
## Cat trebuie sa stea nemiscat inainte sa porneasca tragerea. Fara pauza asta
## jucatorul ar putea trage la fiecare pas ciupind joystick-ul.
const SETTLE_TIME := 0.12

@export var hero_class: HeroClass
## Joystick-ul virtual din HUD. Lasat gol, eroul merge doar pe taste.
@export var joystick_path: NodePath

var stats: HeroStats
var is_moving: bool = false

var _settle_timer: float = 0.0
var _joystick: Node = null

@onready var _combat: HeroCombat = $Combat
@onready var _health: HeroHealth = $Health
@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group(&"hero")

	if joystick_path != NodePath():
		_joystick = get_node_or_null(joystick_path)

	_setup_stats()

	_health.died.connect(func() -> void: died.emit())
	_health.setup(stats.max_health)

	_combat.setup(self, stats)

	if hero_class != null:
		if hero_class.sprite != null:
			_sprite.texture = hero_class.sprite
		_sprite.modulate = hero_class.accent_color
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
	_combat.set_can_attack(not is_moving and is_zero_approx(_settle_timer))


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
	if absf(direction.x) > 0.05:
		_sprite.flip_h = direction.x < 0.0


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


## Adauga o abilitate rularii curente, fuzionand-o daca e cazul.
func grant_ability(ability: Ability) -> void:
	_combat.add_ability(ability)


func take_damage(amount: float) -> void:
	_health.take_damage(amount)


func heal(amount: float) -> void:
	_health.heal(amount)


func get_health() -> float:
	return _health.current


func get_max_health() -> float:
	return _health.maximum
