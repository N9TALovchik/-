--=====================================================
-- PreviewManager.lua
-- Просто плавающий фрейм + контейнер. Всё из кода.
--=====================================================

local Players    = game:GetService('Players')
local RunService = game:GetService('RunService')
local CoreGui    = game:GetService('CoreGui')

local PreviewManager = {}
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
    ClipDescendants        = true,
    Draggable              = true,
}

PreviewManager.State = {
    Gui       = nil,
    MainFrame = nil,
    Container = nil,
    Stroke    = nil,
    Corner    = nil,
    SyncConn  = nil,
}

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
        ClipsDescendants = C.ClipDescendants,
        Active = true,
        Draggable = C.Draggable,
        Parent = gui,
    })

    local corner = create('UICorner', {
        CornerRadius = UDim.new(0, C.CornerRadius),
        Parent = frame,
    })

    local stroke = create('UIStroke', {
        Color = C.OutlineColor,
        Thickness = C.OutlineThickness,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = frame,
    })

    local container = create('Frame', {
        Name = 'Container',
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ClipsDescendants = C.ClipDescendants,
        Parent = frame,
    })
    create('UICorner', {
        CornerRadius = UDim.new(0, C.CornerRadius),
        Parent = container,
    })

    S.Gui       = gui
    S.MainFrame = frame
    S.Container = container
    S.Stroke    = stroke
    S.Corner    = corner
end

--=====================================================
-- sync with Library
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

--=====================================================
-- lifecycle
--=====================================================
function PreviewManager:SetLibrary(lib) PreviewManager.Library = lib end

function PreviewManager:Create()
    self:Build()
    self:StartSync()
end

function PreviewManager:Destroy()
    local S = PreviewManager.State
    if S.SyncConn then S.SyncConn:Disconnect() S.SyncConn = nil end
    if S.Gui then S.Gui:Destroy() S.Gui = nil end
end

--=====================================================
-- getters
--=====================================================
function PreviewManager:GetContainer() return PreviewManager.State.Container end
function PreviewManager:GetFrame()     return PreviewManager.State.MainFrame end
function PreviewManager:GetGui()       return PreviewManager.State.Gui end

--=====================================================
-- setters (для вызова из своего кода)
--=====================================================
function PreviewManager:SetEnabled(b) PreviewManager.Config.Enabled = b and true or false end

function PreviewManager:SetSize(x, y)
    PreviewManager.Config.Size = Vector2.new(x, y)
    if PreviewManager.State.MainFrame then
        PreviewManager.State.MainFrame.Size = UDim2.fromOffset(x, y)
    end
end

function PreviewManager:SetPosition(udim2)
    PreviewManager.Config.Position = udim2
    if PreviewManager.State.MainFrame then
        PreviewManager.State.MainFrame.Position = udim2
    end
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
    local s = PreviewManager.State.Stroke
    if s then
        s.Color = PreviewManager.Config.OutlineColor
        s.Thickness = PreviewManager.Config.OutlineThickness
    end
end

function PreviewManager:SetCornerRadius(r)
    PreviewManager.Config.CornerRadius = r
    local st = PreviewManager.State
    if st.Corner then st.Corner.CornerRadius = UDim.new(0, r) end
    if st.Container then
        local c = st.Container:FindFirstChildOfClass('UICorner')
        if c then c.CornerRadius = UDim.new(0, r) end
    end
end

function PreviewManager:SetClipping(b)
    PreviewManager.Config.ClipDescendants = b and true or false
    local st = PreviewManager.State
    if st.MainFrame then st.MainFrame.ClipsDescendants = b end
    if st.Container then st.Container.ClipsDescendants = b end
end

function PreviewManager:SetDraggable(b)
    PreviewManager.Config.Draggable = b and true or false
    if PreviewManager.State.MainFrame then
        PreviewManager.State.MainFrame.Draggable = b and true or false
    end
end

return PreviewManager
