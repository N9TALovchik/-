-- ShopManager.lua
-- Добавляет вкладку удалённого магазина (ID NPC: Smugglers)

local ShopManager = {}

function ShopManager:Init(Window, Tabs)
    assert(Window, "ShopManager: Window is required")
    assert(Library, "Library must be loaded before ShopManager")
    
    local shopTab = Window:AddTab('Remote Shop')
    Tabs.Shop = shopTab
    
    local configGroup = shopTab:AddLeftGroupbox('NPC Configuration')
    local shopGroup = shopTab:AddRightGroupbox('Items')
    
    local currentNPCId = "Smugglers"
    local currentConfig = nil
    local products = {}
    local remoteEvent = nil
    local buttons = {}
    
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
        -- Поиск продуктов: может быть в config.Products или config.Data.Products
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
        Library:Notify("Loaded NPC: " .. (config.Visuals and config.Visuals.DisplayName or npcId) .. " | Items: " .. count, 2)
        return true
    end
    
    -- Очистка группы товаров (работает корректно)
    local function clearItemsGroup()
        for _, btn in ipairs(buttons) do
            pcall(function() btn:Destroy() end)
        end
        buttons = {}
        -- Удаляем все дочерние элементы shopGroup, кроме самой группы
        for _, child in ipairs(shopGroup:GetChildren()) do
            if child:IsA("GuiObject") then
                pcall(function() child:Destroy() end)
            end
        end
    end
    
    local function rebuildItemsUI()
        clearItemsGroup()
        
        if not currentConfig or next(products) == nil then
            shopGroup:AddLabel("No items available.")
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
    
    -- UI: только информация и одна кнопка загрузки
    configGroup:AddLabel("NPC ID: " .. currentNPCId)
    configGroup:AddButton('Load Shop', function()
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
