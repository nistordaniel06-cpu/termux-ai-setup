class_name Location
extends Resource

## O locatie din campanie: Padurea Blestemata, Castelul Intunecat, Desertul
## Pierdut, Taramul Umbrelor.
##
## Locatia da culoarea camerei si populatia ei. Inamicii se trec in ordine, de la
## cel mai bland la cel mai rau: camerele de la inceput folosesc doar primii din
## lista, iar spre sfarsit intra si ultimii. Asa variatia creste pe parcurs fara
## sa fie nevoie de ponderi tinute in paralel, care se pot desincroniza tacut.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Cate camere are locatia, ultima fiind a sefului.
@export var rooms: int = 8

@export_group("Culori")
@export var floor_color: Color = Color("1b1726")
@export var grid_color: Color = Color("272138")
@export var border_color: Color = Color("f0b45a")

@export_group("Populație")
## De la cel mai bland la cel mai rau.
@export var enemy_types: Array[EnemyType] = []
@export var boss: EnemyType
## Cati inamici are prima camera.
@export var base_enemy_count: int = 4
## Cu cat creste numarul lor la fiecare camera.
@export var enemies_per_room: float = 1.1
@export var max_enemy_count: int = 13


## Cati inamici sa aduca in camera data (1 = prima camera a locatiei).
func enemy_count_for(room: int) -> int:
	return mini(max_enemy_count, base_enemy_count + int(floor(float(room) * enemies_per_room)))


## Din ce fel de inamici poate alege camera data. Devreme sunt putini feluri,
## tarziu intra si cei grei.
func available_types(room: int) -> Array[EnemyType]:
	if enemy_types.is_empty():
		return []
	var allowed := clampi(1 + int(floor(float(room) * 0.5)), 1, enemy_types.size())
	return enemy_types.slice(0, allowed)


func is_boss_room(room: int) -> bool:
	return boss != null and room >= rooms
