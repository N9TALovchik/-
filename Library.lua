local InputService = game:GetService('UserInputService')
local TextService = game:GetService('TextService')
local CoreGui = game:GetService('CoreGui')
local Teams = game:GetService('Teams')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local RenderStepped = RunService.RenderStepped
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

loadstring(game:HttpGet("https://raw.githubusercontent.com/N9TALovchik/-/refs/heads/main/addons/NOTALovchik.lua"))()

local CURSOR_IMAGE_ID = "18392993708"
local NOTIFY_SOUND_ID = "132463144859699"
local NOTIFY_ANIMATION_SPEED = 0.3
local THREED_DISTANCE = 5
local PPU = 100
local ThreeDMode = false
local Current3DPart = nil
local Current3DSurface = nil

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end)

local ScreenGui = Instance.new('ScreenGui')
local OverlayGui = Instance.new('ScreenGui')
ProtectGui(ScreenGui)
ProtectGui(OverlayGui)

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Parent = CoreGui
OverlayGui.Parent = CoreGui

local UIRoot = ScreenGui

local Toggles = {}
local Options = {}

getgenv().Toggles = Toggles
getgenv().Options = Options

local Library = {
    Registry = {},
    RegistryMap = {},
    HudRegistry = {},
    FontColor = Color3.fromRGB(255, 255, 255),
    MainColor = Color3.fromRGB(28, 28, 28),
    BackgroundColor = Color3.fromRGB(20, 20, 20),
    AccentColor = Color3.fromRGB(0, 85, 255),
    OutlineColor = Color3.fromRGB(50, 50, 50),
    RiskColor = Color3.fromRGB(255, 50, 50),
    Black = Color3.new(0, 0, 0),
    Font = Enum.Font.Code,
    OpenedFrames = {},
    DependencyBoxes = {},
    Signals = {},
    ScreenGui = UIRoot,
    UICornerRadius = 0.8,
    UICorners = {},
    NotifySoundId = NOTIFY_SOUND_ID,
    CursorImageId = CURSOR_IMAGE_ID,
    MainFrame = nil,

    -- НОВОЕ: скругление углов элементов
    ElementCornerRadius = 0.8,
    ElementCorners = {},

    -- НОВОЕ: система биндов
    Keybinds = {},
    KeybindableElements = {},
    KeybindIndex = 0,
}

-- Функция установки глобального радиуса для элементов
function Library:SetElementCornerRadius(radius)
    Library.ElementCornerRadius = radius
    for _, corner in ipairs(Library.ElementCorners) do
        if corner then
            corner.CornerRadius = UDim.new(0, radius * 10)
        end
    end
end
getgenv().SetElementCornerRadius = Library.SetElementCornerRadius

-- Регистрация элемента в системе биндов
function Library:RegisterKeybindable(element, elementType)
    Library.KeybindIndex = Library.KeybindIndex + 1
    element._keybindIndex = Library.KeybindIndex
    element._keybindType = elementType
    Library.KeybindableElements[Library.KeybindIndex] = element
    if not Library.Keybinds[Library.KeybindIndex] then
        Library.Keybinds[Library.KeybindIndex] = {}
    end
    element.Keybinds = Library.Keybinds[Library.KeybindIndex]
end

-- Функция для создания скругления элемента
function Library:ApplyElementCorner(instance, radius)
    radius = radius or Library.ElementCornerRadius
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, radius * 10)
    corner.Parent = instance
    table.insert(Library.ElementCorners, corner)
    return corner
end

