--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CompySharedScripts = ReplicatedStorage.CompyAgent

local _DefaultConfig = require(CompySharedScripts.Config)

local BlackboardService = {}
BlackboardService.__index = BlackboardService

type BlackboardServiceData = {
	config: typeof(_DefaultConfig),
	teamSightings: {
		[string]: {
			[number]: {
				enemyId: number,
				position: Vector3,
				updatedAt: number,
			}
		},
	},
	running: boolean,
	thread: thread?,
}

export type BlackboardService = typeof(setmetatable({} :: BlackboardServiceData, BlackboardService))

function BlackboardService.PublishEnemySighting(
	self: BlackboardService,
	teamId: string,
	enemyId: number,
	position: Vector3,
	now: number
): ()
	local sightings = self.teamSightings[teamId]
	if not sightings then
		sightings = {}
		self.teamSightings[teamId] = sightings
	end

	sightings[enemyId] = {
		enemyId = enemyId,
		position = position,
		updatedAt = now,
	}
end

function BlackboardService.GetEnemySightings(self: BlackboardService, teamId: string): { Vector3 }
	local sightings = self.teamSightings[teamId]
	if not sightings then
		return {}
	end

	local enemyIds: { number } = {}
	for enemyId in pairs(sightings) do
		table.insert(enemyIds, enemyId)
	end
	table.sort(enemyIds)

	local positions: { Vector3 } = {}
	for _, enemyId in ipairs(enemyIds) do
		table.insert(positions, sightings[enemyId].position)
	end
	return positions
end

function BlackboardService.Cleanup(self: BlackboardService, now: number): ()
	for teamId, sightings in pairs(self.teamSightings) do
		for enemyId, sighting in pairs(sightings) do
			if now - sighting.updatedAt > self.config.Blackboard.SightingLifetime then
				sightings[enemyId] = nil
			end
		end
		if next(sightings) == nil then
			self.teamSightings[teamId] = nil
		end
	end
end

function BlackboardService.Start(self: BlackboardService): ()
	if self.running then
		return
	end
	self.running = true
	self.thread = task.spawn(function(): ()
		while self.running do
			task.wait(self.config.Cadence.BlackboardCleanupInterval)
			self:Cleanup(os.clock())
		end
	end)
end

function BlackboardService.Stop(self: BlackboardService): ()
	self.running = false
	self.thread = nil
	table.clear(self.teamSightings)
end

function BlackboardService.new(config: typeof(_DefaultConfig)): BlackboardService
	return setmetatable({
		config = config,
		teamSightings = {},
		running = false,
		thread = nil,
	}, BlackboardService)
end

return BlackboardService
