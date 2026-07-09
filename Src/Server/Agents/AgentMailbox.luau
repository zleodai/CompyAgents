local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local AgentMailbox = {}
AgentMailbox.__index = AgentMailbox

function AgentMailbox:Push(event: Types.AgentEvent): ()
	table.insert(self.events, event)
end

function AgentMailbox:Drain(): { Types.AgentEvent }
	local events = self.events
	self.events = {}
	return events
end

function AgentMailbox.new(): Types.AgentMailbox
	local self = setmetatable({}, AgentMailbox)
	self.events = {}
	return self
end

return AgentMailbox
