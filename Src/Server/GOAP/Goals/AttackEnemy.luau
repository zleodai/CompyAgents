--!strict

return {
	id = "AttackEnemy",
	priority = 2,
	activation = {
		hasEnemyPos = true,
	},
	desired = {
		enemyEngaged = true,
	},
}
