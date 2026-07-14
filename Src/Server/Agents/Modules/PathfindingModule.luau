--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NoobPath = require(ReplicatedStorage.Packages.NoobPath)
local CompySharedScripts = ReplicatedStorage.CompyAgent
local DefaultNoobPathConfig = require(CompySharedScripts.Config.NoobPathConfig)

local PathfindingModule = {}
PathfindingModule.__index = PathfindingModule

type PathfindingModuleData = {
	targetPosition: Vector3?,
	lastTargetPosition: Vector3?,
	runPath: (Vector3) -> (),
	stopPath: () -> (),
	destroyPath: () -> (),
	setSpeed: (number) -> (),
}

export type PathfindingModule = typeof(setmetatable({} :: PathfindingModuleData, PathfindingModule))

function PathfindingModule.SetTarget(self: PathfindingModule, target: Vector3?): ()
	self.targetPosition = target
end

function PathfindingModule.Update(self: PathfindingModule, character: Model, moveSpeed: number): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = moveSpeed
	end
	self.setSpeed(moveSpeed)

	local targetPosition = self.targetPosition
	if not targetPosition then
		if self.lastTargetPosition then
			self.stopPath()
			self.lastTargetPosition = nil
		end
		return
	end

	if self.lastTargetPosition and (self.lastTargetPosition - targetPosition).Magnitude <= 0.05 then
		return
	end

	self.lastTargetPosition = targetPosition
	self.runPath(targetPosition)
end

function PathfindingModule.Destroy(self: PathfindingModule): ()
	self.targetPosition = nil
	self.lastTargetPosition = nil
	self.destroyPath()
end

function PathfindingModule.new(character: Model, config: typeof(DefaultNoobPathConfig)?): PathfindingModule
	local pathConfig = config or DefaultNoobPathConfig
	if not pathConfig.Enabled then
		return setmetatable({
			targetPosition = nil,
			lastTargetPosition = nil,
			runPath = function(_targetPosition: Vector3): () end,
			stopPath = function(): () end,
			destroyPath = function(): () end,
			setSpeed = function(_moveSpeed: number): () end,
		}, PathfindingModule)
	end

	local pathfinder = NoobPath.Humanoid(character, pathConfig.AgentParams, pathConfig.Precise)
	pathfinder.Timeout = pathConfig.Timeout
	pathfinder.Visualize = pathConfig.Visualize

	return setmetatable({
		targetPosition = nil,
		lastTargetPosition = nil,
		runPath = function(targetPosition: Vector3): ()
			pathfinder:Run(targetPosition)
		end,
		stopPath = function(): ()
			pathfinder:Stop()
		end,
		destroyPath = function(): ()
			pathfinder:Destroy()
		end,
		setSpeed = function(moveSpeed: number): ()
			pathfinder.Speed = moveSpeed
		end,
	}, PathfindingModule)
end

return PathfindingModule
