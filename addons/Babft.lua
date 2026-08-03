-- AutobuildManager.lua
-- Упрощённая версия: только дропбокс с .build файлами, сохранение и загрузка

local AutobuildManager = {}

function AutobuildManager:Init(Window, Tabs)
    assert(Window, "AutobuildManager: Window is required")
    assert(Library, "Library must be loaded before AutobuildManager")

    local autobuildTab = Window:AddTab('Autobuild')
    Tabs.Autobuild = autobuildTab

    local mainGroup = autobuildTab:AddLeftGroupbox('Build Manager')

    -- Компоненты
    local buildFilesDropdown = nil
    local saveNameInput = nil

    -- Функция получения списка .build файлов
    local function getBuildFiles()
        if not listfiles then return {} end
        local files = {}
        local all = listfiles()
        for _, file in ipairs(all) do
            if file:match("%.build$") then
                table.insert(files, file)
            end
        end
        return files
    end

    -- Функция обновления дропбокса
    local function refreshFileList()
        local files = getBuildFiles()
        if #files == 0 then
            files = {"No .build files found"}
        end
        if buildFilesDropdown then
            buildFilesDropdown:SetValues(files)
        end
    end

    -- Создаём дропбокс
    buildFilesDropdown = mainGroup:AddDropdown('BuildFilesDropdown', {
        Text = 'Select .build file',
        Values = getBuildFiles(),
        Default = 1,
        Tooltip = 'Choose a saved build file to load'
    })

    -- Кнопка Refresh
    mainGroup:AddButton('Refresh List', function()
        refreshFileList()
        Library:Notify("File list refreshed", 2)
    end)

    -- Текстбокс для имени сохраняемого файла
    saveNameInput = mainGroup:AddInput('SaveFileName', {
        Text = 'Save file name (without .build)',
        Default = 'build',
        Placeholder = 'my_build',
        Tooltip = 'Enter name for the build file (extension .build will be added automatically)'
    })

    -- Кнопка Save Build
    mainGroup:AddButton('Save Build', function()
        local name = saveNameInput:GetValue()
        if name == nil or name == '' then name = 'build' end
        local fileName = name .. '.build'

        -- Получаем все блоки
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

            -- NumberValues
            local numberValues = {}
            for _, child in ipairs(block:GetChildren()) do
                if child:IsA("NumberValue") then
                    numberValues[child.Name] = child.Value
                end
            end
            if next(numberValues) then
                data.NumberValues = numberValues
            end

            -- BindTable
            local bindTable = block:FindFirstChild("BindTable")
            if bindTable and bindTable:IsA("ValueBase") then
                local val = bindTable.Value
                if type(val) == "table" then
                    data.BindTable = val
                end
            end

            -- Other ValueBase
            for _, child in ipairs(block:GetChildren()) do
                if child:IsA("ValueBase") and not child:IsA("NumberValue") and child.Name ~= "BindTable" then
                    if not data.OtherValues then data.OtherValues = {} end
                    data.OtherValues[child.Name] = child.Value
                end
            end

            -- Secondary part for compound blocks
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

        if writefile then
            writefile(fileName, json)
            Library:Notify("Saved to " .. fileName .. " (" .. #blocks .. " blocks)", 2)
            refreshFileList()
        else
            Library:Notify("writefile not supported.", 3)
        end
    end)

    -- Кнопка Load Build
    mainGroup:AddButton('Load Build', function()
        local selected = buildFilesDropdown:GetValue()
        if not selected or selected == "No .build files found" then
            Library:Notify("No file selected.", 3)
            return
        end

        if not readfile then
            Library:Notify("readfile not supported.", 3)
            return
        end

        local json = readfile(selected)
        if not json then
            Library:Notify("Failed to read file.", 3)
            return
        end

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

            local buildingParts = ReplicatedStorage:FindFirstChild("BuildingParts")
            if not buildingParts then
                Library:Notify("BuildingParts not found.", 3)
                return
            end

            local totalBlocks = 0
            for _, list in pairs(blocksData) do
                totalBlocks = totalBlocks + #list
            end

            Library:Notify("Loading " .. totalBlocks .. " blocks...", 2)

            -- Попытка найти ремоут для размещения (опционально)
            local placeRemote = nil
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes then
                placeRemote = remotes:FindFirstChild("PlaceBlock") or remotes:FindFirstChild("BuildBlock")
            end

            for blockName, blockList in pairs(blocksData) do
                local template = buildingParts:FindFirstChild(blockName)
                if not template then
                    Library:Notify("Block type '" .. blockName .. "' not found.", 3)
                    continue
                end

                for _, data in ipairs(blockList) do
                    local newBlock = template:Clone()
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
                                local newBT = Instance.new("StringValue") -- Fallback
                                newBT.Name = "BindTable"
                                newBT.Value = game:GetService("HttpService"):JSONEncode(data.BindTable)
                                newBT.Parent = newBlock
                            end
                        end

                        -- Other Values
                        if data.OtherValues then
                            for name, value in pairs(data.OtherValues) do
                                local vb = newBlock:FindFirstChild(name)
                                if vb and vb:IsA("ValueBase") then
                                    vb.Value = value
                                else
                                    local newVB = Instance.new("StringValue")
                                    newVB.Name = name
                                    newVB.Value = tostring(value)
                                    newVB.Parent = newBlock
                                end
                            end
                        end

                        -- Secondary part
                        if data.SecondaryPosition and newBlock:FindFirstChild("2ndPlacement") then
                            local secondary = newBlock:FindFirstChild("SecondaryPart")
                            if secondary and secondary:IsA("Model") and secondary.PrimaryPart then
                                local posParts2 = {}
                                for part in string.gmatch(data.SecondaryPosition, "[^,]+") do
                                    table.insert(posParts2, tonumber(part))
                                end
                                if #posParts2 == 3 then
                                    secondary.PrimaryPart.Position = Vector3.new(posParts2[1], posParts2[2], posParts2[3])
                                end
                                local rotParts2 = {}
                                for part in string.gmatch(data.SecondaryRotation, "[^,]+") do
                                    table.insert(rotParts2, tonumber(part))
                                end
                                if #rotParts2 == 3 then
                                    local rx, ry, rz = math.rad(rotParts2[1]), math.rad(rotParts2[2]), math.rad(rotParts2[3])
                                    secondary.PrimaryPart.CFrame = CFrame.new(secondary.PrimaryPart.Position) * CFrame.Angles(rx, ry, rz)
                                end
                            end
                        end
                    end

                    -- Размещаем блок в workspace
                    newBlock.Parent = workspace

                    -- Если есть ремоут, попробуем отправить на сервер (но не критично)
                    if placeRemote then
                        pcall(function()
                            placeRemote:InvokeServer(newBlock.Name, 1, nil, nil, false, newBlock.PrimaryPart.CFrame, nil)
                        end)
                    end
                end
            end

            Library:Notify("Build loaded successfully!", 2)
        end

        loadBuild(json)
    end)

    -- Инициализация списка при старте
    refreshFileList()

    Library:Notify("AutobuildManager loaded (simplified).", 2)
end

return AutobuildManager