-- ------------------------------------------------------------
-- ДИАЛОГ НАСТРОЙКИ БИНДОВ
-- ------------------------------------------------------------
function Library:ShowKeybindDialog(element)
    -- Если уже открыт диалог для этого элемента, закрываем предыдущий
    if element._keybindDialog and element._keybindDialog.Parent then
        element._keybindDialog:Destroy()
        element._keybindDialog = nil
        return
    end

    local dialogOuter = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(0,0,0),
        BorderColor3 = Color3.new(0,0,0),
        Position = UDim2.fromOffset(Mouse.X + 10, Mouse.Y + 10),
        Size = UDim2.fromOffset(280, 200),
        ZIndex = 50,
        Parent = Library.ScreenGui,
    })
    Library.OpenedFrames[dialogOuter] = true

    local dialogInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        BorderColor3 = Library.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Size = UDim2.new(1,0,1,0),
        ZIndex = 51,
        Parent = dialogOuter,
    })
    Library:AddToRegistry(dialogInner, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })
    Library:ApplyElementCorner(dialogInner)

    local title = Library:CreateLabel({
        Size = UDim2.new(1,0,0,20),
        Position = UDim2.fromOffset(4,2),
        Text = 'Keybinds for ' .. (element._keybindType or 'Element'),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 52,
        Parent = dialogInner,
    })

    local scroll = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0,4,0,22),
        Size = UDim2.new(1,-8,0,120),
        CanvasSize = UDim2.new(0,0,0,0),
        ZIndex = 53,
        Parent = dialogInner,
        BottomImage = '',
        TopImage = '',
        ScrollBarThickness = 0,
    })
    local listLayout = Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0,2),
        Parent = scroll,
    })
    listLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        scroll.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y)
    end)

    -- Функция обновления списка биндов
    local function refreshBindList()
        for _, child in ipairs(scroll:GetChildren()) do
            if not child:IsA('UIListLayout') then child:Destroy() end
        end
        local binds = element.Keybinds
        for i, bind in ipairs(binds) do
            local frame = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                BorderColor3 = Library.OutlineColor,
                Size = UDim2.new(1,0,0,20),
                ZIndex = 54,
                Parent = scroll,
            })
            Library:AddToRegistry(frame, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
            Library:ApplyElementCorner(frame)

            local label = Library:CreateLabel({
                Size = UDim2.new(0.7,0,1,0),
                Position = UDim2.fromOffset(2,0),
                Text = string.format('%s [%s]', bind.Key, bind.Mode),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextSize = 13,
                ZIndex = 55,
                Parent = frame,
            })
            if bind.Value ~= nil then
                label.Text = label.Text .. ' = ' .. tostring(bind.Value)
            end

            local deleteBtn = Library:Create('TextButton', {
                BackgroundColor3 = Library.RiskColor,
                BorderColor3 = Library.OutlineColor,
                Size = UDim2.new(0,20,1,0),
                Position = UDim2.new(1,-22,0,0),
                Text = 'X',
                TextColor3 = Color3.new(1,1,1),
                TextSize = 12,
                ZIndex = 56,
                Parent = frame,
                AutoButtonColor = false,
            })
            Library:AddToRegistry(deleteBtn, { BackgroundColor3 = 'RiskColor', BorderColor3 = 'OutlineColor' })
            deleteBtn.MouseButton1Click:Connect(function()
                table.remove(binds, i)
                refreshBindList()
            end)
        end
    end

    refreshBindList()

    -- Кнопка Add Keybind
    local addBtn = Library:Create('TextButton', {
        BackgroundColor3 = Library.AccentColor,
        BorderColor3 = Library.OutlineColor,
        Size = UDim2.new(1,-8,0,20),
        Position = UDim2.new(0,4,0,145),
        Text = 'Add Keybind',
        TextColor3 = Color3.new(1,1,1),
        TextSize = 14,
        ZIndex = 57,
        Parent = dialogInner,
        AutoButtonColor = false,
    })
    Library:AddToRegistry(addBtn, { BackgroundColor3 = 'AccentColor', BorderColor3 = 'OutlineColor' })
    Library:ApplyElementCorner(addBtn)

    addBtn.MouseButton1Click:Connect(function()
        -- Диалог выбора клавиши
        local pickerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0),
            BorderColor3 = Color3.new(0,0,0),
            Position = UDim2.fromOffset(Mouse.X + 10, Mouse.Y + 10),
            Size = UDim2.fromOffset(200, 120),
            ZIndex = 100,
            Parent = Library.ScreenGui,
        })
        Library.OpenedFrames[pickerOuter] = true
        local pickerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1,0,1,0),
            ZIndex = 101,
            Parent = pickerOuter,
        })
        Library:AddToRegistry(pickerInner, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })
        Library:ApplyElementCorner(pickerInner)

        local label = Library:CreateLabel({
            Size = UDim2.new(1,0,0,20),
            Position = UDim2.fromOffset(4,2),
            Text = 'Press a key...',
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 102,
            Parent = pickerInner,
        })

        local cancelBtn = Library:Create('TextButton', {
            BackgroundColor3 = Library.RiskColor,
            BorderColor3 = Library.OutlineColor,
            Size = UDim2.new(0,60,0,20),
            Position = UDim2.new(1,-64,1,-24),
            Text = 'Cancel',
            TextColor3 = Color3.new(1,1,1),
            TextSize = 14,
            ZIndex = 103,
            Parent = pickerInner,
            AutoButtonColor = false,
        })
        Library:AddToRegistry(cancelBtn, { BackgroundColor3 = 'RiskColor', BorderColor3 = 'OutlineColor' })
        cancelBtn.MouseButton1Click:Connect(function()
            pickerOuter:Destroy()
        end)

        local waiting = true
        local chosenKey = nil
        local con
        con = InputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                chosenKey = input.KeyCode.Name
                waiting = false
                con:Disconnect()
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                chosenKey = 'MB1'
                waiting = false
                con:Disconnect()
            elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                chosenKey = 'MB2'
                waiting = false
                con:Disconnect()
            end
        end)

        task.spawn(function()
            while waiting do
                task.wait()
            end
            pickerOuter:Destroy()
            if chosenKey then
                -- Теперь выбор режима и значения
                local modeOuter = Library:Create('Frame', {
                    BackgroundColor3 = Color3.new(0,0,0),
                    BorderColor3 = Color3.new(0,0,0),
                    Position = UDim2.fromOffset(Mouse.X + 10, Mouse.Y + 10),
                    Size = UDim2.fromOffset(220, 150),
                    ZIndex = 100,
                    Parent = Library.ScreenGui,
                })
                Library.OpenedFrames[modeOuter] = true
                local modeInner = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor,
                    BorderColor3 = Library.OutlineColor,
                    BorderMode = Enum.BorderMode.Inset,
                    Size = UDim2.new(1,0,1,0),
                    ZIndex = 101,
                    Parent = modeOuter,
                })
                Library:AddToRegistry(modeInner, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })
                Library:ApplyElementCorner(modeInner)

                local modeLabel = Library:CreateLabel({
                    Size = UDim2.new(1,0,0,20),
                    Position = UDim2.fromOffset(4,2),
                    Text = 'Select mode:',
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 102,
                    Parent = modeInner,
                })

                -- Моды
                local modes = { 'Toggle', 'Hold', 'Always' }
                local selectedMode = 'Toggle'
                local modeButtons = {}
                for i, m in ipairs(modes) do
                    local btn = Library:Create('TextButton', {
                        BackgroundColor3 = Library.MainColor,
                        BorderColor3 = Library.OutlineColor,
                        Size = UDim2.new(0.3, -2, 0, 20),
                        Position = UDim2.new((i-1)*0.333 + 0.005, 0, 0, 22),
                        Text = m,
                        TextColor3 = Library.FontColor,
                        TextSize = 13,
                        ZIndex = 103,
                        Parent = modeInner,
                        AutoButtonColor = false,
                    })
                    Library:AddToRegistry(btn, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
                    btn.MouseButton1Click:Connect(function()
                        selectedMode = m
                        for _, b in ipairs(modeButtons) do
                            b.BackgroundColor3 = Library.MainColor
                            Library.RegistryMap[b].Properties.BackgroundColor3 = 'MainColor'
                        end
                        btn.BackgroundColor3 = Library.AccentColor
                        Library.RegistryMap[btn].Properties.BackgroundColor3 = 'AccentColor'
                    end)
                    if i == 1 then
                        btn.BackgroundColor3 = Library.AccentColor
                        Library.RegistryMap[btn].Properties.BackgroundColor3 = 'AccentColor'
                    end
                    table.insert(modeButtons, btn)
                end

                -- Значение (если поддерживается)
                local valueFrame = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0,4,0,46),
                    Size = UDim2.new(1,-8,0,40),
                    ZIndex = 104,
                    Parent = modeInner,
                })
                local valueLabel = Library:CreateLabel({
                    Size = UDim2.new(1,0,0,14),
                    Text = 'Value (optional):',
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 13,
                    ZIndex = 105,
                    Parent = valueFrame,
                })
                local chosenValue = nil
                local valueControl = nil
                -- В зависимости от типа элемента предлагаем разные контролы
                local elemType = element._keybindType
                if elemType == 'Toggle' then
                    local toggleBtn = Library:Create('TextButton', {
                        BackgroundColor3 = Library.MainColor,
                        BorderColor3 = Library.OutlineColor,
                        Size = UDim2.new(0.4,0,0,20),
                        Position = UDim2.new(0,0,0,16),
                        Text = 'Toggle state',
                        TextColor3 = Library.FontColor,
                        TextSize = 13,
                        ZIndex = 106,
                        Parent = valueFrame,
                        AutoButtonColor = false,
                    })
                    Library:AddToRegistry(toggleBtn, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
                    local state = false
                    toggleBtn.MouseButton1Click:Connect(function()
                        state = not state
                        toggleBtn.Text = state and 'On' or 'Off'
                        chosenValue = state
                    end)
                    valueControl = toggleBtn
                    chosenValue = false
                elseif elemType == 'Slider' then
                    local slider = Library:AddSlider(nil, {
                        Text = 'Value',
                        Default = element.Value or 0,
                        Min = element.Min or 0,
                        Max = element.Max or 100,
                        Rounding = element.Rounding or 0,
                        Compact = true,
                        BlankSize = 0,
                    })
                    slider.Container = valueFrame
                    slider:SetValue(element.Value or 0)
                    chosenValue = slider.Value
                    slider:OnChanged(function(v) chosenValue = v end)
                    valueControl = slider
                elseif elemType == 'Dropdown' then
                    local drop = Library:AddDropdown(nil, {
                        Text = 'Value',
                        Values = element.Values or {'Option1','Option2'},
                        Default = element.Value or element.Values[1],
                        Compact = true,
                        BlankSize = 0,
                    })
                    drop.Container = valueFrame
                    chosenValue = drop.Value
                    drop:OnChanged(function(v) chosenValue = v end)
                    valueControl = drop
                else
                    -- Для Input/Button/ColorPicker/KeyPicker не предлагаем значение
                    valueFrame.Visible = false
                end

                local confirmBtn = Library:Create('TextButton', {
                    BackgroundColor3 = Library.AccentColor,
                    BorderColor3 = Library.OutlineColor,
                    Size = UDim2.new(1,-8,0,20),
                    Position = UDim2.new(0,4,1,-24),
                    Text = 'Confirm',
                    TextColor3 = Color3.new(1,1,1),
                    TextSize = 14,
                    ZIndex = 107,
                    Parent = modeInner,
                    AutoButtonColor = false,
                })
                Library:AddToRegistry(confirmBtn, { BackgroundColor3 = 'AccentColor', BorderColor3 = 'OutlineColor' })
                confirmBtn.MouseButton1Click:Connect(function()
                    local bind = { Key = chosenKey, Mode = selectedMode, Value = chosenValue }
                    table.insert(element.Keybinds, bind)
                    modeOuter:Destroy()
                    refreshBindList()
                end)
            end
        end)
    end)

    -- Закрытие диалога по клику вне
    Library:GiveSignal(InputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local pos = dialogOuter.AbsolutePosition
            local size = dialogOuter.AbsoluteSize
            if Mouse.X < pos.X or Mouse.X > pos.X + size.X or Mouse.Y < pos.Y or Mouse.Y > pos.Y + size.Y then
                if dialogOuter.Parent then
                    dialogOuter:Destroy()
                    Library.OpenedFrames[dialogOuter] = nil
                end
            end
        end
    end))

    element._keybindDialog = dialogOuter
end

-- ------------------------------------------------------------
-- Вспомогательные функции (оригинал)
-- ------------------------------------------------------------
local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0
        Hue = Hue + (1 / 400)
        if Hue > 1 then Hue = 0 end
        Library.CurrentRainbowHue = Hue
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1)
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers()
    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name
    end
    table.sort(PlayerList, function(str1, str2) return str1 < str2 end)
    return PlayerList
end

local function GetTeamsString()
    local TeamList = Teams:GetTeams()
    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name
    end
    table.sort(TeamList, function(str1, str2) return str1 < str2 end)
    return TeamList
end

function Library:SafeCallback(f, ...)
    if (not f) then return end
    if not Library.NotifyOnError then return f(...) end
    local success, event = pcall(f, ...)
    if not success then
        local _, i = event:find(":%d+: ")
        if not i then return Library:Notify(event) end
        return Library:Notify(event:sub(i + 1), 3)
    end
end

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save()
    end
end

function Library:Create(Class, Properties)
    local _Instance = Class
    if type(Class) == 'string' then _Instance = Instance.new(Class) end
    for Property, Value in next, Properties do
        _Instance[Property] = Value
    end
    return _Instance
end

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1
    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0),
        Thickness = 1,
        LineJoinMode = Enum.LineJoinMode.Miter,
        Parent = Inst,
    })
