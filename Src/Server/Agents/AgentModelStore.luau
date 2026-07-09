local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local AgentModelFactory = require(CompyServerScripts.Agents.AgentModelFactory)
local Types = require(CompyServerScripts.Core.Types)

local AgentModelStore = {}
AgentModelStore.__index = AgentModelStore

function AgentModelStore:_getFolder(): Folder
	local folder = Workspace:FindFirstChild(self.config.Agent.ModelFolderName)
	if folder and folder:IsA("Folder") then
		return folder
	end

	local created = Instance.new("Folder")
	created.Name = self.config.Agent.ModelFolderName
	created.Parent = Workspace
	return created
end

function AgentModelStore:CreateForAgent(agentState: Types.AgentState, spawnCFrame: CFrame): Model
	local model = self.factory:Create(agentState, spawnCFrame)
	model.Parent = self:_getFolder()
	self.models[agentState.id] = model
	return model
end

function AgentModelStore:GetModel(agentId: string): Model?
	return self.models[agentId]
end

function AgentModelStore:HideModel(agentId: string): ()
	local model = self.models[agentId]
	if model then
		model.Parent = nil
	end
end

function AgentModelStore:DestroyAll(): ()
	for _, model in pairs(self.models) do
		model:Destroy()
	end
	table.clear(self.models)
end

function AgentModelStore.new(config: Types.Config): Types.AgentModelStore
	local self = setmetatable({}, AgentModelStore)
	self.config = config
	self.factory = AgentModelFactory.new(config)
	self.models = {}
	return self
end

return AgentModelStore
