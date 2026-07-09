local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Enums = require(CompyServerScripts.Core.Enums)

local RifleData = {
	[Enums.Rifles.AK47] = {
		shotCooldown = 0.1,
		shotDamage = 20,
		ammoInMagazine = 30,
		reloadTime = 2.5,
		aimDownSightsTime = 0.2,
		accuracy = 0.7,
		inaccuracyDeviation = 20,
	},
	[Enums.Rifles.AK12] = {
		shotCooldown = 0.1,
		shotDamage = 20,
		ammoInMagazine = 30,
		reloadTime = 2,
		aimDownSightsTime = 0.1,
		accuracy = 0.8,
		inaccuracyDeviation = 20,
	},
}

return RifleData
