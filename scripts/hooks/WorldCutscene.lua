local WorldCutscene, super = Class(WorldCutscene)

function WorldCutscene:text(text, ...)
    text = string.gsub(text, "Ralsei", "Ralsea")
    text = string.gsub(text, "RALSEI", "RALSEA")
    return super.text(self,text,...)
end

return WorldCutscene