--!strict

local InventoryModule = {}
InventoryModule.__index = InventoryModule

type InventoryModuleData = {
	magazines: number,
}

export type InventoryModule = typeof(setmetatable({} :: InventoryModuleData, InventoryModule))

function InventoryModule.TryTakeMagazine(self: InventoryModule): boolean
	if self.magazines <= 0 then
		return false
	end

	self.magazines -= 1
	return true
end

function InventoryModule.StoreMagazine(self: InventoryModule): ()
	self.magazines += 1
end

function InventoryModule.new(magazines: number): InventoryModule
	return setmetatable({
		magazines = math.max(0, magazines),
	}, InventoryModule)
end

return InventoryModule
