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
}
Parameter.Custom = {
	new = function<V>(
		key: string,
		method: (Random) -> V,
		serializeCallback: ((customValue: V) -> JSONValue)?
	): CustomParameter
		return {
			Key = key,
			Type = "Custom",
			Method = method,
			SerializeCallback = serializeCallback or fallbackSerializer,
		}
	end,
	generate = function(param: CustomParameter, rng: Random): any?
		return param.Method(rng)
	end :: (any, Random) -> any?,
	serialize = function(param: CustomParameter, value: any?): JSONValue
		return param.SerializeCallback(value)
	end :: (any, any?) -> JSONValue,
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
	serialize = function(param: IntegerParameter, value: any?): JSONValue
		if typeof(value) == "number" and math.abs(value) == math.huge then
			return value > 0 and "INF" or "-INF"
		elseif typeof(value) == "number" and (value ~= value) then
			return "NaN"
		end
		return value
	end :: (any, any?) -> JSONValue,
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
		local minLength = math.max(param.MinLength or 1, 1)
		local maxLength = math.max(minLength, param.MaxLength or CONSTANTS.DEFAULT_TABLE_SIZE)
		local length = rng:NextInteger(minLength, maxLength)
		local result = {}
		for i = 1, length do
			local value = Parameter.Any.generate(param.ValueType, rng)
			result[i] = value
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
}

type ComputedParameter = {
	Key: string,
	Type: "Computed",
	Inputs: { Parameter },
	ComputeFunc: (...any?) -> any,
	SerializeCallback: (customValue: any?) -> JSONValue,
}
Parameter.Computed = {
	new = function(
		key: string,
		inputs: { Parameter },
		computeFunc: (...any?) -> any,
		serializeCallback: ((customValue: any?) -> JSONValue)?
	): ComputedParameter
		return {
			Key = key,
			Type = "Computed",
			Inputs = inputs,
			ComputeFunc = computeFunc,
			SerializeCallback = serializeCallback or fallbackSerializer,
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
		local minLength = math.max(param.MinLength or 1, 1)
		local maxLength = math.max(minLength, param.MaxLength or CONSTANTS.DEFAULT_TABLE_SIZE)
		local length = if minLength == maxLength then minLength else rng:NextInteger(minLength, maxLength)
		local result = {}
		local hashMap: { [string]: true? } = {}
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
		local minLength = math.max(param.MinLength or 1, 1)
		local maxLength = math.max(minLength, param.MaxLength or CONSTANTS.DEFAULT_STRING_LENGTH)
		local length = rng:NextInteger(minLength, maxLength)
		local chars = {}
		for i = 1, length do
			local charCode = rng:NextInteger(32, 126) -- Printable ASCII range
			chars[i] = string.char(charCode)
		end
		return table.concat(chars)
	end :: (any, Random) -> string,
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
}
type BrickColorParameter = {
	Key: string,
	Type: "BrickColor",
}
Parameter.BrickColor = {
	new = function(key: string): BrickColorParameter
		return {
			Key = key,
			Type = "BrickColor",
		}
	end,
	generate = function(param: BrickColorParameter, rng: Random): BrickColor
		return BrickColor.new(rng:NextNumber(), rng:NextNumber(), rng:NextNumber())
	end :: (any, Random) -> string,
	serialize = function(param: BrickColorParameter, value: any?): JSONValue
		if typeof(value) == "BrickColor" then
			return value.Name
		end
		return value
	end :: (any, any?) -> JSONValue,
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
		local minLength = math.max(param.MinLength or 1, 1)
		local maxLength = math.max(minLength, param.MaxLength or CONSTANTS.DEFAULT_TABLE_SIZE)
		local length = rng:NextInteger(minLength, maxLength)
		local result = {}
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

return Parameter
