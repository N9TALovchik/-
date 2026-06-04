local ShopManager = {}

function ShopManager:Init(Window, Tabs)
    assert(Window, "ShopManager: Window is required")
    assert(Library, "Library must be loaded before ShopManager")
    
    -- Создаём вкладку
    local shopTab = Window:AddTab('Remote Shop')
    Tabs.Shop = shopTab
    
    -- Группы
    local configGroup = shopTab:AddLeftGroupbox('NPC Configuration')
    local shopGroup = shopTab:AddRightGroupbox('Items')
    
    -- Фиксированный ID
    local NPC_ID = "Smugglers"
    local products = {}
    local remoteEvent = nil
    local productButtons = {}  -- храним созданные кнопки
    
    -- Поиск удалённого события
    local function getRemoteEvent()
        if remoteEvent then return remoteEvent end
        local repStorage = game:GetService("ReplicatedStorage")
        local network = repStorage:FindFirstChild("Network")
        if network then
            local npcShop = network:FindFirstChild("NPCShop")
            if npcShop then
                remoteEvent = npcShop:FindFirstChild("Update")
            end
        end
        return remoteEvent
    end
    
    -- Загрузка конфига
    local function loadConfig()
        local repStorage = game:GetService("ReplicatedStorage")
        local npcFolder = repStorage:FindFirstChild("Data")
            and repStorage.Data:FindFirstChild("Gameplay")
            and repStorage.Data.Gameplay:FindFirstChild("NPC")
        if not npcFolder then
            Library:Notify("NPC folder not found", 3)
            return false
        end
        
        local npcModule = npcFolder:FindFirstChild(NPC_ID)
        if not npcModule then
            Library:Notify("NPC not found: " .. NPC_ID, 3)
            return false
        end
        
        -- Поиск модуля конфига
        local configScript = npcModule:FindFirstChild("Config") or npcModule:FindFirstChild("ShopConfig")
        if not configScript then
            Library:Notify("Config module not found", 3)
            return false
        end
        
        local success, config = pcall(require, configScript)
        if not success then
            Library:Notify("Failed to load config", 3)
            return false
        end
        
        -- Определяем товары
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
        Library:Notify("Loaded " .. count .. " items", 2)
        return true
    end
    
    -- Очистка кнопок товаров
    local function clearProducts()
        for _, btn in ipairs(productButtons) do
            pcall(function() btn:Destroy() end)
        end
        productButtons = {}
    end
    
    -- Создание кнопок товаров
    local function rebuildProducts()
        clearProducts()
        
        if not products or next(products) == nil then
            shopGroup:AddLabel("No items available")
            return
        end
        
        local MarketplaceService = game:GetService("MarketplaceService")
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        
        for name, data in pairs(products) do
            local priceText = ""
            if data.Pass then
                priceText = "Robux"
            elseif data.CurrencyType == "Event" then
                priceText = tostring(data.Price) .. " Event"
            else
                priceText = tostring(data.Price) .. " Cash"
            end
            
            local desc = data.Desc or ""
            local buttonText = name .. "\n" .. desc .. "\n" .. priceText
            
            local btn = shopGroup:AddButton(buttonText, function()
                if data.Pass then
                    MarketplaceService:PromptProductPurchase(LocalPlayer, data.Pass)
                else
                    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
                    if not cash then
                        Library:Notify("Cash stat not found", 3)
                        return
                    end
                    if cash.Value >= data.Price then
                        local remote = getRemoteEvent()
                        if remote then
                            remote:FireServer(NPC_ID, name)
                            Library:Notify("Purchase request sent for " .. name, 2)
                        else
                            Library:Notify("Remote event not found", 3)
                        end
                    else
                        Library:Notify("Not enough Cash (need " .. data.Price .. ")", 3)
                    end
                end
            end)
            table.insert(productButtons, btn)
        end
    end
    
    -- UI левой группы (только кнопка загрузки)
    configGroup:AddButton('Load Shop Items', function()
        if loadConfig() then
            rebuildProducts()
        end
    end)
    
    configGroup:AddDivider()
    configGroup:AddLabel("NPC ID: " .. NPC_ID)
    
    -- Автозагрузка при старте
    task.spawn(function()
        task.wait(0.5)
        if loadConfig() then
            rebuildProducts()
        end
    end)
    
    Library:Notify("ShopManager loaded", 2)
end

return ShopManager
