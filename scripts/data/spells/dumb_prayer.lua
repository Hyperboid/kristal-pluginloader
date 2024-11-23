local spell, super = Class(Spell, "exampleplugin/dumb_prayer")

function spell:init()
    super.init(self)

    -- Display name
    self.name = "Dumb Prayer"
    -- Name displayed when cast (optional)
    self.cast_name = nil

    -- Battle description
    self.effect = "Worse\nHealSling"
    -- Menu description
    self.description = "Heavenly light restores a little HP to\none enemy. Depends on Magic."

    -- TP cost
    self.cost = 32

    -- Target mode (ally, party, enemy, enemies, or none)
    self.target = "enemy"

    -- Tags that apply to this spell
    self.tags = {"heal"}
end

function spell:onCast(user, target)
    target:heal(user.chara:getStat("magic") * 5)
end


return spell