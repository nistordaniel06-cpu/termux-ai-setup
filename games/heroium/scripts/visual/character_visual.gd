class_name CharacterVisual
extends Resource

## Cum arata un personaj, descris ca date.
##
## Rostul resursei asteia e unul singur: cand vine arta finala, sa fie de
## completat un camp intr-un .tres, nu de modificat cod. Nimeni din joc nu
## intreaba "e desenat sau e sprite" - intreaba `CharacterBodyView`, iar acela
## alege dupa ce gaseste aici.
##
## Se incearca in ordinea asta, prima care exista castiga:
##   1. `sprite_frames` - arta animata (AnimatedSprite2D)
##   2. `texture`       - arta statica (Sprite2D)
##   3. `silhouette`    - silueta desenata in cod (CharacterArt)
##
## Silueta ramane mereu la capat ca plasa de siguranta. Un Sprite2D fara textura
## nu deseneaza nimic si nu se plange, iar jocul a stat odata complet gri exact
## din motivul asta - de aceea absenta artei duce la o forma vizibila, nu la gol.

@export_group("Artă")
## Arta animata. Are prioritate daca e pusa.
@export var sprite_frames: SpriteFrames
## Arta statica, folosita daca nu exista `sprite_frames`.
@export var texture: Texture2D

@export_group("Rezervă desenată")
@export var silhouette: CharacterArt.Silhouette = CharacterArt.Silhouette.SKELETON

@export_group("Culoare")
## Culoarea corpului si a efectelor lui (scantei, sageti, sange). Pe sprite se
## aplica peste, deci o arta alba se poate colora din .tres.
@export var tint: Color = Color("d9464f")

@export_group("Așezare")
## Cat de mare e arta fata de raza de coliziune. 1.0 = inaltimea artei egaleaza
## diametrul. Se regleaza cand vine arta, fara sa se atinga coliziunile.
@export var art_scale: float = 1.0
@export var art_offset: Vector2 = Vector2.ZERO

@export_group("Animații")
## Numele animatiilor cerute din `sprite_frames`. Daca lipsesc, nu se intampla
## nimic rau - AnimatedSprite2D ramane pe prima animatie pe care o are.
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"


## Are arta adevarata, sau se cade pe silueta desenata?
func has_art() -> bool:
	return sprite_frames != null or texture != null
