--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local AgentService = require(CompyServerScripts.World.AgentService)
local Team = require(CompySharedScripts.Team)

local TEST_TEAMS: Team.Registry = {
	Blue = {
		Color = Color3.fromRGB(55, 125, 255),
		SpawnOrigin = Vector3.zero,
		SpawnSpacing = 12,
		Forward = Vector3.xAxis,
	},
	Red = {
		Color = Color3.fromRGB(235, 70, 70),
		SpawnOrigin = Vector3.zero,
		SpawnSpacing = 12,
		Forward = -Vector3.xAxis,
	},
	Green = {
		Color = Color3.fromRGB(70, 235, 125),
		SpawnOrigin = Vector3.zero,
		SpawnSpacing = 12,
		Forward = Vector3.zAxis,
	},
}

type TestContext = {
	Assert: (condition: boolean, message: string) -> (),
	AssertEqual: (actual: any, expected: any, message: string) -> (),
	AssertNear: (actual: number, expected: number, tolerance: number, message: string) -> (),
	AssertThrows: (callback: () -> (), message: string) -> (),
}

type FakeAgent = {
	id: number,
	teamId: Team.Id,
	controller: {
		GetHumanoid: (self: any) -> Humanoid,
		GetModel: (self: any) -> Model,
		GetHeadPart: (self: any) -> BasePart,
	},
}

local function createFakeAgent(id: number, position: Vector3, teamId: Team.Id?): (FakeAgent, Model, Humanoid)
	local model = Instance.new("Model")
	model.Name = `AgentServiceTest_{id}`

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root
	for _, partName in ipairs({ "Head", "Torso" }) do
		local part = Instance.new("Part")
		part.Name = partName
		part.Anchored = true
		part.Parent = model
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	model:PivotTo(CFrame.new(position))
	model.Parent = Workspace

	local controller = {}
	function controller:GetHumanoid(): Humanoid
		return humanoid
	end
	function controller:GetModel(): Model
		return model
	end
	function controller:GetHeadPart(): BasePart
		return model.Head :: BasePart
	end

	return {
		id = id,
		teamId = teamId or "Blue",
		controller = controller,
	}, model, humanoid
end

local AgentServiceTests = {}

table.insert(AgentServiceTests, {
	name = "AgentService registers identity and cached position idempotently",
	run = function(context: TestContext): ()
		local service = AgentService.new({ PositionUpdateInterval = 0.1 }, TEST_TEAMS)
		local fakeAgent, model = createFakeAgent(1, Vector3.new(4, 5, 6))
		local agent = fakeAgent :: any

		local firstId = service:Register(agent, "Blue")
		local secondId = service:Register(agent, "Blue")
		context.AssertEqual(firstId, 1, "first registration should return the immutable ID")
		context.AssertEqual(secondId, 1, "duplicate registration should be idempotent")
		context.AssertEqual(service:GetId(agent), 1, "Agent lookup should return the ID")
		context.AssertEqual(service:GetAgent(1), agent, "ID lookup should return the Agent")
		context.AssertEqual(service:GetTeamId(1), "Blue", "registration should retain the authoritative team ID")
		context.AssertEqual(service:GetLastRecordedPosition(1), Vector3.new(4, 5, 6), "registration should cache the pivot")

		service:End()
		model:Destroy()
	end,
})

table.insert(AgentServiceTests, {
	name = "AgentService rejects collisions and non-live Agents",
	run = function(context: TestContext): ()
		local service = AgentService.new(nil, TEST_TEAMS)
		local firstFake, firstModel = createFakeAgent(7, Vector3.zero)
		local secondFake, secondModel = createFakeAgent(7, Vector3.new(1, 0, 0))
		local deadFake, deadModel, deadHumanoid = createFakeAgent(8, Vector3.zero)
		deadHumanoid.Health = 0

		service:Register(firstFake :: any, "Blue")
		context.AssertThrows(function(): ()
			service:Register(secondFake :: any, "Blue")
		end, "different Agents must not share an ID")
		secondFake.id = 9
		secondModel.Parent = nil
		context.AssertEqual(service:Register(secondFake :: any, "Blue"), nil, "unparented Agents should be rejected")
		context.AssertEqual(service:Register(deadFake :: any, "Blue"), nil, "dead Agents should be rejected")
		context.AssertThrows(function(): ()
			service:Register(firstFake :: any, "Unknown")
		end, "unknown registration teams should be rejected")

		service:End()
		firstModel:Destroy()
		secondModel:Destroy()
		deadModel:Destroy()
	end,
})

