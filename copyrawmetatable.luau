--module by 12345koip
--retrieves a metatable regardless of the __metatable field
--view full license on the GitHub

--temporary results table to store retrieved metamethods
local results = {}

--type function for result
type function getReturnValue(T)
	if (not T:is("table")) then
		return types.newtable()
	elseif T:is("table") then
		return types.newtable()
	else
		return types.singleton(nil)
	end
end

--userdata object + metamethods setting up
local userdata, metamethodRetrievers, userdataMt do
	userdata = newproxy(true)
	userdataMt = getmetatable(userdata)

	--a bunch of functions used for running the metamethods with controlled parameters
	metamethodRetrievers = table.freeze({
		__add = function(item) return item + userdata end,
		__sub = function(item) return item - userdata end,
		__mul = function(item) return item * userdata end,
		__div = function(item) return item / userdata end,
		__mod = function(item) return item % userdata end,
		__pow = function(item) return item ^ userdata end,
		__unm = function(item) return -item end,
		__eq = function(item) return item == userdata end,
		__lt = function(item) return item < userdata end,
		__le = function(item) return item <= userdata end,
		__concat = function(item) return item..userdata end,
		__len = function(item) return #item end,
		__index = function(item) return item[userdata] end,
		__newindex = function(item)
			local key = string.rep("ergfbgferfgferfvb", math.random(1, 6))
			item[key] = userdata
			item[key] = nil
		end,
		__call = function(item) return item(userdata) end,
		__tostring = function(item) return tostring(item) end
	})

	local function inspectStack(name: string) --inspects levels in the stack for metamethods
		--loop through stack levels looking for a metamethod that isnt this function
		for level = 1, 20, 1 do
			--try get the function and its name
			local s, funcAtLevel = pcall(debug.info, level, "f")
			local s2, funcName = pcall(debug.info, funcAtLevel, "n")

			--if it succeeded and the located metamethod is different to those existing with the same name
			if (s and s2 and funcName == name and funcAtLevel ~= userdataMt[name] and funcAtLevel ~= metamethodRetrievers[name]) then
				results[name] = funcAtLevel
			end
		end
	end

	--set up metamethods
	userdataMt.__add = function()
		inspectStack("__add") --inspect the stack for __add

		--return a placeholder value to be used
		return 3
	end

	userdataMt.__sub = function()
		inspectStack("__sub") --inspect for __sub
		return 3 --return a placeholder
	end

	userdataMt.__mul = function()
		inspectStack("__mul")
		return 3
	end

	userdataMt.__div = function()
		inspectStack("__div")
		return 3
	end

	userdataMt.__mod = function()
		inspectStack("__mod")
		return 3
	end

	userdataMt.__pow = function()
		inspectStack("__pow")
		return 3
	end

	userdataMt.__eq = function()
		inspectStack("__eq")
		return false
	end

	userdataMt.__lt = function()
		inspectStack("__lt")
		return false
	end

	userdataMt.__le = function()
		inspectStack("__le")
		return false
	end

	userdataMt.__concat = function()
		inspectStack("__concat")
		return "a"
	end

	userdataMt.__tostring = function()
		--when __tostring is invoked on the proxy, check a bunch of metamethods which might require that
		inspectStack("__newindex")
		inspectStack("__index")
		inspectStack("__tostring")
		inspectStack("__call")
		inspectStack("__concat")
		return "userdata"
	end
end

--all the characters that can be used to generate a valid key
local characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_"

