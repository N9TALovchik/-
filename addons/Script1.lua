local ShopManager = {}

function ShopManager:Init(Window, Tabs)
    assert(Window, "ShopManager: Window is required")
    assert(Library, "Library must be loaded before ShopManager")
    
    local shopTab = Window:AddTab('Arrp')
    Tabs.Shop = shopTab
    
    local configGroup = shopTab:AddLeftGroupbox('Auto Buy Settings')
    local itemsGroup = shopTab:AddRightGroupbox('Shop Items')
    
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

    _G.SpinbotEnabled = false
    _G.SpinbotSpeed = 180

    local spinbotToggle = miscGroup:AddToggle('SpinbotToggle', {
        Text = 'Spinbot',
        Default = false,
        Tooltip = 'Вращает персонажа (чистый CFrame). Может мешать движению.'
    })

    local spinbotSpeedSlider = miscGroup:AddSlider('SpinbotSpeed', {
        Text = 'Spin Speed',
        Min = 10,
        Max = 3000,
        Default = 180,
        Rounding = 0,
        Suffix = '°/s',
        Tooltip = 'Скорость вращения (градусов в секунду)'
    })

    local spinbotConnection = nil
    local savedAutoRotate = nil

    local function setAutoRotate(enabled)
        local char = game.Players.LocalPlayer.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate = enabled
        end
    end

    local function toggleSpinbot()
        if spinbotConnection then
            spinbotConnection:Disconnect()
            spinbotConnection = nil
        end
        if savedAutoRotate ~= nil then
            setAutoRotate(savedAutoRotate)
            savedAutoRotate = nil
        end

        if not _G.SpinbotEnabled then return end

        local player = game.Players.LocalPlayer
        spinbotConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
            local char = player.Character
            if not char then return end
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            if humanoid.SeatPart then
                if savedAutoRotate ~= nil then
                    setAutoRotate(savedAutoRotate)
                    savedAutoRotate = nil
                end
                return
            end

            if savedAutoRotate == nil then
                savedAutoRotate = humanoid.AutoRotate
                humanoid.AutoRotate = false
            end

            local angle = math.rad(_G.SpinbotSpeed * dt)
            root.CFrame = root.CFrame * CFrame.Angles(0, angle, 0)
        end)
    end

    spinbotToggle:OnChanged(function(enabled)
        _G.SpinbotEnabled = enabled
        toggleSpinbot()
    end)

    spinbotSpeedSlider:OnChanged(function(value)
        _G.SpinbotSpeed = value
    end)

    local deathSpawnToggle = miscGroup:AddToggle('DeathSpawnToggle', {
        Text = 'Death Spawn',
        Default = false,
        Tooltip = 'Возрождаться там же, где умер (позиция обновляется при каждой смерти)'
    })
    local lastDeathPos = nil
    local deathSpawnConnections = {}

    local function enableDeathSpawn()
        local player = game.Players.LocalPlayer
        local charAddedConn = player.CharacterAdded:Connect(function(char)
            if lastDeathPos then
                local hrp = char:WaitForChild("HumanoidRootPart", 2)
                if hrp then
                    hrp.CFrame = CFrame.new(lastDeathPos)
                end
            end
            local humanoid = char:WaitForChild("Humanoid", 5)
            if humanoid then
                local diedConn = humanoid.Died:Connect(function()
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        lastDeathPos = root.Position
                    end
                end)
                table.insert(deathSpawnConnections, diedConn)
            end
        end)
        table.insert(deathSpawnConnections, charAddedConn)

        if player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                local diedConn = humanoid.Died:Connect(function()
                    local root = player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        lastDeathPos = root.Position
                    end
                end)
                table.insert(deathSpawnConnections, diedConn)
            end
        end
    end

    local function disableDeathSpawn()
        for _, conn in ipairs(deathSpawnConnections) do
            conn:Disconnect()
        end
        deathSpawnConnections = {}
        lastDeathPos = nil
    end

    deathSpawnToggle:OnChanged(function(enabled)
        if enabled then
            enableDeathSpawn()
        else
            disableDeathSpawn()
        end
    end)

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


    -- ============================================================
    -- BUTTON: OPEN/CLOSE ARSENAL UI
    -- ============================================================
    miscGroup:AddButton('Toggle Arsenal', function()
        local playerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end
        local arsenalUI = playerGui:FindFirstChild("ArsenalUI")
        if arsenalUI then
            local main = arsenalUI:FindFirstChild("Main")
            if main then
                main.Visible = not main.Visible
                if main.Visible then
                    local event = arsenalUI:FindFirstChild("Event")
                    if event and event:IsA("BindableEvent") then
                        event:Fire("Open")
                    end
                end
                Library:Notify(main.Visible and "Arsenal opened" or "Arsenal closed", 2)
            else
                Library:Notify("ArsenalUI Main not found", 3)
            end
        else
            Library:Notify("ArsenalUI not found", 3)
        end
    end)

    -- ============================================================
    -- BUTTON: OPEN/CLOSE WARDROBE UI
    -- ============================================================
    miscGroup:AddButton('Toggle Wardrobe', function()
        local playerGui = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
        if not playerGui then return end
        local wardrobe = playerGui:FindFirstChild("Wardrobe")
        if wardrobe then
            local main = wardrobe:FindFirstChild("Main")
            if main then
                main.Visible = not main.Visible
                Library:Notify(main.Visible and "Wardrobe opened" or "Wardrobe closed", 2)
            else
                Library:Notify("Wardrobe Main not found", 3)
            end
        else
            Library:Notify("Wardrobe UI not found", 3)
        end
    end)

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
    -- ESP GROUP (Car ESP) – с Local Check
    -- =====================================================
    local espGroup = shopTab:AddLeftGroupbox('ESP')
    local workspace = game:GetService("Workspace")
    local runService = game:GetService("RunService")

    local carHighlightToggle = espGroup:AddToggle('CarHighlightToggle', {
        Text = 'Car Highlight',
        Default = false,
        Tooltip = 'Включает подсветку и текст над машинами'
    })
    espGroup:AddLabel('Fill Color'):AddColorPicker('CarHighlightFillColor', { Default = Color3.fromRGB(255, 0, 0) })
    espGroup:AddLabel('Outline Color'):AddColorPicker('CarHighlightOutlineColor', { Default = Color3.fromRGB(255, 255, 255) })
    local fillTransSlider = espGroup:AddSlider('CarHighlightFillTrans', {
        Text = 'Fill Transparency', Min = 0, Max = 1, Default = 0.5, Rounding = 2, Suffix = ''
    })
    local outlineTransSlider = espGroup:AddSlider('CarHighlightOutlineTrans', {
        Text = 'Outline Transparency', Min = 0, Max = 1, Default = 0, Rounding = 2, Suffix = ''
    })

    local showOwnerToggle = espGroup:AddToggle('ShowOwnerToggle', { Text = 'Show Owner', Default = true })
    local showNameToggle = espGroup:AddToggle('ShowNameToggle', { Text = 'Show Name', Default = true })
    local showHPToggle = espGroup:AddToggle('ShowHPToggle', { Text = 'Show HP', Default = true })
    local strokeSizeSlider = espGroup:AddSlider('CarInfoTextSize', {
        Text = 'Stroke Size', Min = 8, Max = 48, Default = 8, Rounding = 0
    })
    espGroup:AddLabel('Text Color'):AddColorPicker('CarInfoTextColor', { Default = Color3.fromRGB(255, 255, 255) })

    -- ===== CAR ESP LOCAL CHECK (скрывать ESP для машины локального игрока) =====
    local localCheckToggle = espGroup:AddToggle('CarESPLocalCheck', {
        Text = 'Local Check',
        Default = false,
        Tooltip = 'Не показывать ESP на машине, в которой сидит локальный игрок'
    })
    _G.NOTALovchik_CarESPLocalOnly = false

    local carModels = {}
    local carDrawings = {}
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

    -- Функция получения текущей машины игрока
    local function getCurrentCar()
        local char = game.Players.LocalPlayer.Character
        if not char then return nil end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return nil end
        local seat = humanoid.SeatPart
        if not seat then return nil end
        local model = seat:FindFirstAncestorWhichIsA("Model")
        if model and model:FindFirstChild("Wheels") and (model:FindFirstChild("DriveSeat") or model:FindFirstChildWhichIsA("VehicleSeat")) then
            return model
        end
        return nil
    end

    local function updateCarDrawings(carModel, camera)
        local drawings = carDrawings[carModel]

        -- Если включён Local Check и это машина локального игрока – скрываем
        if localCheckToggle.Value and carModel == getCurrentCar() then
            if drawings then
                for _, d in pairs(drawings) do
                    d.Visible = false
                end
            end
            return
        end

        if not carHighlightToggle.Value then
            if drawings then
                for _, d in pairs(drawings) do
                    pcall(function() d:Remove() end)
                end
                carDrawings[carModel] = nil
            end
            return
        end

        local anyInfo = showOwnerToggle.Value or showNameToggle.Value or showHPToggle.Value
        if not anyInfo then
            if drawings then
                for _, d in pairs(drawings) do
                    pcall(function() d:Remove() end)
                end
                carDrawings[carModel] = nil
            end
            return
        end

        local primaryPart = carModel.PrimaryPart or carModel:FindFirstChild("DriveSeat") or carModel:FindFirstChildWhichIsA("BasePart")
        if not primaryPart then
            if drawings then
                for _, d in pairs(drawings) do
                    d.Visible = false
                end
            end
            return
        end

        local modelSize = carModel:GetExtentsSize()
        if modelSize.Magnitude == 0 then
            modelSize = Vector3.new(4, 2, 4)
        end

        local centerPos = primaryPart.Position
        local topPos = centerPos + Vector3.new(0, modelSize.Y * 0.5 + 1, 0)

        local screenTop, onScreen = camera:WorldToViewportPoint(topPos)
        local distance = (centerPos - camera.CFrame.Position).Magnitude
        if distance > 1000 then onScreen = false end

        if not onScreen then
            if drawings then
                for _, d in pairs(drawings) do
                    d.Visible = false
                end
            end
            return
        end

        if not drawings then
            drawings = {
                Owner = Drawing.new("Text"),
                Name = Drawing.new("Text"),
                HP = Drawing.new("Text")
            }
            for _, d in pairs(drawings) do
                d.Visible = false
                d.Center = true
                d.Outline = true
                d.Font = 2
            end
            carDrawings[carModel] = drawings
        end

        local textColor = Options.CarInfoTextColor.Value or Color3.fromRGB(255, 255, 255)
        local textSize = strokeSizeSlider.Value

        local ownerText = showOwnerToggle.Value and getOwnerName(carModel:GetAttribute("VehicleOwnerUserId") or 0) or nil
        local nameText = showNameToggle.Value and carModel.Name or nil
        local hpValue = tonumber(carModel:GetAttribute("VehicleHP")) or 0
        local maxHP = tonumber(carModel:GetAttribute("VehicleMaxHP")) or 1000
        local hpPercent = (maxHP > 0) and math.floor((hpValue / maxHP) * 100) or 0
        local hpText = showHPToggle.Value and (hpPercent .. "%") or nil

        local lineHeight = textSize * 1.5
        local startY = screenTop.Y - lineHeight

        if ownerText then
            drawings.Owner.Text = ownerText
            drawings.Owner.Position = Vector2.new(screenTop.X, startY)
            drawings.Owner.Color = textColor
            drawings.Owner.Size = textSize
            drawings.Owner.Visible = true
        else
            drawings.Owner.Visible = false
        end

        if nameText then
            drawings.Name.Text = nameText
            drawings.Name.Position = Vector2.new(screenTop.X, startY + lineHeight)
            drawings.Name.Color = textColor
            drawings.Name.Size = textSize
            drawings.Name.Visible = true
        else
            drawings.Name.Visible = false
        end

        if hpText then
            drawings.HP.Text = hpText
            drawings.HP.Position = Vector2.new(screenTop.X, startY + lineHeight * 2)
            drawings.HP.Color = textColor
            drawings.HP.Size = textSize
            drawings.HP.Visible = true
        else
            drawings.HP.Visible = false
        end
    end

    local function removeCarDrawings(carModel)
        local drawings = carDrawings[carModel]
        if drawings then
            for _, d in pairs(drawings) do
                pcall(function() d:Remove() end)
            end
            carDrawings[carModel] = nil
        end
    end

    local function onCarAdded(car)
        if not car:IsA("Model") then return end
        table.insert(carModels, car)
        if carHighlightToggle.Value then
            -- Если включён Local Check и это машина локального игрока – не добавляем хайлайт
            if not (localCheckToggle.Value and car == getCurrentCar()) then
                addCarHighlight(car)
            end
        end

        car:GetAttributeChangedSignal("VehicleDestroyed"):Connect(function()
            if car:GetAttribute("VehicleDestroyed") == true then
                onCarRemoved(car)
            end
        end)
        if car:GetAttribute("VehicleDestroyed") == true then
            onCarRemoved(car)
        end
    end

    local function onCarRemoved(car)
        for i, m in ipairs(carModels) do
            if m == car then table.remove(carModels, i) break end
        end
        removeCarHighlight(car)
        removeCarDrawings(car)
    end

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

    local updateConnection = nil
    local function startUpdateLoop()
        if updateConnection then return end
        updateConnection = runService.RenderStepped:Connect(function()
            local camera = workspace.CurrentCamera
            if not camera then return end
            for _, car in ipairs(carModels) do
                pcall(updateCarDrawings, car, camera)
            end
        end)
    end
    local function stopUpdateLoop()
        if updateConnection then
            updateConnection:Disconnect()
            updateConnection = nil
        end
    end

    local function checkLoop()
        if carHighlightToggle.Value and (showOwnerToggle.Value or showNameToggle.Value or showHPToggle.Value) then
            startUpdateLoop()
        else
            stopUpdateLoop()
        end
    end

    carHighlightToggle:OnChanged(function(enabled)
        for _, car in ipairs(carModels) do
            if enabled then
                if not (localCheckToggle.Value and car == getCurrentCar()) then
                    addCarHighlight(car)
                end
            else
                removeCarHighlight(car)
                removeCarDrawings(car)
            end
        end
        checkLoop()
    end)

    showOwnerToggle:OnChanged(checkLoop)
    showNameToggle:OnChanged(checkLoop)
    showHPToggle:OnChanged(checkLoop)

    local function redrawAll()
        if not updateConnection then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        for _, car in ipairs(carModels) do
            pcall(updateCarDrawings, car, camera)
        end
    end
    strokeSizeSlider:OnChanged(redrawAll)
    Options.CarInfoTextColor:OnChanged(redrawAll)

    local function updateAllHighlights()
        if carHighlightToggle.Value then
            for _, car in ipairs(carModels) do
                if not (localCheckToggle.Value and car == getCurrentCar()) then
                    updateHighlight(car)
                else
                    removeCarHighlight(car)
                end
            end
        end
    end
    Options.CarHighlightFillColor:OnChanged(updateAllHighlights)
    Options.CarHighlightOutlineColor:OnChanged(updateAllHighlights)
    fillTransSlider:OnChanged(updateAllHighlights)
    outlineTransSlider:OnChanged(updateAllHighlights)

    localCheckToggle:OnChanged(function(value)
        _G.NOTALovchik_CarESPLocalOnly = value
        updateAllHighlights()
        redrawAll()
        -- также нужно обновить текущие машины
        for _, car in ipairs(carModels) do
            if value and car == getCurrentCar() then
                removeCarHighlight(car)
                removeCarDrawings(car)
            elseif not value then
                if carHighlightToggle.Value then
                    addCarHighlight(car)
                end
                -- перерисуем
            end
        end
    end)

    -- отслеживаем смену машины
    local function onSeatChanged()
        task.wait(0.1)
        if localCheckToggle.Value then
            for _, car in ipairs(carModels) do
                if car == getCurrentCar() then
                    removeCarHighlight(car)
                    removeCarDrawings(car)
                elseif carHighlightToggle.Value then
                    addCarHighlight(car)
                end
            end
        end
    end

    local player = game.Players.LocalPlayer
    player.CharacterAdded:Connect(function(char)
        local humanoid = char:WaitForChild("Humanoid")
        humanoid:GetPropertyChangedSignal("SeatPart"):Connect(onSeatChanged)
    end)
    if player.Character then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:GetPropertyChangedSignal("SeatPart"):Connect(onSeatChanged)
        end
    end

    checkLoop()

    local rageGroup = shopTab:AddLeftGroupbox('Rage')

    _G.SilentAim_Enabled = false
    _G.SilentAim_Hitbox = "Head"
    _G.SilentAim_FOV = 180
    _G.SilentAim_ShowFOV = false
    _G.SilentAim_MaxDistance = 1000
    _G.SilentAim_AutoFire = false
    _G.SilentAim_VisibleCheck = true
    _G.SilentAim_TeamCheck = false
    _G.SilentAim_TargetPriority = "Crosshair"
    _G.SilentAim_ForceFieldCheck = true
    _G.SilentAim_SafeZoneCheck = true
    _G.SilentAim_IgnoreVehicles = true

    local enableToggle = rageGroup:AddToggle('SilentAimEnabled', {
        Text = 'Enable Silent Aim', Default = false, Tooltip = 'Включает перенаправление пуль в цель'
    })
    local hitboxDropdown = rageGroup:AddDropdown('SilentAimHitbox', {
        Text = 'Hitbox', Values = {'Head', 'Torso'}, Default = 'Head', Multi = false, AllowNull = false
    })
    local fovSlider = rageGroup:AddSlider('SilentAimFOV', {
        Text = 'FOV', Min = 0, Max = 360, Default = 180, Rounding = 0, Suffix = '°'
    })
    local showFOVToggle = rageGroup:AddToggle('SilentAimShowFOV', {
        Text = 'Show FOV Circle', Default = false, Tooltip = 'Рисовать круг FOV у курсора'
    })
    local maxDistSlider = rageGroup:AddSlider('SilentAimMaxDistance', {
        Text = 'Max Distance', Min = 0, Max = 5000, Default = 1000, Rounding = 0, Suffix = ' studs'
    })
    local autoFireToggle = rageGroup:AddToggle('SilentAimAutoFire', {
        Text = 'Auto Fire', Default = false, Tooltip = 'Автоматически зажимает кнопку мыши, если цель в FOV'
    })
    local visibleCheckToggle = rageGroup:AddToggle('SilentAimVisibleCheck', {
        Text = 'Visible Check', Default = true, Tooltip = 'Целиться только в видимых врагов (без препятствий)'
    })
    local teamCheckToggle = rageGroup:AddToggle('SilentAimTeamCheck', {
        Text = 'Team Check', Default = false, Tooltip = 'Игнорировать игроков из своей команды'
    })
    local priorityDropdown = rageGroup:AddDropdown('SilentAimTargetPriority', {
        Text = 'Target Priority', Values = {'HP', 'Distance', 'Crosshair', 'Combat'},
        Default = 'Crosshair', Multi = false, AllowNull = false
    })
    local forceFieldCheckToggle = rageGroup:AddToggle('SilentAimForceFieldCheck', {
        Text = 'ForceField Check', Default = true, Tooltip = 'Игнорировать цели с активным ForceField'
    })
    local safeZoneCheckToggle = rageGroup:AddToggle('SilentAimSafeZoneCheck', {
        Text = 'SafeZone Check', Default = true, Tooltip = 'Не стрелять в игроков в сейф‑зонах (если они не в бою)'
    })
    local ignoreVehiclesToggle = rageGroup:AddToggle('SilentAimIgnoreVehicles', {
        Text = 'Ignore Vehicles', Default = true, Tooltip = 'Игнорировать машины при проверке видимости'
    })

    enableToggle:OnChanged(function(v) _G.SilentAim_Enabled = v end)
    hitboxDropdown:OnChanged(function(v) _G.SilentAim_Hitbox = v end)
    fovSlider:OnChanged(function(v) _G.SilentAim_FOV = v end)
    showFOVToggle:OnChanged(function(v) _G.SilentAim_ShowFOV = v end)
    maxDistSlider:OnChanged(function(v) _G.SilentAim_MaxDistance = v end)
    autoFireToggle:OnChanged(function(v) _G.SilentAim_AutoFire = v end)
    visibleCheckToggle:OnChanged(function(v) _G.SilentAim_VisibleCheck = v end)
    teamCheckToggle:OnChanged(function(v) _G.SilentAim_TeamCheck = v end)
    priorityDropdown:OnChanged(function(v) _G.SilentAim_TargetPriority = v end)
    forceFieldCheckToggle:OnChanged(function(v) _G.SilentAim_ForceFieldCheck = v end)
    safeZoneCheckToggle:OnChanged(function(v) _G.SilentAim_SafeZoneCheck = v end)
    ignoreVehiclesToggle:OnChanged(function(v) _G.SilentAim_IgnoreVehicles = v end)

    local player = game:GetService("Players").LocalPlayer
    local camera = workspace.CurrentCamera
    local repStorage = game:GetService("ReplicatedStorage")
    local uis = game:GetService("UserInputService")

    local fovCircle = nil
    local function updateFOVCircle()
        if not _G.SilentAim_ShowFOV or not camera then
            if fovCircle then pcall(function() fovCircle:Remove() end) fovCircle = nil end
            return
        end
        if not fovCircle then
            fovCircle = Drawing.new("Circle")
            fovCircle.Visible = true; fovCircle.Filled = false; fovCircle.Thickness = 1
            fovCircle.Color = Color3.fromRGB(255, 255, 255); fovCircle.Transparency = 0.8
        end
        local mousePos = uis:GetMouseLocation()
        local radius = (_G.SilentAim_FOV / 2) * (camera.ViewportSize.Y / 70)
        fovCircle.Position = mousePos
        fovCircle.Radius = radius
    end

    local function isInsidePart(part, pos)
        local relative = part.CFrame:PointToObjectSpace(pos)
        local size = part.Size
        return math.abs(relative.X) <= size.X/2 and math.abs(relative.Y) <= size.Y/2 and math.abs(relative.Z) <= size.Z/2
    end
    local function isPlayerSafeZoneProtected(targetPlayer)
        if not _G.SilentAim_SafeZoneCheck then return false end
        local char = targetPlayer.Character
        if not char then return false end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return false end
        local zonesFolder = workspace:FindFirstChild("Zones")
        if not zonesFolder then return false end
        local teamName = targetPlayer.Team and targetPlayer.Team.Name or ""
        for _, zone in ipairs(zonesFolder:GetChildren()) do
            if zone:IsA("BasePart") and isInsidePart(zone, root.Position) then
                local zoneName = zone.Name
                if zoneName == "All_Safe" then return true end
                if zoneName == teamName .. "_Safe" then return true end
            end
        end
        return false
    end

    local function getTarget()
        if not camera then return nil end
        local character = player.Character
        if not character then return nil end

        local rayOrigin
        local tool = character:FindFirstChildWhichIsA("Tool")
        local gunFirePoint = tool and tool:FindFirstChild("GunFirePoint", true)

        if player.CameraMode == Enum.CameraMode.LockFirstPerson then
            rayOrigin = camera.CFrame.Position
        else
            if gunFirePoint and gunFirePoint:IsA("BasePart") then
                rayOrigin = gunFirePoint.WorldPosition
            else
                local head = character:FindFirstChild("Head")
                rayOrigin = head and head.Position or (character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart.Position)
            end
        end
        if not rayOrigin then rayOrigin = camera.CFrame.Position end

        local bestTarget = nil
        local bestScore = math.huge
        local fovHalf = _G.SilentAim_FOV / 2

        for _, otherPlayer in ipairs(game:GetService("Players"):GetPlayers()) do
            if otherPlayer == player then continue end
            if _G.SilentAim_TeamCheck and otherPlayer.Team == player.Team then continue end

            local char = otherPlayer.Character
            if not char then continue end

            if _G.SilentAim_ForceFieldCheck and char:FindFirstChildWhichIsA("ForceField") then continue end

            local targetPart = nil
            if _G.SilentAim_Hitbox == "Head" then
                targetPart = char:FindFirstChild("Head")
            elseif _G.SilentAim_Hitbox == "Torso" then
                targetPart = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
            end
            if not targetPart then continue end

            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health <= 0 then continue end

            if isPlayerSafeZoneProtected(otherPlayer) then
                local inCombat = char:GetAttribute("InCombat")
                if not inCombat then continue end
            end

            local camLook = camera.CFrame.LookVector
            local targetDir = (targetPart.Position - camera.CFrame.Position).Unit
            local angle = math.deg(math.acos(math.clamp(camLook:Dot(targetDir), -1, 1)))
            if angle > fovHalf then continue end

            local distance = (targetPart.Position - rayOrigin).Magnitude
            if _G.SilentAim_MaxDistance > 0 and distance > _G.SilentAim_MaxDistance then continue end

            if _G.SilentAim_VisibleCheck then
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                rayParams.FilterDescendantsInstances = { character, char }

                if _G.SilentAim_IgnoreVehicles then
                    local liveCars = workspace:FindFirstChild("LiveCars")
                    if liveCars then
                        for _, car in ipairs(liveCars:GetChildren()) do
                            if car:IsA("Model") then
                                table.insert(rayParams.FilterDescendantsInstances, car)
                            end
                        end
                    end
                end

                local rayResult = workspace:Raycast(rayOrigin, (targetPart.Position - rayOrigin).Unit * distance, rayParams)
                if rayResult and rayResult.Instance then
                    local hit = rayResult.Instance
                    if not hit:IsDescendantOf(char) then
                        continue
                    end
                    if hit:IsA("BasePart") then
                        if hit.Transparency >= 0.9 or not hit.CanCollide then
                            continue
                        end
                    end
                end
            end

            local score = angle
            if _G.SilentAim_TargetPriority == "Distance" then score = distance
            elseif _G.SilentAim_TargetPriority == "HP" then score = humanoid and humanoid.Health or 0
            elseif _G.SilentAim_TargetPriority == "Combat" then
                local inCombat = char:GetAttribute("InCombat") and 1 or 0
                score = 1 - inCombat + angle * 0.001
            end

            if score < bestScore then
                bestScore = score
                bestTarget = targetPart
            end
        end

        return bestTarget
    end

    local weaponRaycastModule = repStorage:FindFirstChild("Modules"):FindFirstChild("WeaponRaycast")
    if weaponRaycastModule then
        local weaponRaycast = require(weaponRaycastModule)
        local originalFromScreen = weaponRaycast.fromScreen
        weaponRaycast.fromScreen = function(cam, screenPoint, rayRange, ignoreList, transparency, epsilon)
            if _G.SilentAim_Enabled then
                local target = getTarget()
                if target then return target.Position end
            end
            return originalFromScreen(cam, screenPoint, rayRange, ignoreList, transparency, epsilon)
        end
    end

    local isMouseHeld = false
    local function updateAutoFire()
        if not _G.SilentAim_AutoFire or not _G.SilentAim_Enabled then
            if isMouseHeld then pcall(function() mouse1release() end); isMouseHeld = false end
            return
        end

        local target = getTarget()
        local character = player.Character
        local tool = character and character:FindFirstChildWhichIsA("Tool")

        if target and tool then
            if not isMouseHeld then
                pcall(function() mouse1press() end)
                isMouseHeld = true
            end
        else
            if isMouseHeld then
                pcall(function() mouse1release() end)
                isMouseHeld = false
            end
        end
    end

    game:GetService("RunService").Heartbeat:Connect(function()
        updateFOVCircle()
        updateAutoFire()
    end)

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
    miscGroup:AddButton('Rapid Fire', function() enableMod('rapidFire') Library:Notify("Rapid Fire (FireRate=0) включён", 2) end)
    miscGroup:AddButton('No Spread', function() enableMod('noSpread') Library:Notify("No Spread (Recoil & Spread=0) включён", 2) end)
    miscGroup:AddButton('Insta Equip', function() enableMod('instaEquip') Library:Notify("Insta Equip (EquipTime=0) включён", 2) end)
    miscGroup:AddButton('All Auto', function() enableMod('allAuto') Library:Notify("All Auto включён (все оружия авто)", 2) end)
    miscGroup:AddButton('Auto Reload', function() enableMod('autoReload') Library:Notify("Auto Reload (AutoReload=true) включён", 2) end)
    miscGroup:AddButton('No Reload Time', function() enableMod('noReloadTime') Library:Notify("No Reload Time (ReloadTime=0) включён", 2) end)
    miscGroup:AddButton('Inf Bullet Speed', function() enableMod('infBulletSpeed') Library:Notify("Inf Bullet Speed (BulletSpeed=9999) включён", 2) end)
    miscGroup:AddButton('Inf ReserveAmmo', function() enableMod('infReserve') Library:Notify("Inf Reserve Ammo (MaxAmmo=99999) включён", 2) end)
    miscGroup:AddButton('Slow Anim', function() enableMod('slowAnim') Library:Notify("Slow Anim (все скорости анимаций 0.1) включён", 2) end)

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

    local playerGroup = shopTab:AddLeftGroupbox('Player Actions')

    local function getPlayerList()
        local players = {}
        local localPlayer = game.Players.LocalPlayer
        for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
            if plr ~= localPlayer then
                table.insert(players, plr.Name)
            end
        end
        table.sort(players)
        if #players == 0 then
            table.insert(players, "No players found")
        end
        return players
    end

    local playerDropdown = playerGroup:AddDropdown('PlayerDropdown', {
        Text = 'Select Player',
        Values = getPlayerList(),
        Default = 1,
        Multi = false,
        AllowNull = false,
        Tooltip = 'Выберите игрока для действий'
    })

    local selectedPlayerName = playerDropdown.Value or "No players found"

    playerDropdown:OnChanged(function(value)
        selectedPlayerName = value
    end)

    playerGroup:AddButton('Refresh Player List', function()
        local newList = getPlayerList()
        playerDropdown:SetValues(newList)
        if #newList > 0 then
            playerDropdown:SetValue(newList[1])
        end
        Library:Notify("Player list refreshed", 2)
    end)

    playerGroup:AddButton('Steal Sound', function()
        if selectedPlayerName == "No players found" or not selectedPlayerName then
            Library:Notify("No player selected", 3)
            return
        end

        local targetPlayer = game:GetService("Players"):FindFirstChild(selectedPlayerName)
        if not targetPlayer then
            Library:Notify("Player not found", 3)
            return
        end

        local character = targetPlayer.Character
        if not character then
            Library:Notify("Target has no character", 3)
            return
        end

        local head = character:FindFirstChild("Head")
        if not head then
            Library:Notify("Target has no Head", 3)
            return
        end

        local sound = nil
        for _, child in ipairs(head:GetDescendants()) do
            if child:IsA("Sound") then
                sound = child
                break
            end
        end

        if not sound then
            Library:Notify("No Sound found in Head", 3)
            return
        end

        local soundId = sound.SoundId
        if not soundId or soundId == "" then
            Library:Notify("Sound has no SoundId", 3)
            return
        end

        local id = soundId:match("rbxassetid://(%d+)")
        if not id then
            id = soundId:match("rbxasset://(%d+)")
        end
        if not id then
            id = soundId:match("^(%d+)$")
        end

        if not id then
            Library:Notify("Could not extract numeric ID from SoundId", 3)
            return
        end

        local success = pcall(function()
            setclipboard(id)
        end)

        if success then
            Library:Notify(string.format("Sound ID copied: %s", id), 2)
        else
            Library:Notify("Failed to copy to clipboard", 3)
        end
    end)

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
    
    -- ============================================================
    -- ГРУППА FUN – INVISIBLE MODE (платформа под картой, проверка на сидение)
    -- ============================================================
    local funGroup = shopTab:AddLeftGroupbox('Fun')
    
    local invisibleToggle = funGroup:AddToggle('InvisibleMode', {
        Text = 'Invisible Mode',
        Default = false,
        Tooltip = 'Оригинал на платформе под картой, прозрачная копия на месте, камера на копии'
    })

    local keybindLabel = funGroup:AddLabel('Toggle Key')
    keybindLabel:AddKeyPicker('InvisibleKeybind', {
        Text = 'Toggle Key',
        Default = 'None',
        Mode = 'Toggle',
        Tooltip = 'Клавиша включения/выключения'
    })

    local invisibleData = {
        savedCFrame = nil,
        savedTransparencies = {},
        savedPlatformStand = false,
        savedAutoRotate = true,
        savedCameraSubject = nil,
        savedCameraMode = nil,
        copyParts = {},
        copyHumanoid = nil,
        savedWalkSpeed = 16,
        savedJumpPower = 50,
        platformPart = nil,
        keepPositionConnection = nil,
        platformPos = Vector3.new(867.782043, -39.9123535, -141.675568),
    }

    local function setAllPartsTransparency(character, transparency)
        if not character then return end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = transparency
            end
        end
    end

    local function setAllCanCollide(character, collide)
        if not character then return end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = collide
            end
        end
    end

    local function saveTransparencies(character)
        if not character then return end
        invisibleData.savedTransparencies = {}
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                invisibleData.savedTransparencies[part] = part.Transparency
            end
        end
    end

    local function restoreTransparencies(character)
        if not character or not invisibleData.savedTransparencies then return end
        for part, trans in pairs(invisibleData.savedTransparencies) do
            if part and part.Parent then
                part.Transparency = trans
            end
        end
        invisibleData.savedTransparencies = {}
    end

    -- Создание упрощённой копии (без клонирования)
    local function createDummyCopy(character)
        local copyModel = Instance.new("Model")
        copyModel.Name = "DummyCopy"

        local partsToCopy = {"Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}
        for _, name in ipairs(partsToCopy) do
            local orig = character:FindFirstChild(name)
            if orig and orig:IsA("BasePart") then
                local newPart = Instance.new(orig.ClassName)
                newPart.Name = orig.Name
                newPart.Size = orig.Size
                newPart.CFrame = orig.CFrame
                newPart.Color = orig.Color
                newPart.Material = orig.Material
                newPart.Transparency = 1
                newPart.Anchored = true
                newPart.CanCollide = false
                newPart.Parent = copyModel
                table.insert(invisibleData.copyParts, newPart)
            end
        end

        local h = Instance.new("Humanoid")
        h.PlatformStand = true
        h.AutoRotate = false
        h.Parent = copyModel

        copyModel.Parent = workspace
        invisibleData.copyHumanoid = h
        return copyModel
    end

    -- Функция для удержания позиции на платформе
    local function startKeepPosition()
        if invisibleData.keepPositionConnection then
            invisibleData.keepPositionConnection:Disconnect()
            invisibleData.keepPositionConnection = nil
        end

        invisibleData.keepPositionConnection = game:GetService("RunService").Heartbeat:Connect(function()
            if not _G.NOTALovchik_InvisibleModeActive then return end
            local player = game.Players.LocalPlayer
            if not player then return end
            local character = player.Character
            if not character then return end
            local hrp = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
            if not hrp then return end

            local currentPos = hrp.Position
            local targetPos = invisibleData.platformPos + Vector3.new(0, 0.5, 0)
            local distance = (currentPos - targetPos).Magnitude
            if distance > 1 then
                -- Если отошёл дальше чем на 1 студию, телепортируем обратно
                hrp.CFrame = CFrame.new(targetPos)
            end
        end)
    end

    local function stopKeepPosition()
        if invisibleData.keepPositionConnection then
            invisibleData.keepPositionConnection:Disconnect()
            invisibleData.keepPositionConnection = nil
        end
    end

    local function toggleInvisibleMode(enabled)
        local player = game.Players.LocalPlayer
        if not player then return end
        local character = player.Character
        if not character then return end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local hrp = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
        if not hrp or not humanoid then return end

        local camera = workspace.CurrentCamera
        if not camera then return end

        if enabled then
            -- Проверка: сидит ли игрок
            if humanoid.Sit or humanoid.SeatPart then
                Library:Notify("You are sitting! Cannot activate Invisible Mode.", 3)
                invisibleToggle:SetValue(false)
                return
            end

            -- Сохраняем состояние
            invisibleData.savedCFrame = hrp.CFrame
            invisibleData.savedPlatformStand = humanoid.PlatformStand
            invisibleData.savedAutoRotate = humanoid.AutoRotate
            invisibleData.savedCameraSubject = camera.CameraSubject
            invisibleData.savedCameraMode = player.CameraMode
            invisibleData.savedWalkSpeed = humanoid.WalkSpeed
            invisibleData.savedJumpPower = humanoid.JumpPower
            saveTransparencies(character)

            -- Создаём копию на месте
            local copy = createDummyCopy(character)
            if not copy then
                Library:Notify("Failed to create dummy copy – disabling", 3)
                invisibleToggle:SetValue(false)
                return
            end

            -- Создаём невидимую платформу под картой
            local platformPos = invisibleData.platformPos
            local platform = Instance.new("Part")
            platform.Name = "InvisiblePlatform"
            platform.Size = Vector3.new(10, 0.2, 10)
            platform.CFrame = CFrame.new(platformPos + Vector3.new(0, -0.5, 0))
            platform.Anchored = true
            platform.CanCollide = true
            platform.Transparency = 1
            platform.Material = Enum.Material.SmoothPlastic
            platform.Color = Color3.new(1,1,1)
            platform.Parent = workspace
            invisibleData.platformPart = platform

            -- Телепортируем оригинал на платформу (чуть выше)
            local targetPos = platformPos + Vector3.new(0, 0.5, 0)
            hrp.CFrame = CFrame.new(targetPos)

            -- Делаем оригинал прозрачным, отключаем коллизии, отключаем управление
            setAllPartsTransparency(character, 1)
            setAllCanCollide(character, false)
            humanoid.PlatformStand = true
            humanoid.AutoRotate = false

            -- Переключаем камеру на копию
            local head = copy:FindFirstChild("Head")
            if head then
                camera.CameraSubject = head
            else
                camera.CameraSubject = copy
            end
            player.CameraMode = Enum.CameraMode.LockFirstPerson

            -- Запускаем удержание позиции
            startKeepPosition()

            _G.NOTALovchik_InvisibleModeActive = true
            Library:Notify("Invisible mode ON", 2)

        else
            -- Останавливаем удержание позиции
            stopKeepPosition()

            -- Удаляем платформу
            if invisibleData.platformPart then
                invisibleData.platformPart:Destroy()
                invisibleData.platformPart = nil
            end

            -- Удаляем копию
            if invisibleData.copyHumanoid then
                local copyModel = invisibleData.copyHumanoid.Parent
                if copyModel then copyModel:Destroy() end
                invisibleData.copyHumanoid = nil
                invisibleData.copyParts = {}
            else
                for _, part in ipairs(invisibleData.copyParts) do
                    part:Destroy()
                end
                invisibleData.copyParts = {}
            end

            -- Возвращаем камеру на оригинал
            if invisibleData.savedCameraSubject then
                camera.CameraSubject = invisibleData.savedCameraSubject
            else
                camera.CameraSubject = character
            end
            if invisibleData.savedCameraMode then
                player.CameraMode = invisibleData.savedCameraMode
            end

            -- Возвращаем оригинал на место
            if invisibleData.savedCFrame then
                hrp.CFrame = invisibleData.savedCFrame
            end

            -- Восстанавливаем всё
            setAllCanCollide(character, true)
            restoreTransparencies(character)
            humanoid.PlatformStand = invisibleData.savedPlatformStand or false
            humanoid.AutoRotate = invisibleData.savedAutoRotate
            humanoid.WalkSpeed = invisibleData.savedWalkSpeed
            humanoid.JumpPower = invisibleData.savedJumpPower

            _G.NOTALovchik_InvisibleModeActive = false
            Library:Notify("Invisible mode OFF", 2)
        end
    end

    local function onCharacterAdded()
        if _G.NOTALovchik_InvisibleModeActive then
            invisibleToggle:SetValue(false)
            toggleInvisibleMode(false)
        end
    end

    game.Players.LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

    invisibleToggle:OnChanged(function(value)
        toggleInvisibleMode(value)
    end)

    Options.InvisibleKeybind:OnClick(function()
        invisibleToggle:SetValue(not invisibleToggle.Value)
    end)
-- ============================================================
-- WHEELS HEIGHT CHANGER + SMOOTH SWAP HEIGHT
-- ============================================================



local wheelsToggle = funGroup:AddToggle('WheelsHeightToggle', {
    Text = 'Wheels Height Changer',
    Default = false,
    Tooltip = 'Включить изменение длины пружин колёс'
})

local frontSlider = funGroup:AddSlider('FrontWheelsHeight', {
    Text = 'Front Spring Length',
    Min = 4.5,
    Max = 10,
    Default = 5,
    Rounding = 1,
    Suffix = ' studs',
    Tooltip = 'Длина пружин передних колёс'
})

local rearSlider = funGroup:AddSlider('RearWheelsHeight', {
    Text = 'Rear Spring Length',
    Min = 4.5,
    Max = 10,
    Default = 5,
    Rounding = 1,
    Suffix = ' studs',
    Tooltip = 'Длина пружин задних колёс'
})

-- ============================================================
-- SERVICES
-- ============================================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- ============================================================
-- CAR
-- ============================================================

local function getCurrentCar()
    local character = Player.Character
    if not character then
        return nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return nil
    end

    local seat = humanoid.SeatPart
    if not seat then
        return nil
    end

    local car = seat:FindFirstAncestorWhichIsA("Model")
    if not car then
        return nil
    end

    local wheels = car:FindFirstChild("Wheels")

    if wheels and (
        car:FindFirstChild("DriveSeat")
        or car:FindFirstChildWhichIsA("VehicleSeat")
    ) then
        return car
    end

    return nil
end

-- ============================================================
-- WHEEL HEIGHT
-- ============================================================

local function setWheelsHeight(car, frontHeight, rearHeight)
    if not car then
        return
    end

    local wheels = car:FindFirstChild("Wheels")
    if not wheels then
        return
    end

    for _, wheel in ipairs(wheels:GetChildren()) do
        if wheel:IsA("BasePart") then
            local spring = wheel:FindFirstChild("Spring")

            if spring and spring:IsA("SpringConstraint") then
                local name = wheel.Name

                local isFront

                if string.find(name, "F") or string.find(name, "f") then
                    isFront = true
                elseif string.find(name, "R") or string.find(name, "r") then
                    isFront = false
                else
                    -- Если название колеса не содержит F/R,
                    -- считаем его передним как в старой версии.
                    isFront = true
                end

                local height = isFront and frontHeight or rearHeight

                spring.MinLength = height
                spring.MaxLength = height
            end
        end
    end
end

-- ============================================================
-- NORMAL WHEELS HEIGHT UPDATE
-- ============================================================

local currentCar = nil

local normalFrontHeight = frontSlider.Value
local normalRearHeight = rearSlider.Value

local function updateNormalHeight()
    if not wheelsToggle.Value then
        return
    end

    currentCar = getCurrentCar()

    if not currentCar then
        return
    end

    setWheelsHeight(
        currentCar,
        normalFrontHeight,
        normalRearHeight
    )
end

-- ============================================================
-- SWAP HEIGHT
-- ============================================================

local swapSpeedSlider = funGroup:AddSlider('SwapSpeed', {
    Text = 'Swap Speed',
    Min = 0.1,
    Max = 5,
    Default = 1,
    Rounding = 1,
    Suffix = 'x',
    Tooltip = 'Скорость плавного обмена передней и задней высоты'
})

local swapToggle = funGroup:AddToggle('SwapWheelsHeight', {
    Text = 'Swap Height',
    Default = false,
    Tooltip = 'Плавно меняет высоту передних и задних колёс местами'
})

-- ============================================================
-- SWAP STATE
-- ============================================================

local swapConnection = nil

local swapFront = frontSlider.Value
local swapRear = rearSlider.Value

local swapFromFront = swapFront
local swapFromRear = swapRear

local swapToFront = swapRear
local swapToRear = swapFront

local swapProgress = 0

-- Длительность одного перехода.
-- При Speed = 1 переход занимает примерно 1 секунду.
local BASE_SWAP_DURATION = 1

-- ============================================================
-- START SWAP
-- ============================================================

local function stopSwap()
    if swapConnection then
        swapConnection:Disconnect()
        swapConnection = nil
    end

    -- После выключения возвращаем управление слайдерам.
    swapFront = frontSlider.Value
    swapRear = rearSlider.Value

    swapProgress = 0
end

local function startSwap()
    -- На всякий случай закрываем старую анимацию.
    if swapConnection then
        swapConnection:Disconnect()
        swapConnection = nil
    end

    -- Wheels Height должен быть включён.
    if not wheelsToggle.Value then
        wheelsToggle:SetValue(true)
    end

    -- Берём реальные значения слайдеров только ОДИН раз
    -- при запуске swap.
    swapFront = frontSlider.Value
    swapRear = rearSlider.Value

    -- Если значения одинаковые, swap всё равно запускаем,
    -- но визуально ничего происходить не будет.
    swapFromFront = swapFront
    swapFromRear = swapRear

    swapToFront = swapRear
    swapToRear = swapFront

    swapProgress = 0

    swapConnection = RunService.Heartbeat:Connect(function(dt)
        if not swapToggle.Value then
            stopSwap()
            return
        end

        local car = getCurrentCar()

        if not car then
            return
        end

        -- ====================================================
        -- SPEED
        -- ====================================================

        local speed = math.max(
            tonumber(swapSpeedSlider.Value) or 1,
            0.01
        )

        local duration = BASE_SWAP_DURATION / speed

        -- ====================================================
        -- PROGRESS
        -- ====================================================

        swapProgress += dt / duration

        -- ====================================================
        -- ПЕРЕХОД
        -- ====================================================

        local alpha = math.clamp(swapProgress, 0, 1)

        -- SmoothStep:
        -- 0 -> 1 плавно разгоняется и плавно тормозит.
        local smoothAlpha = alpha * alpha * (3 - 2 * alpha)

        local frontHeight = swapFromFront
            + (swapToFront - swapFromFront) * smoothAlpha

        local rearHeight = swapFromRear
            + (swapToRear - swapFromRear) * smoothAlpha

        -- ====================================================
        -- APPLY DIRECTLY TO SPRINGS
        -- ====================================================

        setWheelsHeight(
            car,
            frontHeight,
            rearHeight
        )

        -- ====================================================
        -- END OF SWAP
        -- ====================================================

        if swapProgress >= 1 then
            -- Точно выставляем конечные значения,
            -- чтобы не было ошибки float.
            frontHeight = swapToFront
            rearHeight = swapToRear

            setWheelsHeight(
                car,
                frontHeight,
                rearHeight
            )

            -- =================================================
            -- МЕНЯЕМ НАПРАВЛЕНИЕ
            -- =================================================

            swapFromFront = swapToFront
            swapFromRear = swapToRear

            swapToFront = swapFromRear
            swapToRear = swapFromFront

            -- Обнуляем прогресс и сразу начинаем следующий цикл.
            swapProgress = 0
        end
    end)
end

-- ============================================================
-- SWAP TOGGLE
-- ============================================================

swapToggle:OnChanged(function(value)
    if value then
        startSwap()
    else
        stopSwap()

        -- После выключения применяем обычные значения
        -- слайдеров.
        updateNormalHeight()
    end
end)

-- ============================================================
-- WHEELS HEIGHT TOGGLE
-- ============================================================

wheelsToggle:OnChanged(function(value)
    if value then
        updateNormalHeight()

        -- Если Swap уже включён, запускаем его заново,
        -- используя текущие значения.
        if swapToggle.Value then
            startSwap()
        end
    else
        if swapToggle.Value then
            stopSwap()
        end
    end
end)

-- ============================================================
-- MANUAL SLIDER CHANGES
-- ============================================================

frontSlider:OnChanged(function(value)
    normalFrontHeight = value

    -- Если Swap выключен — сразу применяем.
    if not swapToggle.Value then
        updateNormalHeight()
    end
end)

rearSlider:OnChanged(function(value)
    normalRearHeight = value

    -- Если Swap выключен — сразу применяем.
    if not swapToggle.Value then
        updateNormalHeight()
    end
end)

-- ============================================================
-- CHARACTER / CAR UPDATE
-- ============================================================

Player.CharacterAdded:Connect(function()
    currentCar = nil

    task.wait(0.2)

    if wheelsToggle.Value and not swapToggle.Value then
        updateNormalHeight()
    end
end)


    -- ============================================================
    -- ГРУППА: A-CHASSIS TUNING (с атрибутом TunedHash)
    -- ============================================================
    local tuningGroup = shopTab:AddRightGroupbox('A-Chassis Tuning')

    -- ---- Тогл автоприменения ----
    local autoApplyToggle = tuningGroup:AddToggle('AutoTuningApply', {
        Text = 'Auto Apply on Enter',
        Default = false,
        Tooltip = 'Автоматически применять настройки при посадке (если хеш изменился)'
    })

    -- ---- Кнопка Apply (принудительно) ----
    tuningGroup:AddButton('Apply Tuning to Current Car', function()
        applyTuningToCurrentCar(true)  -- true = принудительно, игнорируем хеш
    end)

    tuningGroup:AddDivider()

    -- ---- Список параметров с описаниями (Tooltip) ----
    local tuningParams = {
        {name = 'Weight', label = 'Weight (kg)', default = 1200, desc = 'Вес машины. Меньше = быстрее разгон.'},
        {name = 'WeightDist', label = 'Weight Dist (%)', default = 55, desc = 'Распределение веса (50 = идеал).'},
        {name = 'CGHeight', label = 'CG Height', default = 0.7, desc = 'Высота центра тяжести.'},
        {name = 'FSusDamping', label = 'F Sus Damping', default = 850, desc = 'Демпфирование передней подвески.'},
        {name = 'RSusDamping', label = 'R Sus Damping', default = 850, desc = 'Демпфирование задней подвески.'},
        {name = 'FSusStiffness', label = 'F Sus Stiffness', default = 12000, desc = 'Жёсткость пружин передней подвески.'},
        {name = 'RSusStiffness', label = 'R Sus Stiffness', default = 11000, desc = 'Жёсткость пружин задней подвески.'},
        {name = 'FAntiRoll', label = 'F Anti-Roll', default = 70, desc = 'Стабилизатор передний.'},
        {name = 'RAntiRoll', label = 'R Anti-Roll', default = 60, desc = 'Стабилизатор задний.'},
        {name = 'FSusLength', label = 'F Sus Length', default = 6, desc = 'Длина передней подвески.'},
        {name = 'RSusLength', label = 'R Sus Length', default = 6, desc = 'Длина задней подвески.'},
        {name = 'FPreCompress', label = 'F Pre-Compress', default = 0.5, desc = 'Предсжатие передних пружин.'},
        {name = 'RPreCompress', label = 'R Pre-Compress', default = 0.5, desc = 'Предсжатие задних пружин.'},
        {name = 'FExtensionLim', label = 'F Extension Lim', default = 0.6, desc = 'Ограничение отбоя передних.'},
        {name = 'RExtensionLim', label = 'R Extension Lim', default = 0.6, desc = 'Ограничение отбоя задних.'},
        {name = 'FCompressLim', label = 'F Compress Lim', default = 0.5, desc = 'Ограничение сжатия передних.'},
        {name = 'RCompressLim', label = 'R Compress Lim', default = 0.5, desc = 'Ограничение сжатия задних.'},
        {name = 'FSusAngle', label = 'F Sus Angle', default = 120, desc = 'Угол наклона передней подвески.'},
        {name = 'RSusAngle', label = 'R Sus Angle', default = 120, desc = 'Угол наклона задней подвески.'},
        {name = 'SteerInner', label = 'Steer Inner (deg)', default = 45, desc = 'Угол поворота внутреннего колеса.'},
        {name = 'SteerOuter', label = 'Steer Outer (deg)', default = 40, desc = 'Угол поворота внешнего колеса.'},
        {name = 'SteerSpeed', label = 'Steer Speed', default = 0.08, desc = 'Скорость поворота руля.'},
        {name = 'ReturnSpeed', label = 'Return Speed', default = 0.08, desc = 'Скорость возврата руля.'},
        {name = 'SteerDecay', label = 'Steer Decay', default = 350, desc = 'Затухание руля на скорости.'},
        {name = 'MinSteer', label = 'Min Steer', default = 10, desc = 'Минимальный угол поворота.'},
        {name = 'SteerP', label = 'Steer P', default = 150000, desc = 'Пропорциональный коэффициент руля.'},
        {name = 'SteerD', label = 'Steer D', default = 1500, desc = 'Дифференциальный коэффициент руля.'},
        {name = 'SteerMaxTorque', label = 'Steer Max Torque', default = 80000, desc = 'Макс. момент руля.'},
        {name = 'FCamber', label = 'F Camber', default = -1.5, desc = 'Развал передних колёс.'},
        {name = 'RCamber', label = 'R Camber', default = -1.2, desc = 'Развал задних колёс.'},
        {name = 'FToe', label = 'F Toe', default = 0.2, desc = 'Схождение передних колёс.'},
        {name = 'RToe', label = 'R Toe', default = 0.1, desc = 'Схождение задних колёс.'},
        {name = 'MSteerExp', label = 'M Steer Exp', default = 1.3, desc = 'Экспонента руля.'},
        {name = 'FBrakeForce', label = 'F Brake Force', default = 10000, desc = 'Усилие передних тормозов.'},
        {name = 'RBrakeForce', label = 'R Brake Force', default = 6000, desc = 'Усилие задних тормозов.'},
        {name = 'PBrakeForce', label = 'P Brake Force', default = 12000, desc = 'Усилие ручника.'},
        {name = 'ABSThreshold', label = 'ABS Threshold', default = 20, desc = 'Порог ABS.'},
        {name = 'FDiffSlipThres', label = 'F Diff Slip Thres', default = 50, desc = 'Пробуксовка переднего диффа.'},
        {name = 'FDiffLockThres', label = 'F Diff Lock Thres', default = 60, desc = 'Блокировка переднего диффа.'},
        {name = 'RDiffSlipThres', label = 'R Diff Slip Thres', default = 50, desc = 'Пробуксовка заднего диффа.'},
        {name = 'RDiffLockThres', label = 'R Diff Lock Thres', default = 60, desc = 'Блокировка заднего диффа.'},
        {name = 'CDiffSlipThres', label = 'C Diff Slip Thres', default = 50, desc = 'Пробуксовка центрального диффа.'},
        {name = 'CDiffLockThres', label = 'C Diff Lock Thres', default = 60, desc = 'Блокировка центрального диффа.'},
        {name = 'TCSThreshold', label = 'TCS Threshold', default = 20, desc = 'Порог TCS.'},
        {name = 'TCSGradient', label = 'TCS Gradient', default = 30, desc = 'Плавность TCS.'},
        {name = 'TCSLimit', label = 'TCS Limit (%)', default = 40, desc = 'Макс. снижение мощности TCS.'},
        {name = 'FinalDrive', label = 'Final Drive', default = 2.8, desc = 'Финальная передача.'},
        {name = 'FDMult', label = 'FD Mult', default = 1.8, desc = 'Множитель финальной передачи.'},
        {name = 'AutoUpThresh', label = 'Auto Up Thresh', default = -100, desc = 'Смещение переключения вверх.'},
        {name = 'AutoDownThresh', label = 'Auto Down Thresh', default = 1200, desc = 'Смещение переключения вниз.'},
        {name = 'Horsepower', label = 'Horsepower', default = 9999, desc = 'Мощность л.с.'},
        {name = 'PeakRPM', label = 'Peak RPM', default = 8000, desc = 'Обороты пика мощности.'},
        {name = 'Redline', label = 'Redline', default = 9000, desc = 'Макс. обороты.'},
        {name = 'IdleRPM', label = 'Idle RPM', default = 5000, desc = 'Холостой ход.'},
        {name = 'InclineComp', label = 'Incline Comp', default = 3.0, desc = 'Компенсация наклона.'},
        {name = 'ClutchTol', label = 'Clutch Tol', default = 800, desc = 'Допуск сцепления.'},
        {name = 'FGyroDamp', label = 'F Gyro Damp', default = 350, desc = 'Демпфирование гироскопа перед.'},
        {name = 'RGyroDamp', label = 'R Gyro Damp', default = 400, desc = 'Демпфирование гироскопа зад.'},
        {name = 'FWLgcyDensity', label = 'F Wheel Legacy Density', default = 2, desc = 'Плотность передних колёс.'},
        {name = 'RWLgcyDensity', label = 'R Wheel Legacy Density', default = 2, desc = 'Плотность задних колёс.'},
        {name = 'AxleSize', label = 'Axle Size', default = 2.5, desc = 'Размер оси.'},
        {name = 'AxleDensity', label = 'Axle Density', default = 0.25, desc = 'Плотность оси.'},
        {name = 'SusVisible', label = 'Sus Visible (true/false)', default = 'false', desc = 'Видимость подвески.'},
        {name = 'WsBVisible', label = 'WsB Visible (true/false)', default = 'true', desc = 'Видимость точек крепления.'},
        {name = 'SusRadius', label = 'Sus Radius', default = 0.25, desc = 'Радиус пружин.'},
        {name = 'SusThickness', label = 'Sus Thickness', default = 0.12, desc = 'Толщина пружин.'},
        {name = 'SusCoilCount', label = 'Sus Coil Count', default = 8, desc = 'Количество витков.'},
        {name = 'WsThickness', label = 'Ws Thickness', default = 0.15, desc = 'Толщина элементов.'},
    }

    -- ---- Массив Ratios (передачи) ----
    local ratiosInput = tuningGroup:AddInput('TuningRatios', {
        Text = 'Ratios (comma-separated)',
        Default = '8.0, 5.0, 3.5, 2.5, 1.8, 1.2, 0.8, 0.6',
        Numeric = false,
        Finished = true,
        Tooltip = 'Введите передаточные числа через запятую, точку с запятой или пробел'
    })

    -- ---- Создание Input'ов для каждого параметра ----
    for _, param in ipairs(tuningParams) do
        tuningGroup:AddInput('Tuning_' .. param.name, {
            Text = param.label,
            Default = tostring(param.default),
            Numeric = true,
            Finished = true,
            Tooltip = param.desc
        })
    end

    -- ---- Вспомогательные функции ----
    local function getCurrentCar()
        local char = game.Players.LocalPlayer.Character
        if not char then return nil end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return nil end
        local seat = humanoid.SeatPart
        if not seat then return nil end
        local model = seat:FindFirstAncestorWhichIsA("Model")
        if model and model:FindFirstChild("Wheels") and (model:FindFirstChild("DriveSeat") or model:FindFirstChildWhichIsA("VehicleSeat")) then
            return model
        end
        return nil
    end

    -- ---- Вычисление хеша всех значений из UI ----
    local function getTuningHash()
        local parts = {}
        for _, param in ipairs(tuningParams) do
            local input = Options['Tuning_' .. param.name]
            if input then
                local val = input.Value
                if val == nil or val == '' then
                    val = tostring(param.default)
                end
                table.insert(parts, tostring(val))
            else
                table.insert(parts, tostring(param.default))
            end
        end
        if ratiosInput then
            table.insert(parts, ratiosInput.Value or "")
        end
        return table.concat(parts, "|")
    end

    -- ---- Улучшенный парсинг Ratios (поддержка разных разделителей) ----
    local function parseRatios(str)
        if not str or str == '' then return nil end
        local normalized = str:gsub('[;%s]+', ',')
        local ratios = {}
        for token in string.gmatch(normalized, '([^,]+)') do
            local num = tonumber(token:match('^%s*(.-)%s*$'))
            if num then
                table.insert(ratios, num)
            else
                return nil, "Invalid number: " .. token
            end
        end
        if #ratios < 2 then
            return nil, "At least 2 numbers required"
        end
        return ratios
    end

    -- ---- ПЕРЕЗАПУСК СКРИПТА DRIVE С ВЫСАЖИВАНИЕМ ----
    local function restartDriveScript(car)
        local interface = car:FindFirstChild("A-Chassis Interface")
        if interface then
            local drive = interface:FindFirstChild("Drive")
            if drive and drive:IsA("LocalScript") then
                drive.Disabled = true
                task.wait(0.1)
                drive.Disabled = false
                return true
            end
        end

        for _, child in ipairs(car:GetDescendants()) do
            if child:IsA("LocalScript") or child:IsA("Script") then
                local src = child.Source
                if src and src:find('require(Value["A-Chassis Tune"])') then
                    child.Disabled = true
                    task.wait(0.1)
                    child.Disabled = false
                    return true
                end
            end
        end

        local seat = car:FindFirstChild("DriveSeat") or car:FindFirstChildWhichIsA("VehicleSeat")
        if seat then
            local humanoid = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.Sit = false
                task.wait(0.3)
                humanoid.Sit = true
                return true
            end
        end

        car:BreakJoints()
        return true
    end

    -- ---- Применение тюнинга ----
    local function applyTuningToCurrentCar(force)
        local car = getCurrentCar()
        if not car then
            Library:Notify("Вы не в машине!", 3)
            return
        end

        local currentHash = getTuningHash()
        local storedHash = car:GetAttribute("TunedHash")

        -- Если не принудительно и хеш совпадает – пропускаем
        if not force and storedHash == currentHash then
            return
        end

        local tuneModule = car:FindFirstChild("A-Chassis Tune")
        if not tuneModule then
            Library:Notify("Модуль A-Chassis Tune не найден!", 3)
            return
        end

        local config = require(tuneModule)

        -- Применяем все параметры
        for _, param in ipairs(tuningParams) do
            local input = Options['Tuning_' .. param.name]
            if input then
                local val = input.Value
                if val ~= nil and val ~= '' then
                    local num = tonumber(val)
                    if num ~= nil then
                        config[param.name] = num
                    else
                        if val == 'true' then config[param.name] = true
                        elseif val == 'false' then config[param.name] = false
                        else
                            Library:Notify("Неверное значение для " .. param.name .. ": " .. val, 3)
                            return
                        end
                    end
                end
            end
        end

        if ratiosInput then
            local ratiosStr = ratiosInput.Value
            if ratiosStr and ratiosStr ~= '' then
                local ratios, err = parseRatios(ratiosStr)
                if ratios then
                    config.Ratios = ratios
                else
                    Library:Notify("Ошибка в Ratios: " .. err, 3)
                    return
                end
            end
        end

        -- Сохраняем хеш на машине
        car:SetAttribute("TunedHash", currentHash)

        Library:Notify("Параметры применены. Перезапускаем управление...", 2)

        restartDriveScript(car)
    end

    -- ---- Обработчик автоприменения ----
    local autoApplyConnection = nil

    local function setupAutoApply()
        if autoApplyConnection then
            autoApplyConnection:Disconnect()
            autoApplyConnection = nil
        end

        if not autoApplyToggle.Value then return end

        local player = game.Players.LocalPlayer
        local function onSeatChanged()
            local car = getCurrentCar()
            if car then
                task.wait(0.2)
                applyTuningToCurrentCar(false)  -- не принудительно, проверяем хеш
            end
        end

        if player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                autoApplyConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(onSeatChanged)
            end
        end
        player.CharacterAdded:Connect(function(char)
            local humanoid = char:WaitForChild("Humanoid")
            if autoApplyConnection then autoApplyConnection:Disconnect() end
            autoApplyConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(onSeatChanged)
        end)
    end

    autoApplyToggle:OnChanged(function(value)
        if value then
            setupAutoApply()
            applyTuningToCurrentCar(false)  -- при включении применяем, если хеш отличается
        else
            if autoApplyConnection then
                autoApplyConnection:Disconnect()
                autoApplyConnection = nil
            end
        end
    end)

    Library:Notify("ShopManager loaded. All items are purchased with cash (GamePass ignored).", 3)
end

return ShopManager
