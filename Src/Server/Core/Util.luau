local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

function HideGui()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end

local Util = {}

function Util.LockInputs()
	ContextActionService:BindAction("LockInputs", function()
		return Enum.ContextActionResult.Sink
	end, false, unpack(Enum.PlayerActions:GetEnumItems()))

	task.spawn(function()
		local success, _ = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)

		while not success do
			task.wait(1)
			success, _ = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
		end
	end)
end

function Util.UnlockInputs()
	ContextActionService:UnbindAction("LockInputs")
	StarterGui:SetCore("ResetButtonCallback", true)
end

function Util.HideDefaultGui()
	HideGui()
	local backpackDisabled = true

	task.spawn(function()
		while backpackDisabled do
			task.wait(0.1)
			backpackDisabled = not StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)

			if not backpackDisabled then
				HideGui()
				break
			end
		end
	end)
end

function GetSpacePrefix(i: number): string
	local prefix = ""

	if i <= 0 then
		return prefix
	end

	for _ = 1, i do
		prefix = prefix .. "  "
	end

	return prefix
end

function StringifyElement(x: {}, i: number): string
	if x == nil then
		return "N/A"
	end

	local index: number = i or 1
	local prefix = GetSpacePrefix(index)

	local element = ``
	for key, value in pairs(x) do
		if type(value) == "table" then
			value = Util.StringifyTable(value, index + 1)
		end
		element = element .. `\n{prefix}{key}: {value}`
	end
	return element
end

function Util.StringifyTable(x: any, i: number?): string
	if x == nil then
		return "N/A"
	end

	if type(x) ~= "table" then
		return `{x}`
	end

	local index: number = i or 1
	local prefix = GetSpacePrefix(index - 1)

	local msg = "{"
	msg = msg .. StringifyElement(x, index)
	msg = msg .. "\n" .. prefix .. "}"
	return msg
end

function Util.CframeInspector(posVector: Vector3, oriVector: Vector3): CFrame
	return CFrame.new(posVector.X, posVector.Y, posVector.Z) * CFrame.Angles(math.rad(oriVector.X), math.rad(oriVector.Y), math.rad(oriVector.Z))
end

function Util.StringifyCFrame(cFrame: CFrame): string
	local format = function(x: number): string
		return string.format("%.2f", x)
	end

	local pos = cFrame.Position
	local rX, rY, rZ = cFrame:ToOrientation()

	return `Pos: [{format(pos.X)}, {format(pos.Y)}, {format(pos.Z)}], Rot: [{format(math.deg(rX))}, {format(math.deg(rY))}, {format(math.deg(rZ))}]`
end

function Util.DebugPart(size: Vector3, cFrame: CFrame): Part
	local debugPart = Instance.new("Part")
	debugPart.Size = size
	debugPart.CFrame = cFrame
	debugPart.Color = Color3.new(0, 0, 0)
	debugPart.Material = Enum.Material.Plastic
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.CanQuery = false
	debugPart.CanTouch = false
	debugPart.Parent = workspace

	return debugPart
end

function Util.DebugTextLabel(targetPart: BasePart, text: string, studsOffset: Vector3?, size: UDim2?): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = `{targetPart.Name} Debug`
	billboard.Size = size or UDim2.fromOffset(200, 50)
	billboard.StudsOffset = studsOffset or Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = targetPart

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = `{targetPart.Name} DebugText`
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.new(0, 0, 0)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.Code
	textLabel.TextStrokeTransparency = 0.5
	textLabel.Text = text
	textLabel.Parent = billboard

	billboard.Parent = targetPart
	return textLabel
end

function Util.RemoveYValue(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

return Util
