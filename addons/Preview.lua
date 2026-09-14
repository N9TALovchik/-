--=====================================================
-- PreviewManager.lua
-- Отдельный плавающий фрейм с ESP-превью локального персонажа.
-- Вращение мыши, автоспин, полный ESP overlay.
-- Синхронизация видимости с Library.MainFrame.
--=====================================================

local Players          = game:GetService('Players')
local RunService       = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local CoreGui          = game:GetService('CoreGui')

local Options = getgenv().Options or {}
local Toggles = getgenv().Toggles or {}

local PreviewManager = {}
PreviewManager.Folder  = 'NOTALovchik'
PreviewManager.Library = nil

PreviewManager.Config = {
    Enabled                = true,
    Size                   = Vector2.new(240, 340),
    Position               = UDim2.new(0, 40, 0, 120),
    BackgroundColor        = Color3.fromRGB(20, 20, 26),
    BackgroundTransparency = 0,
    OutlineColor           = Color3.fromRGB(70, 70, 95),
    OutlineThickness       = 1,
    CornerRadius           = 6,

    AutoRotate             = true,
    RotationSpeed          = 0.5,
    ManualYaw              = 0,
    Pitch                  = math.rad(8),
    Distance               = 9,
    FOV                    = 50,
    FocusHeight            = 2.6,

    ShowBox                = true,
    ShowName               = true,
    ShowHealth             = true,
    ShowHeadDot            = true,

    BoxColor               = Color3.fromRGB(255, 255, 255),
    NameColor              = Color3.fromRGB(255, 255, 255),
    HealthColor            = Color3.fromRGB(0, 255, 0),
    HeadDotColor           = Color3.fromRGB(255, 255, 255),
}

PreviewManager.State = {
    Gui           = nil,
    MainFrame     = nil,
    ViewportFrame = nil,
    WorldModel    = nil,
    Camera        = nil,
    Character     = nil,
    ESPContainer  = nil,

    Box           = nil, BoxStroke = nil,
    Name          = nil,
    HealthBg      = nil, HealthFill = nil,
    HeadDot       = nil,

    Yaw           = 0,
    Dragging      = false,
    LastMouseX    = 0,

    SyncConn      = nil,
    RenderConn    = nil,
    CharacterConn = nil,
}

--=====================================================
-- helpers
--=====================================================
local function create(class, props)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    return o
end

local function protectGui(gui)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
    end)
end

local function getGuiParent()
    local ok, cg = pcall(function() return CoreGui end)
    if ok and cg then return cg end
    return Players.LocalPlayer:WaitForChild('PlayerGui')
end

