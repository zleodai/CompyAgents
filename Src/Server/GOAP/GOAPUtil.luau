--!strict

local GOAPUtil = {}

function GOAPUtil.factsSatisfied(facts: { [string]: boolean }, desiredFacts: { [string]: boolean }): boolean
	for key, value in pairs(desiredFacts) do
		if facts[key] ~= value then
			return false
		end
	end
	return true
end

function GOAPUtil.getFactsNotSatisfied(facts: { [string]: boolean }, desiredFacts: { [string]: boolean }): string
	local log = ""
	for key, value in pairs(desiredFacts) do
		if facts[key] ~= value then
			log = log .. `{key} = {facts[key]}, `
		end
	end
	return log
end

return GOAPUtil
