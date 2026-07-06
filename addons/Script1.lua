-- ShopManager.lua (полный, добавлена кнопка Auto Pass Test)
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

    -- ===== БЕСКОНЕЧНЫЕ ПАТРОНЫ (TOGGLE) =====
    local infiniteAmmoToggle = miscGroup:AddToggle('InfiniteAmmoToggle', {
        Text = 'Infinite Ammo',
        Default = false,
        Tooltip = 'Автоматически восполняет патроны у всех оружий'
    })

    local infiniteAmmoConnection = nil
    local function startInfiniteAmmo()
        if infiniteAmmoConnection then
            infiniteAmmoConnection:Disconnect()
            infiniteAmmoConnection = nil
        end
        if not infiniteAmmoToggle.Value then return end

        infiniteAmmoConnection = game:GetService("RunService").Heartbeat:Connect(function()
            local player = game.Players.LocalPlayer
            if not player then return end
            local character = player.Character
            if not character then return end

            local tools = {}
            for _, tool in ipairs(character:GetChildren()) do
                if tool:IsA("Tool") then table.insert(tools, tool) end
            end
            local backpack = player:FindFirstChild("Backpack")
            if backpack then
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") then table.insert(tools, tool) end
                end
            end

            for _, tool in ipairs(tools) do
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
        end)
    end

    infiniteAmmoToggle:OnChanged(function()
        if infiniteAmmoToggle.Value then
            startInfiniteAmmo()
        else
            if infiniteAmmoConnection then
                infiniteAmmoConnection:Disconnect()
                infiniteAmmoConnection = nil
            end
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
        if infStaminaConnection then
            infStaminaConnection:Disconnect()
            infStaminaConnection = nil
        end
        if not infStaminaToggle.Value then return end

        local player = game.Players.LocalPlayer
        infStaminaConnection = game:GetService("RunService").Heartbeat:Connect(function()
            if not player then return end
            player:SetAttribute("currentStamina", 450)
        end)
    end

    infStaminaToggle:OnChanged(function()
        if infStaminaToggle.Value then
            startInfStamina()
        else
            if infStaminaConnection then
                infStaminaConnection:Disconnect()
                infStaminaConnection = nil
            end
        end
    end)

   -- ===== AC BYPASS (удаление регуляторов + Trusted + безопасный респавн) =====
miscGroup:AddButton('AC Bypass', function()
    local player = game:GetService("Players").LocalPlayer
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local collectionService = game:GetService("CollectionService")

    -- 1. Удаляем регуляторы
    local remotes = replicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local targets = {
            ["TellRegulator"] = true,
            ["ConfirmRegulator"] = true,
            ["GetRegulator"] = true
        }
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

    -- 2. Добавляем тег Trusted
    if not player:HasTag("Trusted") then
        collectionService:AddTag(player, "Trusted")
        Library:Notify("Тег Trusted добавлен.", 2)
    end

    -- 3. Безопасно убиваем текущего персонажа (через Health = 0)
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health > 0 then
            humanoid.Health = 0  -- естественная смерть, не детектится как BreakJoints
        end
    end

    -- Оповещаем, что после респавна всё будет чисто
    Library:Notify("Персонаж умрёт и возродится с Trusted. Проверки отключены.", 2)
end)

    -- ===== NoJumpDelay (кнопка с постоянным удалением JumpPhysic) =====
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

    -- ===== AUTO UNCUFF (исправлен: корректная подписка/отписка) =====
local uncuffToggle = miscGroup:AddToggle('UncuffToggle', {
    Text = 'Auto UnCuff',
    Default = false,
    Tooltip = 'Моментально снимает наручники (работает и при включении заранее)'
})

local cuffedByConnection = nil          -- соединение ChildAdded на текущем персонаже
local characterAddedConnection = nil    -- соединение CharacterAdded

local function monitorCharacter(char)
    -- Сначала отключаем предыдущее слежение за ChildAdded (если было)
    if cuffedByConnection then
        cuffedByConnection:Disconnect()
        cuffedByConnection = nil
    end

    -- Если уже есть cuffedBy – сразу снимаем
    local existing = char:FindFirstChild("cuffedBy")
    if existing then
        task.spawn(function()
            local cuffer = existing.Value
            if cuffer then
                local cufferChar = cuffer.Character or cuffer.CharacterAdded:Wait()
                local tool = cufferChar:FindFirstChildWhichIsA("Tool")
                if tool and tool:HasTag("Cuffs") then
                    local remote = tool:FindFirstChildWhichIsA("RemoteEvent")
                    if remote then
                        local player = game.Players.LocalPlayer
                        remote:FireServer("ForceUncuff", math.floor(workspace:GetServerTimeNow() + player.UserId))
                        Library:Notify("Uncuffed!", 2)
                    end
                end
            end
        end)
        return
    end

    -- Иначе подписываемся на появление cuffedBy в этом персонаже
    cuffedByConnection = char.ChildAdded:Connect(function(child)
        if child.Name == "cuffedBy" then
            task.spawn(function()
                task.wait(0.1)
                local cuffer = child.Value
                if cuffer then
                    local cufferChar = cuffer.Character or cuffer.CharacterAdded:Wait()
                    local tool = cufferChar:FindFirstChildWhichIsA("Tool")
                    if tool and tool:HasTag("Cuffs") then
                        local remote = tool:FindFirstChildWhichIsA("RemoteEvent")
                        if remote then
                            local player = game.Players.LocalPlayer
                            remote:FireServer("ForceUncuff", math.floor(workspace:GetServerTimeNow() + player.UserId))
                            Library:Notify("Uncuffed!", 2)
                        end
                    end
                end
            end)
        end
    end)
end

local function toggleUncuff(enabled)
    -- Сбрасываем ВСЕ предыдущие подписки
    if cuffedByConnection then
        cuffedByConnection:Disconnect()
        cuffedByConnection = nil
    end
    if characterAddedConnection then
        characterAddedConnection:Disconnect()
        characterAddedConnection = nil
    end

    if enabled then
        local player = game.Players.LocalPlayer
        local char = player.Character
        if char then
            monitorCharacter(char)
        end
        -- На будущих персонажей
        characterAddedConnection = player.CharacterAdded:Connect(function(newChar)
            if not uncuffToggle.Value then return end
            monitorCharacter(newChar)
        end)
    end
end

uncuffToggle:OnChanged(function()
    toggleUncuff(uncuffToggle.Value)
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
        Min = -5,
        Max = 5,
        Default = savedOffset.x,
        Suffix = ' studs',
        Rounding = 3,
        Tooltip = 'Смещение вправо/влево'
    })
    local sliderY = miscGroup:AddSlider('ViewmodelY', {
        Text = 'Y Offset',
        Min = -5,
        Max = 5,
        Default = savedOffset.y,
        Suffix = ' studs',
        Rounding = 3,
        Tooltip = 'Смещение вверх/вниз'
    })
    local sliderZ = miscGroup:AddSlider('ViewmodelZ', {
        Text = 'Z Offset',
        Min = -5,
        Max = 5,
        Default = savedOffset.z,
        Suffix = ' studs',
        Rounding = 3,
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
        if char then
            setOffsetOnTools(char)
        end
        setOffsetOnTools(player:FindFirstChild("Backpack"))
    end

    local function updateVmHeartbeat()
        if vmHeartbeat then
            vmHeartbeat:Disconnect()
            vmHeartbeat = nil
        end
        if vmToggle.Value then
            vmHeartbeat = game:GetService("RunService").Heartbeat:Connect(applyVmOffset)
        end
    end

    sliderX:OnChanged(function(value)
        saveViewmodelOffset()
        applyVmOffset()
    end)
    sliderY:OnChanged(function(value)
        saveViewmodelOffset()
        applyVmOffset()
    end)
    sliderZ:OnChanged(function(value)
        saveViewmodelOffset()
        applyVmOffset()
    end)

    vmToggle:OnChanged(function(enabled)
        if enabled then
            updateVmHeartbeat()
        else
            if vmHeartbeat then
                vmHeartbeat:Disconnect()
                vmHeartbeat = nil
            end
            local player = game.Players.LocalPlayer
            if player then
                local function resetOffset(container)
                    if container then
                        for _, tool in ipairs(container:GetChildren()) do
                            if tool:IsA("Tool") then
                                tool:SetAttribute("CustomViewmodelOffset", nil)
                            end
                        end
                    end
                end
                resetOffset(player.Character)
                resetOffset(player:FindFirstChild("Backpack"))
            end
        end
    end)

    if vmToggle.Value then
        updateVmHeartbeat()
    end

    -- ===== AUTO PASS TEST (кнопка мгновенной сдачи теста) =====
   -- ===== AUTO PASS TEST (с закрытием GUI MilTest) =====
miscGroup:AddButton('Auto Pass Test', function()
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local startTestRemote = replicatedStorage.Remotes.StartTest
    local player = game.Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- Подключаем перехватчик
    startTestRemote.OnClientEvent:Connect(function(testId)
        startTestRemote:FireServer(testId, true)  -- true = тест пройден
        Library:Notify("Test passed automatically!", 2)

        -- Скрываем GUI теста (если есть)
        local ui = playerGui:FindFirstChild("UI")
        if ui then
            local milTest = ui:FindFirstChild("MilTest")
            if milTest and milTest:IsA("Frame") then
                milTest.Visible = false
            end
        end
    end)

    Library:Notify("Auto pass test activated. The next test will be completed instantly.", 2)
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