table.insert(AgentServiceTests, {
	name = "AgentService refreshes positions on cadence and queries cached radius",
	run = function(context: TestContext): ()
		local service = AgentService.new({ PositionUpdateInterval = 0.1 }, TEST_TEAMS)
		local firstFake, firstModel = createFakeAgent(1, Vector3.zero)
		local secondFake, secondModel = createFakeAgent(2, Vector3.new(3, 0, 4))
		local firstAgent = firstFake :: any
		local secondAgent = secondFake :: any

		service:Register(firstAgent, "Blue")
		service:Register(secondAgent, "Blue")
		service:Start()
		secondModel:PivotTo(CFrame.new(6, 0, 8))
		service:Update(0.09)
		context.AssertEqual(service:GetLastRecordedPosition(2), Vector3.new(3, 0, 4), "position should remain cached below cadence")
		service:Update(0.02)
		context.AssertEqual(service:GetLastRecordedPosition(2), Vector3.new(6, 0, 8), "position should refresh at cadence")

		local nearby = service:GetNearbyAgents(Vector3.zero, 10, firstAgent)
		context.AssertEqual(#nearby, 1, "radius boundary should include the second Agent and exclude self")
		context.AssertEqual(nearby[1].agent, secondAgent, "nearby result should retain the Agent")
		context.AssertNear(nearby[1].distanceSquared, 100, 0.0001, "nearby query should return squared cached distance")

		service:End()
		firstModel:Destroy()
		secondModel:Destroy()
	end,
})

table.insert(AgentServiceTests, {
	name = "AgentService unregisters and ends repeatably",
	run = function(context: TestContext): ()
		local service = AgentService.new(nil, TEST_TEAMS)
		local fakeAgent, model = createFakeAgent(3, Vector3.zero)
		local agent = fakeAgent :: any

		service:Register(agent, "Blue")
		context.Assert(service:Unregister(agent), "first Unregister should remove the Agent")
		context.Assert(not service:Unregister(agent), "repeated Unregister should be safe")
		service:End()
		service:End()
		service:Start()
		context.AssertEqual(service:GetAgent(3), nil, "Start after End should begin empty")

		service:End()
		model:Destroy()
	end,
})

table.insert(AgentServiceTests, {
	name = "AgentService queries deterministic live cached enemies across multiple teams",
	run = function(context: TestContext): ()
		local service = AgentService.new({ PositionUpdateInterval = 0.1 }, TEST_TEAMS)
		local blueFake, blueModel = createFakeAgent(1, Vector3.zero, "Blue")
		local boundaryFake, boundaryModel = createFakeAgent(2, Vector3.new(3, 0, 4), "Red")
		local greenFake, greenModel = createFakeAgent(3, Vector3.new(0, 0, 4), "Green")
		local allyFake, allyModel = createFakeAgent(4, Vector3.new(1, 0, 0), "Blue")
		local outsideFake, outsideModel = createFakeAgent(5, Vector3.new(6, 0, 0), "Red")
		local staleFake, staleModel, staleHumanoid = createFakeAgent(6, Vector3.new(2, 0, 0), "Red")

		service:Register(blueFake :: any, "Blue")
		service:Register(boundaryFake :: any, "Red")
		service:Register(greenFake :: any, "Green")
		service:Register(allyFake :: any, "Blue")
		service:Register(outsideFake :: any, "Red")
		service:Register(staleFake :: any, "Red")

		boundaryModel:PivotTo(CFrame.new(50, 0, 0))
		staleHumanoid.Health = 0

		local enemies = service:GetNearbyEnemyAgents("Blue", Vector3.zero, 5, 1)
		context.AssertEqual(#enemies, 2, "different known teams inside the inclusive cached radius should be returned")
		context.AssertEqual(enemies[1].id, 3, "results should sort by cached distance before ID")
		context.AssertEqual(enemies[1].teamId, "Green", "a third team should be treated as an enemy")
		context.AssertEqual(enemies[2].id, 2, "the cached radius boundary should be inclusive")
		context.AssertEqual(enemies[2].position, Vector3.new(3, 0, 4), "query should return the cached position, not the moved pivot")
		context.AssertNear(enemies[2].distanceSquared, 25, 0.0001, "boundary distance should use the cached position")
		context.AssertEqual(service:GetAgent(6), nil, "a query should prune a non-live registration before returning")

		local enemyHeads = service:GetNearbyAgentHeads("Blue", Vector3.zero, 5, 1)
		context.AssertEqual(#enemyHeads, 2, "nearby head query should project every live enemy candidate")
		context.AssertEqual(enemyHeads[1], greenModel.Head, "head results should preserve distance and ID ordering")
		context.AssertEqual(enemyHeads[2], boundaryModel.Head, "head results should return live BaseParts instead of cached positions")

		local excluded = service:GetNearbyEnemyAgents("Blue", Vector3.zero, 5, 3)
		context.AssertEqual(#excluded, 1, "excludeAgentId should remove the specified candidate")
		context.AssertEqual(excluded[1].id, 2, "the remaining enemy should be deterministic")
		context.AssertThrows(function(): ()
			service:GetNearbyEnemyAgents("Unknown", Vector3.zero, 5, nil)
		end, "unknown querying teams should be rejected")

		service:End()
		blueModel:Destroy()
		boundaryModel:Destroy()
		greenModel:Destroy()
		allyModel:Destroy()
		outsideModel:Destroy()
		staleModel:Destroy()
	end,
})

return AgentServiceTests
