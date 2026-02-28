--!strict
-- Services
local HttpService = game:GetService("HttpService")
-- Packages
-- Modules
-- Types
-- Constants
local CONSTANTS = require(script.Parent.CONSTANTS)
local ENV = require(script.Parent.ENV)
-- Variables
-- References
-- Private Functions
function fallbackSerializer(value: any?): JSONValue
	if
		typeof(value) == "table"
		or typeof(value) == "number"
		or typeof(value) == "string"
		or typeof(value) == "boolean"
		or value == nil
	then
		return value
	else
		error(`Cannot serialize value of type "{typeof(value)}" for ChooseParameter without a custom serializeCallback`)
	end
end
function solveArrayPermutations<V>(arr: { V }, filter: ((V) -> boolean)?): { { V } }
	local results = {}

	local function recurse(current: { V }, remaining: { V })
		if #remaining == 0 then
			if filter == nil or filter(current) then
				table.insert(results, table.clone(current))
			end
			return
		end
		for i = 1, #remaining do
			table.insert(current, remaining[i])
			local next = table.clone(remaining)
			table.remove(next, i)
			recurse(current, next)
			table.remove(current)
		end
	end

	recurse({}, arr)
	return results
end

function solveArrayCombinations<V>(set: { V }, k: number, filter: ((V) -> boolean)?): { { V } }
	local results = {}

	local function recurse(start: number, current: { unknown })
		if #current == k then
			if filter == nil or filter(current) then
				table.insert(results, table.clone(current))
			end
			return
		end

		local remaining = k - #current
		for i = start, #set - remaining + 1 do
			table.insert(current, set[i])
			recurse(i + 1, current)
			table.remove(current)
		end
	end

	recurse(1, {})
	return results
end
function getArrayPermutationCount(setSize: number, minLength: number, maxLength: number): number
	if minLength == math.huge or maxLength == math.huge then
		return math.huge
	end
	local function permCount(n: number, k: number): number
		if k > n then
			return 0
		end
		local result = 1
		for i = 0, k - 1 do
			result = result * (n - i)
		end
		return result
	end

	local total = 0
	for k = minLength, maxLength do
		total = total + permCount(setSize, k)
	end
	return total
end
function solveSetPermutationCount(setSize: number, minLength: number, maxLength: number): number
	if minLength == math.huge or maxLength == math.huge then
		return math.huge
	end
	local function permCount(n: number, k: number): number
		if k > n then
			return 0
		end
		local result = 1
		for i = 0, k - 1 do
			result = result * (n - i)
		end
		return result
	end

	-- With duplicates, exact count is hard to predict analytically,
	-- so we use P(n,k) as a conservative upper bound for the guard
	local total = 0
	for k = minLength, maxLength do
		total = total + permCount(setSize, k)
	end
	return total
end
function solveSetCombinations<V>(valueSet: { V }, lower: number, upper: number, filter: ((V) -> boolean)?): { { V } }
	local sorted = table.clone(valueSet)
	table.sort(sorted)

	local function permutations(arr: { V }): { { V } }
		local results = {}

		local function recurse(current: { V }, remaining: { V })
			if #remaining == 0 then
				if filter == nil or filter(current) then
					table.insert(results, table.clone(current))
				end
				return
			end
			local seen = {}
			for i = 1, #remaining do
				local val = remaining[i]
				local key = tostring(val)
				if not seen[key] then
					seen[key] = true
					table.insert(current, val)
					local next = table.clone(remaining)
					table.remove(next, i)
					recurse(current, next)
					table.remove(current)
				end
			end
		end

		recurse({}, arr)
		return results
	end

	local function combinations(k: number): { { V } }
		local results = {}

		local function recurse(start: number, current: { V })
			if #current == k then
				table.insert(results, table.clone(current))
				return
			end

			local remaining = k - #current
			for i = start, #sorted - remaining + 1 do
				-- skip duplicate values at the same depth level
				if i == start or tostring(sorted[i]) ~= tostring(sorted[i - 1]) then
					table.insert(current, sorted[i])
					recurse(i + 1, current)
					table.remove(current)
				end
			end
		end

		recurse(1, {})
		return results
	end

	local results = {}

	for k = lower, upper do
		for _, combo in combinations(k) do
			for _, perm in permutations(combo) do
				table.insert(results, perm)
			end
		end
	end

	return results
end

-- Class
local Parameter = {}

export type Parameter =
	| IntegerParameter
	| BooleanParameter
	| FloatParameter
	| LiteralParameter
	| Vector2Parameter
	| Vector3Parameter
	| ArrayParameter
	| MapParameter
	| NullableParameter
	| StringParameter
	| Color3Parameter
	| BrickColorParameter
	| CustomParameter
	| ChooseParameter
	| RaffleParameter
	| SetParameter
	| FilterParameter
	| FallbackParameter
	| ComputedParameter
	| StaticParameter