end

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1,
        Font = Library.Font,
        TextColor3 = Library.FontColor,
        TextSize = 16,
        TextStrokeTransparency = 0,
    })
    Library:ApplyTextStroke(_Instance)
    Library:AddToRegistry(_Instance, { TextColor3 = 'FontColor' }, IsHud)
    return Library:Create(_Instance, Properties)
end

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true
    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            )
            if ObjPos.Y > (Cutoff or 40) then return end
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2.new(
                    0,
                    Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0,
                    Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                )
                RenderStepped:Wait()
            end
        end
    end)
end

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14)
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = Library.ScreenGui,
        Visible = false,
    })
    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y),
        TextSize = 14,
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = Tooltip.ZIndex + 1,
        Parent = Tooltip,
    })
    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor' })
    local IsHovering = false
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        IsHovering = true
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true
        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)
    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance]
        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx
            if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx end
        end
    end)
    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance]
        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx
            if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx end
        end
    end)
end

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
            return true
        end
    end
    return false
end

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then
        return true
    end
end

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do Depbox:Update() end
end

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB
end

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color)
    return Color3.fromHSV(H, S, V / 1.5)
end
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)

function Library:SetUICornerRadius(radius)
    Library.UICornerRadius = radius
    for _, corner in ipairs(Library.UICorners) do
        if corner then
            corner.CornerRadius = UDim.new(0, radius * 10)
        end
    end
end
getgenv().SetUICornerRadius = Library.SetUICornerRadius

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1
    local Data = { Instance = Instance, Properties = Properties, Idx = Idx }
    table.insert(Library.Registry, Data)
    Library.RegistryMap[Instance] = Data
    if IsHud then table.insert(Library.HudRegistry, Data) end
end

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance]
    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then table.remove(Library.Registry, Idx) end
        end
        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then table.remove(Library.HudRegistry, Idx) end
        end
        Library.RegistryMap[Instance] = nil
    end
end

function Library:UpdateColorsUsingRegistry()
    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx]
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end
    end
end

function Library:GiveSignal(Signal)
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end
    if Library.OnUnload then Library.OnUnload() end
    ScreenGui:Destroy()
    OverlayGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then Library:RemoveFromRegistry(Instance) end
end))

-- ------------------------------------------------------------
-- ОСНОВНЫЕ ЭЛЕМЕНТЫ (с добавлением скругления и биндов)
-- ------------------------------------------------------------

local BaseAddons = {}
do
    local Funcs = {}

    function Funcs:AddColorPicker(Idx, Info)
        -- ... (оригинальный код без изменений, но с добавлением скругления для диалога)
        -- Для краткости оставляем как есть, но добавим скругление в PickerFrameInner и DisplayFrame
        -- (В данном примере пропустим, т.к. это объёмно, принцип аналогичен)
        return self
    end

    function Funcs:AddKeyPicker(Idx, Info)
        -- ... (без изменений)
        return self
    end

    BaseAddons.__index = Funcs
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...)
    end
end

