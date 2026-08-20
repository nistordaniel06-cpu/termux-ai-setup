class_name CharacterBodyView
extends Node2D

## Corpul vazut al unui personaj, oricare ar fi sursa lui.
##
## Eroul si inamicul vorbesc numai cu nodul asta: `apply()`, `flash()`,
## `set_moving()`. Daca dedesubt e un AnimatedSprite2D, un Sprite2D sau o silueta
## desenata, ei nu au de unde sti si nu au de ce sa afle. Asa, ziua in care apare
## arta finala nu atinge nicio linie din logica jocului.

## Cat tine licarirea alba de la o lovitura.
const FLASH_TIME := 0.18
## Cat de tare se albeste un sprite lovit. Peste 1 chiar luminează in Godot 4.
const FLASH_BOOST := 2.4

var visual: CharacterVisual = null
var radius: float = 16.0

var _art: Node2D = null
var _animated: AnimatedSprite2D = null
var _drawn: CharacterArt = null
var _flash: float = 0.0
var _moving: bool = false


func _ready() -> void:
	set_process(false)


## Construieste corpul din descrierea data. De chemat o singura data, dupa ce
## nodul e in arbore.
func apply(description: CharacterVisual, body_radius: float) -> void:
	visual = description
	radius = body_radius

	if _art != null:
		_art.queue_free()
		_art = null
		_animated = null
		_drawn = null

	if description == null:
		push_warning("CharacterBodyView fara CharacterVisual - corpul ramane gol.")
		return

	if description.sprite_frames != null:
		_build_animated(description)
	elif description.texture != null:
		_build_static(description)
	else:
		_build_drawn(description)


func _build_animated(description: CharacterVisual) -> void:
	var node := AnimatedSprite2D.new()
	node.sprite_frames = description.sprite_frames
	node.modulate = description.tint
	_place(node, description)
	_art = node
	_animated = node
	add_child(node)
	_play(description.idle_animation)


func _build_static(description: CharacterVisual) -> void:
	var node := Sprite2D.new()
	node.texture = description.texture
	node.modulate = description.tint
	_place(node, description)
	_art = node
	add_child(node)


func _build_drawn(description: CharacterVisual) -> void:
	var node := CharacterArt.new()
	node.silhouette = description.silhouette
	node.fill = description.tint
	node.radius = radius
	node.position = description.art_offset
	_art = node
	_drawn = node
	add_child(node)


## Aseaza arta pe raza de coliziune, ca un sprite mare si unul mic sa ocupe
## acelasi loc in lume cat timp au aceeasi raza.
func _place(node: Node2D, description: CharacterVisual) -> void:
	node.position = description.art_offset
	var art_height := _art_height(description)
	if art_height > 0.0:
		var wanted := radius * 2.0 * description.art_scale
		node.scale = Vector2.ONE * (wanted / art_height)


func _art_height(description: CharacterVisual) -> float:
	if description.texture != null:
		return float(description.texture.get_height())
	if description.sprite_frames != null:
		var names := description.sprite_frames.get_animation_names()
		if not names.is_empty() and description.sprite_frames.get_frame_count(names[0]) > 0:
			var frame := description.sprite_frames.get_frame_texture(names[0], 0)
			if frame != null:
				return float(frame.get_height())
	return 0.0


# ====================== CE VEDE RESTUL JOCULUI ======================

## Licarire alba la impact - singurul semn ca lovitura a contat.
func flash() -> void:
	if _drawn != null:
		_drawn.flash()
		return
	if _art == null:
		return
	_flash = FLASH_TIME
	set_process(true)
	_apply_flash()


## Trece intre animatia de mers si cea de stat. Pe arta desenata nu schimba
## nimic - silueta se leagana oricum singura.
func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	if _animated == null or visual == null:
		return
	_play(visual.walk_animation if moving else visual.idle_animation)


func set_tint(color: Color) -> void:
	if visual != null:
		visual.tint = color
	if _drawn != null:
		_drawn.fill = color
	elif _art != null:
		_art.modulate = color


func _play(animation: StringName) -> void:
	if _animated == null or _animated.sprite_frames == null:
		return
	# O animatie ceruta dar inexistenta n-ar trebui sa opreasca personajul.
	if _animated.sprite_frames.has_animation(animation):
		_animated.play(animation)
	elif not _animated.is_playing():
		var names := _animated.sprite_frames.get_animation_names()
		if not names.is_empty():
			_animated.play(names[0])


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_apply_flash()
	if _flash <= 0.0:
		set_process(false)


func _apply_flash() -> void:
	if _art == null or visual == null:
		return
	var strength := _flash / FLASH_TIME
	_art.modulate = visual.tint.lerp(
		Color(FLASH_BOOST, FLASH_BOOST, FLASH_BOOST, visual.tint.a), strength)
