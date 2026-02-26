--!strict
-- Services
-- Packages
-- Modules
local Parameter = require(script.Parent.Parameter)
-- Types
type Parameter = Parameter.Parameter
-- Constants
local CONSTANTS = require(script.Parent.CONSTANTS)
-- Variables
-- References
-- Private Functions
export type TestResult =
	{
		Type: "Error",
		Message: string,
		Parameters: { Parameter.JSONValue },
	}
	| {
		Type: "Success" | "Failure",
		Parameters: { Parameter.JSONValue },
	}
export type Test = {
	Type: "NightTest",
	Iterations: number,
	Parameters: { Parameter },
	Func: (...any) -> boolean,
}
function Test(v: any?): (boolean, string?)
	if
		type(v) == "table"
		and v.Type == "NightTest"
		and typeof(v.Iterations) == "number"
		and typeof(v.Parameters) == "table"
		and typeof(v.Func) == "function"
	then
		return true, nil
	end
	return false, "Expected a NightTest"
end
export type TestMap = { [string]: Test }
function TestMap(v: any?): (boolean, string?)
	if type(v) == "table" then
		local count = 0
		for k, t in v do
			count += 1
			local isTest, err = Test(t)
			if not isTest then
				return false, `Expected a table of NightTests, but key "{k}" is not a NightTest: {err}`
			end
		end
		if count == 0 then
			return false, "Expected a non-empty table of NightTests"
		end
		return true, nil
	end
	return false, "Expected a table of NightTests"
end
export type TestTree = { [string]: Test | TestTree }
function TestTree(v: any?): (boolean, string?)
	if type(v) == "table" then
		local count = 0
		for k, t in v do
			count += 1
			do
				local isTest, err = Test(t)
				if not isTest then
					return false, `Expected a tree of NightTests, but key "{k}" is not a NightTest: {err}`
				end
			end
			do
				local isTestTree, err = TestTree(t)
				if not isTestTree then
					return false, `Expected a tree of NightTests, but key "{k}" is not a NightTest or TestTree: {err}`
				end
			end
		end
		if count == 0 then
			return false, "Expected a non-empty tree of NightTests"
		end
		return true, nil
	end
	return false, "Expected a tree of NightTests"
end
-- Class
return {
	Type = {
		Test = Test,
		TestMap = TestMap,
		TestTree = TestTree,
	},
	new = function(params: { Parameter }, func: (...any) -> boolean, iterations: number?): Test
		params = table.clone(params)
		table.freeze(params)
		local out: Test = {
			Type = "NightTest" :: "NightTest",
			Iterations = iterations or CONSTANTS.DEFAULT_ITERATIONS,
			Parameters = params,
			Func = func,
		}
		table.freeze(out :: any)
		return out
	end,
	run = function(test: Test, rng: Random?): { TestResult }
		local parameters: { { any } } = table.create(test.Iterations) :: any
		rng = rng or Random.new()
		assert(rng, `bad rng`)
		for i = 1, test.Iterations do
			local paramSet = table.create(#test.Parameters)
			for j, param in test.Parameters do
				paramSet[j] = Parameter.Any.generate(param, rng)
			end
			table.freeze(paramSet)
			parameters[i] = paramSet
		end
		table.freeze(parameters)

		local out: { TestResult } = table.create(test.Iterations) :: any

		for i, paramSet in parameters do
			local jsonParams: { Parameter.JSONValue } = table.create(#paramSet) :: any
			for j, param in paramSet do
				jsonParams[j] = Parameter.Any.serialize(test.Parameters[j], param)
			end
			table.freeze(jsonParams)
			local result: TestResult?
			local success: boolean, msg: string? = pcall(function(): string?
				local out = test.Func(table.unpack(paramSet, 1, #test.Parameters))
				assert(typeof(out) == "boolean", `Test function must return a boolean, got {typeof(out)}`)
				result = if out
					then {
						Type = "Success",
						Parameters = jsonParams,
					}
					else {
						Type = "Failure",
						Parameters = jsonParams,
					}

				return nil
			end)
			if not success then
				assert(typeof(msg) == "string", `bad error message: "{msg}"`)
				result = {
					Type = "Error",
					Message = msg,
					Parameters = jsonParams,
				}
			end
			assert(result, `bad result`)
			table.freeze(result)
			out[i] = result
		end
		table.freeze(out)

		return out
	end,
}
