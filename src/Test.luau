--!strict
-- Services
-- Packages
-- Modules
local Parameter = require(script.Parent.Parameter)
local ENV = require(script.Parent.ENV)
local Debug = require(script.Parent.Debug)
-- Types
type Parameter = Parameter.Parameter
-- Constants
-- Variables
-- References
-- Private Functions
export type TestResult =
	{
		Type: "Error",
		Message: string,
		Parameters: { { key: string, value: Parameter.JSONValue } },
	}
	| {
		Type: "Success" | "Failure",
		Parameters: { { key: string, value: Parameter.JSONValue } },
	}
export type Test = {
	Type: "SimpleTest",
	Iterations: number,
	Parameters: { Parameter },
	Func: (...any) -> boolean,
}
function Test(v: any?): (boolean, string?)
	if
		type(v) == "table"
		and v.Type == "SimpleTest"
		and typeof(v.Iterations) == "number"
		and typeof(v.Parameters) == "table"
		and typeof(v.Func) == "function"
	then
		return true, nil
	end
	return false, "Expected a SimpleTest"
end
export type TestMap = { [string]: Test }
function TestMap(v: any?): (boolean, string?)
	if type(v) == "table" then
		local count = 0
		for k, t in v do
			count += 1
			local isTest, err = Test(t)
			if not isTest then
				return false, `Expected a table of SimpleTests, but key "{k}" is not a SimpleTest: {err}`
			end
		end
		if count == 0 then
			return false, "Expected a non-empty table of SimpleTests"
		end
		return true, nil
	end
	return false, "Expected a table of SimpleTests"
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
					return false, `Expected a tree of SimpleTests, but key "{k}" is not a SimpleTest: {err}`
				end
			end
			do
				local isTestTree, err = TestTree(t)
				if not isTestTree then
					return false, `Expected a tree of SimpleTests, but key "{k}" is not a SimpleTest or TestTree: {err}`
				end
			end
		end
		if count == 0 then
			return false, "Expected a non-empty tree of SimpleTests"
		end
		return true, nil
	end
	return false, "Expected a tree of SimpleTests"
end
function pollForPause(duration: number)
	local lastPause = tick()
	return function()
		if tick() - lastPause >= duration then
			lastPause = tick()
			if ENV.PAUSE_DURATION > 0 then
				task.wait(ENV.PAUSE_DURATION)
			end
		end
	end
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
			Type = "SimpleTest" :: "SimpleTest",
			Iterations = iterations or ENV.DEFAULT_ITERATIONS,
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
		Debug.log(`Running test with {test.Iterations} iterations and {#test.Parameters} parameters...`)
		local permutedValues: { [number]: { any } | number } = {}

		local checkPause = pollForPause(1 / 30)
		do
			local isAllPermuted = true
			local function getAvailablePerms(paramCount: number)
				local out = math.floor(test.Iterations ^ (1 / paramCount))
				Debug.log(
					`Permutations available per parameter for {paramCount} parameters for {test.Iterations} iterations: {out}`
				)
				return out
			end
			Debug.log(`Generating permutations for test with {#test.Parameters} parameters...`)
			for i, param in test.Parameters do
				checkPause()
				local permutations = Parameter.Any.permute(param, getAvailablePerms(#test.Parameters))
				permutedValues[i] = permutations
				Debug.log(
					`Generated {if typeof(permutations) == "number" then permutations else #permutations} permutations for parameter #{i} "{param.Key}" which has type "{param.Type}"`
				)
				if typeof(permutations) == "number" then
					isAllPermuted = false
				end
			end
			while not isAllPermuted do
				checkPause()
				local largestPermCount = 0
				local largestPermIndex = 0
				local paramCount = 0
				for i, perms in permutedValues do
					if typeof(perms) == "number" and perms > largestPermCount then
						largestPermCount = perms
						largestPermIndex = i
					end
					paramCount += 1
				end
				if largestPermCount == 0 or paramCount == 0 then
					break
				end
				if ENV.IS_VERBOSE then
					local param = test.Parameters[largestPermIndex]
					Debug.log(
						`Cleared permutations for parameter #{largestPermIndex} "{param.Key}" which has type "{param.Type}" because it had the most permutations at {largestPermCount}`
					)
				end
				permutedValues[largestPermIndex] = nil
				isAllPermuted = true
				local availablePerms = getAvailablePerms(paramCount)
				for i, param in permutedValues do
					local permutations = Parameter.Any.permute(test.Parameters[i], availablePerms)
					permutedValues[i] = permutations
					if typeof(permutations) == "number" then
						isAllPermuted = false
					end
				end
			end
			Debug.log(`Completed generating permutations.`)
		end
		local finalPermutedValues: { [number]: { any }? } = {}
		for i, perms in permutedValues do
			if typeof(perms) == "table" then
				finalPermutedValues[i] = perms
			end
		end
		do
			local permutationCount = 1
			local permutedParameterCount = 0
			for i, perms in finalPermutedValues do
				if perms then
					permutedParameterCount += 1
					permutationCount *= #perms
				end
			end
			assert(permutationCount < test.Iterations, `permute failed, generated {permutationCount} values`)
			Debug.log(
				`Using permutations for {permutedParameterCount} parameters, resulting in {permutationCount} total permutations which will be repeated across the {test.Iterations} iterations`
			)
		end
		Debug.log(`Generating parameter sets for {test.Iterations} iterations...`)
		for i = 1, test.Iterations do
			checkPause()
			local paramSet = table.create(#test.Parameters)
			for j, param in test.Parameters do
				local perms = finalPermutedValues[j]
				paramSet[j] = if perms then perms[j % #perms + 1] else Parameter.Any.generate(param, rng)
			end
			table.freeze(paramSet)
			parameters[i] = paramSet
		end
		table.freeze(parameters)
		Debug.log(`Completed generating parameter sets.`)
		local out: { TestResult } = table.create(test.Iterations) :: any
		Debug.log(`Running {test.Iterations} test cases`)
		for i, paramSet in parameters do
			checkPause()
			local jsonParams: { { key: string, value: Parameter.JSONValue } } = table.create(#paramSet) :: any
			for j = 1, #paramSet do
				jsonParams[j] = {
					key = `{test.Parameters[j].Key}({test.Parameters[j].Type})`,
					value = Parameter.Any.serialize(test.Parameters[j], paramSet[j]),
				}
				table.freeze(jsonParams[j])
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
		Debug.log(`Completed running test.`)
		return out
	end,
}
