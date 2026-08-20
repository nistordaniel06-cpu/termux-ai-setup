class_name HitInfo
extends RefCounted

## Ce s-a intamplat la o lovitura, strans intr-un loc.
##
## Efectele primesc obiectul asta si nu mai au nevoie de nimic altceva: nu cauta
## eroul prin arbore, nu ghicesc unde sa puna un nod nou. Cand adaugam un efect
## care are nevoie de ceva in plus, se adauga aici un camp - si nu se schimba
## semnatura fiecarui efect scris pana atunci.

## Cine a incasat.
var target: Node = null
## Cine a lovit - eroul. Efectele care dau inapoi ceva (vampirism) au nevoie de el.
var attacker: Node = null
## Nodul in care se pot aseza lucruri noi (fulgere, explozii). Sta pe loc si
## traieste cat camera.
var world: Node = null
## Unde a cazut lovitura, in coordonate globale.
var position: Vector2 = Vector2.ZERO
## Cat a incasat tinta, dupa aparare si critice.
var damage: float = 0.0
var is_crit: bool = false


static func create(hit_target: Node, hit_damage: float, crit: bool) -> HitInfo:
	var info := HitInfo.new()
	info.target = hit_target
	info.damage = hit_damage
	info.is_crit = crit
	if hit_target is Node2D:
		info.position = hit_target.global_position
	return info
