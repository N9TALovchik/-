-- ShopManager.lua для LinoriaLib (с авто-баем и маппингом названий)
local ShopManager = {}

function ShopManager:Init(Window, Tabs)
    assert(Window, "ShopManager: Window is required")
    assert(Library, "Library must be loaded before ShopManager")
    
    -- Создаём вкладку
    local shopTab = Window:AddTab('Remote Shop')
    Tabs.Shop = shopTab
    
    -- Группы
    local configGroup = shopTab:AddLeftGroupbox('Auto Buy Settings')
    local itemsGroup = shopTab:AddRightGroupbox('Shop Items')
    
    local currentNPCId = "Smugglers"
    local currentConfig = nil
    local products = {}          -- [shopName] = data
    local remoteEvent = nil
    local uiElements = {}        -- для ручных кнопок/лейблов
    
    -- Авто-бай переменные
    local autoBuyEnabled = false
    local selectedItems = {}     -- [shopName] = true/false
    local autoBuyConnection = nil
    
    -- Маппинг: магазинное имя -> реальное имя Tool'а (если отличается)
    local itemMappings = {}      -- ["аптечка"] = "Аптечка [+]"
    
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
    
    -- Получить реальное имя предмета по магазинному
    local function getRealItemName(shopName)
        return itemMappings[shopName] or shopName
    end
    
    -- Проверка наличия предмета у игрока (по реальному имени)
    local function hasItem(shopName)
        local realName = getRealItemName(shopName)
        local player = game.Players.LocalPlayer
        if not player then return false end
        
        -- Проверка в руках
        local character = player.Character
        if character and character:FindFirstChild(realName) then
            return true
        end
        
        -- Проверка в рюкзаке
        local backpack = player:FindFirstChild("Backpack")
        if backpack and backpack:FindFirstChild(realName) then
            return true
        end
        
        return false
    end
    
    -- Отслеживание появления нового Tool после покупки
    local function waitForNewItem(shopName, timeout)
        local player = game.Players.LocalPlayer
        local startTime = tick()
        local found = nil
        
        -- Функция проверки новых объектов в контейнере
        local function checkContainer(container)
            if not container then return nil end
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then
                    -- Если это не старый предмет (ещё не маппился)
                    local alreadyMapped = false
                    for _, mappedName in pairs(itemMappings) do
                        if mappedName == child.Name then
                            alreadyMapped = true
                            break
                        end
                    end
                    if not alreadyMapped then
                        return child.Name
                    end
                end
            end
            return nil
        end
        
        -- Сохраняем текущие имена Tool'ов до покупки
        local existingTools = {}
        local char = player.Character
        local bp = player:FindFirstChild("Backpack")
        
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then existingTools[tool.Name] = true end
            end
        end
        if bp then
            for _, tool in ipairs(bp:GetChildren()) do
                if tool:IsA("Tool") then existingTools[tool.Name] = true end
            end
        end
        
        -- Ждём появления нового Tool
        while tick() - startTime < timeout do
            -- Проверяем персонажа
            local charNow = player.Character
            if charNow then
                for _, tool in ipairs(charNow:GetChildren()) do
                    if tool:IsA("Tool") and not existingTools[tool.Name] then
                        found = tool.Name
                        break
                    end
                end
            end
            -- Проверяем рюкзак
            local bpNow = player:FindFirstChild("Backpack")
            if bpNow and not found then
                for _, tool in ipairs(bpNow:GetChildren()) do
                    if tool:IsA("Tool") and not existingTools[tool.Name] then
                        found = tool.Name
                        break
                    end
                end
            end
            
            if found then break end
            task.wait(0.05)
        end
        
        if found and found ~= shopName then
            itemMappings[shopName] = found
            Library:Notify(string.format("Mapped: '%s' -> '%s'", shopName, found), 2)
        end
        return found
    end
    
    -- Покупка предмета (с отслеживанием реального имени)
    local function purchaseItem(shopName, data)
        if data.Pass then
            return false  -- GamePass не автоматизируем
        end
        
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
                -- После отправки запроса ждём появления предмета (если ещё не запомнен)
                if not itemMappings[shopName] then
                    task.spawn(function()
                        local realName = waitForNewItem(shopName, 3)
                        if realName then
                            Library:Notify("Learned real name: " .. realName, 2)
                        end
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
                    if not data.Pass then
                        if not hasItem(shopName) then
                            purchaseItem(shopName, data)
                            task.wait(0.1) -- задержка между покупками
                        end
                    end
                end
            end
        end)
    end
    
    -- Загрузка конфига NPC
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
        if config.Products then
            products = config.Products
        elseif config.Data and config.Data.Products then
            products = config.Data.Products
        else
            products = {}
            Library:Notify("Products not found in config", 3)
            return false
        end
        
        local count = 0
        for _ in pairs(products) do count = count + 1 end
        Library:Notify("Loaded NPC: " .. (config.Visuals and config.Visuals.DisplayName or currentNPCId) .. " | Items: " .. count, 2)
        
        -- Обновляем Dropdown значениями из товаров (только не GamePass)
        local itemNames = {}
        for name, data in pairs(products) do
            if not data.Pass then
                table.insert(itemNames, name)
            end
        end
        if Options.ItemsDropdown then
            Options.ItemsDropdown:SetValues(itemNames)
        end
        
        return true
    end
    
    -- Отрисовка товаров в правой панели (ручная покупка)
    local function rebuildItemsUI()
        for _, element in ipairs(uiElements) do
            pcall(function() element:Destroy() end)
        end
        uiElements = {}
        
        if not currentConfig or next(products) == nil then
            local noItemsLabel = itemsGroup:AddLabel("No items found. Check console.")
            table.insert(uiElements, noItemsLabel)
            return
        end
        
        local MarketplaceService = game:GetService("MarketplaceService")
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        
        for shopName, data in pairs(products) do
            local priceText = ""
            if data.Pass then
                priceText = "Price: Robux (GamePass ID: " .. data.Pass .. ")"
            elseif data.CurrencyType == "Event" then
                priceText = "Price: " .. tostring(data.Price) .. " Event"
            else
                priceText = "Price: " .. tostring(data.Price) .. " Cash"
            end
            
            local priceLabel = itemsGroup:AddLabel(priceText)
            table.insert(uiElements, priceLabel)
            
            local btn = itemsGroup:AddButton({
                Text = shopName,
                Func = function()
                    if data.Pass then
                        MarketplaceService:PromptProductPurchase(LocalPlayer, data.Pass)
                    else
                        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                        local cashStat = leaderstats and leaderstats:FindFirstChild("Cash")
                        if cashStat and cashStat.Value >= data.Price then
                            local remote = getRemoteEvent()
                            if remote then
                                remote:FireServer(currentNPCId, shopName)
                                Library:Notify("Purchase request sent for " .. shopName, 2)
                                -- Отслеживаем реальное имя при ручной покупке
                                if not itemMappings[shopName] then
                                    task.spawn(function()
                                        local realName = waitForNewItem(shopName, 3)
                                        if realName then
                                            Library:Notify("Learned real name: " .. realName, 2)
                                        end
                                    end)
                                end
                            else
                                Library:Notify("Remote event not found", 3)
                            end
                        else
                            Library:Notify("Not enough Cash! Required: " .. data.Price, 3)
                        end
                    end
                end,
                Tooltip = data.Desc or "Click to buy"
            })
            table.insert(uiElements, btn)
        end
    end
    
    -- ============ UI ЭЛЕМЕНТЫ (LinoriaLib) ============
    
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
        Tooltip = 'Select items to auto-buy (cash items only)'
    })
    
    autoBuyToggle:OnChanged(function()
        autoBuyEnabled = autoBuyToggle.Value
        if autoBuyEnabled then
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
    end)
    
    -- Автоматическая загрузка при старте
    task.spawn(function()
        task.wait(1)
        if loadConfig() then
            rebuildItemsUI()
            selectedItems = {}
        end
    end)
    
    Library:Notify("ShopManager loaded. Auto-buy will learn item names after first purchase.", 4)
end

return ShopManager