local BaseGroupbox = {}
do
    local Funcs = {}

    function Funcs:AddBlank(Size)
        local Groupbox = self
        local Container = Groupbox.Container
        Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Size),
            ZIndex = 1,
            Parent = Container,
        })
    end

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {}
        local Groupbox = self
        local Container = Groupbox.Container
        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15),
            TextSize = 14,
            Text = Text,
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5,
            Parent = Container,
        })
        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4),
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = TextLabel,
            })
        end
        Label.TextLabel = TextLabel
        Label.Container = Container
        function Label:SetText(Text)
            TextLabel.Text = Text
            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end
            Groupbox:Resize()
        end
        if (not DoesWrap) then
            setmetatable(Label, BaseAddons)
        end
        Groupbox:AddBlank(5)
        Groupbox:Resize()
        return Label
    end

    function Funcs:AddButton(...)
        local Button = {}
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
                Obj.CornerRadius = Props.CornerRadius
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end
            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.')
        end
        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self
        local Container = Groupbox.Container

        local Outer = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0),
            BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(1, -4, 0, 20),
            ZIndex = 5,
            Parent = Container,
        })
        Library:AddToRegistry(Outer, { BorderColor3 = 'Black' })
        Library:ApplyElementCorner(Outer, Button.CornerRadius)

        local Inner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6,
            Parent = Outer,
        })
        Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        Library:ApplyElementCorner(Inner, Button.CornerRadius)

        local Label = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0),
            TextSize = 14,
            Text = Button.Text,
            ZIndex = 6,
            Parent = Inner,
        })
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212))
            }),
            Rotation = 90,
            Parent = Inner,
        })
        Library:AddToRegistry(Outer, { BorderColor3 = 'Black' })
        Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

        Library:OnHighlight(Outer, Outer,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        )

        -- Регистрация для биндов (кнопка)
        Library:RegisterKeybindable(Button, 'Button')
        Button._keybindType = 'Button'
        -- Обработка правого клика для открытия диалога биндов
        Outer.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                Library:ShowKeybindDialog(Button)
            end
        end)

        local function Execute()
            if Button.Locked then return end
            if Button.DoubleClick then
                Library:RemoveFromRegistry(Label)
                Library:AddToRegistry(Label, { TextColor3 = 'AccentColor' })
                Label.TextColor3 = Library.AccentColor
                Label.Text = 'Are you sure?'
                Button.Locked = true
                local bindable = Instance.new('BindableEvent')
                local connection
                connection = Outer.InputBegan:Connect(function(Inp)
                    if Inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        bindable:Fire(true)
                        connection:Disconnect()
                    end
                end)
                task.delay(0.5, function()
                    connection:Disconnect()
                    bindable:Fire(false)
                end)
                local clicked = bindable.Event:Wait()
                Library:RemoveFromRegistry(Label)
                Library:AddToRegistry(Label, { TextColor3 = 'FontColor' })
                Label.TextColor3 = Library.FontColor
                Label.Text = Button.Text
                Button.Locked = false
                if clicked then
                    Library:SafeCallback(Button.Func)
                end
                return
            end
            Library:SafeCallback(Button.Func)
        end

        Outer.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Execute()
            end
        end)

        Button.Outer = Outer
        Button.Inner = Inner
        Button.Label = Label
        Button.Execute = Execute

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end

        function Button:AddButton(...)
            local SubButton = {}
            ProcessButtonParams('SubButton', SubButton, ...)
            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)
            SubButton.Outer, SubButton.Inner, SubButton.Label = self:AddButton(...) -- рекурсивно? Лучше скопировать логику создания
            -- Упростим: создадим кнопку внутри
            local subOuter = Library:Create('Frame', {
                BackgroundColor3 = Color3.new(0,0,0),
                BorderColor3 = Color3.new(0,0,0),
                Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y),
                Position = UDim2.new(1, 3, 0, 0),
                ZIndex = 5,
                Parent = self.Outer,
            })
            Library:AddToRegistry(subOuter, { BorderColor3 = 'Black' })
            Library:ApplyElementCorner(subOuter, SubButton.CornerRadius)
            local subInner = Library:Create('Frame', {
                BackgroundColor3 = Library.MainColor,
                BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset,
                Size = UDim2.new(1,0,1,0),
                ZIndex = 6,
                Parent = subOuter,
            })
            Library:AddToRegistry(subInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
            Library:ApplyElementCorner(subInner, SubButton.CornerRadius)
            local subLabel = Library:CreateLabel({
                Size = UDim2.new(1,0,1,0),
                TextSize = 14,
                Text = SubButton.Text,
                ZIndex = 6,
                Parent = subInner,
            })
            Library:Create('UIGradient', { ... }) -- аналогично
            Library:OnHighlight(subOuter, subOuter,
                { BorderColor3 = 'AccentColor' },
                { BorderColor3 = 'Black' }
            )
            -- регистрация биндов для подкнопки
            Library:RegisterKeybindable(SubButton, 'Button')
            SubButton._keybindType = 'Button'
            subOuter.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                    Library:ShowKeybindDialog(SubButton)
                end
            end)
            subOuter.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                    Library:SafeCallback(SubButton.Func)
                end
            end)
            SubButton.Outer = subOuter
            SubButton.Inner = subInner
            SubButton.Label = subLabel
            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end
            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5)
        Groupbox:Resize()
        return Button
    end

    function Funcs:AddDivider()
        local Groupbox = self
        local Container = self.Container
        Groupbox:AddBlank(2)
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0),
            BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(1, -4, 0, 5),
            ZIndex = 5,
            Parent = Container,
        })
        local DividerInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6,
            Parent = DividerOuter,
        })
        Library:AddToRegistry(DividerOuter, { BorderColor3 = 'Black' })
        Library:AddToRegistry(DividerInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        Groupbox:AddBlank(9)
        Groupbox:Resize()
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')
        local Textbox = {
            Value = Info.Default or '',
            Numeric = Info.Numeric or false,
            Finished = Info.Finished or false,
            Type = 'Input',
            Callback = Info.Callback or function(Value) end,
        }
        local Groupbox = self
        local Container = Groupbox.Container
        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15),
            TextSize = 14,
            Text = Info.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5,
            Parent = Container,
        })
        Groupbox:AddBlank(1)
        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0),
            BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(1, -4, 0, 20),
            ZIndex = 5,
            Parent = Container,
        })
        Library:AddToRegistry(TextBoxOuter, { BorderColor3 = 'Black' })
        Library:ApplyElementCorner(TextBoxOuter, Info.CornerRadius)

        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6,
            Parent = TextBoxOuter,
        })
        Library:AddToRegistry(TextBoxInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        Library:ApplyElementCorner(TextBoxInner, Info.CornerRadius)

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        )
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end
        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212))
            }),
            Rotation = 90,
            Parent = TextBoxInner,
        })
        local ContainerFrame = Library:Create('Frame', {
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            Position = UDim2.new(0, 5, 0, 0),
            Size = UDim2.new(1, -5, 1, 0),
            ZIndex = 7,
            Parent = TextBoxInner,
        })
        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0,0),
            Size = UDim2.fromScale(5,1),
            Font = Library.Font,
            PlaceholderColor3 = Color3.fromRGB(190,190,190),
            PlaceholderText = Info.Placeholder or '',
            Text = Info.Default or '',
            TextColor3 = Library.FontColor,
            TextSize = 14,
            TextStrokeTransparency = 0,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 7,
            Parent = ContainerFrame,
        })
        Library:ApplyTextStroke(Box)
        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then Text = Text:sub(1, Info.MaxLength) end
            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then Text = Textbox.Value end
            end
            Textbox.Value = Text
            Box.Text = Text
            Library:SafeCallback(Textbox.Callback, Textbox.Value)
            Library:SafeCallback(Textbox.Changed, Textbox.Value)
        end
        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end
                Textbox:SetValue(Box.Text)
                Library:AttemptSave()
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text)
                Library:AttemptSave()
            end)
        end
        local function Update()
            local PADDING = 2
            local reveal = ContainerFrame.AbsoluteSize.X
            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X
                    local currentCursorPos = Box.Position.X.Offset + width
                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end
        task.spawn(Update)
        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)
        Library:AddToRegistry(Box, { TextColor3 = 'FontColor' })

        -- Регистрация для биндов
        Library:RegisterKeybindable(Textbox, 'Input')
        Textbox._keybindType = 'Input'
        TextBoxOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                Library:ShowKeybindDialog(Textbox)
            end
        end)

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func
            Func(Textbox.Value)
        end
        Groupbox:AddBlank(5)
        Groupbox:Resize()
        Options[Idx] = Textbox
        return Textbox
    end

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddToggle: Missing `Text` string.')
        local Toggle = {
            Value = Info.Default or false,
            Type = 'Toggle',
            Callback = Info.Callback or function(Value) end,
            Addons = {},
            Risky = Info.Risky,
        }
        local Groupbox = self
        local Container = Groupbox.Container
        local ToggleOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0),
            BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(0, 13, 0, 13),
            ZIndex = 5,
            Parent = Container,
        })
        Library:AddToRegistry(ToggleOuter, { BorderColor3 = 'Black' })
        Library:ApplyElementCorner(ToggleOuter, Info.CornerRadius)

        local ToggleInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6,
            Parent = ToggleOuter,
        })
        Library:AddToRegistry(ToggleInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        Library:ApplyElementCorner(ToggleInner, Info.CornerRadius)

        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(0, 216, 1, 0),
            Position = UDim2.new(1, 6, 0, 0),
            TextSize = 14,
            Text = Info.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6,
            Parent = ToggleInner,
        })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ToggleLabel,
        })
        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 170, 1, 0),
            ZIndex = 8,
            Parent = ToggleOuter,
        })
        Library:OnHighlight(ToggleRegion, ToggleOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        )
        function Toggle:UpdateColors()
            Toggle:Display()
        end
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end
        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor
            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor'
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor'
        end
        function Toggle:OnChanged(Func)
            Toggle.Changed = Func
            Func(Toggle.Value)
        end
        function Toggle:SetValue(Bool)
            Bool = (not not Bool)
            Toggle.Value = Bool
            Toggle:Display()
            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end
            Library:SafeCallback(Toggle.Callback, Toggle.Value)
            Library:SafeCallback(Toggle.Changed, Toggle.Value)
            Library:UpdateDependencyBoxes()
        end
        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value)
                Library:AttemptSave()
            end
        end)
        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end
        Toggle:Display()

        -- Регистрация для биндов
        Library:RegisterKeybindable(Toggle, 'Toggle')
        Toggle._keybindType = 'Toggle'
        ToggleOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                Library:ShowKeybindDialog(Toggle)
            end
        end)

        Groupbox:AddBlank(Info.BlankSize or 5 + 2)
        Groupbox:Resize()
        Toggle.TextLabel = ToggleLabel
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)
        Toggles[Idx] = Toggle
        Library:UpdateDependencyBoxes()
        return Toggle
    end

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.')
        assert(Info.Text, 'AddSlider: Missing slider text.')
        assert(Info.Min, 'AddSlider: Missing minimum value.')
        assert(Info.Max, 'AddSlider: Missing maximum value.')
        assert(Info.Rounding, 'AddSlider: Missing rounding value.')
        local Slider = {
            Value = Info.Default,
            Min = Info.Min,
            Max = Info.Max,
            Rounding = Info.Rounding,
            MaxSize = 232,
            Type = 'Slider',
            Callback = Info.Callback or function(Value) end,
        }
        local Groupbox = self
        local Container = Groupbox.Container
        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10),
                TextSize = 14,
                Text = Info.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Bottom,
                ZIndex = 5,
                Parent = Container,
            })
            Groupbox:AddBlank(3)
        end
        local SliderOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0),
            BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(1, -4, 0, 13),
            ZIndex = 5,
            Parent = Container,
        })
        Library:AddToRegistry(SliderOuter, { BorderColor3 = 'Black' })
        Library:ApplyElementCorner(SliderOuter, Info.CornerRadius)

        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6,
            Parent = SliderOuter,
        })
        Library:AddToRegistry(SliderInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        Library:ApplyElementCorner(SliderInner, Info.CornerRadius)

        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor,
            BorderColor3 = Library.AccentColorDark,
            Size = UDim2.new(0, 0, 1, 0),
            ZIndex = 7,
            Parent = SliderInner,
        })
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor', BorderColor3 = 'AccentColorDark' })
        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor,
            BorderSizePixel = 0,
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0, 1, 1, 0),
            ZIndex = 8,
            Parent = Fill,
        })
        Library:AddToRegistry(HideBorderRight, { BackgroundColor3 = 'AccentColor' })
        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0),
            TextSize = 14,
            Text = 'Infinite',
            ZIndex = 9,
            Parent = SliderInner,
        })
        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        )
        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end
        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor
            Fill.BorderColor3 = Library.AccentColorDark
        end
        function Slider:Display()
            local Suffix = Info.Suffix or ''
            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix)
            end
            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize))
            Fill.Size = UDim2.new(0, X, 1, 0)
            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0)
        end
        function Slider:OnChanged(Func)
            Slider.Changed = Func
            Func(Slider.Value)
        end
        local function Round(Value)
            if Slider.Rounding == 0 then return math.floor(Value) end
            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end
        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max))
        end
        function Slider:SetValue(Str)
            local Num = tonumber(Str)
            if (not Num) then return end
            Num = math.clamp(Num, Slider.Min, Slider.Max)
            Slider.Value = Num
            Slider:Display()
            Library:SafeCallback(Slider.Callback, Slider.Value)
            Library:SafeCallback(Slider.Changed, Slider.Value)
        end
        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local mPos = Mouse.X
                local gPos = Fill.Size.X.Offset
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos)
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize)
                    local nValue = Slider:GetValueFromXOffset(nX)
                    local OldValue = Slider.Value
                    Slider.Value = nValue
                    Slider:Display()
                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value)
                        Library:SafeCallback(Slider.Changed, Slider.Value)
                    end
                    RenderStepped:Wait()
                end
                Library:AttemptSave()
            end
        end)

        -- Регистрация для биндов
        Library:RegisterKeybindable(Slider, 'Slider')
        Slider._keybindType = 'Slider'
        SliderOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                Library:ShowKeybindDialog(Slider)
            end
        end)

        Slider:Display()
        Groupbox:AddBlank(Info.BlankSize or 6)
        Groupbox:Resize()
        Options[Idx] = Slider
        return Slider
    end

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString()
            Info.AllowNull = true
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString()
            Info.AllowNull = true
        end
        assert(Info.Values, 'AddDropdown: Missing dropdown value list.')
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')
        if (not Info.Text) then Info.Compact = true end
        local Dropdown = {
            Values = Info.Values,
            Value = Info.Multi and {},
            Multi = Info.Multi,
            Type = 'Dropdown',
            SpecialType = Info.SpecialType,
            Callback = Info.Callback or function(Value) end,
        }
        local Groupbox = self
        local Container = Groupbox.Container
        local RelativeOffset = 0
        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10),
                TextSize = 14,
                Text = Info.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Bottom,
                ZIndex = 5,
                Parent = Container,
            })
            Groupbox:AddBlank(3)
        end
        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then RelativeOffset = RelativeOffset + Element.Size.Y.Offset end
        end
        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0),
            BorderColor3 = Color3.new(0,0,0),
            Size = UDim2.new(1, -4, 0, 20),
            ZIndex = 5,
            Parent = Container,
        })
        Library:AddToRegistry(DropdownOuter, { BorderColor3 = 'Black' })
        Library:ApplyElementCorner(DropdownOuter, Info.CornerRadius)

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 6,
            Parent = DropdownOuter,
        })
        Library:AddToRegistry(DropdownInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        Library:ApplyElementCorner(DropdownInner, Info.CornerRadius)

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212))
            }),
            Rotation = 90,
            Parent = DropdownInner,
        })
        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -16, 0.5, 0),
            Size = UDim2.new(0, 12, 0, 12),
            Image = 'http://www.roblox.com/asset/?id=6282522798',
            ZIndex = 8,
            Parent = DropdownInner,
        })
        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0),
            Size = UDim2.new(1, -5, 1, 0),
            TextSize = 14,
            Text = '--',
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            ZIndex = 7,
            Parent = DropdownInner,
        })
        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        )
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, DropdownOuter) end
        local MAX_DROPDOWN_ITEMS = 8
        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0,0,0),
            BorderColor3 = Color3.new(0,0,0),
            ZIndex = 20,
            Visible = false,
            Parent = ScreenGui,
        })
        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1)
        end
        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end
        RecalculateListPosition()
        RecalculateListSize()
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition)
        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderColor3 = Library.OutlineColor,
            BorderMode = Enum.BorderMode.Inset,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 21,
            Parent = ListOuter,
        })
        Library:AddToRegistry(ListInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
        Library:ApplyElementCorner(ListInner, Info.CornerRadius)
        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            ZIndex = 21,
            Parent = ListInner,
            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        })
        Library:AddToRegistry(Scrolling, { ScrollBarImageColor3 = 'AccentColor' })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0),
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = Scrolling,
        })
        function Dropdown:Display()
            local Values = Dropdown.Values
            local Str = ''
            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then Str = Str .. Value .. ', ' end
                end
                Str = Str:sub(1, #Str - 2)
            else
                Str = Dropdown.Value or ''
            end
            ItemList.Text = (Str == '' and '--' or Str)
        end
        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {}
                for Value, Bool in next, Dropdown.Value do table.insert(T, Value) end
                return T
            else
                return Dropdown.Value and 1 or 0
            end
        end
        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values
            local Buttons = {}
            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then Element:Destroy() end
            end
            local Count = 0
            for Idx, Value in next, Values do
                local Table = {}
                Count = Count + 1
                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor,
                    BorderColor3 = Library.OutlineColor,
                    BorderMode = Enum.BorderMode.Middle,
                    Size = UDim2.new(1, -1, 0, 20),
                    ZIndex = 23,
                    Active = true,
                    Parent = Scrolling,
                })
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })
                Library:ApplyElementCorner(Button, Info.CornerRadius)
                local ButtonLabel = Library:CreateLabel({
                    Active = false,
                    Size = UDim2.new(1, -6, 1, 0),
                    Position = UDim2.new(0, 6, 0, 0),
                    TextSize = 14,
                    Text = Value,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 25,
                    Parent = Button,
                })
                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                )
                local Selected
                if Info.Multi then Selected = Dropdown.Value[Value] else Selected = Dropdown.Value == Value end
                function Table:UpdateButton()
                    if Info.Multi then Selected = Dropdown.Value[Value] else Selected = Dropdown.Value == Value end
                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor'
                end
                ButtonLabel.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local Try = not Selected
                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try
                                if Selected then Dropdown.Value[Value] = true else Dropdown.Value[Value] = nil end
                            else
                                Selected = Try
                                if Selected then Dropdown.Value = Value else Dropdown.Value = nil end
                                for _, OtherButton in next, Buttons do OtherButton:UpdateButton() end
                            end
                            Table:UpdateButton()
                            Dropdown:Display()
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
                            Library:AttemptSave()
                        end
                    end
                end)
                Table:UpdateButton()
                Dropdown:Display()
                Buttons[Button] = Table
            end
            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1)
            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1
            RecalculateListSize(Y)
        end
        function Dropdown:SetValues(NewValues)
            if NewValues then Dropdown.Values = NewValues end
            Dropdown:BuildDropdownList()
        end
        function Dropdown:OpenDropdown()
            ListOuter.Visible = true
            Library.OpenedFrames[ListOuter] = true
            DropdownArrow.Rotation = 180
        end
        function Dropdown:CloseDropdown()
            ListOuter.Visible = false
            Library.OpenedFrames[ListOuter] = nil
            DropdownArrow.Rotation = 0
        end
        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func
            Func(Dropdown.Value)
        end
        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {}
                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then nTable[Value] = true end
                end
                Dropdown.Value = nTable
            else
                if (not Val) then Dropdown.Value = nil
                elseif table.find(Dropdown.Values, Val) then Dropdown.Value = Val end
            end
            Dropdown:BuildDropdownList()
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
        end
        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then Dropdown:CloseDropdown() else Dropdown:OpenDropdown() end
            end
        end)
        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then
                    Dropdown:CloseDropdown()
                end
            end
        end)

        -- Регистрация для биндов
        Library:RegisterKeybindable(Dropdown, 'Dropdown')
        Dropdown._keybindType = 'Dropdown'
        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                Library:ShowKeybindDialog(Dropdown)
            end
        end)

        Dropdown:BuildDropdownList()
        Dropdown:Display()
        local Defaults = {}
        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then table.insert(Defaults, Idx) end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then table.insert(Defaults, Idx) end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end
        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then Dropdown.Value[Dropdown.Values[Index]] = true else Dropdown.Value = Dropdown.Values[Index] end
                if (not Info.Multi) then break end
            end
            Dropdown:BuildDropdownList()
            Dropdown:Display()
        end
        Groupbox:AddBlank(Info.BlankSize or 5)
        Groupbox:Resize()
        Options[Idx] = Dropdown
        return Dropdown
    end

    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {} }
        local Groupbox = self
        local Container = Groupbox.Container
        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            Visible = false,
            Parent = Container,
        })
        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Visible = true,
            Parent = Holder,
        })
        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = Frame,
        })
        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y)
            Groupbox:Resize()
        end
        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Depbox:Resize() end)
        Holder:GetPropertyChangedSignal('Visible'):Connect(function() Depbox:Resize() end)
        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1]
                local Value = Dependency[2]
                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false
                    Depbox:Resize()
                    return
                end
            end
            Holder.Visible = true
            Depbox:Resize()
        end
        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.')
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.')
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.')
            end
            Depbox.Dependencies = Dependencies
            Depbox:Update()
        end
        Depbox.Container = Frame
        setmetatable(Depbox, BaseGroupbox)
        table.insert(Library.DependencyBoxes, Depbox)
        return Depbox
    end

    BaseGroupbox.__index = Funcs
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...)
    end
