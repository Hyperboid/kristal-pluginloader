local preview = {}

preview.hide_background = false

-- thanks jamm, this is totally better thanks replacing 7 bytes in conf.lua
-- i mean i guess it could be annoying to ask everyone to move their savedata BUT STILL THIS SHOULD'VE NEVER BEEN A PROBLEM AAHHHH
if TARGET_MOD and Utils.startsWith(TARGET_MOD, "acj_deoxynn/") then
	return preview
end

function preview:init(mod, button, menu)
	if MainMenu and not Kristal.PluginLoader then
		---@diagnostic disable-next-line: inject-field
		Kristal.PluginLoader = {
			plugin_scripts = {},
			script_chunks = {}
			--[[
			options = {
				textures = Kristal.Config["ebb/textures"] or true
			}]]
		}
		---@return fun(): table, boolean, table
		function Kristal.PluginLoader.iterPlugins(active_only)
			local index = 0
			local all_mods = Kristal.Mods.getMods()
			return function()
				repeat
					index = index + 1
					if index > #all_mods then return nil end
					if all_mods[index].plugin then
						if Kristal.Config["plugins/enabled_plugins"][all_mods[index].id] or (active_only ~= true) then
							return all_mods[index],
								Kristal.Config["plugins/enabled_plugins"][all_mods[index].id],
								Kristal.PluginLoader.plugin_scripts[all_mods[index].id] or {}
						end
					end
				until index > #all_mods
			end
		end
		function Kristal.PluginLoader:addScriptChunk(mod_id, path, chunk)
			if self.script_chunks[mod_id] == nil then self.script_chunks[mod_id] = {} end
			self.script_chunks[mod_id][path] = chunk
		end
		function Kristal.PluginLoader.pluginCall(f, ...)
			local result = {}
			for _,_,plugin in Kristal.PluginLoader.iterPlugins(true) do
				if plugin[f] then
					local plugin_results = {plugin[f](plugin, ...)}
					if(#plugin_results > 0) then
						result = plugin_results
					end
				end
			end
			return Utils.unpack(result)
		end
		---Whether any plugins are active. Mostly for the purpose of Deltaraid.
		---@param ignorelist? string[] List of plugins to ignore during the check.
		---@return boolean active
		---@return table[] banned_plugins
		function Kristal.PluginLoader.checkActive(ignorelist)
			ignorelist = ignorelist or {}
			local banned_plugins = {}
			for plugin in Kristal.PluginLoader.iterPlugins(true) do
				local key = plugin.id
				for _, ignoretest in ipairs(ignorelist) do
					if key == ignoretest then goto continue end
				end
				local plugin = Kristal.Mods.getMod(key)
				table.insert(banned_plugins, plugin)
			    ::continue::
			end
			return (#banned_plugins > 0), banned_plugins
		end

		local function check(setting, default)
			Kristal.Config["plugins/"..setting] = Kristal.Config["plugins/"..setting] == nil and default or Kristal.Config["plugins/"..setting]
		end
		local function opt(setting)
			return Kristal.Config["plugins/"..setting]
		end
		check("enabled_plugins", {})

		Utils.hook(Kristal, "loadMod", function(orig, id, ...)
			if id == mod.id then
				MainMenu:setState("plugins")
				return true
			else
				return orig(id, ...)
			end
		end)

		local orig_up = Battle.update
		local orig_init = Battle.init
		Utils.hook(Registry, "initialize", function (orig, preload)
			local self = Registry
			Kristal.PluginLoader.script_chunks = {}
			for plugin_id, plugin in pairs(Kristal.Mods.data) do
				if opt("enabled_plugins")[plugin.id] then
					for _,path in ipairs(Utils.getFilesRecursive(plugin.path.."/scripts", ".lua")) do
						local chunk = love.filesystem.load(plugin.path.."/scripts/"..path..".lua")
						Kristal.PluginLoader:addScriptChunk(plugin_id, path, chunk)
					end
					if Mod and love.filesystem.getInfo(plugin.path.."/plugin.lua") then
						local chunk = love.filesystem.load(plugin.path.."/plugin.lua")
						Kristal.PluginLoader.plugin_scripts[plugin_id] = assert(chunk(), plugin.path.."/plugin.lua returned nil.")
					elseif Mod and love.filesystem.getInfo(plugin.path.."/lib.lua") then
						local chunk = love.filesystem.load(plugin.path.."/lib.lua")
						Kristal.PluginLoader.plugin_scripts[plugin_id] = assert(chunk(), plugin.path.."/lib.lua returned nil.")
					end
				end
			end
			orig(preload)
		end)
		Utils.hook(Registry, "iterScripts", function (_, base_path, exclude_folder)
			local self = Registry
			local result = {}

			CLASS_NAME_GETTER = function(k)
				for _,v in ipairs(result) do
					if v.id == k then
						return v.out[1]
					end
				end
				return DEFAULT_CLASS_NAME_GETTER(k)
			end

			local chunks = nil
			local parsed = {}
			local queued_parse = {}
			local addChunk, parse

			addChunk = function(path, chunk, file, full_path)
				local success,a,b,c,d,e,f = pcall(chunk)
				if not success then
					if type(a) == "table" and a.included then
						table.insert(queued_parse, {path, chunk, file, full_path})
						return false
					else
						error(a)
					end
				else
					local result_path = file
					if exclude_folder then
						local split_path = Utils.split(file, "/", true)
						result_path = split_path[#split_path]
					end
					local id = type(a) == "table" and a.id or result_path
					table.insert(result, {out = {a,b,c,d,e,f}, path = result_path, id = id, full_path = full_path})
					return true
				end
			end
			parse = function(path, _chunks)
				chunks = _chunks
				parsed = {}
				queued_parse = {}
				-- WORKAROUND: Script chunks may be spread around without particular order
				-- (which have caused loading to fail many times in pretty specific situations),
				-- so we're going to sort them to have stuff load in a sane order
				-- For some reason this also seems to uhh increase loading speed?
				-- (for Dark Place at least)
				for full_path,chunk in Utils.orderedPairs(chunks) do
					if not parsed[full_path] and full_path:sub(1, #path) == path then
						local file = full_path:sub(#path + 1)
						if file:sub(1, 1) == "/" then
							file = file:sub(2)
						end
						parsed[full_path] = true
						addChunk(path, chunk, file, full_path)
					end
				end
				while #queued_parse > 0 do
					local last_queued = queued_parse
					queued_parse = {}
					for _,v in ipairs(last_queued) do
						addChunk(v[1], v[2], v[3], v[4])
					end
					if #queued_parse == #last_queued then
						local failed = {}
						for _,v in ipairs(last_queued) do
							table.insert(failed, v[3])
						end
						error("Couldn't find dependency in " .. path .. " for " .. table.concat(failed, ", "))
					end
				end
			end

			parse(base_path, self.base_scripts)
			if Mod then
				for _,library in Kristal.iterLibraries() do
					parse("scripts/"..base_path, library.info.script_chunks)
				end
				parse("scripts/"..base_path, Mod.info.script_chunks)
				for plugin,_,_ in Kristal.PluginLoader.iterPlugins(true) do
					local value = Kristal.PluginLoader.script_chunks[plugin.id]
					if value then
						parse(base_path, value)
					end
				end
			end

			CLASS_NAME_GETTER = DEFAULT_CLASS_NAME_GETTER

			local i = 0
		---@diagnostic disable-next-line: undefined-field, deprecated
			local n = table.getn(result)
			return function()
				i = i + 1
				if i <= n then
					local full_path = result[i].full_path
					if Mod then
						full_path = Mod.info.path.."/"..full_path
					end
					return full_path, result[i].path, unpack(result[i].out)
				end
			end
		end)
		love.filesystem.load(mod.path.."/assetsloader.lua")()
		Utils.hook(Kristal, "callEvent", function (_, f, ...)
			if not Mod then return end
			local lib_result = {Kristal.libCall(nil, f, ...)}
			local mod_result = {Kristal.modCall(f, ...)}
			local plugin_result = {Kristal.PluginLoader.pluginCall(f, ...)}
			--print("EVENT: "..tostring(f), #mod_result, #lib_result)
			if(#plugin_result > 0) then
				return Utils.unpack(plugin_result)
			elseif(#mod_result > 0) then
				return Utils.unpack(mod_result)
			else
				return Utils.unpack(lib_result)
			end
		end)
	end
	local loader = Kristal.PluginLoader

	if MainMenu and MainMenu.mod_list ~= Kristal.PluginLoader.mod_list then
		local PluginOptionsHandler = require(mod.path.."/pluginoptionshandler")
		MainMenu.state_manager:addState("plugins", PluginOptionsHandler(MainMenu))

		Kristal.PluginLoader.mod_list = MainMenu.mod_list
	end

	for _, mod in ipairs(Kristal.Mods.getMods()) do
		if not mod.plugin then goto continue end
		if not love.filesystem.getInfo(mod.path.."/options.lua") then goto continue end
		local result = love.filesystem.load(mod.path.."/options.lua")(mod)
		MainMenu.state_manager:addState("plugin_"..mod.id, result(MainMenu))
		::continue::
	end

    button:setColor(1, 1, 1)
    button:setFavoritedColor(.8, .6, 1)
	self.button = button
end

function preview:update()
	local count = #(({Kristal.PluginLoader.checkActive()})[2])
	local function plural(number, word)
		if number == 1 then
			return number.." "..word
		else
			return number.." "..word.."s"
		end
	end
	self.button.subtitle = plural(count, "plugin").." enabled"
end

function preview:draw()
end

local subfont = Assets.getFont("main", 16)
function preview:drawOverlay()
	if MainMenu and MainMenu.state == "MODSELECT" then
	end
end

return preview