export type JSONValue = string | number | boolean | { [string]: JSONValue } | { JSONValue } | nil
type CustomParameter = {
	Key: string,
	Type: "Custom",
	Method: (Random) -> any?,
	SerializeCallback: (customValue: any?) -> JSONValue,
	Permutations: { any }?,
}
Parameter.Custom = {
	new = function<V>(
		key: string,
		method: (Random) -> V,
		serializeCallback: ((customValue: V) -> JSONValue)?,
		permutations: { V }?
	): CustomParameter
		return {
			Key = key,
			Type = "Custom",
			Method = method,
			SerializeCallback = serializeCallback or fallbackSerializer,
			Permutations = permutations,
		}
	end,
	generate = function(param: CustomParameter, rng: Random): any?
		return param.Method(rng)
	end :: (any, Random) -> any?,
	serialize = function(param: CustomParameter, value: any?): JSONValue
		return param.SerializeCallback(value)
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: CustomParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { any } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations
		if param.Permutations and #param.Permutations <= actualLimit then
			if filterFunc then
				local out = {}
				for _, v in param.Permutations do
					if filterFunc(v) then
						table.insert(out, v)
					end
				end
				if #out > maxPermutations then
					return #param.Permutations
				end
				return out
			end
			return table.clone(param.Permutations)
		end

		return if param.Permutations then #param.Permutations else math.huge
	end,
}

type IntegerParameter = {
	Key: string,
	Type: "Integer",
	Min: number?,
	Max: number?,
	Increment: number?,
}
Parameter.Integer = {
	new = function(key: string, min: number?, max: number?, increment: number?): IntegerParameter
		return {
			Key = key,
			Type = "Integer",
			Min = min,
			Max = max,
			Increment = increment,
		}
	end,
	generate = function(param: IntegerParameter, rng: Random): number
		local min = param.Min or -CONSTANTS.BIGGEST_INTEGER
		local max = param.Max or CONSTANTS.BIGGEST_INTEGER
		local value = rng:NextInteger(min, max)
		local increment = param.Increment
		if increment then
			local remainder = value % increment
			value -= remainder
		end
		return value
	end :: (any, Random) -> number,
	serialize = function(param: IntegerParameter, value: any?): JSONValue
		if typeof(value) == "number" and math.abs(value) == math.huge then
			return value > 0 and "INF" or "-INF"
		elseif typeof(value) == "number" and (value ~= value) then
			return "NaN"
		end
		return value
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: IntegerParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { number } | number
		if param.Max then
			local min = param.Min or 0
			local increment = param.Increment or 1
			local total = math.floor(((param.Max - min) / increment) + 1)
			local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations
			if total > actualLimit then
				return total
			end
			local permutations = {}
			for i = min, param.Max, increment do
				if filterFunc == nil or filterFunc(i) then
					table.insert(permutations, i)
				end
			end
			if #permutations > maxPermutations then
				return #permutations
			end
			return permutations
		end
		return math.huge
	end,
}

