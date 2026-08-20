class_name HeroSkin
extends Resource

## O infatisare a eroului: culoare si nume, cumparata cu monede.
##
## Cosmeticele nu ating nicio statistica, si asta e o alegere, nu o scapare. Din
## clipa in care o culoare ar da si putere, alegerea n-ar mai fi despre cum vrei
## sa arati, ci despre ce esti obligat sa porti.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Culoarea corpului. Inlocuieste accentul clasei, atat.
@export var color: Color = Color("f0b45a")
@export var unlocked_by_default: bool = false
@export var cost: int = 0
