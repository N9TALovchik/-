-- ShopManager.lua для LinoriaLib (авто-бай с мультивыбором)
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
    local products = {}          -- { [itemName] = data }
    local remoteEvent = nil
    local uiElements = {}        -- для ручных кнопок/лейблов (правая панель)
    
    -- Переменные для авто-бая
    local autoBuyEnabled = false
    local selectedItems = {}     -- { [itemName] = true/false }
    local autoBuyConnection = nil
    
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
    
    -- Проверка наличия предмета у игрока (в руках или рюкзаке)
    local function hasItem(itemName)
        local player = game.Players.LocalPlayer
        if not player then return false end
        
        -- Проверка в руках
        local character = player.Character
        if character then
            local tool = character:FindFirstChild(itemName)
            if tool and tool:IsA("Tool") then
                return true
            end
        end
        
        -- Проверка в рюкзаке
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            local tool = backpack:FindFirstChild(itemName)
            if tool and tool:IsA("Tool") then
                return true
            end
        end
        
        return false
    end
    
    -- Покупка предмета
    local function purchaseItem(itemName, data)
        if data.Pass then
            -- Для GamePass покупка через Robux (не автоматизируем)
            return false
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
                remote:FireServer(currentNPCId, itemName)
                Library:Notify("Auto-bought: " .. itemName, 2)
                return true
            else
                Library:Notify("Remote event not found", 3)
                return false
            end
        else
            -- Недостаточно денег – ничего не делаем
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
            
            -- Перебираем выбранные предметы
            for itemName, isSelected in pairs(selectedItems) do
                if isSelected and products[itemName] then
                    local data = products[itemName]
                    -- Пропускаем GamePass
                    if not data.Pass then
                        if not hasItem(itemName) then
                            purchaseItem(itemName, data)
                            task.wait(0.1) -- небольшая задержка между покупками
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
            if not data.Pass then  -- только покупаемые за внутриигровую валюту
                table.insert(itemNames, name)
            end
        end
        if Options.ItemsDropdown then
            Options.ItemsDropdown:SetValues(itemNames)
        end
        
        return true
    end
    
    -- Отрисовка товаров в правой группе (ручная покупка)
    local function rebuildItemsUI()
        -- Удаляем старые элементы
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
        
        for name, data in pairs(products) do
            -- Лейбл с ценой
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
            
            -- Кнопка с названием (ручная покупка)
            local btn = itemsGroup:AddButton({
                Text = name,
                Func = function()
                    if data.Pass then
                        MarketplaceService:PromptProductPurchase(LocalPlayer, data.Pass)
                    else
                        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                        local cashStat = leaderstats and leaderstats:FindFirstChild("Cash")
                        if cashStat and cashStat.Value >= data.Price then
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
                end,
                Tooltip = data.Desc or "Click to buy"
            })
            table.insert(uiElements, btn)
        end
    end
    
    -- ============ UI ЭЛЕМЕНТЫ (LinoriaLib) ============
    
    -- Toggle для включения авто-бая
    local autoBuyToggle = configGroup:AddToggle('AutoBuyToggle', {
        Text = 'Auto Buy',
        Default = false,
        Tooltip = 'Automatically buy selected items every 0.1 sec if not owned'
    })
    
    -- Dropdown с мультивыбором для предметов
    local itemsDropdown = configGroup:AddDropdown('ItemsDropdown', {
        Text = 'Items to Auto Buy',
        Values = {},  -- заполнится после загрузки конфига
        Multi = true,
        Default = {},
        Tooltip = 'Select items to auto-buy (only cash items)'
    })
    
    -- Обработчики событий UI
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
        -- selectedItems = таблица { [itemName] = true/false }
        selectedItems = itemsDropdown.Value
    end)
    
    -- Автоматическая загрузка при старте
    task.spawn(function()
        task.wait(1)
        if loadConfig() then
            rebuildItemsUI()
            -- Инициализируем selectedItems пустой таблицей
            selectedItems = {}
        end
    end)
    
    Library:Notify("ShopManager loaded. Use Remote Shop tab. Auto-buy is ready.", 2)
end

return ShopManager
