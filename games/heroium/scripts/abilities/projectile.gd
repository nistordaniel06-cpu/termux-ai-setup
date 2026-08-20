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
## burn_dps / explosion_radius - vechile doua efecte, ramase ca dictionar din
## motive de compatibilitate cu ce era deja testat.
var effects: Dictionary = {}
## Frost, Lightning Chain, Vampirism si oricare altul compozabil, adaugate fara
## sa se atinga linia asta de cod vreodata din nou.
var on_hit_effects: Array[AbilityEffect] = []
## Cine a tras - efectele care dau ceva inapoi (vampirism) au nevoie de el.
var attacker: Node = null

var _direction: Vector2 = Vector2.RIGHT
var _age: float = 0.0
var _already_hit: Array[Node] = []

## Viteza si raza dinaintea oricarui bonus de marime/viteza. Un proiectil
## refolosit din bazin trebuie sa porneasca mereu de aici, nu de la ce a
## ramas dupa ultima rulare - altfel bonusurile s-ar aduna intre folosiri
## in loc sa se aplice mereu peste aceleasi valori de baza.
var _base_speed: float = 0.0
var _base_radius: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	_base_speed = speed
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null and collider.shape is CircleShape2D:
		# Forma vine din scena, deci e aceeasi resursa pentru toate proiectilele -
		# fara copie, marimea data de o abilitate a unui erou ar redimensiona
		# coliziunea tuturor sagetilor din joc, chiar si ale celor fara ea.
		var shape: CircleShape2D = (collider.shape as CircleShape2D).duplicate()
		collider.shape = shape
		_base_radius = shape.radius


## Chemat de Pool cand un proiectil lasat deoparte e dat din nou - inainte ca
## `launch()` sa-i stabileasca directia si dauna. Coliziunea sta oprita pana
## atunci, ca un proiectil "mort" sa nu mai poata lovi nimic din pauza lui.
func pool_activate() -> void:
	monitoring = true
	monitorable = true


## Chemat de Pool cand proiectilul e lasat deoparte, in loc sa fie sters.
func pool_deactivate() -> void:
	monitoring = false
	monitorable = false


## Nodul e deja rotit pe directia de zbor, deci desenul e mereu orientat pe +X.
func _draw() -> void:
	draw_line(Vector2(-20.0, 0.0), Vector2.ZERO, Color(1.0, 0.85, 0.5, 0.35), 5.0, true)
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.93, 0.72))
	draw_circle(Vector2.ZERO, 2.4, Color.WHITE)


## Porneste proiectilul. Copiaza din statistici doar ce-i trebuie, ca sa nu
## depinda de erou dupa ce a plecat din arc.
func launch(
	direction: Vector2,
	stats: HeroStats,
	hit_effects: Dictionary = {},
	shooter: Node = null,
	compose_effects: Array[AbilityEffect] = []
) -> void:
	_direction = direction.normalized()
	rotation = _direction.angle()

	# Un proiectil refolosit din bazin poarta insemnele rularii lui de dinainte
	# - varsta si ce a lovit deja. Fara resetul asta, unul reintors din pauza
	# ar putea muri instant (varsta veche > lifetime) sau ar refuza sa loveasca
	# ceva ce a mai lovit cu vieti in urma.
	_age = 0.0
	_already_hit.clear()

	speed = _base_speed * stats.projectile_speed_mult
	scale = Vector2.ONE * stats.projectile_scale
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null and collider.shape is CircleShape2D:
		# Coliziunea creste odata cu desenul - altfel o sageata mare ar
		# arata puternica si ar lovi ca una obisnuita.
		(collider.shape as CircleShape2D).radius = _base_radius * stats.projectile_scale

	damage = stats.attack
	crit_chance = stats.crit_chance
	crit_multiplier = stats.crit_multiplier
	pierce_left = stats.pierce
	bounces_left = stats.bounces
	effects = hit_effects
	attacker = shooter
	on_hit_effects = compose_effects


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

	_age += delta
	if _age >= lifetime:
		Pool.release(self)


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

	if not on_hit_effects.is_empty():
		var info := HitInfo.create(node, final_damage, is_crit)
		info.attacker = attacker
		info.world = get_parent()
		for effect in on_hit_effects:
			if effect != null:
				effect.on_hit(info)
		# Efectele compozabile nu deseneaza nimic ele insele (un Resource care
		# ar referi Fx la nivel de script risca sa nu compileze daca e incarcat
		# inainte ca autoloadurile sa fie gata - o cursa reala, vazuta in acest
		# proiect). Scanteia confirma vizual ca "s-a intamplat ceva in plus".
		Fx.burst(global_position, Color("9ad9ff"), 4, 130.0)

	if pierce_left > 0:
		pierce_left -= 1
	else:
		Pool.release(self)


func _explode(radius: float, splash: float) -> void:
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node2D
		if enemy == null or enemy in _already_hit:
			continue
		if global_position.distance_to(enemy.global_position) <= radius and enemy.has_method(&"take_damage"):
			enemy.take_damage(splash, false)
