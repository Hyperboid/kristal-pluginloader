Utils.hook(Assets, "loadData", function (orig, data)
    for plugin, enabled in Kristal.PluginLoader.iterPlugins(true) do
        -- load stuff
    end
    orig(data)
end)