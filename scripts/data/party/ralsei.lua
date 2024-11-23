local character, super = Class("ralsei", true)

function character:init()
    super.init(self)
    -- Display name
    self.name = "Ralsea"
    self:addSpell("exampleplugin/dumb_prayer")
end

function character:onSave(data)
    Utils.removeFromTable(data.spells, "exampleplugin/dumb_prayer")
    return super.onSave(self, data)
end

function character:onLoad(data)
    self:addSpell("exampleplugin/dumb_prayer")
    super.onLoad(self, data)
end

return character