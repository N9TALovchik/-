-- ShopManager.lua (финальная: без GamePass, с маппингом по существующим предметам)
local ShopManager = {}

function ShopManager:Init(Window, Tabs)
    assert(Window, "ShopManager: Window is required")
    assert(Library, "Library must be loaded before ShopManager")
    
    local shopTab = Window:AddTab('Remote Shop')
    Tabs.Shop = shopTab
    
    local configGroup = shopTab:AddLeftGroupbox('Auto Buy Settings')
    local itemsGroup = shopTab:AddRightGroupbox('Shop Items')
    
    local currentNPCId = "Smugglers"
    local currentConfig = nil
    local products = {}              -- [shopName] = data (только НЕ GamePass)
    local allProducts = {}           -- все продукты (включая GamePass, но не показываем)
    local remoteEvent = nil
    local uiElements = {}
    
    -- Авто-бай
    local autoBuyEnabled = false
    local selectedItems = {}         -- [shopName] = true/false
    local autoBuyConnection = nil
    
    -- Маппинг названий: магазинное имя -> реальное имя Tool'а
    local itemMappings = {}
    
    -- Поиск удалённого события
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
    
    -- Попытка найти реальный Tool по магазинному имени (в инвентаре)
    local function findRealToolName(shopName)
        local player = game.Players.LocalPlayer
        local containers = { player.Character, player:FindFirstChild("Backpack") }
        
        local shopLower = string.lower(shopName)
        for _, container in ipairs(containers) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") then
                        local toolLower = string.lower(tool.Name)
                        -- Проверяем, содержит ли название Tool'а магазинное имя (без учёта регистра)
                        if string.find(toolLower, shopLower, 1, true) then
                            return tool.Name
                        end
                    end
                end
            end
        end
        return nil
    end
    
    -- Обновить маппинг для всех выбранных предметов, которые уже есть в инвентаре
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
    
    -- Получить реальное имя предмета
    local function getRealItemName(shopName)
        return itemMappings[shopName] or shopName
    end
    
    -- Проверка наличия предмета
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
        
        -- Если маппинга ещё нет, пробуем найти по частичному совпадению
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
    
    -- Отслеживание нового предмета после покупки
    local function waitForNewItem(shopName, timeout)
        local player = game.Players.LocalPlayer
        local startTime = tick()
        
        -- Собираем текущие имена Tool'ов
        local existingTools = {}
        local function collectTools(container)
            if not container then return end
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    existingTools[tool.Name] = true
                end
            end
        end
        collectTools(player.Character)
        collectTools(player:FindFirstChild("Backpack"))
        
        while tick() - startTime < timeout do
            local function checkContainer(container)
                if not container then return nil end
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and not existingTools[tool.Name] then
                        return tool.Name
                    end
                end
                return nil
            end
            
            local newName = checkContainer(player.Character) or checkContainer(player:FindFirstChild("Backpack"))
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
    
    -- Покупка предмета (только Cash)
    local function purchaseItem(shopName, data)
        if data.Pass then return false end  -- не покупаем GamePass
        
        local player = game.Players.LocalPlayer
        local leaderstats = player:FindFirstChild("leaderstats")
        local cashStat = leaderstats and leaderstats:FindFirstChild("Cash")
        if not cashStat then
            Library:Notify("Cash stat not found", 3)
            return false
        end
        
        if cashStat.Value >= data.Price then
            local remote = getRemoteEvent()
            if remote then
                remote:FireServer(currentNPCId, shopName)
                Library:Notify("Purchase request sent for " .. shopName, 2)
                -- После покупки пытаемся выучить реальное имя (если ещё не знаем)
                if not itemMappings[shopName] then
                    task.spawn(function()
                        waitForNewItem(shopName, 3)
                    end)
                end
                return true
            else
                Library:Notify("Remote event not found", 3)
                return false
            end
        else
            Library:Notify("Not enough Cash! Required: " .. data.Price, 3)
            return false
        end
    end
    
    -- Цикл авто-бая
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
                    local data = products[shopName]
                    if not data.Pass and not hasItem(shopName) then
                        purchaseItem(shopName, data)
                        task.wait(0.1)
                    end
                end
            end
        end)
    end
    
    -- Загрузка конфига (фильтруем GamePass)
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
        
        -- Отфильтровываем GamePass предметы
        products = {}
        allProducts = sourceProducts
        for name, data in pairs(sourceProducts) do
            if not data.Pass then
                products[name] = data
            end
        end
        
        local count = 0
        for _ in pairs(products) do count = count + 1 end
        Library:Notify("Loaded NPC: " .. (config.Visuals and config.Visuals.DisplayName or currentNPCId) .. " | Cash items: " .. count, 2)
        
        -- Обновляем дропдаун (только Cash предметы)
        local itemNames = {}
        for name in pairs(products) do
            table.insert(itemNames, name)
        end
        if Options.ItemsDropdown then
            Options.ItemsDropdown:SetValues(itemNames)
        end
        
        return true
    end
    
    -- Отрисовка правой панели (только Cash предметы)
    local function rebuildItemsUI()
        for _, element in ipairs(uiElements) do
            pcall(function() element:Destroy() end)
        end
        uiElements = {}
        
        if not currentConfig or next(products) == nil then
            local noItemsLabel = itemsGroup:AddLabel("No cash items found.")
            table.insert(uiElements, noItemsLabel)
            return
        end
        
        local MarketplaceService = game:GetService("MarketplaceService")
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        
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
        Tooltip = 'Select items (cash only)'
    })
    
    autoBuyToggle:OnChanged(function()
        autoBuyEnabled = autoBuyToggle.Value
        if autoBuyEnabled then
            updateMappingsFromInventory()  -- при включении авто-бая проверяем уже имеющиеся предметы
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
    
    -- Загрузка при старте
    task.spawn(function()
        task.wait(1)
        if loadConfig() then
            rebuildItemsUI()
            selectedItems = {}
        end
    end)
    
    Library:Notify("ShopManager loaded. GamePass items are hidden.", 3)
end

return ShopManager
