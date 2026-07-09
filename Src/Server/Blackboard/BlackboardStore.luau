local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local BlackboardStore = {}
BlackboardStore.__index = BlackboardStore

local function isBetterSighting(candidate: Types.EnemySighting, current: Types.EnemySighting?): boolean
	if not current then
		return true
	end

	if candidate.confidence ~= current.confidence then
		return candidate.confidence > current.confidence
	end

	if candidate.lastSeenAt ~= current.lastSeenAt then
		return candidate.lastSeenAt > current.lastSeenAt
	end

	return candidate.agentId < current.agentId
end

function BlackboardStore:RecordTeammatePosition(agentId: string, position: Vector3, now: number): ()
	self.teammatePositions[agentId] = {
		agentId = agentId,
		position = position,
		updatedAt = now,
	}
end

function BlackboardStore:RecordTeammateDeath(agentId: string, position: Vector3, now: number): ()
	self.teammateDeaths[agentId] = {
		agentId = agentId,
		position = position,
		updatedAt = now,
	}
end

function BlackboardStore:RecordEnemySighting(
	agentId: string,
	position: Vector3,
	confidence: number,
	confirmed: boolean,
	now: number
): ()
	local sighting = {
		agentId = agentId,
		position = position,
		confidence = confidence,
		confirmed = confirmed,
		lastSeenAt = now,
	}

	self.enemySightings[agentId] = sighting

	if confirmed then
		self.confirmedEnemyPositions[agentId] = sighting
	else
		self.assumedEnemyLocations[agentId] = sighting
	end
end

function BlackboardStore:GetBestEnemySighting(): Types.EnemySighting?
	local best = nil
	for _, sighting in pairs(self.enemySightings) do
		if isBetterSighting(sighting, best) then
			best = sighting
		end
	end
	return best
end

function BlackboardStore:Reserve(resourceId: string, ownerId: string, now: number, duration: number): boolean
	local existing = self.reservations[resourceId]
	if existing and existing.ownerId ~= ownerId and existing.expiresAt > now then
		return false
	end

	self.reservations[resourceId] = {
		resourceId = resourceId,
		ownerId = ownerId,
		expiresAt = now + duration,
	}

	return true
end

function BlackboardStore:ReleaseReservation(resourceId: string, ownerId: string): ()
	local existing = self.reservations[resourceId]
	if existing and existing.ownerId == ownerId then
		self.reservations[resourceId] = nil
	end
end

function BlackboardStore:PublishIntent(ownerId: string, intent: Types.IntentData, now: number, duration: number): ()
	self.intents[ownerId] = {
		ownerId = ownerId,
		intent = intent,
		updatedAt = now,
		expiresAt = now + duration,
	}
end

function BlackboardStore:Cleanup(now: number): ()
	for agentId, sighting in pairs(self.enemySightings) do
		if now - sighting.lastSeenAt > 10 then
			self.enemySightings[agentId] = nil
			self.confirmedEnemyPositions[agentId] = nil
			self.assumedEnemyLocations[agentId] = nil
		end
	end

	for resourceId, reservation in pairs(self.reservations) do
		if reservation.expiresAt <= now then
			self.reservations[resourceId] = nil
		end
	end

	for ownerId, intent in pairs(self.intents) do
		if intent.expiresAt <= now then
			self.intents[ownerId] = nil
		end
	end
end

function BlackboardStore.new(teamId: string): Types.BlackboardStore
	local self = setmetatable({}, BlackboardStore)
	self.teamId = teamId
	self.teammatePositions = {}
	self.teammateDeaths = {}
	self.assumedEnemyLocations = {}
	self.confirmedEnemyPositions = {}
	self.enemySightings = {}
	self.intents = {}
	self.reservations = {}
	return self
end

return BlackboardStore