--get a random key to make it harder to metamethod hide
local function getkey()
	local password = ""

	for i = 1, math.random(45, 75), 1 do --make it between 45 and 75 characters long
		local key = math.random(1, #characters)
		password ..= string.sub(characters, key, key)
	end

	return password
end

--checks to see if a table has a protected metatable or not
local function isMetatableProtected(target: Instance|any): boolean
	--attempt to overwrite the metatable with another value. If it errors, the metatable is protected.
	local success, err = pcall(function()
		--get the old metatable so we can restore it
		local old = getmetatable(target)

		--try and set the new one
		setmetatable(target, {})

		--if that didn't error, we can overwrite it with the old one
		setmetatable(target, old)
	end)

	return (not success and string.match(err:lower(), "protected metatable") ~= nil)
end

--checks to see if the given target is an <code>Instance</code>, bypassing the <code>__type</code> metamethod
local function isInstance(target: any, onModdedMetamethodDetected: (string) -> ()?): (boolean, boolean)
	--get what is expected to be __index
	local __in = select(2, xpcall(function() return target[getkey()](target) end, function() return debug.info(2, "f") end))
	
	--doesn't matter if __index is hooked, wrapping it 198 times and calling it again will C stack overflow if it is hooked
	--tables don't have __index so that can't be hooked either
	for i = 1, 198, 1 do
		__in = coroutine.wrap(__in)
	end

	--try to call it again
	local errorMsg = select(2, pcall(__in))

	--check for a suspicious error message - detect sethiddenstack
	local s, suspiciousMatch = pcall(function() --secondary wrapped function so dont need to check that :D
		return errorMsg:match("%u?%l?%d[%u%l%d_]+")
	end)

	if (not s and onModdedMetamethodDetected) then --no error message - gotta be hooked
		onModdedMetamethodDetected("stack retriever is hooked")
		return true
	elseif (not s) then
		return true
	end

	--if it stack overflowed, it was an instance. Or, if it said invalid arg, it's also an instance. Only instances have __namecall.
	if (errorMsg:match("C stack overflow") or errorMsg:match("missing argument #1 %(Instance expected%)")) then
		return true
	elseif (suspiciousMatch and #suspiciousMatch > 5) then
		if (onModdedMetamethodDetected) then onModdedMetamethodDetected(suspiciousMatch) end
		return true, true
	end

	return false
end

--Returns the real metatable of <code>target</code>, bypassing any metamethods.
local function copyrawmetatable<T>(target: T, onModdedMetamethodDetected: (string) -> ()?): getReturnValue<T>
	table.clear(results)

	local metatable do --get the metatable
		--if its an instance, return its core metamethods (__index, __newindex, __type, __metatable and __namecall)
		local isInstance, hideMetamethods = isInstance(target, onModdedMetamethodDetected)

		if (isInstance and typeof(isInstance) == "boolean") then
			metatable = {
				__index = select(2, xpcall(function() return target[getkey()] end, function() return debug.info(2, "f") end)),
				__newindex = select(2, xpcall(function() target[getkey()] = nil end, function() return debug.info(2, "f") end)),
				__namecall = select(2, xpcall(function() return target:iweurfhbvhcgyudsiewhjrebdf_yes_i_just_ran_my_hand_over_my_keyboard() end, function() return debug.info(2, "f") end)),
				__type = typeof(target),
				__metatable = getmetatable(target)
			}

			--if the expected functions aren't the expected functions, leave them out
			if (hideMetamethods) then
				metatable.__index = nil
				metatable.__newindex = nil
				metatable.__namecall = nil
			end

		elseif (type(target) == "table" and typeof(isInstance) == "boolean") then --table or proxy
			--check if the metatable is protected. if not, just return it like that
			if (not isMetatableProtected(target)) then
				return getmetatable(target)
			end

			metatable = { --create the metatable, the __metatable field can be filled already
				__metatable = getmetatable(target)
			}

			--now, run each function and get the stack inspected metamethod
			for name, func in metamethodRetrievers do

				--use an xpcall to stack inspect any erroring metamethods
				local s, metamethod = xpcall(function()
					func(target) --return the result from the results table
					return results[name]
				end, function()
					--iterate over stack levels until found, if the metamethod errored
					for level = 2, 25, 1 do
						local s, funcAtLevel = pcall(debug.info, level, "f")
						local s2, funcName = pcall(debug.info, funcAtLevel, "n")

						--if the metamethod is a function and is the metamethod of the table
						if (s and s2 and funcName == name and funcAtLevel ~= userdataMt[name] and funcAtLevel ~= metamethodRetrievers[name] and typeof(funcAtLevel) == "function") then
							return funcAtLevel
						end
					end
				end) --try to run the retriever

				metatable[name] = metamethod --store the metamethod
			end

			return table.freeze(metatable)

		elseif (isInstance == -1 and typeof(isInstance) == "number") then --suspicious call stack error
			return

		else --invalid target
			error(
				target ~= nil and "invalid argument #1 to 'copyrawmetatable' (Instance or table expected, got "..typeof(target)..")"
					or "missing argument #1 to 'copyrawmetatable'"
			)
		end
	end

	return metatable --return the raw metatable
end

return copyrawmetatable
