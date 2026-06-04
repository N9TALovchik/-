-- ShopManager.lua
-- Добавляет вкладку удалённого магазина в существующее меню LinoriaLib (ID NPC фиксирован: Smugglers)

local ShopManager = {}

function ShopManager:Init(Window, Tabs)
    assert(Window, "ShopManager: Window is required")
    assert(Library, "Library must be loaded before ShopManager")
    
    -- Создаём новую вкладку
    local shopTab = Window:AddTab('Remote Shop')
    Tabs.Shop = shopTab
    
    -- Группы
    local configGroup = shopTab:AddLeftGroupbox('NPC Configuration')
    local shopGroup = shopTab:AddRightGroupbox('Items')
    
    -- Фиксированный ID NPC
    local currentNPCId = "Smugglers"
    local currentConfig = nil
    local products = {}
    local remoteEvent = nil
    local buttons = {}
    
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
    
    -- Загрузка конфига NPC (с отладкой)
    local function loadConfig(npcId)
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
        
        local npcModule = npcFolder:FindFirstChild(npcId)
        if not npcModule then
            Library:Notify("NPC not found: " .. tostring(npcId), 3)
            return false
        end
        
        -- Поиск модуля конфигурации (может называться "Config" или "ShopConfig")
        local configScript = npcModule:FindFirstChild("Config")
        if not configScript then
            configScript = npcModule:FindFirstChild("ShopConfig")
        end
        if not configScript then
            Library:Notify("Config/ShopConfig not found in NPC module", 3)
            -- Выводим список детей для отладки
            local children = {}
            for _, ch in ipairs(npcModule:GetChildren()) do
                table.insert(children, ch.Name)
            end
            Library:Notify("Available children: " .. table.concat(children, ", "), 2)
            return false
        end
        
        local success, config = pcall(require, configScript)
        if not success then
            Library:Notify("Failed to load config: " .. tostring(config), 3)
            return false
        end
        
        currentConfig = config
        
        -- Определяем, где лежат товары
        if config.Products then
            products = config.Products
        elseif config.Data and config.Data.Products then
            products = config.Data.Products
        else
            products = {}
            Library:Notify("Products table not found in config", 3)
            -- Выводим ключи конфига для отладки
            local keys = {}
            for k, _ in pairs(config) do
                table.insert(keys, k)
            end
            Library:Notify("Config keys: " .. table.concat(keys, ", "), 2)
            return false
        end
        
        -- Подсчёт количества товаров (так как products – словарь)
        local productCount = 0
        for _ in pairs(products) do productCount = productCount + 1 end
        
        local displayName = (config.Visuals and config.Visuals.DisplayName) or npcId
        Library:Notify("Loaded NPC: " .. displayName .. " | Items: " .. productCount, 2)
        return true
    end
    
    -- Очистка группы товаров
    local function clearItemsGroup()
        for _, btn in ipairs(buttons) do
            pcall(function() btn:Destroy() end)
        end
        buttons = {}
        for _, child in ipairs(shopGroup:GetChildren()) do
            if child:IsA("GuiObject") and child ~= shopGroup then
                pcall(function() child:Destroy() end)
            end
        end
    end
    
    -- Создание элементов UI для каждого товара
    local function rebuildItemsUI()
        clearItemsGroup()
        
        if not currentConfig or next(products) == nil then
            shopGroup:AddLabel("No items loaded. Check console for errors.")
            return
        end
        
        local displayName = (currentConfig.Visuals and currentConfig.Visuals.DisplayName) or currentNPCId
        shopGroup:AddLabel("NPC: " .. displayName)
        shopGroup:AddDivider()
        
        local MarketplaceService = game:GetService("MarketplaceService")
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        
        for name, data in pairs(products) do
            local priceText = ""
            if data.Pass then
                priceText = "Robux (GamePass)"
            elseif data.CurrencyType == "Event" then
                priceText = tostring(data.Price) .. " Event currency"
            else
                priceText = tostring(data.Price) .. " Cash"
            end
            
            local desc = data.Desc or "No description"
            -- Краткое описание для кнопки
            local buttonText = name .. "\n" .. desc .. "\n" .. priceText
            
            local buyButton = shopGroup:AddButton(buttonText, function()
                if not currentConfig then
                    Library:Notify("No NPC loaded", 3)
                    return
                end
                
                if data.Pass then
                    MarketplaceService:PromptProductPurchase(LocalPlayer, data.Pass)
                else
                    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                    local cashStat = leaderstats and leaderstats:FindFirstChild("Cash")
                    if not cashStat then
                        Library:Notify("Cash stat not found", 3)
                        return
                    end
                    
                    if cashStat.Value >= data.Price then
                        local remote = getRemoteEvent()
                        if remote then
                            remote:FireServer(currentNPCId, name)
                            Library:Notify("Purchase request sent for " .. name, 2)
                        else
                            Library:Notify("Remote event not found", 3)
                        end
                    else
                        Library:Notify("Not enough Cash! Required: " .. data.Price, 3)
                    end
                end
            end)
            
            table.insert(buttons, buyButton)
        end
    end
    
    -- UI: только информация, без редактирования ID
    configGroup:AddLabel("NPC ID: " .. currentNPCId)
    configGroup:AddButton('Load NPC Config', function()
        local success = loadConfig(currentNPCId)
        if success then
            rebuildItemsUI()
        end
    end)
    
    configGroup:AddButton('Refresh Items', function()
        if currentConfig then
            rebuildItemsUI()
        else
            Library:Notify("Load NPC config first", 3)
        end
    end)
    
    configGroup:AddDivider()
    configGroup:AddLabel("Click 'Load NPC Config' to fetch items from Smugglers.")
    
    -- Автоматическая загрузка при старте
    task.spawn(function()
        task.wait(1) -- небольшая задержка для уверенности
        if loadConfig(currentNPCId) then
            rebuildItemsUI()
        end
    end)
    
    Library:Notify("ShopManager loaded. Use Remote Shop tab.", 2)
end

return ShopManager
