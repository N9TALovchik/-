-- ShopManager.lua (полный финальный + SurfaceGui на DriveSeat)
local ShopManager = {}

function ShopManager:Init(Window, Tabs)
    assert(Window, "ShopManager: Window is required")
    assert(Library, "Library must be loaded before ShopManager")
    
    local shopTab = Window:AddTab('Arrp')
    Tabs.Shop = shopTab
    
    local configGroup = shopTab:AddLeftGroupbox('Auto Buy Settings')
    local itemsGroup = shopTab:AddRightGroupbox('Shop Items')
    
    -- ========== ГРУППА MISC ==========
    local miscGroup = shopTab:AddLeftGroupbox('Misc')
    miscGroup:AddLabel('30 minute needed')
    miscGroup:AddButton('AutoPromocode', function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/N9TALovchik/-/refs/heads/main/Script1.lua"))()
        end)
        if not success then
            Library:Notify("Failed to execute AutoPromocode: " .. tostring(err), 3)
        else
            Library:Notify("AutoPromocode script executed!", 2)
        end
    end)

    -- ===== INF STAMINA (TOGGLE) =====
    local infStaminaToggle = miscGroup:AddToggle('InfStaminaToggle', {
        Text = 'Inf Stamina',
        Default = false,
        Tooltip = 'Стамина всегда 450 (не тратится)'
    })

    local infStaminaConnection = nil
    local function startInfStamina()
        if infStaminaConnection then infStaminaConnection:Disconnect() end
        if not infStaminaToggle.Value then return end
        local player = game.Players.LocalPlayer
        infStaminaConnection = game:GetService("RunService").Heartbeat:Connect(function()
            if not player then return end
            player:SetAttribute("currentStamina", 450)
        end)
    end

    infStaminaToggle:OnChanged(function()
        if infStaminaToggle.Value then startInfStamina()
        else
            if infStaminaConnection then infStaminaConnection:Disconnect() infStaminaConnection = nil end
        end
    end)

    -- ===== AC BYPASS =====
    miscGroup:AddButton('AC Bypass', function()
        local player = game:GetService("Players").LocalPlayer
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local collectionService = game:GetService("CollectionService")

        local remotes = replicatedStorage:FindFirstChild("Remotes")
        if remotes then
            local targets = {["TellRegulator"] = true, ["ConfirmRegulator"] = true, ["GetRegulator"] = true}
            local deleted = 0
            for _, remote in ipairs(remotes:GetChildren()) do
                if targets[remote.Name] and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
                    remote:Destroy()
                    deleted = deleted + 1
                end
            end
            Library:Notify(string.format("Deleted %d anti-cheat remote(s).", deleted), 2)
        else
            Library:Notify("Remotes folder not found.", 3)
        end

        if not player:HasTag("Trusted") then
            collectionService:AddTag(player, "Trusted")
        end

        if not _G.TrustedConnection then
            _G.TrustedConnection = player.CharacterAdded:Connect(function()
                if not player:HasTag("Trusted") then
                    collectionService:AddTag(player, "Trusted")
                end
            end)
            Library:Notify("Тег Trusted теперь будет сохраняться после каждой смерти.", 2)
        end

        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                humanoid.Health = 0
            end
        end

        Library:Notify("Персонаж умрёт и возродится с Trusted. Проверки отключены.", 2)
    end)

    -- ===== NoJumpDelay =====
    local noJumpLoopActive = false
    miscGroup:AddButton('NoJumpDelay', function()
        if noJumpLoopActive then return end
        noJumpLoopActive = true
        local player = game.Players.LocalPlayer
        local function removeJump()
            local char = player.Character
            if char then
                local jp = char:FindFirstChild("JumpPhysic")
                if jp and jp:IsA("LocalScript") then jp:Destroy() end
            end
        end
        task.spawn(function()
            while noJumpLoopActive do
                removeJump()
                task.wait(0.5)
            end
        end)
        Library:Notify("NoJumpDelay activated. JumpPhysic will be removed continuously.", 2)
    end)

    -- ===== SHOW INVENTORY =====
    local invHeartbeat = nil
    miscGroup:AddButton('No Hide Inventory', function()
        if invHeartbeat then return end
        local StarterGui = game:GetService("StarterGui")
        invHeartbeat = game:GetService("RunService").Heartbeat:Connect(function()
            pcall(function()
                StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
            end)
        end)
        Library:Notify("Инвентарь теперь всегда виден", 2)
    end)

    -- ===== AUTO UNCUFF =====
    local uncuffToggle = miscGroup:AddToggle('UncuffToggle', {
        Text = 'Auto UnCuff',
        Default = false,
        Tooltip = 'Моментально снимает наручники (работает и при включении заранее)'
    })

    local uncuffHeartbeat = nil
    local function tryUncuff()
        local player = game.Players.LocalPlayer
        if not player then return end
        local char = player.Character
        if not char then return end
        local cuffedBy = char:FindFirstChild("cuffedBy")
        if not cuffedBy then return end
        local cuffer = cuffedBy.Value
        if not cuffer then return end
        local cufferChar = cuffer.Character
        if not cufferChar then return end
        local tool = cufferChar:FindFirstChildWhichIsA("Tool")
        if not (tool and tool:HasTag("Cuffs")) then return end
        local remote = tool:FindFirstChildWhichIsA("RemoteEvent")
        if not remote then return end
        remote:FireServer("ForceUncuff", math.floor(workspace:GetServerTimeNow() + player.UserId))
    end

    local function startUncuffHeartbeat()
        if uncuffHeartbeat then uncuffHeartbeat:Disconnect() end
        uncuffHeartbeat = game:GetService("RunService").Heartbeat:Connect(tryUncuff)
    end

    local function stopUncuffHeartbeat()
        if uncuffHeartbeat then uncuffHeartbeat:Disconnect() uncuffHeartbeat = nil end
    end

    uncuffToggle:OnChanged(function(enabled)
        if enabled then startUncuffHeartbeat() else stopUncuffHeartbeat() end
    end)

    -- ===== RANDOM CHAT SPAM =====
    local chatSpamToggle = miscGroup:AddToggle('ChatSpamToggle', {
        Text = 'Random Chat Spam',
        Default = false,
        Tooltip = 'Отправляет случайные сообщения (99-200 символов) каждый кадр'
    })

    local chatSpamConnection = nil
    local charset = {}
    for c = 65, 90 do table.insert(charset, string.char(c)) end
    for c = 97, 122 do table.insert(charset, string.char(c)) end
    local symbols = {
        '=', '+', '-', '*', '/', '!', '?', '#', '@', '%', '&',
        '(', ')', '[', ']', '{', '}', ':', ';', '"', '\'',
        ',', '.', '<', '>', '~', '`', '|', '\\', '^', '_', ' '
    }
    for _, sym in ipairs(symbols) do table.insert(charset, sym) end

    local function randomString()
        local len = math.random(99, 200)
        local t = {}
        for _ = 1, len do table.insert(t, charset[math.random(#charset)]) end
        return table.concat(t)
    end

    local replicatedStorage = game:GetService("ReplicatedStorage")
    local input = replicatedStorage.Network.Comms.Input

    chatSpamToggle:OnChanged(function(enabled)
        if enabled then
            if chatSpamConnection then chatSpamConnection:Disconnect() end
            chatSpamConnection = game:GetService("RunService").Heartbeat:Connect(function()
                input:FireServer(randomString())
            end)
        else
            if chatSpamConnection then chatSpamConnection:Disconnect() chatSpamConnection = nil end
        end
    end)

    -- ===== VIEWMODEL CHANGER =====
    local savedOffset = nil
    pcall(function()
        if readfile and writefile then
            local data = readfile("viewmodel_offset.json")
            if data then
                savedOffset = game:GetService("HttpService"):JSONDecode(data)
            end
        end
    end)
    if not savedOffset or type(savedOffset) ~= "table" then
        savedOffset = { x = 0, y = -0.3, z = 0 }
    end

    local vmToggle = miscGroup:AddToggle('ViewmodelChanger', {
        Text = 'Viewmodel Offset(ReEquip to Apply)',
        Default = false,
        Tooltip = 'Включает кастомное смещение модели оружия (сохраняется)'
    })

    local sliderX = miscGroup:AddSlider('ViewmodelX', {
        Text = 'X Offset',
        Min = -5, Max = 5, Default = savedOffset.x, Suffix = ' studs', Rounding = 3,
        Tooltip = 'Смещение вправо/влево'
    })
    local sliderY = miscGroup:AddSlider('ViewmodelY', {
        Text = 'Y Offset',
        Min = -5, Max = 5, Default = savedOffset.y, Suffix = ' studs', Rounding = 3,
        Tooltip = 'Смещение вверх/вниз'
    })
    local sliderZ = miscGroup:AddSlider('ViewmodelZ', {
        Text = 'Z Offset',
        Min = -5, Max = 5, Default = savedOffset.z, Suffix = ' studs', Rounding = 3,
        Tooltip = 'Смещение ближе/дальше'
    })

    local function saveViewmodelOffset()
        local data = { x = sliderX.Value, y = sliderY.Value, z = sliderZ.Value }
        pcall(function()
            if writefile then
                writefile("viewmodel_offset.json", game:GetService("HttpService"):JSONEncode(data))
            end
        end)
    end

    local vmHeartbeat = nil
    local function applyVmOffset()
        local player = game.Players.LocalPlayer
        if not player then return end
        local offset = Vector3.new(sliderX.Value, sliderY.Value, sliderZ.Value)

        local function setOffsetOnTools(container)
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") then
                        tool:SetAttribute("CustomViewmodelOffset", offset)
                    end
                end
            end
        end

        local char = player.Character
        if char then setOffsetOnTools(char) end
        setOffsetOnTools(player:FindFirstChild("Backpack"))
    end

    local function updateVmHeartbeat()
        if vmHeartbeat then vmHeartbeat:Disconnect() vmHeartbeat = nil end
        if vmToggle.Value then
            vmHeartbeat = game:GetService("RunService").Heartbeat:Connect(applyVmOffset)
        end
    end

    sliderX:OnChanged(function(value) saveViewmodelOffset() applyVmOffset() end)
    sliderY:OnChanged(function(value) saveViewmodelOffset() applyVmOffset() end)
    sliderZ:OnChanged(function(value) saveViewmodelOffset() applyVmOffset() end)

    vmToggle:OnChanged(function(enabled)
        if enabled then
            updateVmHeartbeat()
        else
            if vmHeartbeat then vmHeartbeat:Disconnect() vmHeartbeat = nil end
            local player = game.Players.LocalPlayer
            if player then
                local function resetOffset(container)
                    if container then
                        for _, tool in ipairs(container:GetChildren()) do
                            if tool:IsA("Tool") then tool:SetAttribute("CustomViewmodelOffset", nil) end
                        end
                    end
                end
                resetOffset(player.Character)
                resetOffset(player:FindFirstChild("Backpack"))
            end
        end
    end)

    if vmToggle.Value then updateVmHeartbeat() end

    -- ===== INSTANT PROMPT =====
    local instantPromptActive = false
    miscGroup:AddButton('Instant Prompt', function()
        if instantPromptActive then return end
        instantPromptActive = true
        local workspace = game:GetService("Workspace")
        local function processPrompt(prompt)
            if prompt:IsA("ProximityPrompt") then prompt.HoldDuration = 0 end
        end
        for _, prompt in ipairs(workspace:GetDescendants()) do processPrompt(prompt) end
        workspace.DescendantAdded:Connect(processPrompt)
        Library:Notify("Instant Prompt активирован. Все промты теперь мгновенные.", 2)
    end)

    -- ===== NO BLACK SCREEN =====
    local noBlackScreenActive = false
    miscGroup:AddButton('No Black Screen', function()
        if noBlackScreenActive then return end
        noBlackScreenActive = true
        local player = game:GetService("Players").LocalPlayer
        local playerScripts = player:WaitForChild("PlayerScripts", 5)
        if not playerScripts then
            Library:Notify("PlayerScripts не найдены.", 3)
            return
        end
        local deathScreen = playerScripts:FindFirstChild("DeathScrean")
        if deathScreen and deathScreen:IsA("LocalScript") then deathScreen:Destroy() end
        playerScripts.ChildAdded:Connect(function(child)
            if child.Name == "DeathScrean" and child:IsA("LocalScript") then child:Destroy() end
        end)
        Library:Notify("No Black Screen активирован. DeathScrean будет удаляться.", 2)
    end)

    -- ===== AUTO PASS TEST =====
    miscGroup:AddButton('Auto Pass Test', function()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local startTestRemote = replicatedStorage.Remotes.StartTest
        local player = game.Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui")

        startTestRemote.OnClientEvent:Connect(function(testId)
            startTestRemote:FireServer(testId, true)
            Library:Notify("Test passed automatically!", 2)

            local ui = playerGui:FindFirstChild("UI")
            if ui then
                local milTest = ui:FindFirstChild("MilTest")
                if milTest and milTest:IsA("Frame") then milTest.Visible = false end
            end
        end)

        Library:Notify("Auto pass test activated. The next test will be completed instantly.", 2)
    end)

    -- =====================================================
    -- ESP GROUP (Car ESP) – SurfaceGui на DriveSeat
    -- =====================================================
    local espGroup = shopTab:AddLeftGroupbox('ESP')
    local workspace = game:GetService("Workspace")

    -- Car Highlight toggle
    local carHighlightToggle = espGroup:AddToggle('CarHighlightToggle', {
        Text = 'Car Highlight',
        Default = false,
        Tooltip = 'Включает подсветку машин'
    })

    espGroup:AddLabel('Fill Color'):AddColorPicker('CarHighlightFillColor', { Default = Color3.fromRGB(255, 0, 0) })
    espGroup:AddLabel('Outline Color'):AddColorPicker('CarHighlightOutlineColor', { Default = Color3.fromRGB(255, 255, 255) })

    local fillTransSlider = espGroup:AddSlider('CarHighlightFillTrans', {
        Text = 'Fill Transparency',
        Min = 0, Max = 1, Default = 0.5, Rounding = 2, Suffix = ''
    })
    local outlineTransSlider = espGroup:AddSlider('CarHighlightOutlineTrans', {
        Text = 'Outline Transparency',
        Min = 0, Max = 1, Default = 0, Rounding = 2, Suffix = ''
    })

    -- Car Info toggles
    local showOwnerToggle = espGroup:AddToggle('ShowOwnerToggle', { Text = 'Show Owner', Default = true })
    local showNameToggle = espGroup:AddToggle('ShowNameToggle', { Text = 'Show Name', Default = true })
    local showHPToggle = espGroup:AddToggle('ShowHPToggle', { Text = 'Show HP', Default = true })

    local textSizeSlider = espGroup:AddSlider('CarInfoTextSize', {
        Text = 'Text Size', Min = 8, Max = 48, Default = 14, Rounding = 0
    })
    espGroup:AddLabel('Text Color'):AddColorPicker('CarInfoTextColor', { Default = Color3.fromRGB(255, 255, 255) })

    -- Вспомогательные таблицы
    local carModels = {}
    local ownerNames = {}

    local function getOwnerName(userId)
        if not userId or userId == 0 then return "None" end
        if not ownerNames[userId] then
            local success, name = pcall(function()
                return game.Players:GetNameFromUserIdAsync(userId)
            end)
            ownerNames[userId] = (success and name) or "?"
        end
        return ownerNames[userId]
    end

    local function addCarHighlight(carModel)
        local hl = Instance.new("Highlight")
        hl.Name = "CarHighlight"
        hl.FillColor = Options.CarHighlightFillColor.Value or Color3.fromRGB(255, 0, 0)
        hl.OutlineColor = Options.CarHighlightOutlineColor.Value or Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = fillTransSlider.Value
        hl.OutlineTransparency = outlineTransSlider.Value
        hl.Parent = carModel
    end

    local function removeCarHighlight(carModel)
        local hl = carModel:FindFirstChild("CarHighlight")
        if hl then hl:Destroy() end
    end

    local function updateHighlight(carModel)
        local hl = carModel:FindFirstChild("CarHighlight")
        if not hl then return end
        hl.FillColor = Options.CarHighlightFillColor.Value or Color3.fromRGB(255, 0, 0)
        hl.OutlineColor = Options.CarHighlightOutlineColor.Value or Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = fillTransSlider.Value
        hl.OutlineTransparency = outlineTransSlider.Value
    end

    local function createOrUpdateLabel(carModel)
        local showOwner = showOwnerToggle.Value
        local showName = showNameToggle.Value
        local showHP = showHPToggle.Value
        local anyInfo = showOwner or showName or showHP
        local gui = carModel:FindFirstChild("CarInfoGUI")

        if not anyInfo then
            if gui then gui:Destroy() end
            return
        end

        -- Ищем DriveSeat (VehicleSeat или BasePart) для Adornee
        local driveSeat = carModel:FindFirstChild("DriveSeat")
        if not (driveSeat and (driveSeat:IsA("VehicleSeat") or driveSeat:IsA("BasePart"))) then
            -- Если сиденье не найдено, просто ничего не делаем
            return
        end

        -- Формируем текст
        local parts = {}
        if showOwner then
            table.insert(parts, getOwnerName(carModel:GetAttribute("VehicleOwnerUserId") or 0))
        end
        if showName then
            table.insert(parts, carModel.Name)
        end
        if showHP then
            local hp = carModel:GetAttribute("VehicleHp")
            table.insert(parts, hp and tostring(hp) or "?")
        end
        local text = "[" .. table.concat(parts, " | ") .. "]"

        local textColor = Options.CarInfoTextColor.Value or Color3.fromRGB(255, 255, 255)
        local textSize = textSizeSlider.Value

        if not gui then
            gui = Instance.new("SurfaceGui")
            gui.Name = "CarInfoGUI"
            gui.AlwaysOnTop = true
            gui.Adornee = driveSeat  -- теперь это точно BasePart или VehicleSeat
            gui.Face = Enum.NormalId.Front
            gui.CanvasSize = UDim2.new(0, 300, 0, 50) -- фиксированный размер холста
            gui.Parent = carModel

            local frame = Instance.new("Frame")
            frame.BackgroundTransparency = 1
            frame.Size = UDim2.new(1, 0, 1, 0)
            frame.Parent = gui

            local label = Instance.new("TextLabel")
            label.Name = "InfoLabel"
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, 0, 1, 0)
            label.Text = text
            label.TextColor3 = textColor
            label.TextSize = textSize
            label.Font = Enum.Font.SourceSansBold
            label.TextStrokeTransparency = 0.5
            label.Parent = frame
        else
            local label = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("InfoLabel")
            if label then
                label.Text = text
                label.TextColor3 = textColor
                label.TextSize = textSize
            end
        end
    end

    local function updateAllLabels()
        for _, car in ipairs(carModels) do
            pcall(createOrUpdateLabel, car)
        end
    end

    local function updateAllHighlights()
        if carHighlightToggle.Value then
            for _, car in ipairs(carModels) do
                updateHighlight(car)
            end
        end
    end

    local function onCarAdded(car)
        if not car:IsA("Model") then return end
        table.insert(carModels, car)
        if carHighlightToggle.Value then
            addCarHighlight(car)
        end
        createOrUpdateLabel(car)
        car:GetAttributeChangedSignal("VehicleHp"):Connect(function()
            pcall(createOrUpdateLabel, car)
        end)
        car:GetAttributeChangedSignal("VehicleOwnerUserId"):Connect(function()
            pcall(createOrUpdateLabel, car)
        end)
    end

    local function onCarRemoved(car)
        for i, m in ipairs(carModels) do
            if m == car then table.remove(carModels, i) break end
        end
        removeCarHighlight(car)
        local gui = car:FindFirstChild("CarInfoGUI")
        if gui then gui:Destroy() end
    end

    -- Запускаем мониторинг LiveCars с отложенным сканированием
    task.defer(function()
        local liveCars = workspace:FindFirstChild("LiveCars")
        if liveCars then
            for _, child in ipairs(liveCars:GetChildren()) do
                if child:IsA("Model") then onCarAdded(child) end
            end
            liveCars.ChildAdded:Connect(function(c) if c:IsA("Model") then onCarAdded(c) end end)
            liveCars.ChildRemoved:Connect(function(c) if c:IsA("Model") then onCarRemoved(c) end end)
        end
    end)

    -- Подписки на изменения настроек
    carHighlightToggle:OnChanged(function(enabled)
        for _, car in ipairs(carModels) do
            if enabled then addCarHighlight(car) else removeCarHighlight(car) end
        end
    end)

    Options.CarHighlightFillColor:OnChanged(updateAllHighlights)
    Options.CarHighlightOutlineColor:OnChanged(updateAllHighlights)
    fillTransSlider:OnChanged(updateAllHighlights)
    outlineTransSlider:OnChanged(updateAllHighlights)

    showOwnerToggle:OnChanged(updateAllLabels)
    showNameToggle:OnChanged(updateAllLabels)
    showHPToggle:OnChanged(updateAllLabels)
    textSizeSlider:OnChanged(updateAllLabels)
    Options.CarInfoTextColor:OnChanged(updateAllLabels)

    -- =====================================================
    -- СИСТЕМА МОДИФИКАЦИИ ОРУЖИЯ (ОТЛОЖЕННЫЙ ПЕРЕХВАТ) – без lifesteal и tracer
    -- =====================================================
    local activeMods = {
        rapidFire = false,
        noSpread = false,
        instaEquip = false,
        allAuto = false,
        autoReload = false,
        noReloadTime = false,
        infBulletSpeed = false,
        infReserve = false,
        slowAnim = false,
        explosionRadius = nil
    }

    local originalSettingsCache = {}
    local requireHooked = false
    local oldRequire = nil

    local function applyMods(original)
        local copy = {}
        for k, v in pairs(original) do copy[k] = v end

        if activeMods.rapidFire then copy.FireRate = 0 end
        if activeMods.noSpread then copy.Spread = 0; copy.Recoil = 0 end
        if activeMods.instaEquip then copy.EquipTime = 0 end
        if activeMods.allAuto then copy.Auto = true end
        if activeMods.autoReload then copy.AutoReload = true end
        if activeMods.noReloadTime then copy.ReloadTime = 0 end
        if activeMods.infBulletSpeed then copy.BulletSpeed = 9999 end
        if activeMods.infReserve then copy.MaxAmmo = 99999 end
        if activeMods.slowAnim then
            copy.IdleAnimationSpeed = 0.1
            copy.RunAnimationSpeed = 0.1
            copy.FireAnimationSpeed = 0.1
            copy.ReloadAnimationSpeed = 0.1
            copy.EquippedAnimationSpeed = 0.1
            copy.SecondaryFireAnimationSpeed = 0.1
            copy.AimIdleAnimationSpeed = 0.1
            copy.AimFireAnimationSpeed = 0.1
            copy.AimSecondaryFireAnimationSpeed = 0.1
            copy.HoldDownAnimationSpeed = 0.1
            copy.SpinaAnimationSpeed = 0.1
            copy.TacticalReloadAnimationSpeed = 0.1
            copy.ShotgunClipinAnimationSpeed = 0.1
            copy.ShotgunPumpinAnimationSpeed = 0.1
            copy.SecondaryShotgunPumpinAnimationSpeed = 0.1
            copy.InspectAnimationSpeed = 0.1
        end
        if type(activeMods.explosionRadius) == "number" then
            copy.ExplosionRadius = activeMods.explosionRadius
        end

        return copy
    end

    local function restartGunScript(tool)
        if not tool or not tool:IsA("Tool") then return end
        local localScript = tool:FindFirstChildWhichIsA("LocalScript")
        if localScript then
            localScript.Disabled = true
            task.wait(0.05)
            localScript.Disabled = false
        end
    end

    local function refreshAllWeapons()
        local player = game.Players.LocalPlayer
        if not player then return end
        local char = player.Character
        local bp = player:FindFirstChild("Backpack")
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then restartGunScript(tool) end
            end
        end
        if bp then
            for _, tool in ipairs(bp:GetChildren()) do
                if tool:IsA("Tool") then restartGunScript(tool) end
            end
        end
    end

    local function ensureRequireHooked()
        if requireHooked then return end
        requireHooked = true

        oldRequire = hookfunction(require, function(moduleScript)
            if moduleScript:IsA("ModuleScript") and moduleScript.Name == "Setting" then
                local parent = moduleScript.Parent
                while parent and not parent:IsA("Tool") do parent = parent.Parent end
                if parent and parent:IsA("Tool") then
                    if not originalSettingsCache[moduleScript] then
                        local original = oldRequire(moduleScript)
                        if type(original) == "table" then
                            originalSettingsCache[moduleScript] = original
                        end
                    end
                    if originalSettingsCache[moduleScript] then
                        return applyMods(originalSettingsCache[moduleScript])
                    end
                end
            end
            return oldRequire(moduleScript)
        end)

        refreshAllWeapons()
    end

    local function enableMod(modName)
        if activeMods[modName] then return end
        activeMods[modName] = true
        ensureRequireHooked()
        refreshAllWeapons()
    end

    -- ===== Enable All Gun Mods =====
    miscGroup:AddButton('Enable All Gun Mods', function()
        enableMod('rapidFire')
        enableMod('noSpread')
        enableMod('instaEquip')
        enableMod('allAuto')
        enableMod('autoReload')
        enableMod('noReloadTime')
        enableMod('infBulletSpeed')
        enableMod('infReserve')
        enableMod('slowAnim')
        
        if not infMagRemoteActive then
            infMagRemoteActive = true
            local player = game.Players.LocalPlayer
            task.spawn(function()
                while infMagRemoteActive do
                    local char = player.Character
                    if char then
                        local tool = char:FindFirstChildWhichIsA("Tool")
                        if tool then
                            local gunServer = tool:FindFirstChild("GunScript_Server")
                            if gunServer then
                                local changeAmmo = gunServer:FindFirstChild("ChangeMagAndAmmo")
                                if changeAmmo then
                                    pcall(function()
                                        changeAmmo:FireServer(999, 9999)
                                    end)
                                end
                            end
                        end
                    end
                    task.wait(0)
                end
            end)
        end
        
        Library:Notify("All gun mods enabled!", 2)
    end)

    miscGroup:AddDivider()
    -- ===== КНОПКИ МОДОВ ОРУЖИЯ =====
    miscGroup:AddButton('Rapid Fire', function() enableMod('rapidFire') Library:Notify("Rapid Fire (FireRate=0) включён", 2) end)
    miscGroup:AddButton('No Spread', function() enableMod('noSpread') Library:Notify("No Spread (Recoil & Spread=0) включён", 2) end)
    miscGroup:AddButton('Insta Equip', function() enableMod('instaEquip') Library:Notify("Insta Equip (EquipTime=0) включён", 2) end)
    miscGroup:AddButton('All Auto', function() enableMod('allAuto') Library:Notify("All Auto включён (все оружия авто)", 2) end)
    miscGroup:AddButton('Auto Reload', function() enableMod('autoReload') Library:Notify("Auto Reload (AutoReload=true) включён", 2) end)
    miscGroup:AddButton('No Reload Time', function() enableMod('noReloadTime') Library:Notify("No Reload Time (ReloadTime=0) включён", 2) end)
    miscGroup:AddButton('Inf Bullet Speed', function() enableMod('infBulletSpeed') Library:Notify("Inf Bullet Speed (BulletSpeed=9999) включён", 2) end)
    miscGroup:AddButton('Inf ReserveAmmo', function() enableMod('infReserve') Library:Notify("Inf Reserve Ammo (MaxAmmo=99999) включён", 2) end)
    miscGroup:AddButton('Slow Anim', function() enableMod('slowAnim') Library:Notify("Slow Anim (все скорости анимаций 0.1) включён", 2) end)

    -- ===== INF MAGAZINE (REMOTE) =====
    local infMagRemoteActive = false
    miscGroup:AddButton('Inf MagazineAmmo', function()
        if infMagRemoteActive then return end
        infMagRemoteActive = true
        local player = game.Players.LocalPlayer
        task.spawn(function()
            while infMagRemoteActive do
                local char = player.Character
                if char then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool then
                        local gunServer = tool:FindFirstChild("GunScript_Server")
                        if gunServer then
                            local changeAmmo = gunServer:FindFirstChild("ChangeMagAndAmmo")
                            if changeAmmo then
                                pcall(function()
                                    changeAmmo:FireServer(999, 9999)
                                end)
                            end
                        end
                    end
                end
                task.wait(0)
            end
        end)
        Library:Notify("Inf Magazine активирован. Магазин и запас постоянно полны.", 2)
    end)

    -- ===== AT4 EXPLOSION RADIUS (TEXTBOX) =====
    local explosionRadiusInput = miscGroup:AddInput('AT4ExplosionRadius', {
        Text = 'AT4 Explosion Radius',
        Default = '',
        Placeholder = 'Введи радиус взрыва (например 8)',
        Numeric = true,
        Finished = true,
        Tooltip = 'Устанавливает ExplosionRadius для всех оружий'
    })

    explosionRadiusInput:OnChanged(function(value)
        local num = tonumber(value)
        if num then
            activeMods.explosionRadius = num
        else
            activeMods.explosionRadius = nil
        end
        if requireHooked then
            refreshAllWeapons()
        else
            ensureRequireHooked()
        end
        Library:Notify("Радиус взрыва установлен на " .. (num and tostring(num) or "нет"), 2)
    end)

    -- ===== АВТО-БАЙ =====
    local currentNPCId = "Smugglers"
    local currentConfig = nil
    local products = {}
    local remoteEvent = nil
    local uiElements = {}
    
    local autoBuyEnabled = false
    local selectedItems = {}
    local autoBuyConnection = nil
    local itemMappings = {}
    
    local function getRemoteEvent()
        if remoteEvent then return remoteEvent end
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local network = replicatedStorage:FindFirstChild("Network")
        if network then
            local npcShop = network:FindFirstChild("NPCShop")
            if npcShop then
                remoteEvent = npcShop:FindFirstChild("Update")
            end
        end
        return remoteEvent
    end
    
    local function findRealToolName(shopName)
        local player = game.Players.LocalPlayer
        local containers = { player.Character, player:FindFirstChild("Backpack") }
        
        local shopLower = string.lower(shopName)
        for _, container in ipairs(containers) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") then
                        local toolLower = string.lower(tool.Name)
                        if string.find(toolLower, shopLower, 1, true) then
                            return tool.Name
                        end
                    end
                end
            end
        end
        return nil
    end
    
    local function updateMappingsFromInventory()
        for shopName, _ in pairs(selectedItems) do
            if not itemMappings[shopName] then
                local realName = findRealToolName(shopName)
                if realName then
                    itemMappings[shopName] = realName
                    Library:Notify(string.format("Mapped (existing): '%s' -> '%s'", shopName, realName), 2)
                end
            end
        end
    end
    
    local function getRealItemName(shopName)
        return itemMappings[shopName] or shopName
    end
    
    local function hasItem(shopName)
        local realName = getRealItemName(shopName)
        local player = game.Players.LocalPlayer
        if not player then return false end
        
        local character = player.Character
        if character and character:FindFirstChild(realName) then
            return true
        end
        
        local backpack = player:FindFirstChild("Backpack")
        if backpack and backpack:FindFirstChild(realName) then
            return true
        end
        
        if not itemMappings[shopName] then
            local found = findRealToolName(shopName)
            if found then
                itemMappings[shopName] = found
                Library:Notify(string.format("Auto-mapped: '%s' -> '%s'", shopName, found), 2)
                return true
            end
        end
        
        return false
    end
    
    local function waitForNewItem(shopName, timeout)
        local player = game.Players.LocalPlayer
        local startTime = tick()
        local shopLower = string.lower(shopName)
        
        local existingTools = {}
        local function collectTools(container)
            if not container then return end
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    existingTools[tool] = true
                end
            end
        end
        collectTools(player.Character)
        collectTools(player:FindFirstChild("Backpack"))
        
        while tick() - startTime < timeout do
            local function findNewMatchingTool()
                for _, container in ipairs({ player.Character, player:FindFirstChild("Backpack") }) do
                    if container then
                        for _, tool in ipairs(container:GetChildren()) do
                            if tool:IsA("Tool") and not existingTools[tool] then
                                local toolLower = string.lower(tool.Name)
                                if string.find(toolLower, shopLower, 1, true) then
                                    return tool.Name
                                end
                            end
                        end
                    end
                end
                return nil
            end
            
            local newName = findNewMatchingTool()
            if newName then
                if newName ~= shopName then
                    itemMappings[shopName] = newName
                    Library:Notify(string.format("Learned real name: '%s' -> '%s'", shopName, newName), 2)
                end
                return newName
            end
            task.wait(0.05)
        end
        return nil
    end
    
    local function purchaseItem(shopName, data)
        local player = game.Players.LocalPlayer
        local leaderstats = player:FindFirstChild("leaderstats")
        local cashStat = leaderstats and leaderstats:FindFirstChild("Cash")
        if not cashStat then
            Library:Notify("Cash stat not found", 3)
            return false
        end
        
        local price = data.Price or 0
        if cashStat.Value >= price then
            local remote = getRemoteEvent()
            if remote then
                remote:FireServer(currentNPCId, shopName)
                Library:Notify("Purchase request sent for " .. shopName, 2)
                if not itemMappings[shopName] then
                    task.spawn(function() waitForNewItem(shopName, 3) end)
                end
                return true
            else
                Library:Notify("Remote event not found", 3)
                return false
            end
        else
            Library:Notify("Not enough Cash! Required: " .. price, 3)
            return false
        end
    end
    
    local function startAutoBuy()
        if autoBuyConnection then
            autoBuyConnection:Disconnect()
            autoBuyConnection = nil
        end
        if not autoBuyEnabled then return end
        
        autoBuyConnection = game:GetService("RunService").Stepped:Connect(function()
            if not autoBuyEnabled then return end
            for shopName, isSelected in pairs(selectedItems) do
                if isSelected and products[shopName] then
                    if not hasItem(shopName) then
                        purchaseItem(shopName, products[shopName])
                        task.wait(0.1)
                    end
                end
            end
        end)
    end
    
    local function loadConfig()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local data = replicatedStorage:FindFirstChild("Data")
        if not data then
            Library:Notify("Data folder not found", 3)
            return false
        end
        local gameplay = data:FindFirstChild("Gameplay")
        if not gameplay then
            Library:Notify("Gameplay folder not found", 3)
            return false
        end
        local npcFolder = gameplay:FindFirstChild("NPC")
        if not npcFolder then
            Library:Notify("NPC folder not found", 3)
            return false
        end
        
        local npcModule = npcFolder:FindFirstChild(currentNPCId)
        if not npcModule then
            Library:Notify("NPC not found: " .. currentNPCId, 3)
            return false
        end
        
        local configScript = npcModule:FindFirstChild("Config") or npcModule:FindFirstChild("ShopConfig")
        if not configScript then
            Library:Notify("Config not found in NPC", 3)
            return false
        end
        
        local success, config = pcall(require, configScript)
        if not success then
            Library:Notify("Failed to load config: " .. tostring(config), 3)
            return false
        end
        
        currentConfig = config
        local sourceProducts = config.Products or (config.Data and config.Data.Products) or {}
        
        products = {}
        for name, data in pairs(sourceProducts) do
            if data.Price then
                products[name] = data
            end
        end
        
        local count = 0
        for _ in pairs(products) do count = count + 1 end
        Library:Notify("Loaded NPC: " .. (config.Visuals and config.Visuals.DisplayName or currentNPCId) .. " | Items: " .. count, 2)
        
        local itemNames = {}
        for name in pairs(products) do
            table.insert(itemNames, name)
        end
        if Options.ItemsDropdown then
            Options.ItemsDropdown:SetValues(itemNames)
        end
        
        return true
    end
    
    local function rebuildItemsUI()
        for _, element in ipairs(uiElements) do
            pcall(function() element:Destroy() end)
        end
        uiElements = {}
        
        if not currentConfig or next(products) == nil then
            local noItemsLabel = itemsGroup:AddLabel("No items found.")
            table.insert(uiElements, noItemsLabel)
            return
        end
        
        local LocalPlayer = game.Players.LocalPlayer
        
        for shopName, data in pairs(products) do
            local priceText = "Price: " .. tostring(data.Price) .. " Cash"
            if data.CurrencyType == "Event" then
                priceText = "Price: " .. tostring(data.Price) .. " Event"
            end
            
            local priceLabel = itemsGroup:AddLabel(priceText)
            table.insert(uiElements, priceLabel)
            
            local btn = itemsGroup:AddButton({
                Text = shopName,
                Func = function()
                    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                    local cashStat = leaderstats and leaderstats:FindFirstChild("Cash")
                    if cashStat and cashStat.Value >= data.Price then
                        local remote = getRemoteEvent()
                        if remote then
                            remote:FireServer(currentNPCId, shopName)
                            Library:Notify("Purchase request sent for " .. shopName, 2)
                            if not itemMappings[shopName] then
                                task.spawn(function() waitForNewItem(shopName, 3) end)
                            end
                        else
                            Library:Notify("Remote event not found", 3)
                        end
                    else
                        Library:Notify("Not enough Cash! Required: " .. data.Price, 3)
                    end
                end,
                Tooltip = data.Desc or "Click to buy"
            })
            table.insert(uiElements, btn)
        end
    end
    
    -- ============ UI (LinoriaLib) ============
    local autoBuyToggle = configGroup:AddToggle('AutoBuyToggle', {
        Text = 'Auto Buy',
        Default = false,
        Tooltip = 'Automatically buy selected items if not owned'
    })
    
    local itemsDropdown = configGroup:AddDropdown('ItemsDropdown', {
        Text = 'Items to Auto Buy',
        Values = {},
        Multi = true,
        Default = {},
        Tooltip = 'Select items to auto-buy'
    })
    
    autoBuyToggle:OnChanged(function()
        autoBuyEnabled = autoBuyToggle.Value
        if autoBuyEnabled then
            updateMappingsFromInventory()
            startAutoBuy()
        else
            if autoBuyConnection then
                autoBuyConnection:Disconnect()
                autoBuyConnection = nil
            end
        end
    end)
    
    itemsDropdown:OnChanged(function()
        selectedItems = itemsDropdown.Value
        if autoBuyEnabled then
            updateMappingsFromInventory()
        end
    end)
    
    task.spawn(function()
        task.wait(1)
        if loadConfig() then
            rebuildItemsUI()
            selectedItems = {}
        end
    end)
    
    Library:Notify("ShopManager loaded. All items are purchased with cash (GamePass ignored).", 3)
end

return ShopManager
