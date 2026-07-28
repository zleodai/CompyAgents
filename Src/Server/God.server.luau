-- !strict

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
		humanoid.WalkSpeed = 64
	end)
end)
