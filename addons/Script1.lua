-- ShopManager.lua (полный, Viewmodel с сохранением и применением ко всем оружиям)
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

  -- ===== AC BYPASS (обновлённый) =====
miscGroup:AddButton('AC Bypass', function()
    local replicatedStorage = game:GetService("ReplicatedStorage")

    -- 1. Удаляем три известных регулятора из папки Remotes
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
        if deleted > 0 then
            Library:Notify(string.format("Deleted %d anti-cheat remote(s) from Remotes.", deleted), 2)
        end
    else
        Library:Notify("Remotes folder not found.", 3)
    end

    -- 2. Удаляем «длинные» RemoteEvent'ы прямо в ReplicatedStorage (GUID-имена, внутри __FUNCTION)
    local deletedLong = 0
    for _, child in ipairs(replicatedStorage:GetChildren()) do
        if child:IsA("RemoteEvent") then
            -- Проверяем: имя длинное (GUID обычно 36 символов с дефисами)
            if #child.Name > 30 and string.match(child.Name, "-") then
                child:Destroy()
                deletedLong = deletedLong + 1
            end
        end
    end
    if deletedLong > 0 then
        Library:Notify(string.format("Deleted %d  RemoteEvents from ReplicatedStorage ", deletedLong), 2)
    end
end)
    -- ===== AUTO UNCUFF =====
    local uncuffToggle = miscGroup:AddToggle('UncuffToggle', {
        Text = 'Auto UnCuff',
        Default = false,
        Tooltip = 'Моментально снимает наручники без мини‑игры'
    })

    local cuffedByConnection = nil
    local function monitorCharacter(char)
        if char:FindFirstChild("cuffedBy") then
            task.spawn(function()
                local cuffedBy = char.cuffedBy
                local cuffer = cuffedBy.Value
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
        if cuffedByConnection then
            cuffedByConnection:Disconnect()
            cuffedByConnection = nil
        end
        if enabled then
            local player = game.Players.LocalPlayer
            local char = player.Character
            if char then
                monitorCharacter(char)
            end
            player.CharacterAdded:Connect(function(newChar)
                if not uncuffToggle.Value then return end
                if cuffedByConnection then
                    cuffedByConnection:Disconnect()
                end
                monitorCharacter(newChar)
            end)
        end
    end

    uncuffToggle:OnChanged(function()
        toggleUncuff(uncuffToggle.Value)
    end)

    -- ===== VIEWMODEL CHANGER (сохранение, автоприменение ко всем оружиям) =====
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

    -- При изменении слайдеров сохраняем и сразу применяем
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
            -- Сбросить атрибут у всех инструментов
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

    -- Первоначальная загрузка: если тоггл включён (не должен), но на всякий случай
    if vmToggle.Value then
        updateVmHeartbeat()
    end

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