type FloatParameter = {
	Key: string,
	Type: "Float",
	Min: number?,
	Max: number?,
	Increment: number?,
}
Parameter.Float = {
	new = function(key: string, min: number?, max: number?, increment: number?): FloatParameter
		return {
			Key = key,
			Type = "Float",
			Min = min,
			Max = max,
			Increment = increment,
		}
	end,
	generate = function(param: FloatParameter, rng: Random): number
		local min = param.Min or -CONSTANTS.BIGGEST_FLOAT
		local max = param.Max or CONSTANTS.BIGGEST_FLOAT
		local value = rng:NextNumber(min, max)
		local increment = param.Increment
		if increment then
			local remainder = value % increment
			value -= remainder
		end
		return value
	end :: (any, Random) -> number,
	serialize = function(param: FloatParameter, value: any?): JSONValue
		if typeof(value) == "number" and math.abs(value) == math.huge then
			return value > 0 and "INF" or "-INF"
		elseif typeof(value) == "number" and (value ~= value) then
			return "NaN"
		end
		return value
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: FloatParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { number } | number
		return math.huge
	end,
}
type BooleanParameter = {
	Key: string,
	Type: "Boolean",
	ChanceTrue: number?,
}
Parameter.Boolean = {
	new = function(key: string, chanceTrue: number?): BooleanParameter
		return {
			Key = key,
			Type = "Boolean",
			ChanceTrue = chanceTrue,
		}
	end,
	generate = function(param: BooleanParameter, rng: Random): boolean
		return rng:NextNumber() < (param.ChanceTrue or 0.5)
	end :: (any, Random) -> boolean,
	permute = function(
		param: BooleanParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { boolean } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations

		local perms = { true, false }
		if #perms > actualLimit then
			return #perms
		end
		local out = {}
		for _, v in perms do
			if filterFunc == nil or filterFunc(v) then
				table.insert(out, v)
			end
		end

		if #out > maxPermutations then
			return #out
		end
		return out
	end,
}

type Vector2Parameter = {
	Key: string,
	Type: "Vector2",
	Min: Vector2?,
	Max: Vector2?,
	Increment: Vector2?,
}
Parameter.Vector2 = {
	new = function(key: string, min: Vector2?, max: Vector2?, increment: Vector2?): Vector2Parameter
		return {
			Key = key,
			Type = "Vector2",
			Min = min,
			Max = max,
			Increment = increment,
		}
	end,
	generate = function(param: Vector2Parameter, rng: Random): Vector2
		local min = param.Min or Vector2.new(-CONSTANTS.BIGGEST_VEC_FLOAT, -CONSTANTS.BIGGEST_VEC_FLOAT)
		local max = param.Max or Vector2.new(CONSTANTS.BIGGEST_VEC_FLOAT, CONSTANTS.BIGGEST_VEC_FLOAT)
		local x = rng:NextNumber(min.X, max.X)
		local y = rng:NextNumber(min.Y, max.Y)
		local value = Vector2.new(x, y)
		local increment = param.Increment
		if increment then
			local remainderX = value.X % increment.X
			local remainderY = value.Y % increment.Y
			value -= Vector2.new(remainderX, remainderY)
		end
		return value
	end :: (any, Random) -> Vector2,
	serialize = function(param: Vector2Parameter, value: any?): JSONValue
		if typeof(value) == "Vector2" then
			if value.X == value.X and value.Y == value.Y then
				if math.abs(value.X) == math.huge or math.abs(value.Y) == math.huge then
					return {
						X = math.abs(value.X) == math.huge and (value.X > 0 and "INF" or "-INF") or value.X,
						Y = math.abs(value.Y) == math.huge and (value.Y > 0 and "INF" or "-INF") or value.Y,
					} :: JSONValue
				end
				return { value.X, value.Y } :: JSONValue
			else
				return {
					if value.X == value.X then tostring(value.X) else "NaN",
					if value.Y == value.Y then tostring(value.Y) else "NaN",
				} :: JSONValue
			end
		end
		return value
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: Vector2Parameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { Vector2 } | number
		return math.huge
	end,
}

type Vector3Parameter = {
	Key: string,
	Type: "Vector3",
	Min: Vector3?,
	Max: Vector3?,
	Increment: Vector3?,
}
Parameter.Vector3 = {
	new = function(key: string, min: Vector3?, max: Vector3?, increment: Vector3?): Vector3Parameter
		return {
			Key = key,
			Type = "Vector3",
			Min = min,
			Max = max,
			Increment = increment,
		}
	end,
	generate = function(param: Vector3Parameter, rng: Random): Vector3
		local min = param.Min
			or Vector3.new(-CONSTANTS.BIGGEST_VEC_FLOAT, -CONSTANTS.BIGGEST_VEC_FLOAT, -CONSTANTS.BIGGEST_VEC_FLOAT)
		local max = param.Max
			or Vector3.new(CONSTANTS.BIGGEST_VEC_FLOAT, CONSTANTS.BIGGEST_VEC_FLOAT, CONSTANTS.BIGGEST_VEC_FLOAT)
		local x = rng:NextNumber(min.X, max.X)
		local y = rng:NextNumber(min.Y, max.Y)
		local z = rng:NextNumber(min.Z, max.Z)
		local value = Vector3.new(x, y, z)
		local increment = param.Increment
		if increment then
			local remainderX = value.X % increment.X
			local remainderY = value.Y % increment.Y
			local remainderZ = value.Z % increment.Z
			value -= Vector3.new(remainderX, remainderY, remainderZ)
		end
		return value
	end :: (any, Random) -> Vector3,
	serialize = function(param: Vector3Parameter, value: any?): JSONValue
		if typeof(value) == "Vector3" then
			if value.X == value.X and value.Y == value.Y and value.Z == value.Z then
				if
					math.abs(value.X) == math.huge
					or math.abs(value.Y) == math.huge
					or math.abs(value.Z) == math.huge
				then
					return {
						X = math.abs(value.X) == math.huge and (value.X > 0 and "INF" or "-INF") or value.X,
						Y = math.abs(value.Y) == math.huge and (value.Y > 0 and "INF" or "-INF") or value.Y,
						Z = math.abs(value.Z) == math.huge and (value.Z > 0 and "INF" or "-INF") or value.Z,
					} :: JSONValue
				end
				return { value.X, value.Y, value.Z } :: JSONValue
			else
				return {
					if value.X == value.X then tostring(value.X) else "NaN",
					if value.Y == value.Y then tostring(value.Y) else "NaN",
					if value.Z == value.Z then tostring(value.Z) else "NaN",
				} :: JSONValue
			end
		end
		return value
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: Vector2Parameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { Vector2 } | number
		return math.huge
	end,
}

type LiteralParameter = {
	Key: string,
	Type: "Literal",
	Values: { string },
}
Parameter.Literal = {
	new = function(key: string, values: { string }): LiteralParameter
		return {
			Key = key,
			Type = "Literal",
			Values = values,
		}
	end,
	generate = function(param: LiteralParameter, rng: Random): string
		local index = rng:NextInteger(1, #param.Values)
		return param.Values[index]
	end :: (any, Random) -> string,
	serialize = function(param: LiteralParameter, value: any?): JSONValue
		return value
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: LiteralParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { string } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations

		if #param.Values > actualLimit then
			return #param.Values
		end
		local out = {}
		for _, v in param.Values do
			if filterFunc == nil or filterFunc(v) then
				table.insert(out, v)
			end
		end
		if #out > maxPermutations then
			return #out
		end
		return out
	end,
}

type ChooseParameter = {
	Key: string,
	Type: "Choose",
	Values: { any },
	SerializeCallback: (customValue: any?) -> JSONValue,
}
Parameter.Choose = {
	new = function<V>(key: string, values: { V }, serializeCallback: ((customValue: V) -> JSONValue)?): ChooseParameter
		assert(#values > 0, `need more than 0 values to choose from`)
		return {
			Key = key,
			Type = "Choose",
			Values = values,
			SerializeCallback = serializeCallback or fallbackSerializer,
		}
	end,
	generate = function(param: ChooseParameter, rng: Random): any
		local index = rng:NextInteger(1, #param.Values)
		return param.Values[index]
	end :: (any, Random) -> any,
	serialize = function(param: ChooseParameter, value: any?): JSONValue
		return param.SerializeCallback(value)
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: ChooseParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { any } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations

		if #param.Values > actualLimit then
			return #param.Values
		end
		local out = {}
		for _, v in param.Values do
			if filterFunc == nil or filterFunc(v) then
				table.insert(out, v)
			end
		end
		if #out > maxPermutations then
			return #out
		end
		return out
	end,
}

type RaffleParameter = {
	Key: string,
	Type: "Raffle",
	Raffle: { { Value: any, Position: number } },
	OddSum: number,
	SerializeCallback: (customValue: any?) -> JSONValue,
}
Parameter.Raffle = {
	new = function<V>(
		key: string,
		odds: { [V]: number },
		serializeCallback: ((customValue: V) -> JSONValue)?
	): RaffleParameter
		local raffle: { any } = {}
		local index = 0
		for v, odd in pairs(odds) do
			local entry: any = {
				Value = v,
				Position = index,
			}
			table.freeze(entry)
			table.insert(raffle, entry)
			index += odd
		end
		table.freeze(raffle)

		return {
			Key = key,
			Type = "Raffle",
			Raffle = raffle,
			OddSum = index,
			SerializeCallback = serializeCallback or fallbackSerializer,
		}
	end,
	generate = function(param: RaffleParameter, rng: Random): any
		local hit = math.clamp(rng:NextNumber() * param.OddSum, 0, param.OddSum)
		for i, entry in param.Raffle do
			if hit < entry.Position or i == #param.Raffle then
				return entry.Value
			end
		end
		error(`Failed to generate value for RaffleParameter "{param.Key}". This should never happen.`)
	end :: (any, Random) -> any,
	serialize = function(param: RaffleParameter, value: any?): JSONValue
		return param.SerializeCallback(value)
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: RaffleParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { any } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations
		if #param.Raffle > actualLimit then
			return #param.Raffle
		end
		local out = {}
		for _, entry in param.Raffle do
			if filterFunc == nil or filterFunc(entry.Value) then
				table.insert(out, entry.Value)
			end
		end
		if #out > maxPermutations then
			return #out
		end
		return out
	end,
}

type ArrayParameter = {
	Key: string,
	Type: "Array",
	ValueType: Parameter,
	IsFrozen: boolean?,
	MinLength: number?,
	MaxLength: number?,
}
Parameter.Array = {
	new = function(
		key: string,
		valueType: Parameter,
		minLength: number?,
		maxLength: number?,
		isFrozen: boolean?
	): ArrayParameter
		return {
			Key = key,
			Type = "Array",
			ValueType = valueType,
			IsFrozen = isFrozen,
			MinLength = minLength,
			MaxLength = maxLength,
		}
	end,
	generate = function(param: ArrayParameter, rng: Random): { any }
		local minLength = math.max(param.MinLength or 0, 0)
		local maxLength = math.max(minLength, param.MaxLength or ENV.DEFAULT_TABLE_SIZE)
		local length = rng:NextInteger(minLength, maxLength)
		local result = {}
		if length > 0 then
			for i = 1, length do
				local value = Parameter.Any.generate(param.ValueType, rng)
				result[i] = value
			end
		end
		if param.IsFrozen then
			return table.freeze(result)
		end
		return result
	end :: (any, Random) -> { any },
	serialize = function(param: ArrayParameter, value: any?): JSONValue
		if typeof(value) == "table" then
			local result = {}
			for i, v in value do
				result[i] = Parameter.Any.serialize(param.ValueType, v)
			end
			return result
		end
		return nil
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: ArrayParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { any } | number
		local lower = math.max(param.MinLength or 0, 0)
		local upper = math.max(lower, param.MaxLength or ENV.DEFAULT_TABLE_SIZE)
		local valueSet = Parameter.Any.permute(param.ValueType, maxPermutations, filterFunc)
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations

		do
			local valueSetCount = if typeof(valueSet) == "number" then valueSet else #valueSet
			local total = getArrayPermutationCount(valueSetCount, valueSetCount, valueSetCount)
			if total > actualLimit then
				return total
			end
		end
		assert(typeof(valueSet) == "table", `bad valueSet`)
		do
			local results: { { unknown } } = {}

			for k = lower, upper do
				for _, combo in solveArrayCombinations(valueSet, k) do
					for _, perm in solveArrayPermutations(combo) do
						table.insert(results, perm)
					end
				end
			end
			if #results > maxPermutations then
				return #results
			end
			return results
		end
	end,
}

type FilterParameter = {
	Key: string,
	Type: "Filter",
	ValueType: Parameter,
	FilterFunc: (v: any?) -> boolean,
}
Parameter.Filter = {
	new = function(key: string, valueType: Parameter, filterFunc: (v: any?) -> boolean): FilterParameter
		return {
			Key = key,
			Type = "Filter",
			ValueType = valueType,
			FilterFunc = filterFunc,
		}
	end,
	generate = function(param: FilterParameter, rng: Random): any
		local value: any?
		local maxRuns = 0
		repeat
			value = Parameter.Any.generate(param.ValueType, rng)
			maxRuns += 1
			assert(
				maxRuns < ENV.MAX_RETRIES,
				`Too many attempts to generate unique value for FilterParameter "{param.Key}".`
			)
		until param.FilterFunc(value)
		return value
	end :: (any, Random) -> any,
	serialize = function(param: FilterParameter, value: any?): JSONValue
		return Parameter.Any.serialize(param.ValueType, value)
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: FilterParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { any } | number
		return Parameter.Any.permute(param.ValueType, maxPermutations, function(v): boolean
			if not param.FilterFunc(v) then
				return false
			end
			if filterFunc and not filterFunc(v) then
				return false
			end
			return true
		end)
	end,
}

type ComputedParameter = {
	Key: string,
	Type: "Computed",
	Inputs: { Parameter },
	ComputeFunc: (...any?) -> any,
	SerializeCallback: (customValue: any?) -> JSONValue,
	Permutations: { any }?,
}
Parameter.Computed = {
	new = function(
		key: string,
		inputs: { Parameter },
		computeFunc: (...any?) -> any,
		serializeCallback: ((customValue: any?) -> JSONValue)?,
		permutations: { any }?
	): ComputedParameter
		return {
			Key = key,
			Type = "Computed",
			Inputs = inputs,
			ComputeFunc = computeFunc,
			SerializeCallback = serializeCallback or fallbackSerializer,
			Permutations = permutations,
		}
	end,
	generate = function(param: ComputedParameter, rng: Random): any
		local inputValues: { any } = {}
		for i, input in param.Inputs do
			inputValues[i] = Parameter.Any.generate(input, rng)
		end
		return param.ComputeFunc(table.unpack(inputValues, 1, #param.Inputs))
	end :: (any, Random) -> any,
	serialize = function(param: ComputedParameter, value: any?): JSONValue
		return param.SerializeCallback(value)
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: ComputedParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { any } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations

		if param.Permutations and #param.Permutations < actualLimit then
			if filterFunc then
				local out = {}
				for _, v in param.Permutations do
					if filterFunc(v) then
						table.insert(out, v)
					end
				end
				if #out >= actualLimit then
					return #out
				end
				return out
			end
			return table.clone(param.Permutations)
		end
		return if param.Permutations then #param.Permutations else math.huge
	end,
}

type SetParameter = {
	Key: string,
	Type: "Set",
	ValueType: Parameter,
	MinLength: number?,
	MaxLength: number?,
	IsFrozen: boolean?,
	HashFunc: (v: any?) -> string,
}
Parameter.Set = {
	new = function(
		key: string,
		valueType: Parameter,
		minLength: number?,
		maxLength: number?,
		isFrozen: boolean?,
		hashFunc: ((v: any?) -> string)?
	): SetParameter
		return {
			Key = key,
			Type = "Set",
			ValueType = valueType,
			IsFrozen = isFrozen,
			MinLength = minLength,
			MaxLength = maxLength,
			HashFunc = hashFunc or tostring,
		}
	end,
	generate = function(param: SetParameter, rng: Random): { any }
		local minLength = math.max(param.MinLength or 0, 0)
		local maxLength = math.max(minLength, param.MaxLength or ENV.DEFAULT_TABLE_SIZE)
		local length = if minLength == maxLength then minLength else rng:NextInteger(minLength, maxLength)
		local result = {}
		local hashMap: { [string]: true? } = {}
		if length > 0 then
			for i = 1, length do
				local value: any?
				local hash: string
				local maxRuns = 0
				repeat
					value = Parameter.Any.generate(param.ValueType, rng)
					hash = param.HashFunc(value)
					maxRuns += 1
					assert(
						maxRuns < ENV.MAX_RETRIES,
						`Too many attempts to generate unique value for SetParameter "{param.Key}".`
					)
				until hashMap[hash] == nil
				hashMap[hash] = true
				result[i] = value
			end
		end
		if param.IsFrozen then
			return table.freeze(result)
		end
		return result
	end :: (any, Random) -> { any },
	serialize = function(param: SetParameter, value: any?): JSONValue
		if typeof(value) == "table" then
			local result = {}
			for i, v in value do
				result[i] = Parameter.Any.serialize(param.ValueType, v)
			end
			return result
		end
		return nil
	end :: (any, any?) -> JSONValue,
	permute = function(param: SetParameter, maxPermutations: number, filterFunc: ((any) -> boolean)?): { any } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations

		local lower = math.max(param.MinLength or 0, 0)
		local upper = math.max(lower, param.MaxLength or ENV.DEFAULT_TABLE_SIZE)
		local valueSet = Parameter.Any.permute(param.ValueType, maxPermutations, filterFunc)
		do
			local valueSetCount = if typeof(valueSet) == "number" then valueSet else #valueSet
			local total = solveSetPermutationCount(valueSetCount, valueSetCount, valueSetCount)
			if total > actualLimit then
				return total
			end
		end
		assert(typeof(valueSet) == "table", `bad valueSet`)
		do
			local results: { { unknown } } = {}
			for _, perm in solveSetCombinations(valueSet, lower, upper, filterFunc) do
				table.insert(results, perm)
			end
			if #results > maxPermutations then
				return #results
			end
			return results
		end
	end,
}

type StringParameter = {
	Key: string,
	Type: "String",
	MinLength: number?,
	MaxLength: number?,
}
Parameter.String = {
	new = function(key: string, minLength: number?, maxLength: number?): StringParameter
		return {
			Key = key,
			Type = "String",
			MinLength = minLength,
			MaxLength = maxLength,
		}
	end,
	generate = function(param: StringParameter, rng: Random): string
		local minLength = math.max(param.MinLength or 0, 0)
		local maxLength = math.max(minLength, param.MaxLength or ENV.DEFAULT_STRING_LENGTH)
		local length = rng:NextInteger(minLength, maxLength)
		if length > 0 then
			local chars = {}
			for i = 1, length do
				local charCode = rng:NextInteger(32, 126) -- Printable ASCII range
				chars[i] = string.char(charCode)
			end
			return table.concat(chars)
		else
			return ""
		end
	end :: (any, Random) -> string,
	permute = function(
		param: StringParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { string } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations

		local lower = math.max(param.MinLength or 0, 0)
		local upper = math.max(lower, param.MaxLength or ENV.DEFAULT_STRING_LENGTH)
		local valueSetCount = 126 - 32 + 1
		do
			local total = getArrayPermutationCount(valueSetCount, valueSetCount, valueSetCount)
			if total > actualLimit then
				return total
			end
		end
		local valueSet = {}
		for charCode = 32, 126 do
			local char = string.char(charCode)
			if filterFunc == nil or filterFunc(char) then
				table.insert(valueSet, char)
			end
		end
		assert(typeof(valueSet) == "table", `bad valueSet`)
		do
			local results: { string } = {}

			for k = lower, upper do
				for _, combo in solveArrayCombinations(valueSet, k) do
					for _, perm in solveArrayPermutations(combo) do
						table.insert(results, table.concat(perm))
					end
				end
			end
			if #results > maxPermutations then
				return #results
			end
			return results
		end
	end,
}
type Color3Parameter = {
	Key: string,
	Type: "Color3",
}
Parameter.Color3 = {
	new = function(key: string): Color3Parameter
		return {
			Key = key,
			Type = "Color3",
		}
	end,
	generate = function(param: Color3Parameter, rng: Random): Color3
		return Color3.fromRGB(rng:NextInteger(0, 255), rng:NextInteger(0, 255), rng:NextInteger(0, 255))
	end :: (any, Random) -> string,
	serialize = function(param: Color3Parameter, value: any?): JSONValue
		if typeof(value) == "Color3" then
			local r = value.R * 255
			local g = value.G * 255
			local b = value.B * 255
			return {
				math.round(r),
				math.round(g),
				math.round(b),
			} :: JSONValue
		end
		return value
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: Color3Parameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { Color3 } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations
		local total = 256 ^ 3
		if actualLimit < total then
			return total
		end
		local rgbValues = {}
		for r = 0, 255 do
			for g = 0, 255 do
				for b = 0, 255 do
					local color = Color3.fromRGB(r, g, b)
					if filterFunc == nil or filterFunc(color) then
						table.insert(rgbValues, color)
					end
				end
			end
		end
		if #rgbValues > maxPermutations then
			return #rgbValues
		end
		return rgbValues
	end,
}
type BrickColorParameter = {
	Key: string,
	Type: "BrickColor",
}
local BRICK_COLOR_VALUES = {
	1,
	2,
	3,
	5,
	6,
	9,
	11,
	12,
	18,
	21,
	22,
	23,
	24,
	25,
	26,
	27,
	28,
	29,
	36,
	37,
	38,
	39,
	40,
	41,
	42,
	43,
	44,
	45,
	47,
	48,
	49,
	50,
	100,
	101,
	102,
	103,
	104,
	105,
	106,
	107,
	108,
	110,
	111,
	112,
	113,
	115,
	116,
	118,
	119,
	120,
	121,
	123,
	124,
	125,
	126,
	127,
	128,
	131,
	133,
	134,
	135,
	136,
	137,
	138,
	140,
	141,
	143,
	145,
	146,
	147,
	148,
	149,
	150,
	151,
	153,
	154,
	157,
	158,
	168,
	176,
	178,
	179,
	180,
	190,
	191,
	192,
	193,
	194,
	195,
	196,
	198,
	199,
	200,
	208,
	209,
	210,
	211,
	212,
	213,
	216,
	217,
	218,
	219,
	220,
	221,
	222,
	223,
	224,
	225,
	226,
	232,
	268,
	301,
	302,
	303,
	304,
	305,
	306,
	307,
	308,
	309,
	310,
	311,
	312,
	313,
	314,
	315,
	316,
	317,
	318,
	319,
	320,
	321,
	322,
	323,
	324,
	325,
	327,
	328,
	329,
	330,
	331,
	332,
	333,
	334,
	335,
	336,
	337,
	338,
	339,
	340,
	341,
	342,
	343,
	344,
	345,
	346,
	347,
	348,
	349,
	350,
	351,
	352,
	353,
	354,
	355,
	356,
	357,
	358,
	359,
	360,
	361,
	362,
	363,
	364,
	365,
	1001,
	1002,
	1003,
	1004,
	1005,
	1006,
	1007,
	1008,
	1009,
	1010,
	1011,
	1012,
	1013,
	1014,
	1015,
	1016,
	1017,
	1018,
	1019,
	1020,
	1021,
	1022,
	1023,
	1024,
	1025,
	1026,
	1027,
	1028,
	1029,
	1030,
	1031,
	1032,
}
Parameter.BrickColor = {
	new = function(key: string): BrickColorParameter
		return {
			Key = key,
			Type = "BrickColor",
		}
	end,
	generate = function(param: BrickColorParameter, rng: Random): BrickColor
		return BrickColor.new(BRICK_COLOR_VALUES[rng:NextInteger(1, #BRICK_COLOR_VALUES)])
	end :: (any, Random) -> string,
	serialize = function(param: BrickColorParameter, value: any?): JSONValue
		if typeof(value) == "BrickColor" then
			return `BrickColor({value.Name})`
		end
		return value
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: BrickColorParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { BrickColor } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations

		if #BRICK_COLOR_VALUES > actualLimit then
			return #BRICK_COLOR_VALUES
		end
		local out = {}
		for _, v in BRICK_COLOR_VALUES do
			local color = BrickColor.new(v)
			if filterFunc == nil or filterFunc(color) then
				table.insert(out, color)
			end
		end
		if #out > maxPermutations then
			return #out
		end
		return out
	end,
}

type MapParameter = {
	Key: string,
	Type: "Map",
	ValueType: Parameter,
	KeyType: Parameter,
	MinLength: number?,
	MaxLength: number?,
}
Parameter.Map = {
	new = function(
		key: string,
		keyType: Parameter,
		valueType: Parameter,
		minLength: number?,
		maxLength: number?
	): MapParameter
		return {
			Key = key,
			Type = "Map",
			ValueType = valueType,
			KeyType = keyType,
			MinLength = minLength,
			MaxLength = maxLength,
		}
	end,
	generate = function(param: MapParameter, rng: Random): { [any]: any }
		local minLength = math.max(param.MinLength or 0, 0)
		local maxLength = math.max(minLength, param.MaxLength or ENV.DEFAULT_TABLE_SIZE)
		local length = rng:NextInteger(minLength, maxLength)
		local result = {}
		if length <= 0 then
			return result
		end
		for i = 1, length do
			local key: any?
			local attemptCount = 0
			local maximumAttempts = math.max(10_000, length ^ 2)
			repeat
				attemptCount += 1
				key = Parameter.Any.generate(param.KeyType, rng)
			until key ~= nil and result[key] == nil and attemptCount < maximumAttempts
			assert(key ~= nil, "Failed to generate unique key for MapParameter")
			assert(
				attemptCount <= maximumAttempts,
				`Exceeded maximum attempts to generate unique key for MapParameter: {attemptCount}/{maximumAttempts} for map of length {length} ({i})`
			)
			local value = Parameter.Any.generate(param.ValueType, rng)
			result[key] = value
		end
		return result
	end :: (any, Random) -> { [any]: any },
	serialize = function(param: MapParameter, value: any?): JSONValue
		if typeof(value) == "table" then
			local result = {}
			for k, v in value do
				local serializedKey = Parameter.Any.serialize(param.KeyType, k)
				local serializedValue = Parameter.Any.serialize(param.ValueType, v)
				result[serializedKey] = serializedValue
			end
			return result
		end
		return nil
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: MapParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { { [any]: any } } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations
		local lower = math.max(param.MinLength or 0, 0)
		local upper = math.max(lower, param.MaxLength or ENV.DEFAULT_TABLE_SIZE)
		local keySet = Parameter.Any.permute(param.KeyType, maxPermutations)
		local valueSet = Parameter.Any.permute(param.ValueType, maxPermutations)

		do
			local keySetCount = if typeof(keySet) == "number" then keySet else #keySet
			local valueSetCount = if typeof(valueSet) == "number" then valueSet else #valueSet
			local total = (1 + valueSetCount) ^ keySetCount
			if total > actualLimit then
				return total
			end
			if typeof(keySet) == "number" then
				return total
			end
			if typeof(valueSet) == "number" then
				return total
			end
		end
		assert(typeof(keySet) == "table", `bad keySet`)
		assert(typeof(valueSet) == "table", `bad valueSet`)
		do
			local keysPerms = solveSetCombinations(keySet, lower, upper)
			if #keysPerms > actualLimit then
				return #keysPerms
			end
			local results: { { [any]: any } } = {}
			for i, keys in keysPerms do
				local function recurse(keyIndex: number, current: { [any]: any })
					if keyIndex > #keys then
						-- All keys assigned, store a copy
						local dict: { [any]: any } = {}
						for k, v in pairs(current) do
							dict[k] = v
						end
						table.insert(results, dict)
						return
					end

					local key = keys[keyIndex]
					for _, value in ipairs(valueSet) do
						current[key] = value
						recurse(keyIndex + 1, current)
					end
					current[key] = nil
				end

				recurse(1, {})
			end

			if #results > maxPermutations then
				return #results
			end
			return results
		end
	end,
}

type NullableParameter = {
	Key: string,
	Type: "Nullable",
	ChanceNull: number?,
	ValueType: Parameter,
}
Parameter.Nullable = {
	new = function(key: string, valueType: Parameter, chanceNull: number?): NullableParameter
		return {
			Key = key,
			Type = "Nullable",
			ChanceNull = chanceNull,
			ValueType = valueType,
		}
	end,
	generate = function(param: NullableParameter, rng: Random): any?
		local chanceNull = param.ChanceNull or 0.5
		if rng:NextNumber() < chanceNull then
			return nil
		else
			return Parameter.Any.generate(param.ValueType, rng)
		end
	end :: (any, Random) -> any?,
	serialize = function(param: NullableParameter, value: any?): JSONValue
		if value == nil then
			return "null"
		else
			return Parameter.Any.serialize(param.ValueType, value)
		end
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: NullableParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { any? } | number
		return math.huge -- can't return a null value in a list in lua, this is included to avoid it being permuted as it would never include a null value
	end,
}

type FallbackParameter = {
	Key: string,
	Type: "Fallback",
	ValueType: Parameter,
	FallbackType: Parameter,
}
Parameter.Fallback = {
	new = function(key: string, valueType: Parameter, fallbackType: Parameter): FallbackParameter
		return {
			Key = key,
			Type = "Fallback",
			ValueType = valueType,
			FallbackType = fallbackType,
		}
	end,
	generate = function(param: FallbackParameter, rng: Random): any?
		local value: any?
		pcall(function(...)
			value = Parameter.Any.generate(param.ValueType, rng)
		end)
		if value == nil then
			return Parameter.Any.generate(param.FallbackType, rng)
		end
		return value
	end :: (any, Random) -> any?,
	serialize = function(param: FallbackParameter, value: any?): JSONValue
		local valueSer = Parameter.Any.serialize(param.ValueType, value)
		local fallbackSer = Parameter.Any.serialize(param.FallbackType, value)
		if fallbackSer ~= valueSer then
			if typeof(valueSer) == "table" then
				valueSer = HttpService:JSONEncode(valueSer)
			end
			if typeof(fallbackSer) == "table" then
				fallbackSer = HttpService:JSONEncode(fallbackSer)
			end
		end
		assert(
			valueSer == fallbackSer,
			`fallback and value serializers must produce the same output for the same input: "{valueSer}" vs "{fallbackSer}"`
		)
		return valueSer
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: FallbackParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { any? } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations
		local values = Parameter.Any.permute(param.ValueType, maxPermutations, filterFunc)
		local fallbackValues = Parameter.Any.permute(param.FallbackType, maxPermutations, filterFunc)
		local valueSetCount = if typeof(values) == "number" then values else #values
		local fallbackSetCount = if typeof(fallbackValues) == "number" then fallbackValues else #fallbackValues
		local total = valueSetCount + fallbackSetCount
		if total > actualLimit then
			return total
		end
		if typeof(values) == "number" then
			return total
		end
		if typeof(fallbackValues) == "number" then
			return total
		end
		local out = {}
		for _, v in values do
			table.insert(out, v)
		end
		for _, v in fallbackValues do
			table.insert(out, v)
		end
		if #out > maxPermutations then
			return #out
		end
		return out
	end,
}

type StaticParameter = {
	Key: string,
	Type: "Static",
	Value: any?,
	SerializeCallback: (customValue: any?) -> JSONValue,
}
Parameter.Static = {
	new = function(key: string, value: any, serializeCallback: ((customValue: any?) -> JSONValue)?): StaticParameter
		return {
			Key = key,
			Type = "Static",
			Value = value,
			SerializeCallback = serializeCallback or fallbackSerializer,
		}
	end,
	generate = function(param: StaticParameter, rng: Random): any?
		return param.Value
	end :: (any, Random) -> any?,
	serialize = function(param: StaticParameter, value: any?): JSONValue
		return param.SerializeCallback(value)
	end :: (any, any?) -> JSONValue,
	permute = function(
		param: StaticParameter,
		maxPermutations: number,
		filterFunc: ((any) -> boolean)?
	): { any? } | number
		local actualLimit = if filterFunc then ENV.MAX_UNCAPPED_PERMUTATIONS else maxPermutations
		if filterFunc == nil or filterFunc(param.Value) then
			if actualLimit < 1 then
				return 1
			end
			return { param.Value }
		else
			return {}
		end
	end,
}

Parameter.Any = {}
Parameter.Any.new = function(): Parameter
	error("Parameter.Any cannot be instantiated directly")
end
Parameter.Any.generate = function(param: Parameter, rng: Random): any?
	local solver = Parameter[param.Type]
	assert(solver, `bad solver: "{param.Type}"`)
	return solver.generate(param, rng)
end :: (any, Random) -> any?
Parameter.Any.serialize = function(param: Parameter, value: any?): JSONValue
	local solver = Parameter[param.Type]
	assert(solver, `bad solver: "{param.Type}"`)
	if solver.serialize then
		return solver.serialize(param, value)
	else
		return fallbackSerializer(value)
	end
end
Parameter.Any.permute = function(param: Parameter, value: any?, filterFunc: ((any) -> boolean)?): { any } | number
	local solver = Parameter[param.Type]
	assert(solver, `bad solver: "{param.Type}"`)
	if solver.permute then
		return solver.permute(param, value, filterFunc)
	end
	return math.huge
end

return Parameter
