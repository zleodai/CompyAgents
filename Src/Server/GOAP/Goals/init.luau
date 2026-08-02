--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Goals = {}

Goals.Goals = {
	["AttackEnemy"] = require(CompyServerScripts.GOAP.Goals.AttackEnemy),
	-- ["CaptureObjective"] = require(CompyServerScripts.GOAP.Goals.CaptureObjective),
} :: { [string]: Types.Goal }

local function ValidGoal(xGoal: string): boolean
	for goal, _ in pairs(Goals.Goals) do
		if xGoal == goal then
			return true
		end
	end
	return false
end

function Goals.FromSelection(selection: { string }): { [string]: Types.Goal }
	local goals = {} :: { [string]: Types.Goal }
	for _, goal in ipairs(selection) do
		if ValidGoal(goal) then
			goals[goal] = Goals.Goals[goal]
		end
	end

	return goals
end

function Goals.All(): { [string]: Types.Goal }
	return table.clone(Goals.Goals) :: { [string]: Types.Goal }
end

return Goals