--=====================================================
-- build
--=====================================================
function PreviewManager:Build()
    local S = PreviewManager.State
    local C = PreviewManager.Config
    if S.Gui and S.Gui.Parent then return end

    local gui = create('ScreenGui', {
        Name = 'NOTALovchik_Preview',
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Enabled = false,
    })
    protectGui(gui)
    gui.Parent = getGuiParent()

    local frame = create('Frame', {
        Name = 'PreviewFrame',
        Size = UDim2.fromOffset(C.Size.X, C.Size.Y),
        Position = C.Position,
        BackgroundColor3 = C.BackgroundColor,
        BackgroundTransparency = C.BackgroundTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Draggable = true,
        Parent = gui,
    })
    create('UICorner', { CornerRadius = UDim.new(0, C.CornerRadius), Parent = frame })
    local stroke = create('UIStroke', {
        Color = C.OutlineColor,
        Thickness = C.OutlineThickness,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = frame,
    })

    local vp = create('ViewportFrame', {
        Name = 'Viewport',
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Ambient = Color3.fromRGB(150, 150, 150),
        LightColor = Color3.fromRGB(255, 255, 255),
        LightDirection = Enum.NormalId.Front,
        Parent = frame,
    })
    create('UICorner', { CornerRadius = UDim.new(0, C.CornerRadius), Parent = vp })

    local world = create('WorldModel', { Parent = vp })
    local cam = create('Camera', { FieldOfView = C.FOV, Parent = vp })
    vp.CurrentCamera = cam

    local esp = create('Frame', {
        Name = 'ESPOverlay',
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 5,
        Parent = frame,
    })

    local box = create('Frame', {
        Name = 'Box',
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 6,
        Parent = esp,
    })
    local boxStroke = create('UIStroke', { Color = C.BoxColor, Thickness = 1, Parent = box })

    local nameLbl = create('TextLabel', {
        Name = 'Name',
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = C.NameColor,
        TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        Text = 'Player',
        Size = UDim2.new(0, 160, 0, 16),
        AnchorPoint = Vector2.new(0.5, 1),
        Visible = false,
        ZIndex = 7,
        Parent = esp,
    })

    local hbg = create('Frame', {
        Name = 'HealthBG',
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 6,
        Parent = esp,
    })
    local hfill = create('Frame', {
        Name = 'HealthFill',
        BackgroundColor3 = C.HealthColor,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 7,
        Parent = esp,
    })

    local dot = create('Frame', {
        Name = 'HeadDot',
        BackgroundColor3 = C.HeadDotColor,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(5, 5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Visible = false,
        ZIndex = 7,
        Parent = esp,
    })
    create('UICorner', { CornerRadius = UDim.new(1, 0), Parent = dot })

    cam.ViewportSize = vp.AbsoluteSize
    vp:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
        cam.ViewportSize = vp.AbsoluteSize
    end)

    vp.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2
           or input.UserInputType == Enum.UserInputType.MouseButton1 then
            S.Dragging = true
            S.LastMouseX = input.Position.X
        end
    end)
    vp.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2
           or input.UserInputType == Enum.UserInputType.MouseButton1 then
            S.Dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not S.Dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local dx = input.Position.X - S.LastMouseX
        S.LastMouseX = input.Position.X
        PreviewManager.Config.ManualYaw = PreviewManager.Config.ManualYaw + dx * math.rad(0.6)
    end)

    S.Gui = gui
    S.MainFrame = frame
    S.ViewportFrame = vp
    S.WorldModel = world
    S.Camera = cam
    S.ESPContainer = esp
    S.Box = box
    S.BoxStroke = boxStroke
    S.Name = nameLbl
    S.HealthBg = hbg
    S.HealthFill = hfill
    S.HeadDot = dot
end

--=====================================================
-- character clone
--=====================================================
function PreviewManager:RefreshCharacter()
    local S = PreviewManager.State
    if not S.WorldModel then return end

    if S.Character then
        pcall(function() S.Character:Destroy() end)
        S.Character = nil
    end

    local lp = Players.LocalPlayer
    if not lp or not lp.Character then return end

    local ok, clone = pcall(function() return lp.Character:Clone() end)
    if not ok or not clone then return end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA('Script') or d:IsA('LocalScript')
           or d:IsA('Sound') or d:IsA('Animator')
           or d:IsA('AnimationController') then
            pcall(function() d:Destroy() end)
        end
    end

    clone.Parent = S.WorldModel

    local okPivot = pcall(function() clone:PivotTo(CFrame.new(0, 0, 0)) end)
    if not okPivot then
        pcall(function() clone:SetPrimaryPartCFrame(CFrame.new(0, 0, 0)) end)
    end

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA('BasePart') then
            d.Anchored = true
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = false
        end
    end

    S.Character = clone
end

--=====================================================
-- camera
--=====================================================
function PreviewManager:UpdateCamera()
    local S = PreviewManager.State
    local C = PreviewManager.Config
    if not S.Camera then return end

    local yaw = S.Yaw + C.ManualYaw
    local pitch = C.Pitch
    local dist = C.Distance
    local focus = Vector3.new(0, C.FocusHeight, 0)
    local offset = Vector3.new(
        math.sin(yaw) * math.cos(pitch) * dist,
        math.sin(pitch) * dist,
        math.cos(yaw) * math.cos(pitch) * dist
    )
    S.Camera.CFrame = CFrame.new(focus + offset, focus)
    S.Camera.FieldOfView = C.FOV
