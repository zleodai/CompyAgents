--[=[
	VisualizationSystem

	Read-only visual subscriber for the data-first simulation. It polls agent
	state at a fixed visual cadence and updates pre-created Roblox Instances.
]=]

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local VisualizationSystem = {}
VisualizationSystem.__index = VisualizationSystem

function VisualizationSystem:Initialize(): ()
	local existing = Workspace:FindFirstChild(self.config.Visualization.FolderName)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = self.config.Visualization.FolderName
	folder.Parent = Workspace
	self.folder = folder
end

function VisualizationSystem:_ensureAgentPart(agent: Types.Agent): BasePart
	if self.parts[agent.id] then
		return self.parts[agent.id]
	end

	local part = Instance.new("Part")
	part.Name = agent.id
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = self.config.Visualization.AgentSize
	part.Color = self.config.Teams[agent.teamId].Color
	part.CFrame = CFrame.new(agent.transform.position + self.config.Visualization.VerticalOffset)
	part.Parent = self.folder
	self.parts[agent.id] = part

	if self.config.Debug.ShowAgentLabels then
		local gui = Instance.new("BillboardGui")
		gui.Name = "DebugLabel"
		gui.Size = UDim2.fromOffset(130, 36)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		gui.AlwaysOnTop = true
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.Code
		label.TextSize = 15
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		self.labels[agent.id] = label
	end

	return part
end

function VisualizationSystem:Step(dt: number): ()
	self.accumulator = self.accumulator + dt
	if self.accumulator < self.config.Cadence.VisualizationInterval then
		return
	end
	self.accumulator = 0

	for _, agent in ipairs(self.agentStore:GetAll()) do
		local part = self:_ensureAgentPart(agent)
		local targetCFrame = CFrame.new(agent.transform.position + self.config.Visualization.VerticalOffset)
		part.CFrame = part.CFrame:Lerp(targetCFrame, self.config.Visualization.LerpAlpha)
		part.Transparency = agent.stats.alive and 0 or 0.65

		local label = self.labels[agent.id]
		if label then
			local goal = agent.decision.currentGoal or "none"
			local actionName = "none"
			local plan = agent.decision.currentPlan
			if plan then
				local action = plan[agent.decision.currentActionIndex]
				if action then
					actionName = action.id
				end
			end

			label.Text = ("%s\n%s/%s\nHP:%d"):format(agent.id, goal, actionName, agent.stats.health)
		end
	end
end

function VisualizationSystem.new(deps: Types.SystemDependencies): Types.VisualizationSystem
	local self = setmetatable({}, VisualizationSystem)

	self.config = deps.config
	self.agentStore = deps.agentStore
	self.parts = {}
	self.labels = {}
	self.accumulator = 0
	self.folder = nil

	return self
end

return VisualizationSystem
