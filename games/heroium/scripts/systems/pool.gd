extends Node

## Bazin de noduri refolosite - autoload (Pool).
##
## Pe telefon, instantiate()/queue_free() la fiecare sageata si fiecare schelet
## e prima cauza de sacadare intr-un joc din genul asta: alocarea si colectarea
## de gunoi se intampla exact cand ecranul e deja plin de proiectile. Bazinul
## tine nodurile moarte in loc sa le arunce, si le da inapoi curate cand mai e
## nevoie de unul din acelasi fel.
##
## Fiecare fel de nod stie singur cum se "curata" pentru refolosire, prin
## metoda `pool_reset()` daca o are - Pool nu stie nimic despre Enemy sau
## Projectile, doar despre cum sa tina si sa scoata noduri dintr-un vector.

## Cate noduri inactive tine minte per scena, inainte sa inceapa sa le arunce
## de-a binelea. O camera plina nu are nevoie de mai mult decat atat deodata.
const MAX_IDLE_PER_SCENE := 40

var _idle: Dictionary = {}  # PackedScene -> Array[Node]


## Un nod gata de folosit: dintr-unul lasat deoparte, sau unul nou daca bazinul
## era gol. Vine deja in arborele dat, dar OPRIT (`pool_activate()` il porneste).
func acquire(scene: PackedScene, parent: Node) -> Node:
	var idle: Array = _idle.get(scene, [])
	var node: Node = null

	while not idle.is_empty() and node == null:
		var candidate: Node = idle.pop_back()
		# Poate fi fost sters intre timp de altcineva (schimbare de scena) -
		# un nod invalid din bazin nu trebuie sa opreasca jocul, doar sarit.
		if is_instance_valid(candidate):
			node = candidate

	if node == null:
		node = scene.instantiate()
		node.set_meta(&"pool_scene", scene)
		parent.add_child(node)
	else:
		if node.get_parent() != parent:
			node.reparent(parent)
		node.visible = true
		node.process_mode = Node.PROCESS_MODE_INHERIT
	node.set_meta(&"pool_idle", false)

	if node.has_method(&"pool_activate"):
		node.pool_activate()
	return node


## Nodul nu mai are treaba acum, dar ramane pregatit pentru urmatoarea cerere -
## nu se sterge. De chemat in loc de `queue_free()`.
##
## Fara-efect daca nodul e deja in bazin: un nod eliberat ramane copil al
## containerului lui (doar ascuns si oprit), deci un al doilea `release()`
## peste el - de exemplu cand o camera isi curata resturile fara sa stie care
## proiectile inca zburau si care erau deja puse deoparte - nu trebuie sa-l
## adauge a doua oara. Un nod care apare de doua ori in bazin ar putea fi dat
## la doua cereri deodata, si atunci amandoua l-ar crede numai al lor.
func release(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.get_meta(&"pool_idle", false):
		return

	var scene: PackedScene = node.get_meta(&"pool_scene", null)
	if scene == null:
		# N-a venit din bazin (ex. instantiat direct in editor) - se sterge normal.
		node.queue_free()
		return

	if node.has_method(&"pool_deactivate"):
		node.pool_deactivate()
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_meta(&"pool_idle", true)

	var idle: Array = _idle.get(scene, [])
	if idle.size() >= MAX_IDLE_PER_SCENE:
		node.queue_free()
		return
	idle.append(node)
	_idle[scene] = idle


## Ce e in asteptare, per scena. Doar pentru teste - jocul nu are nevoie sa stie.
func idle_count(scene: PackedScene) -> int:
	return (_idle.get(scene, []) as Array).size()