end

--=====================================================
-- ESP overlay
--=====================================================
function PreviewManager:UpdateESP()
    local S = PreviewManager.State
    local C = PreviewManager.Config
    if not S.Camera or not S.Character then return end

    local cam = S.Camera
    local char = S.Character
    local hrp = char:FindFirstChild('HumanoidRootPart')
        or char:FindFirstChild('UpperTorso')
        or char:FindFirstChild('Torso')
    if not hrp then return end

    local hum = char:FindFirstChildOfClass('Humanoid')
    local head = char:FindFirstChild('Head') or hrp

    local headPos = head.Position + Vector3.new(0, 0.5, 0)
    local footPos = hrp.Position - Vector3.new(0, 3, 0)

    local headScr, headOn = cam:WorldToViewportPoint(headPos)
    local footScr, footOn = cam:WorldToViewportPoint(footPos)
    local onScreen = headOn and footOn

    if C.ShowBox and onScreen then
        local x1 = math.min(headScr.X, footScr.X)
        local y1 = math.min(headScr.Y, footScr.Y)
        local x2 = math.max(headScr.X, footScr.X)
        local y2 = math.max(headScr.Y, footScr.Y)
        local w = (y2 - y1) * 0.6
        local cx = (x1 + x2) / 2
        local bx = cx - w / 2
        S.Box.Position = UDim2.fromOffset(bx, y1)
        S.Box.Size = UDim2.fromOffset(w, y2 - y1)
        S.BoxStroke.Color = C.BoxColor
        S.Box.Visible = true

        S.Name.Position = UDim2.fromOffset(cx, y1 - 4)
        S.Name.TextColor3 = C.NameColor
        S.Name.Text = Players.LocalPlayer.Name
        S.Name.Visible = C.ShowName

        local hp = 1
        if hum then hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1) end
        local barH = y2 - y1
        local barX = bx - 5
        S.HealthBg.Position = UDim2.fromOffset(barX - 1, y1 - 1)
        S.HealthBg.Size = UDim2.fromOffset(4, barH + 2)
        S.HealthBg.Visible = C.ShowHealth
        S.HealthFill.Position = UDim2.fromOffset(barX, y1 + (barH - barH * hp))
        S.HealthFill.Size = UDim2.fromOffset(2, barH * hp)
        S.HealthFill.BackgroundColor3 = C.HealthColor
        S.HealthFill.Visible = C.ShowHealth
    else
        S.Box.Visible = false
        S.Name.Visible = false
        S.HealthBg.Visible = false
        S.HealthFill.Visible = false
    end

    if C.ShowHeadDot then
        local hs, hv = cam:WorldToViewportPoint(head.Position)
        if hv then
            S.HeadDot.Position = UDim2.fromOffset(hs.X, hs.Y)
            S.HeadDot.BackgroundColor3 = C.HeadDotColor
            S.HeadDot.Visible = true
        else
            S.HeadDot.Visible = false
        end
    else
        S.HeadDot.Visible = false
    end
end

--=====================================================
-- sync + render
--=====================================================
function PreviewManager:StartSync()
    local S = PreviewManager.State
    if S.SyncConn then S.SyncConn:Disconnect() end
    S.SyncConn = RunService.Heartbeat:Connect(function()
        local lib = PreviewManager.Library
        if not lib or not lib.MainFrame then return end
        local shouldShow = lib.MainFrame.Visible and PreviewManager.Config.Enabled
        if S.Gui then S.Gui.Enabled = shouldShow and true or false end
    end)
end

