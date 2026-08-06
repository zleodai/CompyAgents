--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local InvestigateKnownEnemy = require(CompyServerScripts.GOAP.Actions.InvestigateKnownEnemy)
local InvestigateEnemyFiring = require(CompyServerScripts.GOAP.Actions.InvestigateEnemyFiring)
local FindEnemyLocation = require(CompyServerScripts.GOAP.Actions.FindEnemyLocation)
local EngageEnemy = require(CompyServerScripts.GOAP.Actions.EngageEnemy)
local Reload = require(CompyServerScripts.GOAP.Actions.Reload)

local TakeCover = require(CompyServerScripts.GOAP.Actions.TakeCover)
local LeaveCover = require(CompyServerScripts.GOAP.Actions.LeaveCover)
local FromCoverPeek = require(CompyServerScripts.GOAP.Actions.FromCoverPeek)
local FromCoverHide = require(CompyServerScripts.GOAP.Actions.FromCoverHide)
local FromCoverEngageEnemy = require(CompyServerScripts.GOAP.Actions.FromCoverEngageEnemy)
local FromCoverReload = require(CompyServerScripts.GOAP.Actions.FromCoverReload)

local Actions = {}

function Actions.New(): { [string]: Types.Action }
	return {
		["InvestigateKnownEnemy"] = InvestigateKnownEnemy.new(),
		["InvestigateEnemyFiring"] = InvestigateEnemyFiring.new(),
		["FindEnemyLocation"] = FindEnemyLocation.new(),
		["EngageEnemy"] = EngageEnemy.new(),
		["Reload"] = Reload.new(),

		["TakeCover"] = TakeCover.new(),
		["LeaveCover"] = LeaveCover.new(),
		["FromCoverPeek"] = FromCoverPeek.new(),
		["FromCoverHide"] = FromCoverHide.new(),
		["FromCoverEngageEnemy"] = FromCoverEngageEnemy.new(),
		["FromCoverReload"] = FromCoverReload.new(),
	}
end

function Actions.ToArray(instances: { [string]: Types.Action }): { Types.Action }
	local ordered: { Types.Action } = {}
	for _, action in pairs(instances) do
		table.insert(ordered, action)
	end
	return ordered
end

return Actions
