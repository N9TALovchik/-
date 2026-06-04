-- ShopManager.lua
-- Добавляет вкладку удалённого магазина в существующее меню LinoriaLib

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
    
    -- Переменные
    local currentNPCId = "Smugglers"   -- ID по умолчанию (можно изменить)
    local currentConfig = nil
    local products = {}
    local remoteEvent = nil
    local buttons = {}   -- для хранения созданных кнопок
    
    -- Поиск удалённого события (путь из оригинального скрипта)
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
    
    -- Загрузка конфига NPC
    local function loadConfig(npcId)
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local npcFolder = replicatedStorage:FindFirstChild("Data") 
            and replicatedStorage.Data:FindFirstChild("Gameplay") 
            and replicatedStorage.Data.Gameplay:FindFirstChild("NPC")
        if not npcFolder then
            Library:Notify("NPC folder not found", 3)
            return false
        end
        
        local npcModule = npcFolder:FindFirstChild(npcId)
        if not npcModule then
            Library:Notify("NPC not found: " .. tostring(npcId), 3)
            return false
        end
        
        local configScript = npcModule:FindFirstChild("Config")
        if not configScript then
            Library:Notify("Config not found in NPC module", 3)
            return false
        end
        
        local success, config = pcall(require, configScript)
        if not success then
            Library:Notify("Failed to load config: " .. tostring(config), 3)
            return false
        end
        
        currentConfig = config
        products = config.Products or {}
        Library:Notify("Loaded NPC: " .. (config.Visuals and config.Visuals.DisplayName or npcId) .. " | Items: " .. table.getn(products), 2)
        return true
    end
    
    -- Очистка группы товаров
    local function clearItemsGroup()
        for _, btn in ipairs(buttons) do
            pcall(function() btn:Destroy() end)
        end
        buttons = {}
        -- Также удаляем все дочерние элементы группы (например, разделители, метки)
        for _, child in ipairs(shopGroup:GetChildren()) do
            if child:IsA("GuiObject") and child ~= shopGroup then
                pcall(function() child:Destroy() end)
            end
        end
    end
    
    -- Создание элементов для каждого товара
    local function rebuildItemsUI()
        clearItemsGroup()
        
        if not currentConfig or table.getn(products) == 0 then
            shopGroup:AddLabel("No items loaded. Load NPC config first.")
            return
        end
        
        -- Информационная метка
        shopGroup:AddLabel("NPC: " .. (currentConfig.Visuals and currentConfig.Visuals.DisplayName or currentNPCId))
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
            local buttonText = string.format("%s\n%s\n%s", name, desc, priceText)
            
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
    
    -- Элементы управления в левой группе
    local npcIdInput = configGroup:AddInput('ShopNPC_ID', {
        Text = 'NPC ID',
        Default = currentNPCId,
        Placeholder = 'e.g., Smugglers'
    })
    
    configGroup:AddButton('Load NPC Config', function()
        local newId = npcIdInput.Value
        if newId and newId ~= "" then
            currentNPCId = newId
            local success = loadConfig(currentNPCId)
            if success then
                rebuildItemsUI()
            end
        else
            Library:Notify("Please enter NPC ID", 3)
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
    configGroup:AddLabel("After changing NPC ID, click 'Load NPC Config'.")
    
    -- Автоматическая загрузка конфига по умолчанию
    task.spawn(function()
        if currentNPCId and currentNPCId ~= "" then
            if loadConfig(currentNPCId) then
                rebuildItemsUI()
            end
        end
    end)
    
    Library:Notify("ShopManager loaded. Use Remote Shop tab.", 2)
end

return ShopManager
