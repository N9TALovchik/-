-- ShopManager.lua
-- Добавляет вкладку удалённого магазина (фиксированный NPC "Smugglers")

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
    
    -- Функция для очистки всех элементов группы (через методы библиотеки)
    local function clearGroup(group)
        -- В LinoriaLib нет прямого метода удаления всех элементов, поэтому пересоздаём группу
        local parent = group.Parent
        local index = group:GetIndex()
        local newGroup = parent:AddRightGroupbox('Items')
        -- Копируем настройки? Просто удаляем старую и создаём новую
        group:Destroy()
        return newGroup
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
        
        -- Поиск модуля конфигурации
        local configScript = npcModule:FindFirstChild("Config")
        if not configScript then
            configScript = npcModule:FindFirstChild("ShopConfig")
        end
        if not configScript then
            Library:Notify("Config not found in NPC module", 3)
            -- Выводим список детей для отладки
            local children = {}
            for _, ch in ipairs(npcModule:GetChildren()) do
                table.insert(children, ch.Name)
            end
            Library:Notify("Children: " .. table.concat(children, ", "), 2)
            return false
        end
        
        local success, config = pcall(require, configScript)
        if not success then
            Library:Notify("Failed to load config: " .. tostring(config), 3)
            return false
        end
        
        currentConfig = config
        
        -- Отладка: выводим все ключи конфига
        print("[ShopManager] Config loaded. Keys:")
        for k, v in pairs(config) do
            print("  " .. tostring(k) .. " = " .. type(v))
        end
        
        -- Определяем, где лежат товары
        if config.Products then
            products = config.Products
            print("[ShopManager] Products found at config.Products")
        elseif config.Data and config.Data.Products then
            products = config.Data.Products
            print("[ShopManager] Products found at config.Data.Products")
        else
            -- Ищем любое поле, которое является таблицей и может содержать товары
            products = {}
            for k, v in pairs(config) do
                if type(v) == "table" and next(v) then
                    local hasPrice = false
                    for _, item in pairs(v) do
                        if type(item) == "table" and (item.Price or item.Pass) then
                            hasPrice = true
                            break
                        end
                    end
                    if hasPrice then
                        products = v
                        print("[ShopManager] Found products at config." .. tostring(k))
                        break
                    end
                end
            end
        end
        
        local productCount = 0
        for _ in pairs(products) do productCount = productCount + 1 end
        print("[ShopManager] Products count: " .. productCount)
        
        local displayName = (config.Visuals and config.Visuals.DisplayName) or npcId
        Library:Notify("Loaded NPC: " .. displayName .. " | Items: " .. productCount, 2)
        return true
    end
    
    -- Создание элементов UI для каждого товара (пересоздаём группу)
    local function rebuildItemsUI()
        -- Удаляем старую группу и создаём новую
        local oldGroup = shopGroup
        local parent = oldGroup.Parent
        local newGroup = parent:AddRightGroupbox('Items')
        oldGroup:Destroy()
        shopGroup = newGroup
        
        if not currentConfig or next(products) == nil then
            shopGroup:AddLabel("No items loaded. Check console for errors.")
            return
        end
        
        local displayName = (currentConfig.Visuals and currentConfig.Visuals.DisplayName) or currentNPCId
        shopGroup:AddLabel("Shop: " .. displayName)
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
        end
    end
    
    -- UI: только кнопка загрузки
    configGroup:AddLabel("NPC: Smugglers")
    configGroup:AddButton('Load NPC', function()
        local success = loadConfig(currentNPCId)
        if success then
            rebuildItemsUI()
        end
    end)
    
    -- Автоматическая загрузка при старте
    task.spawn(function()
        task.wait(1)
        if loadConfig(currentNPCId) then
            rebuildItemsUI()
        end
    end)
    
    Library:Notify("ShopManager loaded. Use Remote Shop tab.", 2)
end

return ShopManager