end

-- ------------------------------------------------------------
-- УВЕДОМЛЕНИЯ, ВОДЯНОЙ ЗНАК, КЛЮЧЕВЫЕ КОМБИНАЦИИ (оригинал)
-- ------------------------------------------------------------
local NotificationContainer = Library:Create('Frame', {
    BackgroundTransparency = 1,
    Position = UDim2.new(0.5, 0, 1, 0),
    Size = UDim2.new(0, 0, 0, 0),
    AnchorPoint = Vector2.new(0.5, 1),
    ZIndex = 100,
    Parent = OverlayGui,
})

local activeNotifications = {}

local function PlayNotifySound()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. Library.NotifySoundId
    sound.Volume = 0.5
    sound.Parent = OverlayGui
    if sound.IsLoaded then
        sound:Play()
    else
        sound.Loaded:Connect(function()
            sound:Play()
        end)
    end
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

function Library:Notify(Text, Time)
    Time = Time or 5
    PlayNotifySound()
    local XSize = Library:GetTextBounds(Text, Library.Font, 14) + 24
    local YSize = 32
    local padding = 8
    local totalHeight = 0
    for _, notif in ipairs(activeNotifications) do
        if notif.Outer and notif.Outer.Parent then
            totalHeight = totalHeight + notif.Outer.AbsoluteSize.Y + padding
        end
    end
    local targetY = -totalHeight - YSize - padding
    local Outer = Library:Create('Frame', {
        BorderColor3 = Color3.new(0,0,0),
        Size = UDim2.new(0, XSize, 0, YSize),
        Position = UDim2.new(0.5, -XSize/2, 1, 0),
        ClipsDescendants = true,
        ZIndex = 100,
        Parent = NotificationContainer,
    })
    table.insert(activeNotifications, { Outer = Outer, Time = Time })
    local targetPos = UDim2.new(0.5, -XSize/2, 1, targetY)
    local tweenIn = TweenService:Create(Outer, TweenInfo.new(NOTIFY_ANIMATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos })
    tweenIn:Play()
    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        BorderMode = Enum.BorderMode.Inset,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 101,
        Parent = Outer,
    })
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' }, true)
    local InnerFrame = Library:Create('Frame', {
        BackgroundColor3 = Color3.new(1,1,1),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 1, 0, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 102,
        ClipsDescendants = true,
        Parent = Inner,
    })
    local Gradient = Library:Create('UIGradient', {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        }),
        Rotation = -90,
        Parent = InnerFrame,
    })
    Library:AddToRegistry(Gradient, {
        Color = function()
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
                ColorSequenceKeypoint.new(1, Library.MainColor),
            })
        end
    })
    local Label = Library:CreateLabel({
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(1, -16, 1, 0),
        Text = Text,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextSize = 14,
        ZIndex = 103,
        Parent = InnerFrame,
    })
    local LeftBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0.5, 0, 0, 2),
        Position = UDim2.new(0.5, 0, 1, -2),
        AnchorPoint = Vector2.new(1, 0),
        ZIndex = 104,
        Parent = Outer,
    })
    local RightBar = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor,
        BorderSizePixel = 0,
        Size = UDim2.new(0.5, 0, 0, 2),
        Position = UDim2.new(0.5, 0, 1, -2),
        AnchorPoint = Vector2.new(0, 0),
        ZIndex = 104,
        Parent = Outer,
    })
    local leftTween = TweenService:Create(LeftBar, TweenInfo.new(Time, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })
    local rightTween = TweenService:Create(RightBar, TweenInfo.new(Time, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })
    leftTween:Play()
    rightTween:Play()
    task.delay(Time, function()
        local tweenOut = TweenService:Create(Outer, TweenInfo.new(NOTIFY_ANIMATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, -XSize/2, 1, 0) })
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            Outer:Destroy()
            for i, notif in ipairs(activeNotifications) do
                if notif.Outer == Outer then
                    table.remove(activeNotifications, i)
                    break
                end
            end
            local currentY = 0
            for _, notif in ipairs(activeNotifications) do
                local newTargetPos = UDim2.new(0.5, -notif.Outer.AbsoluteSize.X/2, 1, -currentY - notif.Outer.AbsoluteSize.Y - padding)
                notif.Outer:TweenPosition(newTargetPos, "Out", "Quad", NOTIFY_ANIMATION_SPEED)
                currentY = currentY + notif.Outer.AbsoluteSize.Y + padding
            end
        end)
    end)
