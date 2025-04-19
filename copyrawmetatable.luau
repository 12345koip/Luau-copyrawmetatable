--module by 12345koip
--retrieves a metatable regardless of the __metatable field
--view full license on the GitHub, full explanation on the DevForum
--THIS HAS SOME LIMITATIONS!!!

--temporary results table to store retrieved metamethods
local results = {}

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

--Returns the real metatable of <code>target</code>, bypassing the <code>__metatable</code> metamethod.
local function copyrawmetatable(target: Instance|any|{[any]: any}): {[any]: any}
	local metatable do --get the metatable
		--if its an instance, return its core metamethods (__index, __newindex and __namecall)
		if (typeof(target) == "Instance") then
			metatable = {
				__index = select(2, xpcall(function() return target.____ end, function() return debug.info(2, "f") end)),
				__newindex = select(2, xpcall(function() target.____ = nil end, function() return debug.info(2, "f") end)),
				__namecall = select(2, xpcall(function() return target:____() end, function() return debug.info(2, "f") end)),
				__type = typeof(target)
			}
		elseif (typeof(target) == "table") then --table or proxy
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
			
		else --invalid target
			error(
				target ~= nil and "invalid argument #1 to 'copyrawmetatable' (Instance or table expected, got "..typeof(target)..")"
				or "missing argument #1 to 'copyrawmetatable'"
			)
		end
	end
	
	table.clear(results) --remove the metamethod from results table
	
	return metatable --return the raw metatable
end

return copyrawmetatable
