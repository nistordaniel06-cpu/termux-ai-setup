class_name EnemyType
extends Resource

## Ce fel de inamic e: schelet, arcas, demon navalitor, sef.
##
## Un .tres per fel. Statisticile cresc cu "treapta" (cate camere ai trecut), ca
## acelasi schelet sa fie o gustare in Padurea Blestemata si o problema in
## Taramul Umbrelor - fara sa fie nevoie de un fisier nou pentru fiecare nivel.

enum Behavior {
	CHASER,   ## vine drept spre tine si lovi in contact
	SHOOTER,  ## pastreaza distanta, tinteste, apoi trage
	CHARGER,  ## te pandeste, se incarca, apoi navaleste in linie
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var behavior: Behavior = Behavior.CHASER

@export_group("Vizual")
@export var color: Color = Color("d9464f")
@export var radius: float = 16.0

@export_group("Statistici")
@export var base_health: float = 26.0
@export var health_per_tier: float = 7.0
@export var base_speed: float = 74.0
@export var speed_per_tier: float = 3.2
@export var base_damage: float = 9.0
@export var damage_per_tier: float = 1.0
@export var defense: float = 0.0

@export_group("Rasplata")
@export var xp_reward: int = 2
@export var coin_reward: int = 1

@export_group("Sef")
## Sefii au bara proprie, nu se sperie de nimic si incheie o locatie.
@export var is_boss: bool = false


func health_at(tier: int) -> float:
	return base_health + health_per_tier * float(tier)


func speed_at(tier: int) -> float:
	return base_speed + speed_per_tier * float(tier)


func damage_at(tier: int) -> float:
	return base_damage + damage_per_tier * float(tier)