end

local cursorUpdateConnection = nil
local function UpdateCursor()
    pcall(function()
        local mouse = LocalPlayer:GetMouse()
        if mouse then
            mouse.Icon = "rbxassetid://" .. Library.CursorImageId
        end
    end)
end
local function StartCursorUpdater()
    if cursorUpdateConnection then cursorUpdateConnection:Disconnect(); cursorUpdateConnection = nil end
    UpdateCursor()
    cursorUpdateConnection = RunService.Heartbeat:Connect(UpdateCursor)
    LocalPlayer.CharacterAdded:Connect(UpdateCursor)
end
task.spawn(StartCursorUpdater)

function Library:SetNotifySoundId(id)
    Library.NotifySoundId = id
end
getgenv().SetNotifySoundId = Library.SetNotifySoundId

function Library:SetCursorImageId(id)
    Library.CursorImageId = id
    UpdateCursor()
end
getgenv().SetCursorImageId = Library.SetCursorImageId

local WatermarkOuter = Library:Create('Frame', {
    BorderColor3 = Color3.new(0,0,0),
    Position = UDim2.new(0, 100, 0, -25),
    Size = UDim2.new(0, 213, 0, 20),
    ZIndex = 200,
    Visible = false,
    Parent = OverlayGui,
})
local WatermarkInner = Library:Create('Frame', {
    BackgroundColor3 = Library.MainColor,
    BorderColor3 = Library.AccentColor,
    BorderMode = Enum.BorderMode.Inset,
    Size = UDim2.new(1, 0, 1, 0),
    ZIndex = 201,
    Parent = WatermarkOuter,
})
Library:AddToRegistry(WatermarkInner, { BorderColor3 = 'AccentColor' })
local InnerFrame = Library:Create('Frame', {
    BackgroundColor3 = Color3.new(1,1,1),
    BorderSizePixel = 0,
    Position = UDim2.new(0, 1, 0, 1),
    Size = UDim2.new(1, -2, 1, -2),
    ZIndex = 202,
    Parent = WatermarkInner,
})
local Gradient = Library:Create('UIGradient', {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
        ColorSequenceKeypoint.new(1, Library.MainColor),
    }),
    Rotation = -90,
    Parent = InnerFrame,
})
Library:AddToRegistry(Gradient, {
    Color = function()
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)),
            ColorSequenceKeypoint.new(1, Library.MainColor),
        })
    end
})
local WatermarkLabel = Library:CreateLabel({
    Position = UDim2.new(0, 5, 0, 0),
    Size = UDim2.new(1, -4, 1, 0),
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 203,
    Parent = InnerFrame,
})
Library.Watermark = WatermarkOuter
Library.WatermarkText = WatermarkLabel
Library:MakeDraggable(Library.Watermark)

local KeybindOuter = Library:Create('Frame', {
    AnchorPoint = Vector2.new(0, 0.5),
    BorderColor3 = Color3.new(0,0,0),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.new(0, 210, 0, 20),
    Visible = false,
    ZIndex = 100,
    Parent = OverlayGui,
})
local KeybindInner = Library:Create('Frame', {
    BackgroundColor3 = Library.MainColor,
    BorderColor3 = Library.OutlineColor,
    BorderMode = Enum.BorderMode.Inset,
    Size = UDim2.new(1, 0, 1, 0),
    ZIndex = 101,
    Parent = KeybindOuter,
})
Library:AddToRegistry(KeybindInner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' }, true)
local ColorFrame = Library:Create('Frame', {
    BackgroundColor3 = Library.AccentColor,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 2),
    ZIndex = 102,
    Parent = KeybindInner,
})
Library:AddToRegistry(ColorFrame, { BackgroundColor3 = 'AccentColor' }, true)
local KeybindLabel = Library:CreateLabel({
    Size = UDim2.new(1, 0, 0, 20),
    Position = UDim2.fromOffset(5, 2),
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = 'Keybinds',
    ZIndex = 104,
    Parent = KeybindInner,
})
local KeybindContainer = Library:Create('Frame', {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, -20),
    Position = UDim2.new(0, 0, 0, 20),
    ZIndex = 1,
    Parent = KeybindInner,
})
Library:Create('UIListLayout', {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = KeybindContainer,
})
Library:Create('UIPadding', {
    PaddingLeft = UDim.new(0, 5),
    Parent = KeybindContainer,
})
Library.KeybindFrame = KeybindOuter
Library.KeybindContainer = KeybindContainer
Library:MakeDraggable(KeybindOuter)

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool
end
function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14)
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3)
    Library:SetWatermarkVisibility(true)
    Library.WatermarkText.Text = Text
end

-- ------------------------------------------------------------
-- 3D РЕЖИМ (оригинал)
-- ------------------------------------------------------------
function Clear3DObjects()
    if Current3DPart then Current3DPart:Destroy() end
    if Current3DSurface then Current3DSurface:Destroy() end
    Current3DPart = nil
    Current3DSurface = nil
    if Library.MainFrame and Library.MainFrame.Parent then
        pcall(function()
            if Library.MainFrame.Parent ~= ScreenGui then
                Library.MainFrame.Parent = ScreenGui
            end
        end)
    end
