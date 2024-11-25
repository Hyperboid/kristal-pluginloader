Utils.hook(Kristal, "loadModAssets", function (orig, id, asset_type, asset_paths, after)
    -- Get the mod data (loaded from mod.json)
    local mod = Kristal.Mods.getAndLoadMod(id)

    -- No mod found; nothing to load
    if not mod then return end

    -- How many assets we need to load (1 for the mod, 1 for each library)
    local load_count = 1 + #mod.lib_order

    -- Begin mod loading
    MOD_LOADING = true

    local function finishLoadStep()
        -- Finish one load process
        load_count = load_count - 1
        -- Check if all load processes are done (mod and libraries)
        if load_count == 0 then
            -- Finish mod loading
            MOD_LOADING = false

            -- Call the after function
            after()
        end
    end

    -- Finally load all assets (libraries first)
    for _, lib_id in ipairs(mod.lib_order) do
        Kristal.loadAssets(mod.libs[lib_id].path, asset_type or "all", asset_paths or "", finishLoadStep)
    end
    Kristal.loadAssets(mod.path, asset_type or "all", asset_paths or "", finishLoadStep)
    for plugin, enabled in Kristal.PluginLoader.iterPlugins(true) do
        Kristal.loadAssets(plugin.path, asset_type or "all", asset_paths or "", finishLoadStep)
    end
end)