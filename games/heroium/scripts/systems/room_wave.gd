class_name RoomWave
extends RefCounted

## Valul unei camere: cine apare, unde, si cati mai sunt in viata.
##
## Extras din Arena, care facea in acelasi fisier si asta, si progresia intre
## camere, si fazele sefului. RoomWave nu stie ce vine dupa o camera golita -
## doar anunta ca s-a golit. Cine decide urmatorul pas e DungeonProgress.

signal enemy_died(enemy: Enemy)
signal cleared

var alive: int = 0

var min_spawn_distance: float = 260.0
var spawn_radius: float = 420.0

var _enemy_scene: PackedScene
var _xp_orb_scene: PackedScene
var _world: Node2D
var _hero: Hero
## Da limitele camerei curente, ca sa nu apara inamici dincolo de pereti.
## O functie, nu o referinta directa la ArenaFloor - RoomWave n-are treaba cu
## cum arata podeaua, doar cu unde are voie sa puna pe cineva.
var _bounds: Callable


func setup(enemy_scene: PackedScene, xp_orb_scene: PackedScene,
		world: Node2D, hero: Hero, bounds_provider: Callable) -> void:
	_enemy_scene = enemy_scene
	_xp_orb_scene = xp_orb_scene
	_world = world
	_hero = hero
	_bounds = bounds_provider


## Aduce inamicii pentru o camera obisnuita, alesi din ce poate oferi locatia
## la nivelul ei de dificultate curent.
func spawn_normal_room(location: Location, room: int, tier: int) -> void:
	alive = 0
	for i in location.enemy_count_for(room):
		var pool := location.available_types(room)
		if not pool.is_empty():
			spawn(pool[randi() % pool.size()], tier, min_spawn_distance, spawn_radius)


## Aduce doar seful, singur in camera.
func spawn_boss_room(location: Location, tier: int) -> Enemy:
	alive = 0
	return spawn(location.boss, tier, min_spawn_distance, spawn_radius)


## Un inamic anume, la distanta de erou. Folosita si de camerele obisnuite, si
## de ajutoarele chemate de un sef in faza a doua.
func spawn(type: EnemyType, tier: int, min_distance: float, max_distance: float) -> Enemy:
	if type == null or _enemy_scene == null:
		return null

	var enemy: Enemy = Pool.acquire(_enemy_scene, _world) as Enemy
	# Datele intra inainte de intrarea in arbore, ca `_ready` sa le gaseasca gata.
	enemy.setup(type, tier)
	enemy.global_position = _pick_spawn_point(min_distance, max_distance)
	enemy.died.connect(_on_enemy_died)
	alive += 1
	return enemy


func _on_enemy_died(enemy: Enemy) -> void:
	enemy_died.emit(enemy)
	alive -= 1
	if alive <= 0:
		cleared.emit()


## Punct la distanta de erou, dar tot inauntrul camerei - altfel inamicii ar
## aparea dincolo de pereti si n-ar mai avea cum sa ajunga la el.
func _pick_spawn_point(min_distance: float, max_distance: float) -> Vector2:
	# Marginea e a spawnarii, nu a podelei: cerem camera intreaga si ne
	# retragem singuri de la pereti, ca nimeni sa nu apara lipit de zid.
	var bounds: Rect2 = (_bounds.call() as Rect2).grow(-60.0)
	var hero_pos := _hero.global_position

	for attempt in 24:
		var angle := randf() * TAU
		var distance := randf_range(min_distance, max_distance)
		var point := hero_pos + Vector2.RIGHT.rotated(angle) * distance
		if bounds.has_point(point):
			return point

	# Camera e prea stramta pentru inelul cerut: pune-l oriunde inauntru.
	return Vector2(
		randf_range(bounds.position.x, bounds.end.x),
		randf_range(bounds.position.y, bounds.end.y),
	)


## Goleste camera inainte sa fie construita cea noua. In mersul normal al
## jocului n-a mai ramas niciun inamic - camera se incheie tocmai cand moare
## ultimul. Ii stergem oricum, ca o camera "noua" sa fie mereu chiar noua:
## altfel un salt de locatie s-ar aseza peste ce era si `alive` n-ar mai
## corespunde cu ce e pe ecran. Cioburile de experienta NU se sterg aici.
##
## Proiectilele se DAU INAPOI bazinului, nu se sterg: unul deja pus deoparte
## ramane copil al lumii (doar ascuns si oprit), deci un `queue_free()` orb
## peste toti copiii l-ar distruge pe la spatele bazinului, care l-ar crede in
## continuare bun de dat - si urmatoarea cerere ar primi un nod deja mort.
func clear_leftovers() -> void:
	for node in _world.get_children():
		if node is Projectile or node is EnemyProjectile or node is Enemy or node is XpOrb:
			Pool.release(node)
		elif node is Telegraph:
			node.queue_free()
