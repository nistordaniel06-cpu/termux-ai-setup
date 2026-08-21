class_name AbilityEffect
extends Resource

## Un efect al unei abilitati.
##
## O abilitate tine un vector din astea, si de aici vine puterea sistemului: doua
## abilitati luate impreuna isi aduna efectele fara ca nimeni sa fi scris cazul
## acela anume. Inainte, fiecare efect nou era inca un camp in Ability, si
## jumatate din lista ceruta (Frost, Lightning, Vampirism, marimea si viteza
## proiectilului) pur si simplu nu se putea exprima.
##
## Un efect atinge fie statisticile, fie clipa impactului, fie amandoua. Cel care
## nu are treaba cu una dintre ele o lasa neatinsa - de aceea metodele de aici
## sunt goale, nu abstracte.

## Ce scrie pe carte despre efectul asta. Gol inseamna ca descrierea abilitatii
## spune deja destul.
@export_multiline var summary: String = ""


## Peste statisticile rularii, o singura data, cand abilitatea e luata.
func apply_to_stats(_stats: HeroStats) -> void:
	pass


## In clipa in care o sageata a lovit ceva.
func on_hit(_info: HitInfo) -> void:
	pass
