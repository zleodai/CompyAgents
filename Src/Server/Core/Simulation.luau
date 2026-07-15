--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local SPHAgentFactory = require(CompyServerScripts.Integrations.Spearhead.SPHAgentFactory)

local Agent = require(CompyServerScripts.Agents.Agent)
local AgentService = require(CompyServerScripts.World.AgentService)
local EnvironmentService = require(CompyServerScripts.World.EnvironmentService)
local BlackboardService = require(CompyServerScripts.Services.BlackboardService)
local CombatService = require(CompyServerScripts.Services.CombatService)
local MetricsService = require(CompyServerScripts.Services.MetricsService)
local VisualizationService = require(CompyServerScripts.Services.VisualizationService)
local _DefaultConfig = require(CompySharedScripts.Config)

local Simulation = {}
Simulation.__index = Simulation

type SimulationData = {
	config: typeof(_DefaultConfig),
	started: boolean,
	agents: { Agent.Agent },
	modelFolder: Folder?,
	agentService: AgentService.AgentService,
	environment: EnvironmentService.EnvironmentService,
	blackboard: BlackboardService.BlackboardService,
	combat: CombatService.CombatService,
	metrics: MetricsService.MetricsService,
	visualization: VisualizationService.VisualizationService,
	debugAverageFrameMSRemote: RemoteFunction?,
}

export type Simulation = typeof(setmetatable({} :: SimulationData, Simulation))

local function getCharacterPosition(character: Model): Vector3
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.Position
	end
	return character:GetPivot().Position
end

local function getVisionOrigin(character: Model): Vector3
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return character:GetPivot().Position
end

local function isInsideFieldOfView(
	character: Model,
	targetPosition: Vector3,
	fovX: number,
	fovY: number,
	distance: number
): boolean
	local origin = getVisionOrigin(character)
	local offset = targetPosition - origin
	if offset.Magnitude <= 0.001 or offset.Magnitude > distance then
		return false
	end

	local localDirection = character:GetPivot():VectorToObjectSpace(offset.Unit)
	if localDirection.Z >= 0 then
		return false
	end

	local horizontalAngle = math.deg(math.atan2(math.abs(localDirection.X), -localDirection.Z))
	local horizontalMagnitude = Vector2.new(localDirection.X, localDirection.Z).Magnitude
	local verticalAngle = math.deg(math.atan2(math.abs(localDirection.Y), horizontalMagnitude))
	return horizontalAngle <= fovX * 0.5 and verticalAngle <= fovY * 0.5
end

local function appendUnique(positions: { Vector3 }, position: Vector3): ()
	for _, existing in ipairs(positions) do
		if (existing - position).Magnitude <= 0.5 then
			return
		end
	end
	table.insert(positions, position)
end

function Simulation.CollectVisibleWorldPositions(
	self: Simulation,
	agentId: number,
	character: Model,
	positions: { Vector3 },
	fovX: number,
	fovY: number,
	distance: number
): { Vector3 }
	local visible: { Vector3 } = {}
	local origin = getVisionOrigin(character)
	for _, position in ipairs(positions) do
		if isInsideFieldOfView(character, position, fovX, fovY, distance) then
			local hasLineOfSight, rayEnd = self.environment:RaycastLineOfSight(origin, position, { character }, nil)
			self.visualization:RecordRaycast(agentId, origin, rayEnd)
			if hasLineOfSight then
				table.insert(visible, position)
			end
		end
	end
	return visible
end

function Simulation.CreateModelFolder(self: Simulation): Folder
	local existing = Workspace:FindFirstChild(self.config.Simulation.GeneratedModelFolderName)
	if existing and existing:IsA("Folder") then
		self.modelFolder = existing
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = self.config.Simulation.GeneratedModelFolderName
	folder.Parent = Workspace
	self.modelFolder = folder
	return folder
end

function Simulation.SpawnAgents(self: Simulation): ()
	local teamIds: { string } = {}
	for teamId in pairs(self.config.Teams) do
		table.insert(teamIds, teamId)
	end
	table.sort(teamIds)

	local nextAgentId = 1
	for _, teamId in ipairs(teamIds) do
		local factory = SPHAgentFactory.new({
			maxHealth = 80,
		})

		for index = 1, self.config.Simulation.DemoAgentsPerTeam do
			local agentTeamId = teamId
			local agentId = nextAgentId
			nextAgentId += 1
			local agentName = ("%s_%02d"):format(agentTeamId, index)
			local spawnCFrame = self.environment:GetSpawnCFrame(agentTeamId, index)

			local controller = factory:Create(agentName, spawnCFrame)

			local agent = Agent.new({
				id = agentId,
				magazines = self.config.Agent.InitialMagazines,
				fovX = self.config.Agent.FovX,
				fovY = self.config.Agent.FovY,
				visionDistance = self.config.Agent.VisionDistance,
				failedPlanCooldown = self.config.Agent.FailedPlanCooldown,
				controller = controller,
				cadence = self.config.Cadence,
			})

			self.agentService:Register(agentId, agentName, agentTeamId, agent, controller:GetModel())
			table.insert(self.agents, agent)
		end
	end
end

function Simulation.BindDebugRemote(self: Simulation): ()
	local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	local remote = if folder then folder:FindFirstChild("DebugAverageFrameMS") else nil
	if remote and remote:IsA("RemoteFunction") then
		self.debugAverageFrameMSRemote = remote
		remote.OnServerInvoke = function(): number
			return self.metrics:GetAverageFrameMS()
		end
	end
end

function Simulation.UnbindDebugRemote(self: Simulation): ()
	if self.debugAverageFrameMSRemote then
		self.debugAverageFrameMSRemote.OnServerInvoke = function(): number
			return 0
		end
		self.debugAverageFrameMSRemote = nil
	end
end

function Simulation.Start(self: Simulation): ()
	if self.started then
		return
	end
	self.started = true
	self.environment:Refresh()
	self:SpawnAgents()
	self.blackboard:Start()
	self.agentService:BindDebugRemotes()
	self.visualization:Start()
	self.metrics:Start()
	self:BindDebugRemote()

	for _, agent in ipairs(self.agents) do
		agent.startRuntime()
	end
end

function Simulation.Stop(self: Simulation): ()
	if not self.started then
		return
	end
	self.started = false

	for _, agent in ipairs(self.agents) do
		agent.endRuntime()
	end
	self:UnbindDebugRemote()
	self.visualization:Stop()
	self.metrics:Stop()
	self.blackboard:Stop()
	self.combat:Clear()
	self.agentService:DestroyAll()
	table.clear(self.agents)

	if self.modelFolder then
		self.modelFolder:Destroy()
		self.modelFolder = nil
	end
end

function Simulation.new(config: typeof(_DefaultConfig)): Simulation
	local agentService = AgentService.new()
	local environment = EnvironmentService.new(config)
	local blackboard = BlackboardService.new(config)
	local visualization = VisualizationService.new(config, agentService)
	local combat = CombatService.new(
		config,
		agentService,
		function(agentId: number, startPosition: Vector3, endPosition: Vector3): ()
			visualization:RecordTracer(agentId, startPosition, endPosition)
		end
	)
	local metrics = MetricsService.new(config, agentService)

	return setmetatable({
		config = config,
		started = false,
		agents = {},
		modelFolder = nil,
		agentService = agentService,
		environment = environment,
		blackboard = blackboard,
		combat = combat,
		metrics = metrics,
		visualization = visualization,
		debugAverageFrameMSRemote = nil,
	}, Simulation)
end

return Simulation