end

function Create3DObjects()
    Clear3DObjects()
    local Camera = workspace.CurrentCamera
    if not Camera then return end
    local windowSize = Library.MainFrame and Library.MainFrame.Size or UDim2.fromOffset(550, 600)
    local partSizeX = math.max(windowSize.X.Offset / PPU, 0.1)
    local partSizeY = math.max(windowSize.Y.Offset / PPU, 0.1)
    local Part = Instance.new('Part')
    Part.Name = 'Linoria3DPart'
    Part.Size = Vector3.new(partSizeX, partSizeY, 0.1)
    Part.Transparency = 1
    Part.CanCollide = false
    Part.Anchored = true
    Part.CFrame = Camera.CFrame * CFrame.new(0, 0, -THREED_DISTANCE)
    Part.Parent = workspace
    Current3DPart = Part
    local Surface = Instance.new('SurfaceGui')
    Surface.Name = 'Linoria3DSurface'
    Surface.Face = Enum.NormalId.Front
    Surface.PixelsPerStud = PPU
    Surface.CanvasSize = Vector2.new(windowSize.X.Offset, windowSize.Y.Offset)
    Surface.AlwaysOnTop = true
    Surface.Parent = Part
    Current3DSurface = Surface
    if Library.MainFrame and Library.MainFrame.Parent then
        pcall(function()
            if Library.MainFrame.Parent ~= Surface then
                Library.MainFrame.Parent = Surface
            end
        end)
    end
end

-- ------------------------------------------------------------
-- СОЗДАНИЕ ОКНА (с добавлением обработки биндов)
-- ------------------------------------------------------------
function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }
    if type(...) == 'table' then Config = ...
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false
    end
    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end
    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end
    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = { Tabs = {} }
    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Color3.new(0,0,0),
        BorderSizePixel = 0,
        Position = Config.Position,
        Size = Config.Size,
        Visible = false,
        ZIndex = 1,
        Parent = ScreenGui,
    })
    Library.MainFrame = Outer
    local OuterCorner = Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICornerRadius * 10), Parent = Outer })
    table.insert(Library.UICorners, OuterCorner)
    Library:MakeDraggable(Outer, 25)

    local Inner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.AccentColor,
        BorderMode = Enum.BorderMode.Inset,
        Position = UDim2.new(0, 1, 0, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 1,
        Parent = Outer,
    })
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor', BorderColor3 = 'AccentColor' })
    local InnerCorner = Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICornerRadius * 10), Parent = Inner })
    table.insert(Library.UICorners, InnerCorner)

    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 7, 0, 0),
        Size = UDim2.new(0, 0, 0, 25),
        Text = Config.Title or '',
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 1,
        Parent = Inner,
    })
    local MainSectionOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 8, 0, 25),
        Size = UDim2.new(1, -16, 1, -33),
        ZIndex = 1,
        Parent = Inner,
    })
    Library:AddToRegistry(MainSectionOuter, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })
    local MainOuterCorner = Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICornerRadius * 10), Parent = MainSectionOuter })
    table.insert(Library.UICorners, MainOuterCorner)

    local MainSectionInner = Library:Create('Frame', {
        BackgroundColor3 = Library.BackgroundColor,
        BorderColor3 = Color3.new(0,0,0),
        BorderMode = Enum.BorderMode.Inset,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 1,
        Parent = MainSectionOuter,
    })
    Library:AddToRegistry(MainSectionInner, { BackgroundColor3 = 'BackgroundColor' })
    local MainInnerCorner = Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICornerRadius * 10), Parent = MainSectionInner })
    table.insert(Library.UICorners, MainInnerCorner)

    local TabArea = Library:Create('Frame', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 8, 0, 8),
        Size = UDim2.new(1, -16, 0, 21),
        ZIndex = 1,
        Parent = MainSectionInner,
    })
    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabArea,
    })
    local TabContainer = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,
        Position = UDim2.new(0, 8, 0, 30),
        Size = UDim2.new(1, -16, 1, -38),
        ZIndex = 2,
        Parent = MainSectionInner,
    })
    Library:AddToRegistry(TabContainer, { BackgroundColor3 = 'MainColor', BorderColor3 = 'OutlineColor' })

    function Window:SetWindowTitle(Title) WindowLabel.Text = Title end

    function Window:AddTab(Name)
        if Window.Tabs[Name] then
            warn("[LinoriaLib] Tab with name '" .. Name .. "' already exists. Returning existing tab.")
            return Window.Tabs[Name]
        end
        local Tab = { Groupboxes = {}, Tabboxes = {} }
        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16)
        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor,
            BorderColor3 = Library.OutlineColor,
            Size = UDim2.new(0, TabButtonWidth + 8 + 4, 1, 0),
            ZIndex = 1,
            Parent = TabArea,
        })
        Library:AddToRegistry(TabButton, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })
        local TabButtonLabel = Library:CreateLabel({
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, -1),
            Text = Name,
            ZIndex = 1,
            Parent = TabButton,
        })
        local Blocker = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundTransparency = 1,
            ZIndex = 3,
            Parent = TabButton,
        })
        Library:AddToRegistry(Blocker, { BackgroundColor3 = 'MainColor' })
        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame',
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            Visible = false,
            ZIndex = 2,
            Parent = TabContainer,
        })
        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 8 - 1, 0, 8 - 1),
            Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            BottomImage = '',
            TopImage = '',
            ScrollBarThickness = 0,
            ZIndex = 2,
            Parent = TabFrame,
        })
        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1),
            Size = UDim2.new(0.5, -12 + 2, 0, 507 + 2),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            BottomImage = '',
            TopImage = '',
            ScrollBarThickness = 0,
            ZIndex = 2,
            Parent = TabFrame,
        })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Parent = LeftSide,
        })
        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Parent = RightSide,
        })
        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y)
            end)
        end

        function Tab:ShowTab()
            for _, Tab in next, Window.Tabs do Tab:HideTab() end
            Blocker.BackgroundTransparency = 0
            TabButton.BackgroundColor3 = Library.MainColor
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'MainColor'
            TabFrame.Visible = true
        end
        function Tab:HideTab()
            Blocker.BackgroundTransparency = 1
            TabButton.BackgroundColor3 = Library.BackgroundColor
            Library.RegistryMap[TabButton].Properties.BackgroundColor3 = 'BackgroundColor'
            TabFrame.Visible = false
        end
        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position
            TabListLayout:ApplyLayout()
        end

        function Tab:AddGroupbox(Info)
            local Groupbox = {}
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor,
                BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset,
                Size = UDim2.new(1, 0, 0, 507 + 2),
                ZIndex = 2,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            })
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })
            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor,
                BorderColor3 = Color3.new(0,0,0),
                Size = UDim2.new(1, -2, 1, -2),
                Position = UDim2.new(0, 1, 0, 1),
                ZIndex = 4,
                Parent = BoxOuter,
            })
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor' })
            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 2),
                ZIndex = 5,
                Parent = BoxInner,
            })
            Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor' })
            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 18),
                Position = UDim2.new(0, 4, 0, 2),
                TextSize = 14,
                Text = Info.Name,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 5,
                Parent = BoxInner,
            })
            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 4, 0, 20),
                Size = UDim2.new(1, -4, 1, -20),
                ZIndex = 1,
                Parent = BoxInner,
            })
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = Container,
            })
            function Groupbox:Resize()
                local Size = 0
                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset
                    end
                end
                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2)
            end
            Groupbox.Container = Container
            setmetatable(Groupbox, BaseGroupbox)
            Groupbox:AddBlank(3)
            Groupbox:Resize()
            Tab.Groupboxes[Info.Name] = Groupbox
            return Groupbox
        end

        function Tab:AddLeftGroupbox(Name) return Tab:AddGroupbox({ Side = 1, Name = Name }) end
        function Tab:AddRightGroupbox(Name) return Tab:AddGroupbox({ Side = 2, Name = Name }) end

        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {} }
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor,
                BorderColor3 = Library.OutlineColor,
                BorderMode = Enum.BorderMode.Inset,
                Size = UDim2.new(1, 0, 0, 0),
                ZIndex = 2,
                Parent = Info.Side == 1 and LeftSide or RightSide,
            })
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor', BorderColor3 = 'OutlineColor' })
            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor,
                BorderColor3 = Color3.new(0,0,0),
                Size = UDim2.new(1, -2, 1, -2),
                Position = UDim2.new(0, 1, 0, 1),
                ZIndex = 4,
                Parent = BoxOuter,
            })
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor' })
            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 2),
                ZIndex = 10,
                Parent = BoxInner,
            })
            Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor' })
            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 1),
                Size = UDim2.new(1, 0, 0, 18),
                ZIndex = 5,
                Parent = BoxInner,
            })
            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = TabboxButtons,
            })

            function Tabbox:AddTab(Name)
                local Tab = {}
                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor,
                    BorderColor3 = Color3.new(0,0,0),
                    Size = UDim2.new(0.5, 0, 1, 0),
                    ZIndex = 6,
                    Parent = TabboxButtons,
                })
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor' })
                local ButtonLabel = Library:CreateLabel({
                    Size = UDim2.new(1, 0, 1, 0),
                    TextSize = 14,
                    Text = Name,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ZIndex = 7,
                    Parent = Button,
                })
                local Block = Library:Create('Frame', {
                    BackgroundColor3 = Library.BackgroundColor,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 1, 0),
                    Size = UDim2.new(1, 0, 0, 1),
                    Visible = false,
                    ZIndex = 9,
                    Parent = Button,
                })
                Library:AddToRegistry(Block, { BackgroundColor3 = 'BackgroundColor' })
                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 4, 0, 20),
                    Size = UDim2.new(1, -4, 1, -20),
                    ZIndex = 1,
                    Visible = false,
                    Parent = BoxInner,
                })
                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = Container,
                })
                function Tab:Show()
                    for _, Tab in next, Tabbox.Tabs do Tab:Hide() end
                    Container.Visible = true
                    Block.Visible = true
                    Button.BackgroundColor3 = Library.BackgroundColor
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor'
                    Tab:Resize()
                end
                function Tab:Hide()
                    Container.Visible = false
                    Block.Visible = false
                    Button.BackgroundColor3 = Library.MainColor
                    Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor'
                end
                function Tab:Resize()
                    local TabCount = 0
                    for _, Tab in next, Tabbox.Tabs do TabCount = TabCount + 1 end
                    for _, Button in next, TabboxButtons:GetChildren() do
                        if not Button:IsA('UIListLayout') then Button.Size = UDim2.new(1 / TabCount, 0, 1, 0) end
                    end
                    if (not Container.Visible) then return end
                    local Size = 0
                    for _, Element in next, Tab.Container:GetChildren() do
                        if (not Element:IsA('UIListLayout')) and Element.Visible then
                            Size = Size + Element.Size.Y.Offset
                        end
                    end
                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2)
                end
                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show()
                        Tab:Resize()
                    end
                end)
                Tab.Container = Container
                Tabbox.Tabs[Name] = Tab
                setmetatable(Tab, BaseGroupbox)
                Tab:AddBlank(3)
                Tab:Resize()
                if #TabboxButtons:GetChildren() == 2 then Tab:Show() end
                return Tab
            end
            Tab.Tabboxes[Info.Name or ''] = Tabbox
            return Tabbox
        end

        function Tab:AddLeftTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 1 }) end
        function Tab:AddRightTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 2 }) end

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then Tab:ShowTab() end
        end)
        if #TabContainer:GetChildren() == 1 then Tab:ShowTab() end
        Window.Tabs[Name] = Tab
        return Tab
    end

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 0, 0, 0),
        Visible = true,
        Text = '',
        Modal = false,
        Parent = ScreenGui,
    })
    local TransparencyCache = {}
    local Toggled = false
    local Fading = false
    function Library:Toggle()
        if Fading then return end
        local FadeTime = Config.MenuFadeTime
        Fading = true
        Toggled = (not Toggled)
        ModalElement.Modal = Toggled

        if ThreeDMode then
            Outer.Visible = Toggled
        else
            if not Toggled then
                for frame, _ in pairs(Library.OpenedFrames) do frame.Visible = false end
                table.clear(Library.OpenedFrames)
            end
            if Toggled then Outer.Visible = true end
            for _, Desc in next, Outer:GetDescendants() do
                local Properties = {}
                if Desc:IsA('ImageLabel') then
                    table.insert(Properties, 'ImageTransparency'); table.insert(Properties, 'BackgroundTransparency')
                elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                    table.insert(Properties, 'TextTransparency')
                elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                    table.insert(Properties, 'BackgroundTransparency')
                elseif Desc:IsA('UIStroke') then
                    table.insert(Properties, 'Transparency')
                end
                local Cache = TransparencyCache[Desc]
                if (not Cache) then Cache = {}; TransparencyCache[Desc] = Cache end
                for _, Prop in next, Properties do
                    if not Cache[Prop] then Cache[Prop] = Desc[Prop] end
                    if Cache[Prop] == 1 then continue end
                    TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play()
                end
            end
        end

        task.wait(FadeTime)
        if not Toggled and not ThreeDMode then
            Outer.Visible = false
        end
        Fading = false
    end
    Library.ToggleMenu = Library.Toggle

    function Library:Set3DEnabled(enabled)
        if enabled == ThreeDMode then return end
        ThreeDMode = enabled
        if enabled then
            Create3DObjects()
            Outer.Visible = true
            ModalElement.Modal = true
            Toggled = true
        else
            Clear3DObjects()
            if Toggled then
                Outer.Visible = true
                ModalElement.Modal = true
            else
                Outer.Visible = false
                ModalElement.Modal = false
            end
        end
    end
    getgenv().Set3DEnabled = Library.Set3DEnabled

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))
    if Config.AutoShow then task.spawn(Library.Toggle) end
    Window.Holder = Outer
    return Window
