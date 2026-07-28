--!strict

local InventoryModule = {}
InventoryModule.__index = InventoryModule

type InventoryModuleData = {
	magazines: number,
}

export type Inventory = typeof(setmetatable({} :: InventoryModuleData, InventoryModule))

function InventoryModule.TryTakeMagazine(self: Inventory): boolean
	if self.magazines <= 0 then
		return false
	end

	self.magazines -= 1
	return true
end

function InventoryModule.StoreMagazine(self: Inventory): ()
	self.magazines += 1
end

function InventoryModule.New(magazines: number): Inventory
	return setmetatable({
		magazines = math.max(0, magazines),
	}, InventoryModule)
end

return InventoryModule