function PreviewManager:StartRender()
    local S = PreviewManager.State
    if S.RenderConn then S.RenderConn:Disconnect() end
    local lastT = tick()
    S.RenderConn = RunService.RenderStepped:Connect(function()
        local now = tick()
        local dt = now - lastT
        lastT = now
        if not S.Gui or not S.Gui.Enabled then return end
        if PreviewManager.Config.AutoRotate and not S.Dragging then
            S.Yaw = S.Yaw + dt * PreviewManager.Config.RotationSpeed
        end
        PreviewManager:UpdateCamera()
        PreviewManager:UpdateESP()
    end)
end

--=====================================================
-- public API
--=====================================================
function PreviewManager:SetLibrary(lib)
    PreviewManager.Library = lib
end

function PreviewManager:SetFolder(f)
    PreviewManager.Folder = f or PreviewManager.Folder
end

function PreviewManager:Create()
    self:Build()
    self:RefreshCharacter()
    self:StartSync()
    self:StartRender()

    local lp = Players.LocalPlayer
    if lp then
        self.State.CharacterConn = lp.CharacterAdded:Connect(function()
            task.wait(0.5)
            PreviewManager:RefreshCharacter()
        end)
    end
end

function PreviewManager:Destroy()
    local S = PreviewManager.State
    if S.SyncConn then S.SyncConn:Disconnect() S.SyncConn = nil end
    if S.RenderConn then S.RenderConn:Disconnect() S.RenderConn = nil end
    if S.CharacterConn then S.CharacterConn:Disconnect() S.CharacterConn = nil end
    if S.Gui then S.Gui:Destroy() S.Gui = nil end
end

function PreviewManager:SetEnabled(b) PreviewManager.Config.Enabled = b and true or false end
function PreviewManager:SetAutoRotate(b) PreviewManager.Config.AutoRotate = b and true or false end
function PreviewManager:SetRotationSpeed(v) PreviewManager.Config.RotationSpeed = v end
function PreviewManager:SetDistance(v) PreviewManager.Config.Distance = v end
function PreviewManager:SetFOV(v) PreviewManager.Config.FOV = v end
function PreviewManager:ResetYaw()
    PreviewManager.State.Yaw = 0
    PreviewManager.Config.ManualYaw = 0
end
function PreviewManager:SetBackground(color, transparency)
    if color then PreviewManager.Config.BackgroundColor = color end
    if transparency then PreviewManager.Config.BackgroundTransparency = transparency end
    local f = PreviewManager.State.MainFrame
    if f then
        f.BackgroundColor3 = PreviewManager.Config.BackgroundColor
        f.BackgroundTransparency = PreviewManager.Config.BackgroundTransparency
    end
end
function PreviewManager:SetOutline(color, thickness)
    if color then PreviewManager.Config.OutlineColor = color end
    if thickness then PreviewManager.Config.OutlineThickness = thickness end
    local f = PreviewManager.State.MainFrame
    if f then
        local st = f:FindFirstChildOfClass('UIStroke')
        if st then
            st.Color = PreviewManager.Config.OutlineColor
            st.Thickness = PreviewManager.Config.OutlineThickness
        end
    end
end

