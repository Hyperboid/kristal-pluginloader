local preview = {}

preview.hide_background = false

function preview:init(mod, button, menu)
	if MainMenu and not Kristal.Ebb then
		Kristal.Ebb = {
			active = false
			--[[
			options = {
				textures = Kristal.Config["ebb/textures"] or true
			}]]
		}
		
		local function check(setting, default)
			Kristal.Config["ebb/"..setting] = Kristal.Config["ebb/"..setting] == nil and default or Kristal.Config["ebb/"..setting]
		end
		check("callhurt", true)
		check("stagger", false)
		check("rapidtimer", true)
		check("grazeheal", true)
		
		local orig = Kristal.loadMod
		function Kristal.loadMod(id, ...)
			if id == mod.id then
				MainMenu:setState("ebb")
			else
				orig(id, ...)
			end
		end
		
		local orig_up = Battle.update
		local orig_init = Battle.init
		local bleedtimer = 0
		function Battle:update()
			orig_up(self)
			if Kristal.Ebb.active then
				if bleedtimer > 0 and self.party then
					bleedtimer = bleedtimer - 0.5
					for index, --[[@type PartyBattler]] battler in ipairs(self.party) do
						local down = battler.is_down
						if not down then
							battler:hurt(3)
							if down then
								battler.chara.health = 0
							end
						end
					end
				end
			end
			bleedtimer = bleedtimer + DT
		end
		function Battle:init(...)
			orig_init(self, ...)
			if Kristal.Ebb.active then
				bleedtimer = -2
			end
		end
	end
	local ebb = Kristal.Ebb
	
	local heart_broken = love.graphics.newImage(mod.path.."/heart_broken.png")

	local function breakHeart()
		MainMenu.heart.color = {.7,0.4,0.4}
		MainMenu.heart:set(heart_broken)
	end
	local function unbreakHeart()
		MainMenu.heart.color = {Kristal.getSoulColor()}
		MainMenu.heart:set("player/heart_menu")
	end
	
	if MainMenu and MainMenu.mod_list ~= Kristal.Ebb.mod_list then
		local options = require(mod.path.."/options")
		MainMenu.state_manager:addState("ebb", options(MainMenu))
		
		Kristal.Ebb.mod_list = MainMenu.mod_list
		
		local orig = MainMenu.mod_list.onKeyPressed
		MainMenu.state_manager:addEvent("keypressed",{MODSELECT = function(menu, key, is_repeat)
			--Kristal.Console:log("guh.")
			if key == "w" and not is_repeat then
				ebb.active = not ebb.active
				if ebb.active then
					Assets.playSound("ui_spooky_action")
					--Assets.playSound("break2")
					breakHeart()
				else
					Assets.playSound("him_quick")
					unbreakHeart()
				end
				local hearteffect = Sprite("player/heart_menu")
				hearteffect:setOrigin(0.5, 0.5)
				hearteffect:setScale(2, 2)
				hearteffect:setPosition(MainMenu.heart:getPosition())
				hearteffect.color = menu.heart.color
				hearteffect:setLayer(menu.heart.layer - 1)
				MainMenu.stage:addChild(hearteffect)
				MainMenu.stage.timer:tween(.5, hearteffect, {scale_x=4, scale_y=4, alpha=0})
				local col = menu.heart.color
				menu.heart.color = {1,1,1,1}
				MainMenu.stage.timer:tween(.5, menu.heart, {color=col})
				MainMenu.stage.timer:after(.5, function()
					hearteffect:remove()
				end)
			else
				orig(menu.mod_list, key, is_repeat)
			end
		end})
		
		local orig = MainMenu.mod_list.onEnter
		MainMenu.state_manager:addEvent("enter",{MODSELECT = function(menu)
			if ebb.active then
				breakHeart()
			else
				unbreakHeart()
			end
			orig(menu.mod_list)
		end})
		
		local orig = MainMenu.mod_list.onLeave
		MainMenu.state_manager:addEvent("leave",{MODSELECT = function(menu, new_state)
			if new_state == "TITLE" then
				unbreakHeart()
			end
			orig(menu.mod_list)
		end})
	end
	
    button:setColor(1, 1, 1)
    button:setFavoritedColor(.8, .6, 1)
	
	if not MainMenu then
		button.subtitle = "(kristal version outdated! cannot run)"
	elseif math.random() < 1/50 then
		button.subtitle = "sadness"
	elseif math.random() < 1/50 then
		button.subtitle = "suffering"
	else
		button.subtitle = "pain"
	end
end

function preview:update()
end

function preview:draw()
end

local subfont = Assets.getFont("main", 16)
function preview:drawOverlay()
	if MainMenu and MainMenu.state == "MODSELECT" then
		love.graphics.setColor(COLORS.white)
		love.graphics.setFont(subfont)
		local txt = Kristal.Ebb.active and "[W] Deactivate EBB" or "[W] Activate EBB"
		Draw.printShadow(txt, -70, 30, 1, "right", 640)
	end
end

return preview