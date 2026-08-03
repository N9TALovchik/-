
-- AutobuildManager.lua
-- Встраивается в основной скрипт NOTALovchik для сохранения/загрузки построек в .build (JSON)

local AutobuildManager = {}

function AutobuildManager:Init(Window, Tabs)
    assert(Window, "AutobuildManager: Window is required")
    assert(Library, "Library must be loaded before AutobuildManager")

    local autobuildTab = Window:AddTab('Autobuild')
    Tabs.Autobuild = autobuildTab

    local saveGroup = autobuildTab:AddLeftGroupbox('Save Build')
    local loadGroup = autobuildTab:AddRightGroupbox('Load Build')
    local optionsGroup = autobuildTab:AddLeftGroupbox('Options')

    local saveOutput = nil
    local loadInput = nil

    -- ===== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====

    local function getAllBlocks()
        local blocks = {}
        local blocksFolder = workspace:FindFirstChild("Blocks")
        if blocksFolder then
            for _, child in ipairs(blocksFolder:GetChildren()) do
                if child:IsA("Model") and child.PrimaryPart then
                    table.insert(blocks, child)
                end
            end
        else
            local buildingParts = ReplicatedStorage:FindFirstChild("BuildingParts")
            if buildingParts then
                for _, child in ipairs(workspace:GetChildren()) do
                    if child:IsA("Model") and child.PrimaryPart then
                        local template = buildingParts:FindFirstChild(child.Name)
                        if template and template.PrimaryPart then
                            table.insert(blocks, child)
                        end
                    end
                end
            end
        end
        return blocks
    end

    local function getBlockData(block)
        local primary = block.PrimaryPart
        if not primary then return nil end

        local data = {
            ShowShadow = primary.CastShadow,
            CanCollide = primary.CanCollide,
            Color = string.format("%.6f,%.6f,%.6f", primary.Color.R, primary.Color.G, primary.Color.B),
            Anchored = primary.Anchored,
            Rotation = string.format("%.5f,%.5f,%.5f",
                math.deg(primary.Rotation.X),
                math.deg(primary.Rotation.Y),
                math.deg(primary.Rotation.Z)
            ),
            Transparency = primary.Transparency,
            Position = string.format("%.5f, %.5f, %.5f", primary.Position.X, primary.Position.Y, primary.Position.Z),
            Size = string.format("%.5f, %.5f, %.5f", primary.Size.X, primary.Size.Y, primary.Size.Z)
        }

        local numberValues = {}
        for _, child in ipairs(block:GetChildren()) do
            if child:IsA("NumberValue") then
                numberValues[child.Name] = child.Value
            end
        end
        if next(numberValues) then
            data.NumberValues = numberValues
        end

        local bindTable = block:FindFirstChild("BindTable")
        if bindTable and bindTable:IsA("ValueBase") then
            local val = bindTable.Value
            if type(val) == "table" then
                data.BindTable = val
            end
        end

        for _, child in ipairs(block:GetChildren()) do
            if child:IsA("ValueBase") and not child:IsA("NumberValue") and child.Name ~= "BindTable" then
                if not data.OtherValues then data.OtherValues = {} end
                data.OtherValues[child.Name] = child.Value
            end
        end

        -- Специально для "Spring", "Bar", "Rope" – сохраняем вторичную часть
        if block:FindFirstChild("2ndPlacement") then
            local secondary = block:FindFirstChild("SecondaryPart")
            if secondary and secondary:IsA("Model") and secondary.PrimaryPart then
                data.SecondaryPosition = string.format("%.5f, %.5f, %.5f", secondary.PrimaryPart.Position.X, secondary.PrimaryPart.Position.Y, secondary.PrimaryPart.Position.Z)
                data.SecondaryRotation = string.format("%.5f,%.5f,%.5f",
                    math.deg(secondary.PrimaryPart.Rotation.X),
                    math.deg(secondary.PrimaryPart.Rotation.Y),
                    math.deg(secondary.PrimaryPart.Rotation.Z)
                )
            end
        end

        return data
    end

    local function saveBuild()
        local blocks = getAllBlocks()
        if #blocks == 0 then
            Library:Notify("No blocks found to save.", 3)
            return
        end

        local blockTypes = {}
        local blocksData = {}

        for _, block in ipairs(blocks) do
            local blockName = block.Name
            if not table.find(blockTypes, blockName) then
                table.insert(blockTypes, blockName)
            end
            local data = getBlockData(block)
            if data then
                if not blocksData[blockName] then
                    blocksData[blockName] = {}
                end
                table.insert(blocksData[blockName], data)
            end
        end

        local buildData = { blockTypes, blocksData }
        local json = game:GetService("HttpService"):JSONEncode(buildData)

        if saveOutput then
            saveOutput:SetText(json)
        end

        Library:Notify("Build saved to JSON (" .. #blocks .. " blocks)", 2)
        return json
    end

    -- Загрузка из JSON
    local function loadBuild(jsonString)
        local success, decoded = pcall(function()
            return game:GetService("HttpService"):JSONDecode(jsonString)
        end)
        if not success then
            Library:Notify("Invalid JSON format.", 3)
            return
        end

        local blockTypes = decoded[1]
        local blocksData = decoded[2]
        if not blockTypes or not blocksData then
            Library:Notify("Invalid build format.", 3)
            return
        end

        local totalBlocks = 0
        for _, list in pairs(blocksData) do
            totalBlocks = totalBlocks + #list
        end

        Library:Notify("Loading " .. totalBlocks .. " blocks...", 2)

        -- Попытка использовать ремоут для размещения
        local placeRemote = nil
        local toolScript = script.Parent:FindFirstChild("Build") -- предположим, что скрипт строительства находится в родителе
        if toolScript then
            local remote = toolScript:FindFirstChild("RF")
            if remote and remote:IsA("RemoteFunction") then
                placeRemote = remote
            end
        end

        -- Если не нашли, ищем в ReplicatedStorage
        if not placeRemote then
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes then
                placeRemote = remotes:FindFirstChild("PlaceBlock") or remotes:FindFirstChild("BuildBlock")
            end
        end

        local buildingParts = ReplicatedStorage:FindFirstChild("BuildingParts")
        if not buildingParts then
            Library:Notify("BuildingParts not found.", 3)
            return
        end

        local LocalPlayer = game:GetService("Players").LocalPlayer

        for blockName, blockList in pairs(blocksData) do
            local template = buildingParts:FindFirstChild(blockName)
            if not template then
                Library:Notify("Block type '" .. blockName .. "' not found.", 3)
                continue
            end

            for _, data in ipairs(blockList) do
                local newBlock = template:Clone()
                newBlock.Parent = workspace

                -- Применяем данные к PrimaryPart
                local primary = newBlock.PrimaryPart
                if primary then
                    -- Позиция
                    local posParts = {}
                    for part in string.gmatch(data.Position, "[^,]+") do
                        table.insert(posParts, tonumber(part))
                    end
                    if #posParts == 3 then
                        primary.Position = Vector3.new(posParts[1], posParts[2], posParts[3])
                    end

                    -- Поворот
                    local rotParts = {}
                    for part in string.gmatch(data.Rotation, "[^,]+") do
                        table.insert(rotParts, tonumber(part))
                    end
                    if #rotParts == 3 then
                        local rx, ry, rz = math.rad(rotParts[1]), math.rad(rotParts[2]), math.rad(rotParts[3])
                        primary.CFrame = CFrame.new(primary.Position) * CFrame.Angles(rx, ry, rz)
                    end

                    -- Размер
                    local sizeParts = {}
                    for part in string.gmatch(data.Size, "[^,]+") do
                        table.insert(sizeParts, tonumber(part))
                    end
                    if #sizeParts == 3 then
                        primary.Size = Vector3.new(sizeParts[1], sizeParts[2], sizeParts[3])
                    end

                    -- Цвет
                    local colorParts = {}
                    for part in string.gmatch(data.Color, "[^,]+") do
                        table.insert(colorParts, tonumber(part))
                    end
                    if #colorParts == 3 then
                        primary.Color = Color3.new(colorParts[1], colorParts[2], colorParts[3])
                    end

                    primary.Transparency = data.Transparency or 0
                    primary.Anchored = data.Anchored or true
                    primary.CanCollide = data.CanCollide or true
                    primary.CastShadow = data.ShowShadow or false

                    -- NumberValues
                    if data.NumberValues then
                        for name, value in pairs(data.NumberValues) do
                            local nv = newBlock:FindFirstChild(name)
                            if nv and nv:IsA("NumberValue") then
                                nv.Value = value
                            else
                                local newNV = Instance.new("NumberValue")
                                newNV.Name = name
                                newNV.Value = value
                                newNV.Parent = newBlock
                            end
                        end
                    end

                    -- BindTable
                    if data.BindTable then
                        local bt = newBlock:FindFirstChild("BindTable")
                        if bt and bt:IsA("ValueBase") then
                            bt.Value = data.BindTable
                        else
                            local newBT = Instance.new("BindTable") -- предположим, что это ValueBase
                            newBT.Name = "BindTable"
                            newBT.Value = data.BindTable
                            newBT.Parent = newBlock
                        end
                    end

                    -- OtherValues
                    if data.OtherValues then
                        for name, value in pairs(data.OtherValues) do
                            local vb = newBlock:FindFirstChild(name)
                            if vb and vb:IsA("ValueBase") then
                                vb.Value = value
                            else
                                local newVB = Instance.new("StringValue") -- или NumberValue, но используем StringValue для универсальности
                                newVB.Name = name
                                newVB.Value = tostring(value)
                                newVB.Parent = newBlock
                            end
                        end
                    end

                    -- SecondaryPart для составных блоков
                    if data.SecondaryPosition and newBlock:FindFirstChild("2ndPlacement") then
                        local secondary = newBlock:FindFirstChild("SecondaryPart")
                        if secondary and secondary:IsA("Model") and secondary.PrimaryPart then
                            local secPosParts = {}
                            for part in string.gmatch(data.SecondaryPosition, "[^,]+") do
                                table.insert(secPosParts, tonumber(part))
                            end
                            if #secPosParts == 3 then
                                secondary.PrimaryPart.Position = Vector3.new(secPosParts[1], secPosParts[2], secPosParts[3])
                            end
                            local secRotParts = {}
                            for part in string.gmatch(data.SecondaryRotation, "[^,]+") do
                                table.insert(secRotParts, tonumber(part))
                            end
                            if #secRotParts == 3 then
                                local rx, ry, rz = math.rad(secRotParts[1]), math.rad(secRotParts[2]), math.rad(secRotParts[3])
                                secondary.PrimaryPart.CFrame = CFrame.new(secondary.PrimaryPart.Position) * CFrame.Angles(rx, ry, rz)
                            end
                        end
                    end
                end

                -- Если есть ремоут, пытаемся отправить на сервер (для корректной регистрации)
                if placeRemote then
                    pcall(function()
                        placeRemote:InvokeServer(newBlock.Name, 1, nil, nil, false, newBlock.PrimaryPart.CFrame, nil)
                    end)
                else
                    -- Если ремоута нет, просто размещаем в workspace
                    newBlock.Parent = workspace
                end
            end
        end

        Library:Notify("Build loaded successfully!", 2)
    end

    -- ===== UI =====

    saveGroup:AddButton('Save Build', function()
        saveBuild()
    end)

    saveGroup:AddButton('Copy JSON', function()
        local json = saveBuild()
        if json and setclipboard then
            setclipboard(json)
            Library:Notify("JSON copied to clipboard!", 2)
        end
    end)

    saveGroup:AddButton('Save to File', function()
        local json = saveBuild()
        if json and writefile then
            local filename = "build_" .. os.time() .. ".build"
            writefile(filename, json)
            Library:Notify("Saved to " .. filename, 2)
        else
            Library:Notify("writefile not supported.", 3)
        end
    end)

    loadGroup:AddInput('LoadInput', {
        Text = 'Paste JSON here',
        Default = '',
        Placeholder = 'Paste .build JSON...',
        MultiLine = true,
        Finished = true,
        Callback = function(text)
            loadInput = text
        end
    })

    loadGroup:AddButton('Load Build', function()
        if loadInput and loadInput ~= '' then
            loadBuild(loadInput)
        else
            Library:Notify("No JSON input provided.", 3)
        end
    end)

    loadGroup:AddButton('Load from File', function()
        if readfile then
            local files = listfiles()
            local buildFiles = {}
            for _, file in ipairs(files) do
                if file:match("%.build$") then
                    table.insert(buildFiles, file)
                end
            end
            if #buildFiles == 0 then
                Library:Notify("No .build files found.", 3)
                return
            end
            -- Просто загружаем последний файл
            local latest = buildFiles[#buildFiles]
            local content = readfile(latest)
            if content then
                loadBuild(content)
                Library:Notify("Loaded from " .. latest, 2)
            end
        else
            Library:Notify("readfile not supported.", 3)
        end
    end)

    optionsGroup:AddToggle('AutoSaveOnDeath', {
        Text = 'Auto Save on Death',
        Default = false,
        Tooltip = 'Automatically save build when you die.'
    })

    optionsGroup:AddToggle('AutoLoadOnSpawn', {
        Text = 'Auto Load on Spawn',
        Default = false,
        Tooltip = 'Automatically load last build when you spawn.'
    })

    -- Автосохранение при смерти
    local function setupAutoSave()
        local player = game:GetService("Players").LocalPlayer
        if not player then return end
        player.CharacterAdded:Connect(function(char)
            if Options.AutoSaveOnDeath and Options.AutoSaveOnDeath.Value then
                task.wait(1)
                saveBuild()
            end
        end)
    end

    -- Автозагрузка при спавне
    local function setupAutoLoad()
        local player = game:GetService("Players").LocalPlayer
        if not player then return end
        player.CharacterAdded:Connect(function(char)
            if Options.AutoLoadOnSpawn and Options.AutoLoadOnSpawn.Value then
                task.wait(2)
                if readfile then
                    local files = listfiles()
                    local buildFiles = {}
                    for _, file in ipairs(files) do
                        if file:match("%.build$") then
                            table.insert(buildFiles, file)
                        end
                    end
                    if #buildFiles > 0 then
                        local latest = buildFiles[#buildFiles]
                        local content = readfile(latest)
                        if content then
                            loadBuild(content)
                        end
                    end
                end
            end
        end)
    end

    -- Запускаем автоматику
    task.spawn(setupAutoSave)
    task.spawn(setupAutoLoad)

    Library:Notify("AutobuildManager loaded!", 2)
end

return AutobuildManager