--=====================================================
-- settings UI
--=====================================================
function PreviewManager:CreateSettingsUI(tab)
    if not tab or not PreviewManager.Library then return end
    local section = tab:AddLeftGroupbox('ESP Preview')

    section:AddToggle('PreviewEnabled', {
        Text = 'Preview Enabled',
        Default = PreviewManager.Config.Enabled,
        Callback = function(v) PreviewManager:SetEnabled(v) end,
    })
    section:AddToggle('PreviewAutoRotate', {
        Text = 'Auto Rotate',
        Default = PreviewManager.Config.AutoRotate,
        Callback = function(v) PreviewManager:SetAutoRotate(v) end,
    })
    section:AddSlider('PreviewRotSpeed', {
        Text = 'Rotation Speed',
        Min = 0, Max = 3,
        Default = PreviewManager.Config.RotationSpeed,
        Rounding = 2,
        Callback = function(v) PreviewManager:SetRotationSpeed(v) end,
    })
    section:AddSlider('PreviewDistance', {
        Text = 'Camera Distance',
        Min = 3, Max = 20,
        Default = PreviewManager.Config.Distance,
        Rounding = 1,
        Callback = function(v) PreviewManager:SetDistance(v) end,
    })
    section:AddSlider('PreviewFOV', {
        Text = 'Camera FOV',
        Min = 20, Max = 100,
        Default = PreviewManager.Config.FOV,
        Rounding = 0,
        Callback = function(v) PreviewManager:SetFOV(v) end,
    })
    section:AddButton('Reset Yaw', function() PreviewManager:ResetYaw() end)

    section:AddDivider()
    section:AddLabel('Visuals')

    section:AddToggle('PreviewShowBox', {
        Text = 'Box', Default = PreviewManager.Config.ShowBox,
        Callback = function(v) PreviewManager.Config.ShowBox = v end,
    })
    section:AddLabel('Box Color'):AddColorPicker('PreviewBoxColor', {
        Default = PreviewManager.Config.BoxColor,
        Title = 'Box Color',
        Callback = function(c) PreviewManager.Config.BoxColor = c end,
    })
    section:AddToggle('PreviewShowName', {
        Text = 'Name', Default = PreviewManager.Config.ShowName,
        Callback = function(v) PreviewManager.Config.ShowName = v end,
    })
    section:AddLabel('Name Color'):AddColorPicker('PreviewNameColor', {
        Default = PreviewManager.Config.NameColor,
        Title = 'Name Color',
        Callback = function(c) PreviewManager.Config.NameColor = c end,
    })
    section:AddToggle('PreviewShowHealth', {
        Text = 'Health Bar', Default = PreviewManager.Config.ShowHealth,
        Callback = function(v) PreviewManager.Config.ShowHealth = v end,
    })
    section:AddLabel('Health Color'):AddColorPicker('PreviewHealthColor', {
        Default = PreviewManager.Config.HealthColor,
        Title = 'Health Color',
        Callback = function(c) PreviewManager.Config.HealthColor = c end,
    })
    section:AddToggle('PreviewShowHeadDot', {
        Text = 'Head Dot', Default = PreviewManager.Config.ShowHeadDot,
        Callback = function(v) PreviewManager.Config.ShowHeadDot = v end,
    })

    section:AddDivider()
    section:AddLabel('Frame')

    section:AddLabel('Background Color'):AddColorPicker('PreviewBgColor', {
        Default = PreviewManager.Config.BackgroundColor,
        Title = 'Background Color',
        Callback = function(c) PreviewManager:SetBackground(c) end,
    })
    section:AddLabel('Outline Color'):AddColorPicker('PreviewOutlineColor', {
        Default = PreviewManager.Config.OutlineColor,
        Title = 'Outline Color',
        Callback = function(c) PreviewManager:SetOutline(c) end,
    })
    section:AddSlider('PreviewBgTransparency', {
        Text = 'Background Transparency',
        Min = 0, Max = 1,
        Default = PreviewManager.Config.BackgroundTransparency,
        Rounding = 2,
        Callback = function(v) PreviewManager:SetBackground(nil, v) end,
    })
    section:AddSlider('PreviewOutlineThickness', {
        Text = 'Outline Thickness',
        Min = 0, Max = 5,
        Default = PreviewManager.Config.OutlineThickness,
        Rounding = 0,
        Callback = function(v) PreviewManager:SetOutline(nil, v) end,
    })
    section:AddSlider('PreviewCornerRadius', {
        Text = 'Corner Radius',
        Min = 0, Max = 20,
        Default = PreviewManager.Config.CornerRadius,
        Rounding = 0,
        Callback = function(v)
            PreviewManager.Config.CornerRadius = v
            local f = PreviewManager.State.MainFrame
            if f then
                local c = f:FindFirstChildOfClass('UICorner')
                if c then c.CornerRadius = UDim.new(0, v) end
            end
        end,
    })
end

return PreviewManager
