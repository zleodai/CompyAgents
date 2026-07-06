--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)

export type Props = {
	name: string,
	text: string,
	layoutOrder: number,
	onActivated: () -> (),
	tooltipText: string?,
	width: number?,
	isActive: boolean?,
	isDisabled: boolean?,
}

local function IconButton(props: Props)
	local isActive = props.isActive == true
	local isDisabled = props.isDisabled == true
	local backgroundColor = if isActive then Theme.buttonActive else Theme.buttonBackground
	local textColor = if isDisabled then Theme.textMuted else Theme.textPrimary
	local strokeColor = if isActive then Theme.accent else Theme.buttonStroke

	local function onActivated(): ()
		if not isDisabled then
			props.onActivated()
		end
	end

	return React.createElement(React.Fragment, nil, {
		[props.name] = React.createElement("TextButton", {
			Active = not isDisabled,
			AutoButtonColor = not isDisabled,
			BackgroundColor3 = backgroundColor,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			LayoutOrder = props.layoutOrder,
			Size = UDim2.fromOffset(props.width or 30, 28),
			Text = props.text,
			TextColor3 = textColor,
			TextSize = 14,
			TextTransparency = if isDisabled then 0.3 else 0,
			[React.Event.Activated] = onActivated,
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = strokeColor,
				Thickness = 1,
				Transparency = if isDisabled then 0.65 else 0.2,
			}),
		}),
	})
end

return IconButton
