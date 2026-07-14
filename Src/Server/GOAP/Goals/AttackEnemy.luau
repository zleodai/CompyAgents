--!strict

return {
	id = "AttackEnemy",
	priority = 50,
	activation = {
		hasEnemyPos = true,
	},
	desired = {
		enemyEngaged = true,
	},
}
