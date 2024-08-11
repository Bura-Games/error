--!optimize 2
--!strict

type Function = (...any) -> ...any

--[=[
	A JavaScript-style error object.

	```lua
	local function UsingConstructor()
		-- You can use `Error.new`.
		error(Error.new("Something went wrong!"))
	end
	local function UsingCall()
		-- It supports `__call`.
		error(Error("Something went wrong!"))
	end
	local function WithStackTrace()
		-- You can capture a stack trace!
		local exception = Error.new("Something went wrong!")
		Error.captureStackTrace(exception, WithStackTrace)
		error(exception)
	end
	local function WithName()
		-- You can also set the name!
		local exception = Error.new("Something went wrong!")
		exception.name = "UnknownError"
		Error.captureStackTrace(exception, WithName)
		error(exception)
	end
	```

	@tag Supports __tostring

	@class Error
]=]

--[=[
	@prop message string -- The error's message.
	@within Error
]=]
--[=[
	@prop name string -- The error's name.
	@within Error
]=]
--[=[
	@readonly
	@prop stack string? -- The error's stack trace.
	@within Error
]=]

export type Error = {
	message: string,
	name: string,
	stack: string?,
}
type ErrorPrivate = Error & {__stack: string?}

local DEFAULT_NAME = "Error"

local Error = {}
Error.__index = Error
function Error:__tostring()
	return getmetatable(Error :: never).__tostring(self)
end

local function RecalculateStackTrace(exception: Error)
	local self = exception :: ErrorPrivate
	local message = self.message
	self.stack =
		`{self.name or DEFAULT_NAME}{if message and message ~= "" then `: {message}` else ""}\n{self.__stack or ""}`
end
local function CaptureStackTrace(exception: Error, level: number, options: Function?)
	local self = exception :: ErrorPrivate
	if type(options) == "function" then
		local stack = debug.traceback(nil, level)
		local functionName: string = debug.info(options, "n")
		local sourceFilePath: string = debug.info(options, "s")

		local spacedSourceFilePath = string.gsub(sourceFilePath, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
		local stackTraceLinePattern = `{spacedSourceFilePath}:%d* function {functionName}`

		local start = string.find(stack, stackTraceLinePattern)
		local finish: number? = nil

		if start then
			start, finish = string.find(stack, "\n", start + 1)
		end

		if finish then
			stack = string.sub(stack, finish + 1)
		end

		self.__stack = stack
	else
		self.__stack = debug.traceback(nil, level)
	end
	RecalculateStackTrace(self)
end

local function CreateError(message: string?): Error
	local self: Error = setmetatable({
		message = message or "";
		name = DEFAULT_NAME;
	}, Error) :: never
	CaptureStackTrace(self, 4)
	return self
end

--[=[
	Creates a new Error.

	@param message? unknown -- The message of the error. Defaults to an empty string.
	@return Error
]=]
function Error.new(message: unknown?): Error
	return CreateError(if message then tostring(message) else "")
end

--[=[
	Captures the stack trace of the exception.

	@param exception Error -- The exception to capture the stack trace of.
	@param options? (...any) -> ...any -- The function to use as the stack trace source.
]=]
function Error.captureStackTrace(exception: Error, options: Function?)
	CaptureStackTrace(exception, 3, options)
end
--[=[
	Captures the stack trace of the exception. An alias to
	[Error.captureStackTrace].

	@function CaptureStackTrace
	@within Error

	@param exception Error -- The exception to capture the stack trace of.
	@param options? (...any) -> ...any -- The function to use as the stack trace source.
]=]
Error.CaptureStackTrace = Error.captureStackTrace

return setmetatable(Error, {
	__call = function(_, ...)
		return CreateError(...)
	end;

	__tostring = function(self)
		local name = self.name
		if name ~= nil then
			local message = self.message
			return if message and message ~= "" then `{name}: {message}` else tostring(name)
		end

		return DEFAULT_NAME
	end;
})
