class_name EffectStatMod
extends AbilityEffect

## Un modificator simplu de statistica: daună, viteză de atac, mărime sau viteză
## de proiectil, critice. Nu orice efect merită scriptul lui - ăsta acoperă tot
## ce e "înmulțește sau adaugă un număr", care e majoritatea cărților simple.

enum Stat {
	DAMAGE,
	ATTACK_SPEED,
	MOVE_SPEED,
	CRIT_CHANCE,
	PROJECTILE_SIZE,
	PROJECTILE_SPEED,
	MAX_HEALTH,
}

@export var stat: Stat = Stat.DAMAGE
## Pentru DAMAGE/ATTACK_SPEED/MOVE_SPEED: înmulțește (1.25 = +25%).
## Pentru CRIT_CHANCE/MAX_HEALTH: se adaugă direct.
@export var amount: float = 1.0


func apply_to_stats(stats: HeroStats) -> void:
	match stat:
		Stat.DAMAGE:
			stats.mult_attack *= amount
		Stat.ATTACK_SPEED:
			stats.mult_attack_speed *= amount
		Stat.MOVE_SPEED:
			stats.mult_move_speed *= amount
		Stat.CRIT_CHANCE:
			stats.bonus_crit_chance += amount
		Stat.PROJECTILE_SIZE:
			stats.projectile_scale *= amount
		Stat.PROJECTILE_SPEED:
			stats.projectile_speed_mult *= amount
		Stat.MAX_HEALTH:
			stats.bonus_health += amount
