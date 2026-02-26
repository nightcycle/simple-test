--!strict
-- Services
-- Packages
-- Modules
local ENV = require(script.Parent.ENV)
-- Types
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
local Module = {}

function Module.log(str: string)
	if ENV.IS_VERBOSE then
		print(str)
	end
end
function Module.warn(str: string)
	if ENV.IS_VERBOSE then
		warn(str)
	end
end

return Module
