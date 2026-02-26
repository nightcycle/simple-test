--!strict
-- Services
-- Packages
-- Modules
-- Types
-- Constants
local PREFIX = "SIMPLETEST_"
-- Variables
-- References
-- Private Functions
-- Class
local DEFAULT_ENV = {
	IS_VERBOSE = false,
	DEBUG_CLIP_RESULTS_AT = 5,
}
local out = setmetatable({}, {
	__index = function(_, k): any?
		assert(typeof(k) == "string", `Attempt to access non-string key "{k}" in ENV`)
		k = PREFIX .. k
		local v = _G[k]
		local dV = rawget(DEFAULT_ENV, k)
		if dV == nil then
			error(`Attempt to access undefined key "{k}" in ENV`)
		end
		if typeof(v) == "string" then
			if typeof(dV) == "boolean" then
				if v == "true" then
					return true
				elseif v == "false" then
					return false
				else
					return dV
				end
			elseif typeof(dV) == "number" then
				local n = tonumber(v)
				if n ~= nil then
					return n
				else
					return dV
				end
			end
		end
		if v == nil then
			return dV
		else
			return v
		end
	end,
	__newindex = function(_, k, v)
		assert(typeof(k) == "string", `Attempt to access non-string key "{k}" in ENV`)
		k = PREFIX .. k
		assert(rawget(DEFAULT_ENV, k) ~= nil, `Attempt to set undefined key "{k}" in ENV`)
		_G[k] = v
	end,
})

return out :: typeof(DEFAULT_ENV)
