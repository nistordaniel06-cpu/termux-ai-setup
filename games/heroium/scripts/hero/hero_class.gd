class_name HeroClass
extends Resource

## Definitia unei clase de erou: Ranger, Knight sau Mage.
##
## Un fisier .tres per clasa, in res://resources/heroes/. Adaugarea unui erou
## nou inseamna un resource nou, nu cod nou.

enum Archetype {
	RANGER,   ## distanta, cadenta mare, fragil
	KNIGHT,   ## corp la corp, rezistent, lovituri rare si grele
	MAGE,     ## dauna mare in zona, cea mai putina viata
}

@export var id: StringName = &"ranger"
@export var display_name: String = "Ranger"
@export_multiline var description: String = ""
@export var archetype: Archetype = Archetype.RANGER

@export_group("Vizual")
@export var portrait: Texture2D
@export var sprite: Texture2D
## Culoarea proiectilelor si a aurei, ca fiecare erou sa se citeasca dintr-o privire.
@export var accent_color: Color = Color("f0b45a")

@export_group("Joc")
@export var stats: HeroStats
## Abilitatea cu care intra in temnita (ex. Săgeată Perforantă pentru Ranger).
@export var starting_ability: Ability
## Deblocat din start sau cumparat cu monede.
@export var unlocked_by_default: bool = false
@export var unlock_cost: int = 0
