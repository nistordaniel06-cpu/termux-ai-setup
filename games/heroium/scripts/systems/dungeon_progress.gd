class_name DungeonProgress
extends RefCounted

## Ce cameră vine după asta, in functie de regimul ales.
##
## Functii pure: primesc starea curenta ca parametri, intorc o decizie, nu
## tin nimic. Arena ramane singurul loc care detine location/room cu adevarat -
## un al doilea loc care le tine pe-ale lui ar fi putut sa se desincronizeze.
##
## Cele trei regimuri (Campanie, Supraviețuire, Boss Rush) impart aceleasi
## locatii si aceiasi inamici; tot ce difera intre ele e insirarea camerelor,
## si de-asta traieste concentrat aici, nu risipit prin Arena.

## Ce fel de camera urmeaza e decis de Arena insasi, cand cheama build_room() -
## Outcome spune doar UNDE: camera urmatoare din aceeasi locatie, prima din
## urmatoarea, sau capatul jocului.
enum Outcome { NEXT_ROOM, NEXT_LOCATION, VICTORY }


## Camera curenta e a unui sef?
static func is_boss_room(location: Location, room: int, mode: int) -> bool:
	if location == null or location.boss == null:
		return false
	if mode == GameState.Mode.BOSS_RUSH:
		# Fiecare camera e a unui sef, ca sa fie mereu o provocare, nu incalzire.
		return true
	return location.is_boss_room(room)


## Ce se intampla dupa ce camera curenta s-a golit.
static func after_clear(location: Location, location_index: int, room: int, mode: int) -> Outcome:
	if mode == GameState.Mode.BOSS_RUSH:
		# Trecem prin locatii ca sa nu fie mereu acelasi sef; treapta creste
		# oricum cu numarul de camere curatate.
		return Outcome.NEXT_LOCATION

	if room < location.rooms:
		return Outcome.NEXT_ROOM

	# Locatia s-a incheiat. In Campanie, ultima inseamna ca ai terminat jocul;
	# in Supraviețuire se reia ultima locatie, cu inamici tot mai grei.
	if mode == GameState.Mode.CAMPAIGN and is_last_location(location_index):
		return Outcome.VICTORY

	return Outcome.NEXT_LOCATION


static func is_last_location(location_index: int) -> bool:
	return location_index >= GameState.locations.size() - 1
