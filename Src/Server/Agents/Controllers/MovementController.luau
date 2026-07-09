local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local MovementController = {}
MovementController.__index = MovementController

local function positionsClose(a: Vector3, b: Vector3, tolerance: number): boolean
	return (a - b).Magnitude <= tolerance
end

local function getFlatUnit(vector: Vector3): Vector3?
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.001 then
		return nil
	end
	return flat.Unit
end

local function rotateTowards(currentDirection: Vector3, desiredDirection: Vector3, maxRadians: number): Vector3
	if desiredDirection.Magnitude <= 0.001 then
		return currentDirection
	end

	local desiredUnit = desiredDirection.Unit
	local currentUnit = currentDirection.Magnitude > 0.001 and currentDirection.Unit or desiredUnit
	local dot = math.clamp(currentUnit:Dot(desiredUnit), -1, 1)
	local angle = math.acos(dot)

	if angle <= maxRadians or angle <= 0.001 then
		return desiredUnit
	end

	local alpha = math.clamp(maxRadians / angle, 0, 1)
	local blended = currentUnit:Lerp(desiredUnit, alpha)
	if blended.Magnitude <= 0.001 then
		return desiredUnit
	end

	return blended.Unit
end

local function applyFacingToModel(state: Types.AgentState, facing: Vector3): ()
	local flatFacing = getFlatUnit(facing)
	if not flatFacing then
		return
	end

	local rootPart = state.rootPart
	if rootPart then
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flatFacing)
		return
	end

	local model = state.model
	if model then
		local pivot = model:GetPivot()
		model:PivotTo(CFrame.lookAt(pivot.Position, pivot.Position + flatFacing))
	end
end

function MovementController:_syncFromModel(): ()
	local rootPart = self.state.rootPart
	if not rootPart then
		return
	end

	local previous = self.state.position
	self.state.position = rootPart.Position - Vector3.new(0, self.config.Agent.HipHeight, 0)

	local movementFacing = getFlatUnit(self.state.position - previous)
	local rootFacing = getFlatUnit(rootPart.CFrame.LookVector)
	if movementFacing then
		self.state.facing = movementFacing
	elseif rootFacing then
		self.state.facing = rootFacing
	end
end

function MovementController:_ensureNoobPath(): ()
	if self.pathAgent or not self.config.NoobPath.Enabled or not self.state.model then
		return
	end

	local noobPathModule = require(ReplicatedStorage.Packages.NoobPath)
	local pathAgent = noobPathModule.Humanoid(self.state.model, self.config.NoobPath.AgentParams, self.config.NoobPath.Precise)
	pathAgent.Timeout = self.config.NoobPath.Timeout
	pathAgent.Speed = self.config.Agent.WalkSpeed
	pathAgent.Visualize = self.config.NoobPath.Visualize
	self.pathAgent = pathAgent

	table.insert(self.connections, pathAgent.Reached:Connect(function(): ()
		self.state.arrived = true
		self.state.moving = false
		self.state.destination = nil
		self.lastDestination = nil
		self.runtime:PushEvent({
			kind = "MoveCompleted",
		})
	end))

	table.insert(self.connections, pathAgent.Trapped:Connect(function(): ()
		self.state.moving = false
		self.lastDestination = nil
		self.runtime:PushEvent({
			kind = "MoveFailed",
			reason = "trapped",
		})
	end))

	table.insert(self.connections, pathAgent.Error:Connect(function(errorType: string): ()
		self.state.moving = false
		self.state.destination = nil
		self.lastDestination = nil
		self.runtime:PushEvent({
			kind = "MoveFailed",
			reason = tostring(errorType),
		})
	end))
end

function MovementController:SetDestination(destination: Vector3): ()
	if positionsClose(self.state.position, destination, 1) then
		self.state.destination = nil
		self.state.moving = false
		self.state.arrived = true
		return
	end

	self.state.destination = destination
	self.state.arrived = false
end

function MovementController:FaceToward(targetPosition: Vector3, dt: number): ()
	local desiredDirection = getFlatUnit(targetPosition - self.state.position)
	if not desiredDirection then
		return
	end

	local currentDirection = getFlatUnit(self.state.facing) or desiredDirection
	local maxRadians = self.config.Combat.TurnRateRadiansPerSecond * dt
	local facing = rotateTowards(currentDirection, desiredDirection, maxRadians)
	self.state.facing = facing
	applyFacingToModel(self.state, facing)
end

function MovementController:Stop(): ()
	if self.pathAgent then
		pcall(function(): ()
			self.pathAgent:Stop()
		end)
	end
	self.state.destination = nil
	self.state.moving = false
end

function MovementController:_tickManual(dt: number): ()
	local destination = self.state.destination
	if not destination then
		return
	end

	local offset = destination - self.state.position
	if offset.Magnitude <= 1 then
		self.state.position = destination
		self.state.destination = nil
		self.state.moving = false
		self.state.arrived = true
		self.runtime:PushEvent({
			kind = "MoveCompleted",
		})
		return
	end

	local step = math.min(offset.Magnitude, self.config.Agent.WalkSpeed * dt)
	self.state.position += offset.Unit * step
	self.state.facing = offset.Unit
	self.state.moving = true

	if self.state.rootPart then
		self.state.rootPart.CFrame = CFrame.lookAt(
			self.state.position + Vector3.new(0, self.config.Agent.HipHeight, 0),
			self.state.position + Vector3.new(0, self.config.Agent.HipHeight, 0) + self.state.facing
		)
	end
end

function MovementController:Tick(dt: number): ()
	self:_syncFromModel()

	local destination = self.state.destination
	if not destination then
		self.state.moving = false
		return
	end

	if self.config.NoobPath.Enabled then
		self:_ensureNoobPath()
		if self.pathAgent then
			local shouldRun = self.lastDestination == nil or not positionsClose(self.lastDestination, destination, 1)
			if shouldRun then
				self.lastDestination = destination
				self.state.moving = true
				pcall(function(): ()
					self.pathAgent:Run(destination)
				end)
			end
			self:_syncFromModel()
			return
		end
	end

	self:_tickManual(dt)
end

function MovementController:Destroy(): ()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	if self.pathAgent then
		pcall(function(): ()
			self.pathAgent:Destroy()
		end)
	end
end

function MovementController.new(runtime: Types.AgentRuntime): Types.MovementController
	local self = setmetatable({}, MovementController)
	self.runtime = runtime
	self.state = runtime.state
	self.config = runtime.config
	self.pathAgent = nil
	self.lastDestination = nil
	self.connections = {}
	return self
end

return MovementController
