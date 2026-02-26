--!strict
-- Services
-- Packages
-- Modules
local Parameter = require(script.Parameter)
local Test = require(script.Test)
local Debug = require(script.Debug)
local Summary = require(script.Summary)
-- Types
export type Test = Test.Test
export type TestMap = Test.TestMap
export type TestTree = Test.TestTree
export type TestResult = Test.TestResult
export type Parameter = Parameter.Parameter
export type Summary = Summary.Summary
export type SummaryType = Summary.SummaryType
-- Constants
local CONSTANTS = require(script.CONSTANTS)
-- Variables
-- References
-- Private Functions
function toPath(inst: Instance): string
	local path = inst:GetFullName()
	path = path:gsub("%.spec.luau", ""):gsub("%.", "/")
	return path
end

-- Class
local Module = {}

Module.CONSTANTS = CONSTANTS
Module.Parameter = Parameter
Module.Summary = Summary
Module.Test = Test
Module.Debug = Debug
Module.search = function(instances: { Instance }): TestMap
	local out: { [string]: Test } = {}
	for _, instance in instances do
		if instance:IsA("ModuleScript") and instance.Name:match("%.spec.luau") then
			local success, module = pcall(require, instance)
			if success then
				do
					local isTest, _err = Test.Type.Test(module)
					if isTest then
						local path = toPath(instance)
						assert(out[path] == nil, `duplicate path at: "path}"`)
						out[path] = module
						continue
					end
				end
				do
					local isTestMap, _err = Test.Type.TestMap(module)
					if isTestMap then
						local path = toPath(instance)
						for k, v in module do
							local keyPath = `{path}/{k}`
							assert(out[keyPath] == nil, `duplicate path at: "{keyPath}"`)
							out[keyPath] = v
						end
						continue
					end
				end
				do
					local isTestTree, _err = Test.Type.TestTree(module)
					if isTestTree then
						local path = toPath(instance)
						local toAdd: { [string]: Test } = {}
						local function recurse(tree: Test.TestTree, currentPath: string): boolean
							for k, v in tree do
								local keyPath = `{currentPath}/{k}`
								assert(toAdd[keyPath] == nil, `duplicate path at: "{keyPath}"`)
								if Test.Type.Test(v) then
									toAdd[keyPath] = v :: Test.Test
								elseif Test.Type.TestTree(v) then
									recurse(v :: Test.TestTree, keyPath)
								else
									return false
								end
							end
							return true
						end
						recurse(module, path)
						for k, v in toAdd do
							assert(out[k] == nil, `duplicate path at: "{k}"`)
							out[k] = v
						end
						continue
					end
				end
			end
		end
	end
	table.freeze(out)
	return out
end

Module.run = function(tests: TestMap, summaryType: SummaryType): Summary
	Debug.log(`Running tests...`)
	local results: { [string]: { TestResult } } = {}
	for path, test in tests do
		Debug.log(`Running test: "{path}"`)
		results[path] = Test.run(test)
	end
	Debug.log("Completed running tests")
	if summaryType == "FullJSON" then
		return Summary.newFullJSON(results)
	elseif summaryType == "Overview" then
		return Summary.newOverview(results)
	else
		error(`Invalid summary type: "{summaryType}"`)
	end
end

return Module