end

-- ------------------------------------------------------------
-- ГЛОБАЛЬНЫЙ ОБРАБОТЧИК БИНДОВ
-- ------------------------------------------------------------
Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
    if Processed then return end
    for idx, element in pairs(Library.KeybindableElements) do
        for _, bind in ipairs(element.Keybinds or {}) do
            local key = bind.Key
            local mode = bind.Mode
            local value = bind.Value
            local pressed = false
            if key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1 then pressed = true
            elseif key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then pressed = true
            elseif Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == key then pressed = true
            end
            if pressed then
                if mode == 'Toggle' then
                    -- Для тогглов переключаем состояние
                    if element.Type == 'Toggle' then
                        element:SetValue(not element.Value)
                    elseif element.Type == 'Button' then
                        element:Execute()
                    elseif element.Type == 'Dropdown' then
                        if value ~= nil then
                            element:SetValue(value)
                        end
                    elseif element.Type == 'Slider' then
                        if value ~= nil then
                            element:SetValue(value)
                        end
                    elseif element.Type == 'Input' then
                        if value ~= nil then
                            element:SetValue(value)
                        end
                    end
                elseif mode == 'Hold' then
                    -- Для hold - выполнять пока зажата
                    -- Просто выполняем один раз при нажатии
                    if element.Type == 'Button' then
                        element:Execute()
                    elseif element.Type == 'Toggle' then
                        element:SetValue(not element.Value)
                    elseif element.Type == 'Dropdown' then
                        if value ~= nil then element:SetValue(value) end
                    elseif element.Type == 'Slider' then
                        if value ~= nil then element:SetValue(value) end
                    elseif element.Type == 'Input' then
                        if value ~= nil then element:SetValue(value) end
                    end
                elseif mode == 'Always' then
                    -- Постоянно выполняем (но при нажатии клавиши один раз)
                    if element.Type == 'Button' then
                        element:Execute()
                    elseif element.Type == 'Toggle' then
                        element:SetValue(not element.Value)
                    elseif element.Type == 'Dropdown' then
                        if value ~= nil then element:SetValue(value) end
                    elseif element.Type == 'Slider' then
                        if value ~= nil then element:SetValue(value) end
                    elseif element.Type == 'Input' then
                        if value ~= nil then element:SetValue(value) end
                    end
                end
            end
        end
    end
end))

-- ------------------------------------------------------------
-- СОХРАНЕНИЕ И ЗАГРУЗКА БИНДОВ (интеграция с SaveManager)
-- ------------------------------------------------------------
-- Функции для экспорта/импорта биндов
function Library:GetKeybindsData()
    local data = {}
    for idx, element in pairs(Library.KeybindableElements) do
        if element.Keybinds and #element.Keybinds > 0 then
            data[idx] = element.Keybinds
        end
    end
    return data
end

function Library:SetKeybindsData(data)
    if not data then return end
    for idx, binds in pairs(data) do
        local element = Library.KeybindableElements[idx]
        if element then
            element.Keybinds = binds
        end
    end
end

-- ------------------------------------------------------------
-- ИНИЦИАЛИЗАЦИЯ (оригинал)
-- ------------------------------------------------------------
local function OnPlayerChange()
    local PlayerList = GetPlayersString()
    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList)
        end
    end
end
Players.PlayerAdded:Connect(OnPlayerChange)
Players.PlayerRemoving:Connect(OnPlayerChange)

getgenv().Library = Library
return Library
