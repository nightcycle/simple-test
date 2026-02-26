--!strict
-- Services
-- Packages
-- Modules
local Test = require(script.Parent.Test)
local ENV = require(script.Parent.ENV)
-- Types
type Test = Test.Test
type TestMap = Test.TestMap
type TestResult = Test.TestResult
export type SummaryType = "FullJSON" | "Overview"
export type Summary =
	{
		Type: "FullJSON",
		Count: number,
		Passed: boolean,
		Results: { [string]: { TestResult } },
	}
	| {
		Type: "Overview",
		Count: number,
		Passed: boolean,
		Results: {
			[string]: "Fail" | "Success" | string,
		},
		DebugInfo: { [string]: { TestResult } }?,
	}
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
return {
	newFullJSON = function(results: { [string]: { TestResult } }): Summary
		local passed = true
		local count = 0
		for _, testresults in results do
			count += 1
			for _, result in testresults do
				if result.Type == "Failure" or result.Type == "Error" then
					passed = false
					break
				end
			end
			if not passed then
				break
			end
		end
		results = table.clone(results)
		table.freeze(results)
		local out: Summary = {
			Type = "FullJSON",
			Count = count,
			Passed = passed,
			Results = results,
		}
		table.freeze(out)
		return out
	end,
	newOverview = function(results: { [string]: { TestResult } }): Summary
		local overviewResults: { [string]: "Fail" | "Success" | string } = {}
		local passed = true
		local count = 0
		local debugInfo: { [string]: { TestResult } } = {}

		for path, testresults in results do
			local debugInfoForTest: { TestResult } = {}
			for _, result in testresults do
				if result.Type == "Failure" or result.Type == "Error" then
					if #debugInfoForTest < ENV.DEBUG_CLIP_RESULTS_AT then
						table.insert(debugInfoForTest, result)
					else
						break
					end
				end
			end
			table.freeze(debugInfoForTest)
			if #debugInfoForTest > 0 then
				debugInfo[path] = debugInfoForTest
			end
		end
		table.freeze(debugInfo)
		for path, testResults in results do
			count += 1
			local testPassed = true
			for _, result in testResults do
				if result.Type == "Failure" then
					overviewResults[path] = "Fail"
					testPassed = false
					break
				elseif result.Type == "Error" then
					overviewResults[path] = result.Message
					testPassed = false
					break
				end
			end
			if testPassed then
				overviewResults[path] = "Success"
			else
				passed = false
			end
		end
		table.freeze(overviewResults)
		local out: Summary = {
			Type = "Overview",
			Count = count,
			Passed = passed,
			Results = overviewResults,
			DebugInfo = if passed then nil else debugInfo,
		}
		table.freeze(out)
		return out
	end,
}
