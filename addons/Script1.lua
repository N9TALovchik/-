-- ShopManager.lua
-- Добавляет вкладку удалённого магазина (фиксированный NPC: Smugglers)
-- Выводит отладку в консоль для диагностики структуры конфига

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
    
    -- Функция для безопасного вывода в консоль (для отладки)
    local function debugPrint(...)
        print("[ShopManager Debug]", ...)
    end
    
    local function loadConfig(npcId)
        local replicatedStorage = game:GetService("ReplicatedStorage")
        debugPrint("Looking for ReplicatedStorage.Data.Gameplay.NPC...")
        
        local data = replicatedStorage:FindFirstChild("Data")
        if not then
            Library:Notify("Data folder not found", 3)
            return false
        end
        local gameplay = data:FindFirstChild("Gameplay")
        if not then
            Library:Notify("Gameplay folder not found", 3)
            return false
        end
        local npcFolder = gameplay:FindFirstChild("NPC")
        if not then
            Library:Notify("NPC folder not found", 3)
            return false
        end
        
        debugPrint("NPC folder found. Children:")
        for _, ch in ipairs(npcFolder:GetChildren()) do
            debugPrint(" -", ch.Name, ch.ClassName)
        end
        
        local npcModule = npcFolder:FindFirstChild(npcId)
        if not then
            Library:Notify("NPC not found: " .. tostring(npcId), 3)
            return false
        end
        debugPrint("NPC module found:", npcModule.Name)
        
        -- Ищем ModuleScript с конфигом
        local configScript = npcModule:FindFirstChild("Config")
        if not then
            configScript = npcModule:FindFirstChild("ShopConfig")
        end
        if not then
            Library:Notify("Config/ShopConfig not found in NPC module", 3)
            debugPrint("Children of NPC module:")
            for _, ch in ipairs(npcModule:GetChildren()) do
                debugPrint(" -", ch.Name, ch.ClassName)
            end
            return false
        end
        debugPrint("Config script found:", configScript.Name)
        
        local success, config = pcall(require, configScript)
        if not success then
            Library:Notify("Failed to load config: " .. tostring(config), 3)
            return false
        end
        debugPrint("Config loaded successfully. Type:", type(config))
        
        currentConfig = config
        
        -- Ищем Products: может быть в config.Products, config.Data.Products, или config.Shop.Products и т.д.
        local foundProducts = nil
        if config.Products then
            foundProducts = config.Products
            debugPrint("Found config.Products")
        elseif config.Data and config.Data.Products then
            foundProducts = config.Data.Products
            debugPrint("Found config.Data.Products")
        elseif config.Shop and config.Shop.Products then
            foundProducts = config.Shop.Products
            debugPrint("Found config.Shop.Products")
        else
            -- Выводим все ключи верхнего уровня
            debugPrint("Products not found in standard locations. Top-level keys:")
            for k, v in pairs(config) do
                debugPrint(" -", k, type(v))
                -- Если значение — таблица, посмотрим и её ключи
                if type(v) == "table" then
                    for k2, v2 in pairs(v) do
                        debugPrint("    *", k2, type(v2))
                    end
                end
            end
            products = {}
            Library:Notify("Products table not found in config. Check console for details.", 3)
            return false
        end
        
        products = foundProducts
        local productCount = 0
        for _ in pairs(products) do productCount = productCount + 1 end
        debugPrint("Product count:", productCount)
        
        local displayName = (config.Visuals and config.Visuals.DisplayName) or npcId
        Library:Notify("Loaded NPC: " .. displayName .. " | Items: " .. productCount, 2)
        return true
    end
    
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
    
    local function rebuildItemsUI()
        clearItemsGroup()
        
        if not currentConfig or next(products) == nil then
            shopGroup:AddLabel("No items found. Check console for errors.")
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
    
    -- UI: только кнопка загрузки (без лишнего текста)
    configGroup:AddButton('Load NPC Shop', function()
        local success = loadConfig(currentNPCId)
        if success then
            rebuildItemsUI()
        end
    end)
    
    -- Автоматическая загрузка
    task.spawn(function()
        task.wait(1)
        if loadConfig(currentNPCId) then
            rebuildItemsUI()
        end
    end)
    
    Library:Notify("ShopManager loaded. Use 'Remote Shop' tab.", 2)
end

return ShopManager
