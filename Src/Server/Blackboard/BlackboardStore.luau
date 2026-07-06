--[=[
	BlackboardStore

	Team-local shared memory for decentralized coordination. Agents publish
	sightings, reservations, intents, and danger claims here without requiring a
	central commander.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local BlackboardStore = {}
BlackboardStore.__index = BlackboardStore

function BlackboardStore:RecordEnemySighting(contact: Types.PerceptionContact, now: number): ()
	self.enemySightings[contact.agentId] = {
		agentId = contact.agentId,
		teamId = contact.teamId,
		position = contact.position,
		confidence = contact.confidence or 1,
		lastSeenAt = now,
		expiresAt = now + 3,
	}
end

function BlackboardStore:GetBestEnemySighting(): Types.EnemySighting?
	local best = nil

	for _, sighting in pairs(self.enemySightings) do
		if not best or sighting.confidence > best.confidence or sighting.lastSeenAt > best.lastSeenAt then
			best = sighting
		end
	end

	return best
end

function BlackboardStore:Reserve(resourceId: string, ownerId: Types.AgentId, now: number, duration: number): boolean
	local existing = self.reservations[resourceId]
	if existing and existing.ownerId ~= ownerId and existing.expiresAt > now then
		return false
	end

	self.reservations[resourceId] = {
		resourceId = resourceId,
		ownerId = ownerId,
		createdAt = now,
		expiresAt = now + duration,
	}

	return true
end

function BlackboardStore:PublishIntent(
	ownerId: Types.AgentId,
	intent: Types.IntentDraft,
	now: number,
	duration: number
): ()
	local record: Types.IntentRecord = {
		ownerId = ownerId,
		role = intent.role,
		target = intent.target,
		createdAt = now,
		expiresAt = now + duration,
	}

	self.intents[ownerId] = record
end

function BlackboardStore:Cleanup(now: number): ()
	for enemyId, sighting in pairs(self.enemySightings) do
		if sighting.expiresAt <= now then
			self.enemySightings[enemyId] = nil
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

function BlackboardStore.new(teamId: Types.TeamId): Types.BlackboardStore
	local self = setmetatable({}, BlackboardStore)

	self.teamId = teamId
	self.enemySightings = {}
	self.reservations = {}
	self.intents = {}
	self.dangerZones = {}

	return self
end

return BlackboardStore
