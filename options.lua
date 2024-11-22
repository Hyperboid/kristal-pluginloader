local PluginOptionsHandler, super = Class(StateClass, "PluginOptionsHandler")

function PluginOptionsHandler:init(menu)
    self.menu = menu
	
    self.scroll_target_y = 0
    self.scroll_y = 0
    self.selected_option = 1

    self.noise_timer = 0
	
	local function yeahnah(val)
		return function()
			if Kristal.Config["plugins/"..val] then
				return "YES"
			else
				return "NO"
			end
		end
	end
	
	local function toggle(val)
		return function()
			Kristal.Config["plugins/"..val] = not Kristal.Config["plugins/"..val]
		end
	end
    local NyI = {
        value = function()
            return "NyI"
        end,
        callback = function ()
            Assets.playSound("bluh")
        end
    }
    local function enum(name, val, options) 
        return {
            name = name,
            value = function ()
                return Kristal.Config["plugins/"..val]
            end,
            callback = function()
                local index = Utils.getIndex(options, Kristal.Config["plugins/"..val])
                if index == nil then index = 0 end
                index = ((index) % (#options)+1)
                Kristal.Config["plugins/"..val] = options[index]
            end
        }
    end
	self.options = {}
    for _, mod in pairs(Kristal.Mods.getMods()) do
        local id = mod.id
        if mod.plugin then
            local name = mod.name
            if type(mod.plugin) == "table" and mod.plugin.name then
                name = mod.plugin.name
            end
            local option = { name = name }
            function option.value() return Kristal.Config["plugins/enabled_plugins"][id] and "ON" or "OFF" end
            function option.callback() Kristal.Config["plugins/enabled_plugins"][id] = not Kristal.Config["plugins/enabled_plugins"][id] end
            if type(mod.plugin) == "table" and mod.plugin.menu then
                function option.value() return Kristal.Config["plugins/enabled_plugins"][id] and "ON >" or "OFF >" end
                function option.callback() self.menu:setState(mod.plugin.menu) end
            end
            table.insert(self.options, option)
        end
        
    end
end

function PluginOptionsHandler:registerEvents()
    self:registerEvent("enter", self.onEnter)
    self:registerEvent("keypressed", self.onKeyPressed)
    self:registerEvent("update", self.update)
    self:registerEvent("draw", self.draw)
end

function PluginOptionsHandler:onEnter(old_state)
    if old_state == "MODSELECT" then
        self.selected_option = 1

        self.scroll_target_y = 0
        self.scroll_y = 0
    end
end

function PluginOptionsHandler:onLeave()
	Kristal.saveConfig()
end

function PluginOptionsHandler:onKeyPressed(key, is_repeat)
	
    if Input.isCancel(key) then
        Assets.stopAndPlaySound("ui_move")

        Kristal.saveConfig()

        self.menu:setState("MODSELECT")
        return
    end

    local move_noise = false
	--[[
    local page_dir = "right"
    local old_page = self.selected_page
    if Input.is("left", key) then
        self.selected_page = self.selected_page - 1
        page_dir = "left"
    end
    if Input.is("right", key) then
        self.selected_page = self.selected_page + 1
        page_dir = "right"
    end
    self.selected_page = Utils.clamp(self.selected_page, 1, #self.pages)

    if self.selected_page ~= old_page then
        move_noise = true
        self.selected_option = 1
        self.scroll_target_y = 0
        self.scroll_y = 0
        self.page_scroll_direction = page_dir
        self.page_scroll_timer = 0.1
    end
	
    local page = self.pages[self.selected_page]
	]]
    local options = self.options
    local max_option = #options + 1

    local old_option = self.selected_option
    if Input.is("up", key) then self.selected_option = self.selected_option - 1 end
    if Input.is("down", key) then self.selected_option = self.selected_option + 1 end
    if self.selected_option > max_option then self.selected_option = is_repeat and max_option or 1 end
    if self.selected_option < 1 then self.selected_option = is_repeat and 1 or max_option end

    if old_option ~= self.selected_option then
        move_noise = true
    end

    if move_noise then
        Assets.stopAndPlaySound("ui_move")
    end

    if Input.isConfirm(key) then
        Assets.stopAndPlaySound("ui_select")

        if self.selected_option == max_option then
            -- "Back" button
            Kristal.saveConfig()

            self.menu:setState("MODSELECT")
        elseif options[self.selected_option].callback then
            options[self.selected_option].callback()
        end
    end
end

function PluginOptionsHandler:getHeartPos()
    local options = self.options
    local max_option = #options + 1

    local x, y = 152, 129

    if self.selected_option < max_option then
        x = 152
        y = 129 + (self.selected_option - 1) * 32 + self.scroll_target_y
    else
        -- "Back" button
        x = 320 - 32 - 16 + 1
        y = 480 - 16 + 1
    end

    return x, y
end

function PluginOptionsHandler:update()
    local options = self.options
    local max_option = #options + 1

    if self.selected_option < max_option then
        local y_off = (self.selected_option - 1) * 32

        if y_off + self.scroll_target_y < 0 then
            self.scroll_target_y = self.scroll_target_y + (0 - (y_off + self.scroll_target_y))
        end

        if y_off + self.scroll_target_y > (9 * 32) then
            self.scroll_target_y = self.scroll_target_y + ((9 * 32) - (y_off + self.scroll_target_y))
        end
    end

    if (math.abs((self.scroll_target_y - self.scroll_y)) <= 2) then
        self.scroll_y = self.scroll_target_y
    end
    self.scroll_y = self.scroll_y + ((self.scroll_target_y - self.scroll_y) / 2) * DTMULT

    self.menu.heart_target_x, self.menu.heart_target_y = self:getHeartPos()
end

function PluginOptionsHandler:draw()
    local menu_font = Assets.getFont("main")

    local options = self.options

    local title = "PLUGINS"
    local title_width = menu_font:getWidth(title)

    Draw.setColor(1, 1, 1)
    Draw.printShadow(title, 0, 48, 2, "center", 640)

    local menu_x = 185 - 14
    local menu_y = 110

    local width = 360
    local height = 32 * 10
    local total_height = 32 * #options

    Draw.pushScissor()
    Draw.scissor(menu_x, menu_y, width + 10, height + 10)

    menu_y = menu_y + self.scroll_y

    for i, option in ipairs(options) do
        local y = menu_y + 32 * (i - 1)

        Draw.printShadow(option.name, menu_x, y)

        local value_x = menu_x + (32 * 8)
        local value = option.value and option.value(value_x, y) or nil

        if value then
            Draw.printShadow(tostring(value), value_x, y)
        end
    end

    -- Draw the scrollbar background if the menu scrolls
    if total_height > height then
        Draw.setColor({ 0, 0, 0, 0.5 })
        love.graphics.rectangle("fill", menu_x + width, 0, 4, menu_y + height - self.scroll_y)

        local scrollbar_height = (height / total_height) * height
        local scrollbar_y = (-self.scroll_y / (total_height - height)) * (height - scrollbar_height)

        Draw.popScissor()
        Draw.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", menu_x + width, menu_y + scrollbar_y - self.scroll_y, 4, scrollbar_height)
    else
        Draw.popScissor()
    end

    Draw.printShadow("Back", 0, 454 - 8, 2, "center", 640)
end

return PluginOptionsHandler