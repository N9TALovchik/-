-- ShopManager.lua (исправленная версия, без clearItemsGroup, без лишних вызовов)
local ShopManager = {}

function ShopManager:Init(Window, Tabs)
    assert(Window, "ShopManager: Window is required")
    assert(Library, "Library must be loaded before ShopManager")
    
    -- Создаём вкладку
    local shopTab = Window:AddTab('Remote Shop')
    Tabs.Shop = shopTab
    
    -- Группы
    local configGroup = shopTab:AddLeftGroupbox('Configuration')
    local itemsGroup = shopTab:AddRightGroupbox('Items')
    
    local currentNPCId = "Smugglers"
    local currentConfig = nil
    local products = {}
    local remoteEvent = nil
    local buttons = {} -- храним кнопки для возможного удаления
    
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
    
    -- Загрузка конфига
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
        
        local configScript = npcModule:FindFirstChild("Config")
        if not configScript then
            configScript = npcModule:FindFirstChild("ShopConfig")
        end
        if not configScript then
            Library:Notify("Config not found in NPC", 3)
            local children = {}
            for _, ch in ipairs(npcModule:GetChildren()) do
                table.insert(children, ch.Name)
            end
            Library:Notify("Available: " .. table.concat(children, ", "), 2)
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
            local keys = {}
            for k in pairs(config) do
                table.insert(keys, k)
            end
            Library:Notify("Config keys: " .. table.concat(keys, ", "), 2)
            return false
        end
        
        local count = 0
        for _ in pairs(products) do count = count + 1 end
        Library:Notify("Loaded NPC: " .. (config.Visuals and config.Visuals.DisplayName or currentNPCId) .. " | Items: " .. count, 2)
        return true
    end
    
    -- Отрисовка товаров (удаляем старые кнопки и создаём новые)
    local function rebuildItemsUI()
        -- Удаляем ранее созданные кнопки
        for _, btn in ipairs(buttons) do
            pcall(function() btn:Destroy() end)
        end
        buttons = {}
        
        -- Очищаем группу от всех элементов (можно использовать Clear, если есть, но мы просто удалим кнопки)
        -- Дополнительно удаляем возможные метки, которые могли быть добавлены
        for _, child in ipairs(itemsGroup:GetChildren()) do
            if child:IsA("GuiObject") and child ~= itemsGroup then
                pcall(function() child:Destroy() end)
            end
        end
        
        if not currentConfig or next(products) == nil then
            itemsGroup:AddLabel("No items found. Check console.")
            return
        end
        
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
            
            local btn = itemsGroup:AddButton(buttonText, function()
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
            table.insert(buttons, btn)
        end
    end
    
    -- UI элементы
    configGroup:AddLabel("NPC: " .. currentNPCId)
    configGroup:AddButton('Load Shop', function()
        if loadConfig() then
            rebuildItemsUI()
        end
    end)
    
    -- Автоматическая загрузка при старте
    task.spawn(function()
        task.wait(1)
        if loadConfig() then
            rebuildItemsUI()
        end
    end)
    
    Library:Notify("ShopManager loaded. Use Remote Shop tab.", 2)
end

return ShopManager
