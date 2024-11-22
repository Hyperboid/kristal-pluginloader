local preview = {}

preview.hide_background = false

function preview:init(mod, button, menu)
	if MainMenu and not Kristal.PluginLoader then
		---@diagnostic disable-next-line: inject-field
		Kristal.PluginLoader = {
			active = false,
			script_chunks = {}
			--[[
			options = {
				textures = Kristal.Config["ebb/textures"] or true
			}]]
		}
		function Kristal.PluginLoader:addScriptChunk(mod_id, path, chunk)
			if self.script_chunks[mod_id] == nil then self.script_chunks[mod_id] = {} end
			self.script_chunks[mod_id][path] = chunk
		end
		---Whether any plugins are active. Mostly for the purpose of Deltaraid.
		---@param ignorelist string[] List of plugins to ignore during the check.
		---@return boolean active
		function Kristal.PluginLoader:checkActive(ignorelist)
			ignorelist = ignorelist or {}
			for key, value in pairs(Kristal.Config["plugins/enabled_plugins"]) do
				for _, ignoretest in ipairs(ignorelist) do
					if value == ignoretest then goto continue end
				end
				if Kristal.Mods.getMod(key) and value then return true end
			    ::continue::
			end
			return false
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
			else
				orig(id, ...)
			end
		end)

		local orig_up = Battle.update
		local orig_init = Battle.init
		Utils.hook(Registry, "initialize", function (orig, preload)
			local self = Registry
			if not self.preload then
				self.base_scripts = {}
		
				local chapter = Kristal.getModOption("chapter") or 2
				Game.chapter = chapter
		
				for _,path in ipairs(Utils.getFilesRecursive("data", ".lua")) do
					local chunk = love.filesystem.load("data/"..path..".lua")
					self.base_scripts["data/"..path] = chunk
				end

				for plugin_id, plugin in pairs(Kristal.Mods.data) do
					if opt("enabled_plugins")[plugin.id] then
						for _,path in ipairs(Utils.getFilesRecursive(plugin.path.."/scripts", ".lua")) do
							local chunk = love.filesystem.load(mod.path.."/scripts/"..path..".lua")
							Kristal.PluginLoader:addScriptChunk(plugin_id, path, chunk)
						end
					end
				end

				Registry.initActors()
			end
			if not preload then
				Registry.initGlobals()
				Registry.initObjects()
				Registry.initDrawFX()
				Registry.initItems()
				Registry.initSpells()
				Registry.initPartyMembers()
				Registry.initRecruits()
				Registry.initEncounters()
				Registry.initEnemies()
				Registry.initWaves()
				Registry.initBullets()
				Registry.initCutscenes()
				Registry.initEventScripts()
				Registry.initTilesets()
				Registry.initMaps()
				Registry.initEvents()
				Registry.initControllers()
				Registry.initShops()
				Registry.initBorders()
		
				Kristal.callEvent(KRISTAL_EVENT.onRegistered)
			end
		
			self.preload = preload
		
			Hotswapper.updateFiles("registry")
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
			end
			for id, value in pairs(Kristal.PluginLoader.script_chunks) do
				if Kristal.Config["plugins/enabled_plugins"][id] then
					parse(base_path, value)
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
	end
	local loader = Kristal.PluginLoader
	
	local heart_broken = love.graphics.newImage(mod.path.."/heart_broken.png")

	if MainMenu and MainMenu.mod_list ~= Kristal.PluginLoader.mod_list then
		local options = require(mod.path.."/options")
		MainMenu.state_manager:addState("plugins", options(MainMenu))

		Kristal.PluginLoader.mod_list = MainMenu.mod_list
	end

    button:setColor(1, 1, 1)
    button:setFavoritedColor(.8, .6, 1)

	if not MainMenu then
		button.subtitle = "(kristal version outdated! cannot run)"
	else
		button.subtitle = Utils.pick{
			"CHAOS, CHAOS!",
		}
	end
end

function preview:update()
end

function preview:draw()
end

local subfont = Assets.getFont("main", 16)
function preview:drawOverlay()
	if MainMenu and MainMenu.state == "MODSELECT" then
	end
end

return preview