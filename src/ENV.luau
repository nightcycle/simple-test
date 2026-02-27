--!strict
-- Services
-- Packages
-- Modules
-- Types
-- Constants
local PREFIX = "SIMPLETEST__"
-- Variables
-- References
-- Private Functions
-- Class
local DEFAULT_ENV = {
	IS_VERBOSE = false,
	DEBUG_CLIP_RESULTS_AT = 5,
	SEARCH_FILTER_PATH = "", --ex: "game/ServerScriptService/Path/To/Test"
	PAUSE_DURATION = 1 / 30, --if set to 0 it will not pause the thread
	MAX_RETRIES = 100_000,
}
local out = setmetatable({}, {
	__index = function(_, k): any?
		assert(typeof(k) == "string", `Attempt to access non-string key "{k}" in ENV`)
		local dV = rawget(DEFAULT_ENV, k)
		k = PREFIX .. k
		local v = _G[k]
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
		assert(rawget(DEFAULT_ENV, k) ~= nil, `Attempt to set undefined key "{k}" in ENV`)
		k = PREFIX .. k
		_G[k] = v
	end,
})

return out :: typeof(DEFAULT_ENV)
