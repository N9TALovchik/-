local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService');
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();
loadstring(game:HttpGet("https://raw.githubusercontent.com/N9TALovchik/-/refs/heads/main/addons/NOTALovchik.lua"))()
local CURSOR_IMAGE_ID = "18392993708"
local NOTIFY_SOUND_ID = "132463144859699"
local NOTIFY_ANIMATION_SPEED = 0.3
local THREED_DISTANCE = 5
local PPU = 100
local ThreeDMode = false
local Current3DPart, Current3DSurface
local SPEED_MIN, SPEED_MAX = 0.1, 15.0
local RainbowClock = 0
local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end
local ScreenGui = Instance.new('ScreenGui')
local OverlayGui = Instance.new('ScreenGui')
local BindGui = Instance.new('ScreenGui')
ProtectGui(ScreenGui); ProtectGui(OverlayGui); ProtectGui(BindGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
BindGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
BindGui.DisplayOrder = 10
BindGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui; OverlayGui.Parent = CoreGui; BindGui.Parent = CoreGui

local function getScreenGui(obj) while obj and not obj:IsA('ScreenGui') do obj = obj.Parent end return obj or ScreenGui end
local Toggles, Options = {}, {}
getgenv().Toggles = Toggles; getgenv().Options = Options

local Library = {
    Registry = {}; RegistryMap = {}; HudRegistry = {};
    FontColor = Color3.fromRGB(255,255,255); MainColor = Color3.fromRGB(28,28,28);
    BackgroundColor = Color3.fromRGB(20,20,20); AccentColor = Color3.fromRGB(0,85,255);
    OutlineColor = Color3.fromRGB(50,50,50); RiskColor = Color3.fromRGB(255,50,50);
    Black = Color3.new(0,0,0); Font = Enum.Font.Code;
    OpenedFrames = {}; DependencyBoxes = {}; Signals = {};
    ScreenGui = ScreenGui; UICornerRadius = 1; UICorners = {};
    NotifySoundId = NOTIFY_SOUND_ID; CursorImageId = CURSOR_IMAGE_ID;
    MainFrame = nil; _resizing = false; _hoveredResizeHandle = nil;
    UICorner = {
        Button = 8, Toggle = 3, Slider = 8, Dropdown = 4,
        DropdownList = 4, Groupbox = 6, KeyPicker = 3, Keybind = 4,
    };
    CornerRefs = {};
    CornerBase = {};
    WindowCornerRefs = {};
    OutlineStrokes = {};
    RemoveLines = true;
};

function Library:RegisterCorner(corner, kind)
    if not corner or not kind then return corner end
    Library.CornerRefs[kind] = Library.CornerRefs[kind] or {}
    table.insert(Library.CornerRefs[kind], corner)
    Library.CornerBase[corner] = Library.UICorner[kind] or 0
    return corner
end
function Library:RegisterWindowCorner(corner)
    if not corner then return corner end
    table.insert(Library.WindowCornerRefs, corner)
    Library.CornerBase[corner] = corner.CornerRadius.Offset
    return corner
end
function Library:SetCornerRadius(kind, radius)
    Library.UICorner = Library.UICorner or {}
    Library.UICorner[kind] = radius
    for _, c in ipairs(Library.CornerRefs[kind] or {}) do
        if c and c.Parent then
            Library.CornerBase[c] = radius
            c.CornerRadius = UDim.new(0, radius * (Library.UICornerRadius or 1))
        end
    end
end
function Library:SetWindowCorner(r)
    for _, c in next, Library.WindowCornerRefs do
        if c and c.Parent then
            c.CornerRadius = UDim.new(0, r)
        end
    end
end
function Library:SetGlobalCornerRadius(r)
    Library.UICornerRadius = r
    for corner, base in next, Library.CornerBase do
        if corner and corner.Parent then
            corner.CornerRadius = UDim.new(0, base * r)
        end
    end
end
function Library:CreateStroke(Props)
    local p = {}
    for k, v in next, Props do p[k] = v end
    p.Color = p.Color or Library.OutlineColor
    p.Thickness = p.Thickness or 1
    p.ApplyStrokeMode = p.ApplyStrokeMode or Enum.ApplyStrokeMode.Border
    local s = Library:Create('UIStroke', p)
    table.insert(Library.OutlineStrokes, s)
    return s
end
function Library:SetOutlineColor(c)
    Library.OutlineColor = c
    for _, s in next, Library.OutlineStrokes do
        if s and s.Parent then s.Color = c end
    end
end
function Library:SetAccentColor(c)
    Library.AccentColor = c
    Library.AccentColorDark = Library:GetDarkerColor(c)
    Library:UpdateColorsUsingRegistry()
end
getgenv().SetUICornerRadius = function(r) return Library:SetGlobalCornerRadius(r) end
getgenv().SetGlobalCornerRadius = function(r) return Library:SetGlobalCornerRadius(r) end
getgenv().SetWindowCorner = function(r) return Library:SetWindowCorner(r) end
getgenv().SetCornerRadius = function(kind, r) return Library:SetCornerRadius(kind, r) end
getgenv().SetOutlineColor = function(c) return Library:SetOutlineColor(c) end
getgenv().SetAccentColor = function(c) return Library:SetAccentColor(c) end

local RainbowStep, Hue = 0, 0
table.insert(Library.Signals, RenderStepped:Connect(function(d) RainbowClock = RainbowClock + d end))
table.insert(Library.Signals, RenderStepped:Connect(function(d)
    RainbowStep = RainbowStep + d
    if RainbowStep >= 1/60 then RainbowStep = 0; Hue = Hue + 1/400; if Hue > 1 then Hue = 0 end
        Library.CurrentRainbowHue = Hue; Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1) end
end))

local function GetPlayersString()
    local l = Players:GetPlayers()
    for i = 1, #l do l[i] = l[i].Name end
    table.sort(l, function(a, b) return a < b end); return l
end
local function GetTeamsString()
    local l = Teams:GetTeams()
    for i = 1, #l do l[i] = l[i].Name end
    table.sort(l, function(a, b) return a < b end); return l
end
function Library:SafeCallback(f, ...)
    if not f then return end
    if not Library.NotifyOnError then return f(...) end
    local ok, ev = pcall(f, ...)
    if not ok then local _, i = ev:find(":%d+: ") if not i then return Library:Notify(ev) end return Library:Notify(ev:sub(i+1), 3) end
end
function Library:AttemptSave() if Library.SaveManager then Library.SaveManager:Save() end end
function Library:Create(Class, Props)
    local inst = Class; if type(Class) == 'string' then inst = Instance.new(Class) end
    for p, v in next, Props do inst[p] = v end; return inst
end
function Library:ApplyTextStroke(inst)
    inst.TextStrokeTransparency = 1
    Library:Create('UIStroke', { Color = Color3.new(0,0,0); Thickness = 1; LineJoinMode = Enum.LineJoinMode.Miter; Parent = inst })
end
function Library:CreateLabel(Props, IsHud)
    local props = Props or {}
    local a, b, c, d, e, f = props.StartImage, props.EndImage, props.StartImageColor, props.EndImageColor, props.StartImageOffset, props.EndImageOffset
    props.StartImage, props.EndImage, props.StartImageColor, props.EndImageColor, props.StartImageOffset, props.EndImageOffset = nil, nil, nil, nil, nil, nil
    local function valid(id) if id == nil then return false end local s = tostring(id) return not (s == '' or s == '0' or s == 'rbxassetid://0' or s == 'rbxassetid://') end
    local hS, hE = valid(a), valid(b)
    local inst = Library:Create('TextLabel', { BackgroundTransparency = 1; Font = Library.Font; TextColor3 = Library.FontColor; TextSize = 16; TextStrokeTransparency = 0; RichText = true })
    Library:ApplyTextStroke(inst); Library:AddToRegistry(inst, { TextColor3 = 'FontColor' }, IsHud)
    if not (hS or hE) then return Library:Create(inst, props) end
    local wrap = Library:Create('Frame', { BackgroundTransparency = 1; Position = props.Position or UDim2.new(); Size = props.Size or UDim2.new(1,0,0,16); AnchorPoint = props.AnchorPoint or Vector2.new(); ZIndex = props.ZIndex; Parent = props.Parent })
    local ts = props.TextSize or 16; local px = ts; local pad = 4
    local lp = hS and (px+pad) or 0; local rp = hE and (px+pad) or 0; local zi = (props.ZIndex or 1) + 1
    if hS then Library:Create('ImageLabel', { BackgroundTransparency = 1; Position = UDim2.fromOffset((e and e.X) or 0, (e and e.Y) or 0); Size = UDim2.fromOffset(px,px); Image = a; ImageColor3 = c or Color3.new(1,1,1); ZIndex = zi; Parent = wrap }) end
    if hE then Library:Create('ImageLabel', { BackgroundTransparency = 1; AnchorPoint = Vector2.new(1,0); Position = UDim2.new(1, (f and f.X) or 0, 0, (f and f.Y) or 0); Size = UDim2.fromOffset(px,px); Image = b; ImageColor3 = d or Color3.new(1,1,1); ZIndex = zi; Parent = wrap }) end
    props.Parent = wrap; props.Position = UDim2.fromOffset(lp, 0); props.Size = UDim2.new(1, -lp-rp, 1, 0); props.AnchorPoint = nil; props.ZIndex = zi
    Library:Create(inst, props); return inst
end
function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = false
    local dragging, startMX, startMY, startAbsX, startAbsY = false, 0, 0, 0, 0
    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, gp)
        if gp then return end
        if Library._resizing or Library._hoveredResizeHandle then return end
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local ap, as = Instance.AbsolutePosition, Instance.AbsoluteSize
        if Mouse.X < ap.X or Mouse.X > ap.X+as.X or Mouse.Y < ap.Y or Mouse.Y > ap.Y+as.Y then return end
        if Input.Position.Y - ap.Y > (Cutoff or 40) then return end
        dragging = true; startMX = Input.Position.X; startMY = Input.Position.Y; startAbsX = ap.X; startAbsY = ap.Y
        Instance.AnchorPoint = Vector2.new(0, 0); Instance.Position = UDim2.fromOffset(startAbsX, startAbsY)
    end))
    Library:GiveSignal(InputService.InputChanged:Connect(function(Input)
        if not dragging then return end
        if Library._resizing then dragging = false return end
        if Input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        Instance.Position = UDim2.fromOffset(startAbsX + (Input.Position.X - startMX), startAbsY + (Input.Position.Y - startMY))
    end))
    Library:GiveSignal(InputService.InputEnded:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end))
end
function Library:AddToolTip(InfoStr, Hover)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14)
    local TT = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; Size = UDim2.fromOffset(X+5, Y+4); ZIndex = 100; Parent = getScreenGui(Hover); Visible = false })
    local L = Library:CreateLabel({ Position = UDim2.fromOffset(3,1); Size = UDim2.fromOffset(X,Y); TextSize = 14; Text = InfoStr; TextColor3 = Library.FontColor; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 101; Parent = TT })
    Library:AddToRegistry(TT, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
    Library:AddToRegistry(L, { TextColor3 = 'FontColor' })
    local hov = false
    Hover.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        hov = true; TT.Visible = true
        while hov do RunService.Heartbeat:Wait() TT.Position = UDim2.fromOffset(Mouse.X+15, Mouse.Y+12) end
    end)
    Hover.MouseLeave:Connect(function() hov = false; TT.Visible = false end)
end
function Library:OnHighlight(HL, Inst, Props, Def)
    HL.MouseEnter:Connect(function()
        local R = Library.RegistryMap[Inst]
        for p, c in next, Props do Inst[p] = Library[c] or c; if R and R.Properties[p] then R.Properties[p] = c end end
    end)
    HL.MouseLeave:Connect(function()
        local R = Library.RegistryMap[Inst]
        for p, c in next, Def do Inst[p] = Library[c] or c; if R and R.Properties[p] then R.Properties[p] = c end end
    end)
end
function Library:MouseIsOverOpenedFrame()
    for F, _ in next, Library.OpenedFrames do
        if F and F.Parent then
            local ap, as = F.AbsolutePosition, F.AbsoluteSize
            if Mouse.X >= ap.X and Mouse.X <= ap.X+as.X and Mouse.Y >= ap.Y and Mouse.Y <= ap.Y+as.Y then return true end
        end
    end
end
function Library:IsMouseOverFrame(F)
    local ap, as = F.AbsolutePosition, F.AbsoluteSize
    return Mouse.X >= ap.X and Mouse.X <= ap.X+as.X and Mouse.Y >= ap.Y and Mouse.Y <= ap.Y+as.Y
end
function Library:UpdateDependencyBoxes() for _, d in next, Library.DependencyBoxes do d:Update() end end
function Library:MapValue(v, a, b, c, d) return (1 - ((v-a)/(b-a))) * c + ((v-a)/(b-a)) * d end
function Library:GetTextBounds(t, f, s, r) local b = TextService:GetTextSize(t, s, f, r or Vector2.new(1920,1080)); return b.X, b.Y end
function Library:GetDarkerColor(c) local h,s,v = Color3.toHSV(c); return Color3.fromHSV(h,s,v/1.5) end
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor)

function Library:AddToRegistry(Inst, Props, IsHud)
    local I = #Library.Registry + 1
    local D = { Instance = Inst; Properties = Props; Idx = I }
    table.insert(Library.Registry, D); Library.RegistryMap[Inst] = D
    if IsHud then table.insert(Library.HudRegistry, D) end
end
function Library:RemoveFromRegistry(Inst)
    local D = Library.RegistryMap[Inst]
    if D then
        for i = #Library.Registry, 1, -1 do if Library.Registry[i] == D then table.remove(Library.Registry, i) end end
        for i = #Library.HudRegistry, 1, -1 do if Library.HudRegistry[i] == D then table.remove(Library.HudRegistry, i) end end
        Library.RegistryMap[Inst] = nil
    end
end
function Library:UpdateColorsUsingRegistry()
    for _, O in next, Library.Registry do
        for p, c in next, O.Properties do
            if type(c) == 'string' then O.Instance[p] = Library[c]
            elseif type(c) == 'function' then O.Instance[p] = c() end
        end
    end
end
function Library:GiveSignal(s) table.insert(Library.Signals, s) end
function Library:Unload()
    for i = #Library.Signals, 1, -1 do table.remove(Library.Signals, i):Disconnect() end
    if Library.OnUnload then Library.OnUnload() end
    ScreenGui:Destroy(); OverlayGui:Destroy(); BindGui:Destroy()
end
function Library:OnUnload(cb) Library.OnUnload = cb end
Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(I) if Library.RegistryMap[I] then Library:RemoveFromRegistry(I) end end))

local BaseAddons = {}
do
    local Funcs = {}

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel
        assert(Info.Default, 'AddColorPicker: Missing default value.')
        local CP = {
            Value = Info.Default; Transparency = Info.Transparency or 0;
            Type = 'ColorPicker'; Title = type(Info.Title) == 'string' and Info.Title or 'Color picker';
            Callback = Info.Callback or function() end; Mode = 'Standard';
            OnlyStandart = (Info.OnlyStandart == 1);
            RainbowSpeed = 1; RainbowBrightness = 1; GradientSpeed = 1;
            GradientColorA = Info.Default; GradientColorB = Color3.fromRGB(255,0,0); GradientEditTarget = 'A';
        }
        function CP:SetHSVFromRGB(c) local h,s,v = Color3.toHSV(c); CP.Hue, CP.Sat, CP.Vib = h, s, v end
        CP:SetHSVFromRGB(CP.Value)
        local function PH(m)
            if m == 'Rainbow' then return Info.Transparency and 160 or 132
            elseif m == 'Gradient' then return Info.Transparency and 384 or 362
            else return Info.Transparency and 322 or 297 end
        end
        local Display = Library:Create('Frame', { BackgroundColor3 = CP.Value; BorderColor3 = Library:GetDarkerColor(CP.Value); BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(0,28,0,14); ZIndex = 6; Active = true; Parent = ToggleLabel })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = Display }), 'Button')
        Library:Create('ImageLabel', { BorderSizePixel = 0; Size = UDim2.new(0,27,0,13); ZIndex = 5; Image = 'http://www.roblox.com/asset/?id=12977615774'; Visible = not not Info.Transparency; Parent = Display })
        local PFO = Library:Create('Frame', { Name = 'Color'; BackgroundColor3 = Color3.new(1,1,1); BorderColor3 = Library.OutlineColor; Position = UDim2.fromOffset(Display.AbsolutePosition.X, Display.AbsolutePosition.Y + 18); Size = UDim2.fromOffset(230, PH(CP.Mode)); Visible = false; ZIndex = 15; Parent = getScreenGui(ToggleLabel) })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Groupbox); Parent = PFO }), 'Groupbox')
        Display:GetPropertyChangedSignal('AbsolutePosition'):Connect(function() PFO.Position = UDim2.fromOffset(Display.AbsolutePosition.X, Display.AbsolutePosition.Y + 18) end)
        local PFI = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1,0,1,0); ZIndex = 16; Parent = PFO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Groupbox); Parent = PFI }), 'Groupbox')
        Library:CreateStroke({ Parent = PFI })
        local Highlight = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1,0,0,2); ZIndex = 17; Parent = PFI; BackgroundTransparency = Library.RemoveLines and 1 or 0 })
        Library:CreateLabel({ Size = UDim2.new(1,0,0,14); Position = UDim2.fromOffset(5,5); TextXAlignment = Enum.TextXAlignment.Left; TextSize = 14; Text = CP.Title; TextWrapped = false; ZIndex = 16; Parent = PFI })
        local ModeBtn = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(4,25); Size = UDim2.new(1,-8,0,18); ZIndex = 30; Active = true; Parent = PFI })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = ModeBtn }), 'Button')
        Library:AddToRegistry(ModeBtn, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        local MBL = Library:CreateLabel({ Size = UDim2.new(1,-22,1,0); Position = UDim2.fromOffset(4,0); Text = 'Standard'; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 31; Parent = ModeBtn })
        Library:CreateLabel({ Size = UDim2.new(0,20,1,0); Position = UDim2.new(1,-22,0,0); Text = 'v'; TextSize = 12; ZIndex = 31; Parent = ModeBtn })
        local ModeList = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(4,45); Size = UDim2.new(1,-8,0,0); Visible = false; ZIndex = 32; Parent = PFI })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.DropdownList); Parent = ModeList }), 'DropdownList')
        Library:CreateStroke({ Parent = ModeList })
        Library:AddToRegistry(ModeList, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = ModeList })
        local CY = 68
        local StdContent = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.fromOffset(0, CY); Size = UDim2.new(1,0,0,220); ZIndex = 17; Parent = PFI })
        local SVMO = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.new(0,4,0,0); Size = UDim2.new(0,200,0,200); ZIndex = 17; Parent = StdContent })
        local SVMI = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1,0,1,0); ZIndex = 18; Active = true; Parent = SVMO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = SVMI }), 'Button')
        local SVM = Library:Create('ImageLabel', { BorderSizePixel = 0; Size = UDim2.new(1,0,1,0); ZIndex = 18; Image = 'rbxassetid://4155801252'; Parent = SVMI })
        local CO = Library:Create('ImageLabel', { AnchorPoint = Vector2.new(0.5,0.5); Size = UDim2.new(0,6,0,6); BackgroundTransparency = 1; Image = 'http://www.roblox.com/asset/?id=9619665977'; ImageColor3 = Color3.new(0,0,0); ZIndex = 19; Parent = SVM })
        Library:Create('ImageLabel', { Size = UDim2.new(0,4,0,4); Position = UDim2.new(0,1,0,1); BackgroundTransparency = 1; Image = 'http://www.roblox.com/asset/?id=9619665977'; ZIndex = 20; Parent = CO })
        local HSO = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.new(0,208,0,0); Size = UDim2.new(0,15,0,200); ZIndex = 17; Parent = StdContent })
        local HSI = Library:Create('Frame', { BackgroundColor3 = Color3.new(1,1,1); BorderSizePixel = 0; Size = UDim2.new(1,0,1,0); ZIndex = 18; Active = true; Parent = HSO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = HSI }), 'Button')
        local HC = Library:Create('Frame', { BackgroundColor3 = Color3.new(1,1,1); AnchorPoint = Vector2.new(0,0.5); BorderColor3 = Color3.new(0,0,0); Size = UDim2.new(1,0,0,1); ZIndex = 18; Parent = HSI })
        local HBO = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.fromOffset(4,203); Size = UDim2.new(0.5,-6,0,20); ZIndex = 18; Parent = StdContent })
        local HBI = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1,0,1,0); ZIndex = 18; Parent = HBO })
        Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212)) }); Rotation = 90; Parent = HBI })
        local HB = Library:Create('TextBox', { BackgroundTransparency = 1; Position = UDim2.new(0,5,0,0); Size = UDim2.new(1,-5,1,0); Font = Library.Font; PlaceholderColor3 = Color3.fromRGB(190,190,190); PlaceholderText = 'Hex color'; Text = '#FFFFFF'; TextColor3 = Library.FontColor; TextSize = 14; TextStrokeTransparency = 0; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 20; Parent = HBI })
        Library:ApplyTextStroke(HB)
        local RBB = Library:Create(HBO:Clone(), { Position = UDim2.new(0.5,2,0,203); Size = UDim2.new(0.5,-6,0,20); Parent = StdContent })
        local RB = Library:Create(RBB.Frame:FindFirstChild('TextBox'), { Text = '255, 255, 255'; PlaceholderText = 'RGB color'; TextColor3 = Library.FontColor })
        local RC = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.fromOffset(0, CY); Size = UDim2.new(1,0,0,70); Visible = false; ZIndex = 17; Parent = PFI })
        local RSL = Library:CreateLabel({ Position = UDim2.fromOffset(5,0); Size = UDim2.new(1,-10,0,14); Text = 'Rainbow Speed: 1.0'; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 18; Parent = RC })
        local RSO = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(5,16); Size = UDim2.new(1,-10,0,12); ZIndex = 18; Active = true; Parent = RC })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Slider); Parent = RSO }), 'Slider')
        Library:AddToRegistry(RSO, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        local RSF = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0.2,0,1,0); ZIndex = 19; Parent = RSO })
        Library:AddToRegistry(RSF, { BackgroundColor3 = 'AccentColor' })
        local RBL = Library:CreateLabel({ Position = UDim2.fromOffset(5,34); Size = UDim2.new(1,-10,0,14); Text = 'Brightness: 1.00'; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 18; Parent = RC })
        local RBO = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(5,50); Size = UDim2.new(1,-10,0,12); ZIndex = 18; Active = true; Parent = RC })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Slider); Parent = RBO }), 'Slider')
        Library:AddToRegistry(RBO, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        local RBF = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0.9,0,1,0); ZIndex = 19; Parent = RBO })
        Library:AddToRegistry(RBF, { BackgroundColor3 = 'AccentColor' })
        local GC = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.fromOffset(0, CY); Size = UDim2.new(1,0,0,290); Visible = false; ZIndex = 17; Parent = PFI })
        local GCAB = Library:Create('Frame', { BackgroundColor3 = CP.GradientColorA; BorderColor3 = Library.AccentColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(4,2); Size = UDim2.new(0.5,-6,0,22); ZIndex = 18; Active = true; Parent = GC })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = GCAB }), 'Button')
        Library:CreateLabel({ Size = UDim2.new(1,0,1,0); Text = 'A'; TextSize = 13; TextColor3 = Color3.new(1,1,1); TextStrokeTransparency = 0; TextStrokeColor3 = Color3.new(0,0,0); ZIndex = 19; Parent = GCAB })
        local GCBB = Library:Create('Frame', { BackgroundColor3 = CP.GradientColorB; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.new(0.5,2,0,2); Size = UDim2.new(0.5,-6,0,22); ZIndex = 18; Active = true; Parent = GC })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = GCBB }), 'Button')
        Library:CreateLabel({ Size = UDim2.new(1,0,1,0); Text = 'B'; TextSize = 13; TextColor3 = Color3.new(1,1,1); TextStrokeTransparency = 0; TextStrokeColor3 = Color3.new(0,0,0); ZIndex = 19; Parent = GCBB })
        local GSVMO = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.new(0,4,0,28); Size = UDim2.new(0,200,0,200); ZIndex = 17; Parent = GC })
        local GSVMI = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1,0,1,0); ZIndex = 18; Active = true; Parent = GSVMO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = GSVMI }), 'Button')
        local GSVM = Library:Create('ImageLabel', { BorderSizePixel = 0; Size = UDim2.new(1,0,1,0); ZIndex = 18; Image = 'rbxassetid://4155801252'; Parent = GSVMI })
        local GCO = Library:Create('ImageLabel', { AnchorPoint = Vector2.new(0.5,0.5); Size = UDim2.new(0,6,0,6); BackgroundTransparency = 1; Image = 'http://www.roblox.com/asset/?id=9619665977'; ImageColor3 = Color3.new(0,0,0); ZIndex = 19; Parent = GSVM })
        Library:Create('ImageLabel', { Size = UDim2.new(0,4,0,4); Position = UDim2.new(0,1,0,1); BackgroundTransparency = 1; Image = 'http://www.roblox.com/asset/?id=9619665977'; ZIndex = 20; Parent = GCO })
        local GHO = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.new(0,208,0,28); Size = UDim2.new(0,15,0,200); ZIndex = 17; Parent = GC })
        local GHI = Library:Create('Frame', { BackgroundColor3 = Color3.new(1,1,1); BorderSizePixel = 0; Size = UDim2.new(1,0,1,0); ZIndex = 18; Active = true; Parent = GHO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = GHI }), 'Button')
        local GHC = Library:Create('Frame', { BackgroundColor3 = Color3.new(1,1,1); AnchorPoint = Vector2.new(0,0.5); BorderColor3 = Color3.new(0,0,0); Size = UDim2.new(1,0,0,1); ZIndex = 18; Parent = GHI })
        local GSL = Library:CreateLabel({ Position = UDim2.fromOffset(5,235); Size = UDim2.new(1,-10,0,14); Text = 'Gradient Speed: 1.0'; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 18; Parent = GC })
        local GSO = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(5,252); Size = UDim2.new(1,-10,0,12); ZIndex = 18; Active = true; Parent = GC })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Slider); Parent = GSO }), 'Slider')
        Library:AddToRegistry(GSO, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        local GSF = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0.2,0,1,0); ZIndex = 19; Parent = GSO })
        Library:AddToRegistry(GSF, { BackgroundColor3 = 'AccentColor' })
        local TBO, TBI, TBC
        local function gTY()
            if CP.Mode == 'Rainbow' then return CY + 70
            elseif CP.Mode == 'Gradient' then return CY + 290
            else return CY + 228 end
        end
        if Info.Transparency then
            TBO = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.fromOffset(4, gTY()); Size = UDim2.new(1,-8,0,15); ZIndex = 30; Parent = PFI })
            TBI = Library:Create('Frame', { BackgroundColor3 = CP.Value; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1,0,1,0); ZIndex = 30; Active = true; Parent = TBO })
            Library:AddToRegistry(TBI, { BorderColor3 = 'OutlineColor' })
            Library:Create('ImageLabel', { BackgroundTransparency = 1; Size = UDim2.new(1,0,1,0); Image = 'http://www.roblox.com/asset/?id=12978095818'; ZIndex = 31; Parent = TBI })
            TBC = Library:Create('Frame', { BackgroundColor3 = Color3.new(1,1,1); AnchorPoint = Vector2.new(0.5,0); BorderColor3 = Color3.new(0,0,0); Size = UDim2.new(0,1,1,0); ZIndex = 32; Parent = TBI })
        end
        local Seq = {}
        for h = 0, 1, 0.1 do table.insert(Seq, ColorSequenceKeypoint.new(h, Color3.fromHSV(h, 1, 1))) end
        Library:Create('UIGradient', { Color = ColorSequence.new(Seq); Rotation = 90; Parent = HSI })
        Library:Create('UIGradient', { Color = ColorSequence.new(Seq); Rotation = 90; Parent = GHI })
        function CP:GetEffectiveColor()
            if CP.Mode == 'Standard' then return Color3.fromHSV(CP.Hue, CP.Sat, CP.Vib)
            elseif CP.Mode == 'Rainbow' then local t = RainbowClock * CP.RainbowSpeed; return Color3.fromHSV(t % 1, 1, CP.RainbowBrightness)
            elseif CP.Mode == 'Gradient' then local t = (math.sin(RainbowClock * CP.GradientSpeed) + 1) * 0.5; return CP.GradientColorA:Lerp(CP.GradientColorB, t) end
            return CP.Value
        end
        local function uRS()
            local s = math.clamp((CP.RainbowSpeed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), 0, 1)
            RSF.Size = UDim2.new(s,0,1,0); RSL.Text = string.format('Rainbow Speed: %.1f', CP.RainbowSpeed)
            local b = math.clamp(CP.RainbowBrightness, 0.05, 1)
            RBF.Size = UDim2.new(b,0,1,0); RBL.Text = string.format('Brightness: %.2f', CP.RainbowBrightness)
        end
        local function uGS()
            local s = math.clamp((CP.GradientSpeed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), 0, 1)
            GSF.Size = UDim2.new(s,0,1,0); GSL.Text = string.format('Gradient Speed: %.1f', CP.GradientSpeed)
        end
        function CP:Display()
            if CP.Mode == 'Standard' then
                CP.Value = Color3.fromHSV(CP.Hue, CP.Sat, CP.Vib)
                SVM.BackgroundColor3 = Color3.fromHSV(CP.Hue, 1, 1)
                CO.Position = UDim2.new(CP.Sat, 0, 1 - CP.Vib, 0)
                HC.Position = UDim2.new(0, 0, CP.Hue, 0)
                HB.Text = '#' .. CP.Value:ToHex()
                RB.Text = table.concat({ math.floor(CP.Value.R*255), math.floor(CP.Value.G*255), math.floor(CP.Value.B*255) }, ', ')
            elseif CP.Mode == 'Gradient' then
                local nc = Color3.fromHSV(CP.Hue, CP.Sat, CP.Vib)
                if CP.GradientEditTarget == 'A' then CP.GradientColorA = nc else CP.GradientColorB = nc end
                GCAB.BackgroundColor3 = CP.GradientColorA; GCBB.BackgroundColor3 = CP.GradientColorB
                GCAB.BorderColor3 = (CP.GradientEditTarget == 'A') and Library.AccentColor or Library.OutlineColor
                GCBB.BorderColor3 = (CP.GradientEditTarget == 'B') and Library.AccentColor or Library.OutlineColor
                GSVM.BackgroundColor3 = Color3.fromHSV(CP.Hue, 1, 1)
                GCO.Position = UDim2.new(CP.Sat, 0, 1 - CP.Vib, 0)
                GHC.Position = UDim2.new(0, 0, CP.Hue, 0)
                CP.Value = CP.GradientColorA
            end
            uRS(); uGS()
            local dc = CP:GetEffectiveColor()
            Display.BackgroundColor3 = dc; Display.BorderColor3 = Library:GetDarkerColor(dc)
            if TBI then TBI.BackgroundColor3 = CP.Value; TBC.Position = UDim2.new(1 - CP.Transparency, 0, 0, 0) end
            Library:SafeCallback(CP.Callback, CP.Value, CP.Transparency)
            Library:SafeCallback(CP.Changed, CP.Value, CP.Transparency)
        end
        function CP:GetSaveData()
            return { value = CP.Value:ToHex(), transparency = CP.Transparency, mode = CP.Mode, hue = CP.Hue, sat = CP.Sat, vib = CP.Vib, rainbowSpeed = CP.RainbowSpeed, rainbowBrightness = CP.RainbowBrightness, gradientSpeed = CP.GradientSpeed, gradientColorA = CP.GradientColorA:ToHex(), gradientColorB = CP.GradientColorB:ToHex(), gradientEditTarget = CP.GradientEditTarget }
        end
        function CP:LoadSaveData(d)
            if type(d) ~= 'table' then return end
            if d.hue then CP.Hue = d.hue end; if d.sat then CP.Sat = d.sat end; if d.vib then CP.Vib = d.vib end
            if d.transparency then CP.Transparency = d.transparency end
            if d.rainbowSpeed then CP.RainbowSpeed = d.rainbowSpeed end
            if d.rainbowBrightness then CP.RainbowBrightness = d.rainbowBrightness end
            if d.gradientSpeed then CP.GradientSpeed = d.gradientSpeed end
            if d.gradientColorA then local ok, c = pcall(Color3.fromHex, d.gradientColorA) if ok then CP.GradientColorA = c end end
            if d.gradientColorB then local ok, c = pcall(Color3.fromHex, d.gradientColorB) if ok then CP.GradientColorB = c end end
            if d.gradientEditTarget then CP.GradientEditTarget = d.gradientEditTarget end
            if d.mode then CP:SetMode(d.mode) else CP:Display() end
        end
        local savedStd = nil
        local function SM(nm)
            if CP.OnlyStandart and nm ~= 'Standard' then return end
            if CP.Mode == 'Standard' and nm ~= 'Standard' then savedStd = { CP.Hue, CP.Sat, CP.Vib } end
            CP.Mode = nm; MBL.Text = nm
            StdContent.Visible = (nm == 'Standard'); RC.Visible = (nm == 'Rainbow'); GC.Visible = (nm == 'Gradient')
            ModeList.Visible = false
            PFO.Size = UDim2.fromOffset(230, PH(nm))
            if TBO then TBO.Position = UDim2.fromOffset(4, gTY()) end
            if nm == 'Gradient' then
                if CP.GradientEditTarget == 'A' then CP:SetHSVFromRGB(CP.GradientColorA) else CP:SetHSVFromRGB(CP.GradientColorB) end
            elseif nm == 'Standard' and savedStd then CP.Hue, CP.Sat, CP.Vib = savedStd[1], savedStd[2], savedStd[3] end
            CP:Display()
        end
        for _, opt in ipairs({ 'Standard', 'Rainbow', 'Gradient' }) do
            local OB = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,0,18); ZIndex = 33; Active = true; Parent = ModeList })
            Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = OB }), 'Button')
            local OL = Library:CreateLabel({ Size = UDim2.new(1,-6,1,0); Position = UDim2.fromOffset(6,0); Text = opt; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 34; Parent = OB })
            if CP.OnlyStandart and opt ~= 'Standard' then OL.TextColor3 = Color3.fromRGB(100,100,100)
            else
                Library:OnHighlight(OB, OB, { BackgroundColor3 = 'AccentColor' }, { BackgroundColor3 = 'MainColor' })
                OB.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then SM(opt) end end)
            end
        end
        ModeList.Size = UDim2.new(1,-8,0, 18*3+2)
        ModeBtn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then ModeList.Visible = not ModeList.Visible end end)
        local CM = {}
        do
            CM.Container = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; ZIndex = 14; Visible = false; Parent = getScreenGui(ToggleLabel) })
            CM.Inner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.fromScale(1,1); ZIndex = 15; Parent = CM.Container })
            Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.DropdownList); Parent = CM.Inner }), 'DropdownList')
            Library:CreateStroke({ Parent = CM.Inner })
            Library:Create('UIListLayout', { Name = 'Layout'; FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = CM.Inner })
            Library:Create('UIPadding', { Name = 'Padding'; PaddingLeft = UDim.new(0, 4); Parent = CM.Inner })
            local function uMP() CM.Container.Position = UDim2.fromOffset(Display.AbsolutePosition.X + Display.AbsoluteSize.X + 4, Display.AbsolutePosition.Y + 1) end
            local function uMS()
                local mW = 60
                for _, l in next, CM.Inner:GetChildren() do if l:IsA('TextLabel') then mW = math.max(mW, l.TextBounds.X) end end
                CM.Container.Size = UDim2.fromOffset(mW + 8, CM.Inner.Layout.AbsoluteContentSize.Y + 4)
            end
            Display:GetPropertyChangedSignal('AbsolutePosition'):Connect(uMP)
            CM.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(uMS)
            task.spawn(uMP); task.spawn(uMS)
            Library:AddToRegistry(CM.Inner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
            function CM:Show() self.Container.Visible = true end
            function CM:Hide() self.Container.Visible = false end
            function CM:AddOption(Str, cb)
                if type(cb) ~= 'function' then cb = function() end end
                local B = Library:CreateLabel({ Active = false; Size = UDim2.new(1,0,0,15); TextSize = 13; Text = Str; ZIndex = 16; Parent = self.Inner; TextXAlignment = Enum.TextXAlignment.Left })
                Library:OnHighlight(B, B, { TextColor3 = 'AccentColor' }, { TextColor3 = 'FontColor' })
                B.InputBegan:Connect(function(i) if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end cb() end)
            end
            CM:AddOption('Copy color', function() Library.ColorClipboard = CP.Value Library:Notify('Copied color!', 2) end)
            CM:AddOption('Paste color', function() if not Library.ColorClipboard then return Library:Notify('You have not copied a color!', 2) end CP:SetValueRGB(Library.ColorClipboard) end)
            CM:AddOption('Copy HEX', function() pcall(setclipboard, CP.Value:ToHex()) Library:Notify('Copied hex code!', 2) end)
            CM:AddOption('Copy RGB', function() pcall(setclipboard, table.concat({ math.floor(CP.Value.R*255), math.floor(CP.Value.G*255), math.floor(CP.Value.B*255) }, ', ')) Library:Notify('Copied RGB!', 2) end)
        end
        Library:AddToRegistry(PFI, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor' })
        Library:AddToRegistry(SVMI, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(HBI, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(RBB.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor' })
        Library:AddToRegistry(RB, { TextColor3 = 'FontColor' }); Library:AddToRegistry(HB, { TextColor3 = 'FontColor' })
        HB.FocusLost:Connect(function(enter)
            if enter then local ok, r = pcall(Color3.fromHex, HB.Text) if ok and typeof(r) == 'Color3' then CP.Hue, CP.Sat, CP.Vib = Color3.toHSV(r) end end
            CP:Display()
        end)
        RB.FocusLost:Connect(function(enter)
            if enter then local r,g,b = RB.Text:match('(%d+),%s*(%d+),%s*(%d+)') if r then CP.Hue, CP.Sat, CP.Vib = Color3.toHSV(Color3.fromRGB(r,g,b)) end end
            CP:Display()
        end)
        RSO.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local mnX = RSO.AbsolutePosition.X; local mxX = mnX + RSO.AbsoluteSize.X
                local mx = math.clamp(Mouse.X, mnX, mxX)
                CP.RainbowSpeed = SPEED_MIN + ((mx-mnX)/(mxX-mnX)) * (SPEED_MAX - SPEED_MIN)
                uRS(); CP:Display(); RenderStepped:Wait()
            end
        end end)
        RBO.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local mnX = RBO.AbsolutePosition.X; local mxX = mnX + RBO.AbsoluteSize.X
                local mx = math.clamp(Mouse.X, mnX, mxX)
                CP.RainbowBrightness = math.clamp(0.05 + ((mx-mnX)/(mxX-mnX)) * 0.95, 0.05, 1)
                uRS(); CP:Display(); RenderStepped:Wait()
            end
        end end)
        GSO.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local mnX = GSO.AbsolutePosition.X; local mxX = mnX + GSO.AbsoluteSize.X
                local mx = math.clamp(Mouse.X, mnX, mxX)
                CP.GradientSpeed = SPEED_MIN + ((mx-mnX)/(mxX-mnX)) * (SPEED_MAX - SPEED_MIN)
                uGS(); CP:Display(); RenderStepped:Wait()
            end
        end end)
        GCAB.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then CP.GradientEditTarget = 'A'; CP:SetHSVFromRGB(CP.GradientColorA); CP:Display() end end)
        GCBB.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then CP.GradientEditTarget = 'B'; CP:SetHSVFromRGB(CP.GradientColorB); CP:Display() end end)
        SVM.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local mnX = SVM.AbsolutePosition.X; local mxX = mnX + SVM.AbsoluteSize.X
                local mx = math.clamp(Mouse.X, mnX, mxX)
                local mnY = SVM.AbsolutePosition.Y; local mxY = mnY + SVM.AbsoluteSize.Y
                local my = math.clamp(Mouse.Y, mnY, mxY)
                CP.Sat = (mx-mnX)/(mxX-mnX); CP.Vib = 1 - ((my-mnY)/(mxY-mnY))
                CP:Display(); RenderStepped:Wait()
            end; Library:AttemptSave()
        end end)
        GSVM.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local mnX = GSVM.AbsolutePosition.X; local mxX = mnX + GSVM.AbsoluteSize.X
                local mx = math.clamp(Mouse.X, mnX, mxX)
                local mnY = GSVM.AbsolutePosition.Y; local mxY = mnY + GSVM.AbsoluteSize.Y
                local my = math.clamp(Mouse.Y, mnY, mxY)
                CP.Sat = (mx-mnX)/(mxX-mnX); CP.Vib = 1 - ((my-mnY)/(mxY-mnY))
                CP:Display(); RenderStepped:Wait()
            end
        end end)
        HSI.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local mnY = HSI.AbsolutePosition.Y; local mxY = mnY + HSI.AbsoluteSize.Y
                local my = math.clamp(Mouse.Y, mnY, mxY)
                CP.Hue = (my-mnY)/(mxY-mnY)
                CP:Display(); RenderStepped:Wait()
            end; Library:AttemptSave()
        end end)
        GHI.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local mnY = GHI.AbsolutePosition.Y; local mxY = mnY + GHI.AbsoluteSize.Y
                local my = math.clamp(Mouse.Y, mnY, mxY)
                CP.Hue = (my-mnY)/(mxY-mnY)
                CP:Display(); RenderStepped:Wait()
            end
        end end)
        Display.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PFO.Visible then CP:Hide() else CM:Hide(); CP:Show() end
            elseif i.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then CM:Show(); CP:Hide() end
        end)
        if TBI then TBI.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                local mnX = TBI.AbsolutePosition.X; local mxX = mnX + TBI.AbsoluteSize.X
                local mx = math.clamp(Mouse.X, mnX, mxX)
                CP.Transparency = 1 - ((mx-mnX)/(mxX-mnX))
                CP:Display(); RenderStepped:Wait()
            end; Library:AttemptSave()
        end end) end
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local ap, as = PFO.AbsolutePosition, PFO.AbsoluteSize
                if Mouse.X < ap.X or Mouse.X > ap.X+as.X or Mouse.Y < (ap.Y-21) or Mouse.Y > ap.Y+as.Y then CP:Hide() end
                if not Library:IsMouseOverFrame(CM.Container) then CM:Hide() end
            end
        end))
        function CP:OnChanged(f) CP.Changed = f f(CP.Value) end
        function CP:Show()
            for F, _ in next, Library.OpenedFrames do if F.Name == 'Color' then F.Visible = false; Library.OpenedFrames[F] = nil end end
            PFO.Visible = true; Library.OpenedFrames[PFO] = true
        end
        function CP:Hide() PFO.Visible = false; Library.OpenedFrames[PFO] = nil; ModeList.Visible = false end
        function CP:SetValue(hsv, t) local c = Color3.fromHSV(hsv[1], hsv[2], hsv[3]); CP.Transparency = t or 0; CP:SetHSVFromRGB(c); CP:Display() end
        function CP:SetValueRGB(c, t) CP.Transparency = t or 0; CP:SetHSVFromRGB(c); CP:Display() end
        function CP:SetMode(m) SM(m) end
        CP:Display()
        CP.DisplayFrame = Display
        Library:GiveSignal(RenderStepped:Connect(function()
            if CP.Mode == 'Standard' then return end
            local c
            if CP.Mode == 'Rainbow' then local t = RainbowClock * CP.RainbowSpeed; c = Color3.fromHSV(t % 1, 1, CP.RainbowBrightness)
            elseif CP.Mode == 'Gradient' then local t = (math.sin(RainbowClock * CP.GradientSpeed) + 1) * 0.5; c = CP.GradientColorA:Lerp(CP.GradientColorB, t)
            else return end
            CP.Value = c; Display.BackgroundColor3 = c; Display.BorderColor3 = Library:GetDarkerColor(c)
            if TBI then TBI.BackgroundColor3 = c end
            Library:SafeCallback(CP.Callback, c, CP.Transparency); Library:SafeCallback(CP.Changed, c, CP.Transparency)
        end))
        Options[Idx] = CP
        return self
    end

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self; local ToggleLabel = self.TextLabel; local Container = self.Container
        assert(Info.Default, 'AddKeyPicker: Missing default value.')
        local KP = {
            Value = Info.Default; Toggled = false; Mode = Info.Mode or 'Toggle'; Type = 'KeyPicker';
            Callback = Info.Callback or function() end; ChangedCallback = Info.ChangedCallback or function() end;
            SyncToggleState = Info.SyncToggleState or false,
        }
        if KP.SyncToggleState then Info.Modes = { 'Toggle' } Info.Mode = 'Toggle' end
        local PO = Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(0,52,0,15); ZIndex = 6; Active = true; Parent = ToggleLabel })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.KeyPicker); Parent = PO }), 'KeyPicker')
        local PI = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; Size = UDim2.new(1,0,1,0); ZIndex = 7; ClipsDescendants = true; Parent = PO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.KeyPicker); Parent = PI }), 'KeyPicker')
        Library:CreateStroke({ Parent = PI })
        Library:AddToRegistry(PI, { BackgroundColor3 = 'BackgroundColor' })
        local DL = Library:CreateLabel({ Size = UDim2.new(1,0,1,0); TextSize = 13; Text = Info.Default; TextWrapped = false; TextTruncate = Enum.TextTruncate.AtEnd; ZIndex = 8; Parent = PI })
        local MSO = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1); Size = UDim2.new(0,60,0,32); Visible = false; ZIndex = 14; Parent = getScreenGui(ToggleLabel) })
        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function() MSO.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1) end)
        local MSI = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; Size = UDim2.new(1,0,1,0); ZIndex = 15; Parent = MSO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.DropdownList); Parent = MSI }), 'DropdownList')
        Library:CreateStroke({ Parent = MSI })
        Library:AddToRegistry(MSI, { BackgroundColor3 = 'BackgroundColor' })
        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = MSI })
        local CL = Library:Create('TextLabel', { BackgroundTransparency = 1; Font = Library.Font; TextColor3 = Library.FontColor; TextSize = 13; TextStrokeTransparency = 0; RichText = false; TextXAlignment = Enum.TextXAlignment.Left; Size = UDim2.new(1,0,0,18); Visible = false; ZIndex = 200; Parent = Library.KeybindContainer })
        Library:ApplyTextStroke(CL); Library:AddToRegistry(CL, { TextColor3 = 'FontColor' }, true)
        local Modes = Info.Modes or { 'Toggle', 'Hold' }
        local MBtns = {}
        for _, Mode in next, Modes do
            local MB = {}
            local L = Library:CreateLabel({ Active = false; Size = UDim2.new(1,0,0,15); TextSize = 13; Text = Mode; ZIndex = 16; Parent = MSI })
            function MB:Select() for _, b in next, MBtns do b:Deselect() end KP.Mode = Mode L.TextColor3 = Library.AccentColor Library.RegistryMap[L].Properties.TextColor3 = 'AccentColor' MSO.Visible = false end
            function MB:Deselect() KP.Mode = nil L.TextColor3 = Library.FontColor Library.RegistryMap[L].Properties.TextColor3 = 'FontColor' end
            L.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then MB:Select() Library:AttemptSave() end end)
            if Mode == KP.Mode then MB:Select() end
            MBtns[Mode] = MB
        end
        local mc = 0
        for _ in next, Modes do mc = mc + 1 end
        MSO.Size = UDim2.new(0,60,0, (15*mc)+2)
        function KP:Update()
            if Info.NoUI then return end
            local St = KP:GetState()
            CL.Text = string.format('[%s] %s (%s)', KP.Value, Info.Text, KP.Mode)
            CL.Visible = true
            CL.TextColor3 = St and Library.AccentColor or Library.FontColor
            local R = Library.RegistryMap[CL]
            if R and R.Properties then R.Properties.TextColor3 = St and 'AccentColor' or 'FontColor' end
            local YS, XS, has = 0, 0, false
            for _, L in next, Library.KeybindContainer:GetChildren() do
                if L:IsA('TextLabel') and L.Visible then
                    has = true; YS = YS + 18
                    local tb = TextService:GetTextSize(L.Text, L.TextSize, L.Font, Vector2.new(math.huge, math.huge))
                    if tb.X > XS then XS = tb.X end
                end
            end
            if has then Library.KeybindFrame.Visible = true Library.KeybindFrame.Size = UDim2.new(0, math.max(XS+45, 220), 0, YS+28)
            else Library.KeybindFrame.Visible = false end
        end
        function KP:GetState()
            if KP.Mode == 'Hold' then
                if KP.Value == 'None' then return false end
                if KP.Value == 'MB1' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
                if KP.Value == 'MB2' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
                return InputService:IsKeyDown(Enum.KeyCode[KP.Value])
            else return KP.Toggled end
        end
        function KP:SetValue(D)
            local K, M = D[1], D[2]
            DL.Text = K; KP.Value = K
            if MBtns[M] then MBtns[M]:Select() end
            KP:Update()
        end
        function KP:OnClick(cb) KP.Clicked = cb end
        function KP:OnChanged(cb) KP.Changed = cb cb(KP.Value) end
        if ParentObj.Addons then table.insert(ParentObj.Addons, KP) end
        function KP:DoClick()
            if ParentObj.Type == 'Toggle' and KP.SyncToggleState then ParentObj:SetValue(not ParentObj.Value) end
            Library:SafeCallback(KP.Callback, KP.Toggled); Library:SafeCallback(KP.Clicked, KP.Toggled)
        end
        local picking = false
        PO.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if picking then return end
                picking = true; DL.Text = ''
                local brk, txt = false, ''
                task.spawn(function() while not brk do if txt == '...' then txt = '' end txt = txt .. '.' DL.Text = txt wait(0.4) end end)
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do RenderStepped:Wait() end
                local ev
                ev = InputService.InputBegan:Connect(function(Inp)
                    local K
                    if Inp.KeyCode == Enum.KeyCode.Escape then K = 'None'
                    elseif Inp.UserInputType == Enum.UserInputType.Keyboard then K = Inp.KeyCode.Name
                    elseif Inp.UserInputType == Enum.UserInputType.MouseButton1 then K = 'MB1'
                    elseif Inp.UserInputType == Enum.UserInputType.MouseButton2 then K = 'MB2' end
                    brk = true; picking = false
                    if K then DL.Text = K KP.Value = K Library:SafeCallback(KP.ChangedCallback, Inp.KeyCode or Inp.UserInputType) Library:SafeCallback(KP.Changed, Inp.KeyCode or Inp.UserInputType) end
                    Library:AttemptSave(); ev:Disconnect()
                end)
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                MSO.Visible = not MSO.Visible
            end
        end)
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if not picking then
                if KP.Mode == 'Toggle' then
                    local K = KP.Value
                    if K == 'MB1' or K == 'MB2' then
                        if (K == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1) or (K == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2) then KP.Toggled = not KP.Toggled KP:DoClick() end
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard and K ~= 'None' then
                        if Input.KeyCode.Name == K then KP.Toggled = not KP.Toggled KP:DoClick() end
                    end
                end
                KP:Update()
            end
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and MSO.Visible then
                local ap, as = MSO.AbsolutePosition, MSO.AbsoluteSize
                if Mouse.X < ap.X or Mouse.X > ap.X+as.X or Mouse.Y < (ap.Y-21) or Mouse.Y > ap.Y+as.Y then MSO.Visible = false end
            end
        end))
        Library:GiveSignal(InputService.InputEnded:Connect(function(Input) if not picking then KP:Update() end end))
        KP:Update()
        Options[Idx] = KP
        return self
    end

    BaseAddons.__index = Funcs
    BaseAddons.__namecall = function(t, k, ...) return Funcs[k](...) end
end

local BaseGroupbox = {}
do
    local Funcs = {}

    function Funcs:AddBlank(Size)
        Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,0,0,Size); ZIndex = 1; Parent = self.Container })
    end

    function Funcs:AddLabel(Text, DoesWrap, SI, EI, SIC, EIC, SIO, EIO)
        local Label = {}; local Groupbox = self; local Container = Groupbox.Container
        if type(DoesWrap) == 'table' then
            local o = DoesWrap; DoesWrap, SI, EI, SIC, EIC, SIO, EIO = o.Wrap, o.StartImage, o.EndImage, o.StartImageColor, o.EndImageColor, o.StartImageOffset, o.EndImageOffset
        end
        local TL = Library:CreateLabel({ Size = UDim2.new(1,-4,0,15); TextSize = 14; Text = Text; TextWrapped = DoesWrap or false; TextXAlignment = Enum.TextXAlignment.Left; StartImage = SI; EndImage = EI; StartImageColor = SIC; EndImageColor = EIC; StartImageOffset = SIO; EndImageOffset = EIO; ZIndex = 7; Parent = Container })
        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TL.AbsoluteSize.X, math.huge)))
            TL.Size = UDim2.new(1,-4,0,Y)
        else
            Library:Create('UIListLayout', { Padding = UDim.new(0,4); FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Enum.HorizontalAlignment.Right; SortOrder = Enum.SortOrder.LayoutOrder; Parent = TL })
        end
        Label.TextLabel = TL; Label.Container = Container
        function Label:SetText(t)
            TL.Text = t
            if DoesWrap then local Y = select(2, Library:GetTextBounds(t, Library.Font, 14, Vector2.new(TL.AbsoluteSize.X, math.huge))) TL.Size = UDim2.new(1,-4,0,Y) end
            Groupbox:Resize()
        end
        if not DoesWrap then setmetatable(Label, BaseAddons) end
        Groupbox:AddBlank(5); Groupbox:Resize()
        return Label
    end

    function Funcs:AddButton(...)
        local Button = {}; local Idx = nil
        local function PBP(O, ...)
            local f, s = select(1, ...), select(2, ...)
            if type(f) == 'string' and type(s) == 'table' then
                Idx = f; O.Text = s.Text or f; O.Func = s.Func; O.DoubleClick = s.DoubleClick; O.Tooltip = s.Tooltip; O.SaveState = s.SaveState; O.Value = s.Default
                O.StartImage, O.EndImage, O.StartImageColor, O.EndImageColor, O.StartImageOffset, O.EndImageOffset = s.StartImage, s.EndImage, s.StartImageColor, s.EndImageColor, s.StartImageOffset, s.EndImageOffset
            elseif type(f) == 'table' then
                O.Text = f.Text; O.Func = f.Func; O.DoubleClick = f.DoubleClick; O.Tooltip = f.Tooltip; O.SaveState = f.SaveState; O.Value = f.Default
                O.StartImage, O.EndImage, O.StartImageColor, O.EndImageColor, O.StartImageOffset, O.EndImageOffset = f.StartImage, f.EndImage, f.StartImageColor, f.EndImageColor, f.StartImageOffset, f.EndImageOffset
            else O.Text = f; O.Func = s end
            local t = select(3, ...)
            if type(t) == 'table' then
                O.SaveState = t.SaveState
                O.StartImage, O.EndImage, O.StartImageColor, O.EndImageColor, O.StartImageOffset, O.EndImageOffset = t.StartImage, t.EndImage, t.StartImageColor, t.EndImageColor, t.StartImageOffset, t.EndImageOffset
                if t.Default ~= nil then O.Value = t.Default end
            end
        end
        PBP(Button, ...)
        Button.Type = 'Button'
        if Button.SaveState == nil then Button.SaveState = false end
        if Button.Value == nil then Button.Value = false end
        assert(type(Button.Func) == 'function', 'AddButton: `Func` callback is missing.')
        local Groupbox = self; local Container = Groupbox.Container
        local function CBB(B)
            local Outer = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,-4,0,20); ZIndex = 5; Active = true })
            local Inner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 6; ClipsDescendants = true; Parent = Outer })
            Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = Inner }), 'Button')
            Library:CreateStroke({ Parent = Inner })
            Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212)) }); Rotation = 90; Parent = Inner })
            local Ripple = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BackgroundTransparency = 1; BorderSizePixel = 0; AnchorPoint = Vector2.new(0.5,0.5); Position = UDim2.new(0.5,0,0.5,0); Size = UDim2.new(0,0,0,0); ZIndex = 7; Parent = Inner })
            Library:Create('UICorner', { CornerRadius = UDim.new(1,0); Parent = Ripple })
            local L = Library:CreateLabel({ Size = UDim2.new(1,0,1,0); TextSize = 14; Text = B.Text; StartImage = B.StartImage; EndImage = B.EndImage; StartImageColor = B.StartImageColor; EndImageColor = B.EndImageColor; StartImageOffset = B.StartImageOffset; EndImageOffset = B.EndImageOffset; ZIndex = 6; Parent = Inner })
            Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor' })
            return Outer, Inner, L, Ripple
        end
        local function PR(R)
            if not R or not R.Parent then return end
            local p = R.Parent; local ms = math.max(p.AbsoluteSize.X, p.AbsoluteSize.Y)
            R.Size = UDim2.fromOffset(0,0); R.BackgroundTransparency = 0.35
            TweenService:Create(R, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(ms*1.4, ms*1.4), BackgroundTransparency = 1 }):Play()
        end
        local function IE(B)
            local function WFE(ev, to, v)
                local bb = Instance.new('BindableEvent')
                local cn = ev:Once(function(...) if type(v) == 'function' and v(...) then bb:Fire(true) else bb:Fire(false) end end)
                task.delay(to, function() cn:disconnect() bb:Fire(false) end)
                return bb.Event:Wait()
            end
            local function VC(Inp)
                if Library:MouseIsOverOpenedFrame() then return false end
                if Inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return false end
                return true
            end
            B.Outer.InputBegan:Connect(function(Inp)
                if Inp.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then Library.BindSystem:Open(B) return end
                if not VC(Inp) then return end
                if B.Locked then return end
                PR(B.Ripple)
                if B.DoubleClick then
                    Library:RemoveFromRegistry(B.Label); Library:AddToRegistry(B.Label, { TextColor3 = 'AccentColor' })
                    B.Label.TextColor3 = Library.AccentColor; B.Label.Text = 'Are you sure?'; B.Locked = true
                    local clicked = WFE(B.Outer.InputBegan, 0.5, VC)
                    Library:RemoveFromRegistry(B.Label); Library:AddToRegistry(B.Label, { TextColor3 = 'FontColor' })
                    B.Label.TextColor3 = Library.FontColor; B.Label.Text = B.Text
                    task.defer(rawset, B, 'Locked', false)
                    if clicked then PR(B.Ripple) Library:SafeCallback(B.Func) end
                    return
                end
                if B.SaveState then B:SetValue(not B.Value) end
                Library:SafeCallback(B.Func)
            end)
        end
        Button.Outer, Button.Inner, Button.Label, Button.Ripple = CBB(Button)
        Button.Outer.Parent = Container
        function Button:SetValue(b)
            b = not not b; Button.Value = b
            local R = Library.RegistryMap[Button.Inner]
            if R then R.Properties.BackgroundColor3 = b and 'AccentColor' or 'MainColor' end
            Button.Inner.BackgroundColor3 = b and Library.AccentColor or Library.MainColor
            Library:SafeCallback(Button.Callback, b); Library:SafeCallback(Button.Changed, b)
        end
        function Button:OnChanged(f) Button.Changed = f f(Button.Value) end
        IE(Button)
        function Button:AddTooltip(t) if type(t) == 'string' then Library:AddToolTip(t, self.Outer) end return self end
        function Button:AddButton(...)
            local SB = {}; PBP(SB, ...); SB.Type = 'Button'
            self.Outer.Size = UDim2.new(0.5,-2,0,20)
            SB.Outer, SB.Inner, SB.Label, SB.Ripple = CBB(SB)
            SB.Outer.Position = UDim2.new(1,3,0,0)
            SB.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SB.Outer.Parent = self.Outer
            function SB:AddTooltip(t) if type(t) == 'string' then Library:AddToolTip(t, self.Outer) end return SB end
            if type(SB.Tooltip) == 'string' then SB:AddTooltip(SB.Tooltip) end
            IE(SB); return SB
        end
        if type(Button.Tooltip) == 'string' then Button:AddTooltip(Button.Tooltip) end
        Groupbox:AddBlank(5); Groupbox:Resize()
        if Idx then Options[Idx] = Button end
        return Button
    end

    function Funcs:AddDivider()
        local Groupbox = self; local Container = self.Container
        Groupbox:AddBlank(2)
        local DO = Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; Size = UDim2.new(1,-4,0,1); ZIndex = 7; Parent = Container })
        Groupbox:AddBlank(9); Groupbox:Resize()
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')
        local TB = { Value = Info.Default or ''; Numeric = Info.Numeric or false; Finished = Info.Finished or false; Type = 'Input'; Callback = Info.Callback or function() end }
        local Groupbox = self; local Container = Groupbox.Container
        Library:CreateLabel({ Size = UDim2.new(1,0,0,15); TextSize = 14; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; StartImage = Info.StartImage; EndImage = Info.EndImage; StartImageColor = Info.StartImageColor; EndImageColor = Info.EndImageColor; StartImageOffset = Info.StartImageOffset; EndImageOffset = Info.EndImageOffset; ZIndex = 7; Parent = Container })
        Groupbox:AddBlank(1)
        local TBO = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,-4,0,20); ZIndex = 5; Parent = Container })
        local TBI = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 6; ClipsDescendants = true; Parent = TBO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = TBI }), 'Button')
        Library:CreateStroke({ Parent = TBI })
        Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212)) }); Rotation = 90; Parent = TBI })
        Library:AddToRegistry(TBI, { BackgroundColor3 = 'MainColor' })
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, TBO) end
        local Inner = Library:Create('Frame', { BackgroundTransparency = 1; ClipsDescendants = true; Position = UDim2.new(0,5,0,0); Size = UDim2.new(1,-5,1,0); ZIndex = 7; Parent = TBI })
        local Box = Library:Create('TextBox', { BackgroundTransparency = 1; Position = UDim2.fromOffset(0,0); Size = UDim2.new(1,0,1,0); Font = Library.Font; PlaceholderColor3 = Color3.fromRGB(190,190,190); PlaceholderText = Info.Placeholder or ''; Text = Info.Default or ''; TextColor3 = Library.FontColor; TextSize = 14; TextStrokeTransparency = 0; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 7; RichText = true; Parent = Inner })
        Library:ApplyTextStroke(Box)
        function TB:SetValue(t)
            if Info.MaxLength and #t > Info.MaxLength then t = t:sub(1, Info.MaxLength) end
            if TB.Numeric and (not tonumber(t)) and t:len() > 0 then t = TB.Value end
            TB.Value = t; Box.Text = t
            Library:SafeCallback(TB.Callback, TB.Value); Library:SafeCallback(TB.Changed, TB.Value)
        end
        if TB.Finished then Box.FocusLost:Connect(function(en) if not en then return end TB:SetValue(Box.Text) Library:AttemptSave() end)
        else Box:GetPropertyChangedSignal('Text'):Connect(function() TB:SetValue(Box.Text) Library:AttemptSave() end) end
        local function Update()
            local P = 2; local rv = Inner.AbsoluteSize.X
            if not Box:IsFocused() or Box.TextBounds.X <= rv - 2*P then Box.Position = UDim2.new(0, P, 0, 0)
            else
                local c = Box.CursorPosition
                if c ~= -1 then
                    local st = string.sub(Box.Text, 1, c-1)
                    local w = TextService:GetTextSize(st, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X
                    local cp = Box.Position.X.Offset + w
                    if cp < P then Box.Position = UDim2.fromOffset(P-w, 0)
                    elseif cp > rv-P-1 then Box.Position = UDim2.fromOffset(rv-w-P-1, 0) end
                end
            end
        end
        task.spawn(Update)
        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update); Box.Focused:Connect(Update)
        Library:AddToRegistry(Box, { TextColor3 = 'FontColor' })
        function TB:OnChanged(f) TB.Changed = f f(TB.Value) end
        Groupbox:AddBlank(5); Groupbox:Resize()
        Options[Idx] = TB
        return TB
    end

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')
        local Toggle = { Value = Info.Default or false; Type = 'Toggle'; Callback = Info.Callback or function() end; Addons = {}; Risky = Info.Risky }
        local Groupbox = self; local Container = Groupbox.Container
        local TO = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(0,13,0,13); ZIndex = 7; Active = true; Parent = Container })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Toggle); Parent = TO }), 'Toggle')
        Library:CreateStroke({ Parent = TO })
        local TI = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 8; Parent = TO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Toggle); Parent = TI }), 'Toggle')
        Library:AddToRegistry(TI, { BackgroundColor3 = 'MainColor' })
        local TL = Library:CreateLabel({ Size = UDim2.new(0,216,1,0); Position = UDim2.new(1,6,0,0); TextSize = 14; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; StartImage = Info.StartImage; EndImage = Info.EndImage; StartImageColor = Info.StartImageColor; EndImageColor = Info.EndImageColor; StartImageOffset = Info.StartImageOffset; EndImageOffset = Info.EndImageOffset; ZIndex = 9; Parent = TI })
        Library:Create('UIListLayout', { Padding = UDim.new(0,4); FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Enum.HorizontalAlignment.Right; SortOrder = Enum.SortOrder.LayoutOrder; Parent = TL })
        local TR = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(0,170,1,0); ZIndex = 10; Active = true; Parent = TO })
        Library:OnHighlight(TR, TO, { BackgroundColor3 = 'AccentColor' }, { BackgroundColor3 = 'MainColor' })
        function Toggle:UpdateColors() Toggle:Display() end
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, TR) end
        function Toggle:Display(anim)
            if anim then
                TI.AnchorPoint = Vector2.new(0.5, 0.5)
                TI.Position = UDim2.new(0.5, 0, 0.5, 0)
                TI.Size = UDim2.new(0, 2, 0, 2)
                TweenService:Create(TI, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.new(1,0,1,0) }):Play()
            else
                TI.AnchorPoint = Vector2.new(0, 0)
                TI.Position = UDim2.new(0, 0, 0, 0)
                TI.Size = UDim2.new(1, 0, 1, 0)
            end
            TI.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor
            Library.RegistryMap[TI].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor'
        end
        function Toggle:OnChanged(f) Toggle.Changed = f f(Toggle.Value) end
        function Toggle:SetValue(b)
            local old = Toggle.Value
            b = not not b; Toggle.Value = b
            Toggle:Display(old ~= b)
            for _, A in next, Toggle.Addons do if A.Type == 'KeyPicker' and A.SyncToggleState then A.Toggled = b A:Update() end end
            Library:SafeCallback(Toggle.Callback, b); Library:SafeCallback(Toggle.Changed, b); Library:UpdateDependencyBoxes()
        end
        TR.InputBegan:Connect(function(Inp)
            if Inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then Toggle:SetValue(not Toggle.Value) Library:AttemptSave()
            elseif Inp.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then Library.BindSystem:Open(Toggle) end
        end)
        if Toggle.Risky then Library:RemoveFromRegistry(TL) TL.TextColor3 = Library.RiskColor Library:AddToRegistry(TL, { TextColor3 = 'RiskColor' }) end
        Toggle:Display()
        Groupbox:AddBlank(Info.BlankSize or 5+2); Groupbox:Resize()
        Toggle.TextLabel = TL; Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)
        Toggles[Idx] = Toggle
        Library:UpdateDependencyBoxes()
        return Toggle
    end

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default and Info.Text and Info.Min and Info.Max and Info.Rounding, 'AddSlider: missing required fields.')
        local Slider = { Value = Info.Default; Min = Info.Min; Max = Info.Max; Rounding = Info.Rounding; Type = 'Slider'; Text = Info.Text; Callback = Info.Callback or function() end }
        local Groupbox = self; local Container = Groupbox.Container
        if not Info.Compact then
            Library:CreateLabel({ Size = UDim2.new(1,0,0,14); TextSize = 14; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Bottom; StartImage = Info.StartImage; EndImage = Info.EndImage; StartImageColor = Info.StartImageColor; EndImageColor = Info.EndImageColor; StartImageOffset = Info.StartImageOffset; EndImageOffset = Info.EndImageOffset; ZIndex = 7; Parent = Container })
            Groupbox:AddBlank(3)
        end
        local SO = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,-4,0,13); ZIndex = 5; Active = true; ClipsDescendants = true; Parent = Container })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Slider); Parent = SO }), 'Slider')
        Library:CreateStroke({ Parent = SO })
        Library:AddToRegistry(SO, { BackgroundColor3 = 'MainColor' })
        local SI = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 6; Active = true; ClipsDescendants = true; Parent = SO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Slider); Parent = SI }), 'Slider')
        Library:AddToRegistry(SI, { BackgroundColor3 = 'MainColor' })
        local Fill = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; Size = UDim2.new(0,0,1,0); ZIndex = 7; Parent = SI })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Slider); Parent = Fill }), 'Slider')
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor' })
        local DL = Library:CreateLabel({ Size = UDim2.new(1,0,1,0); TextSize = 14; Text = 'Infinite'; ZIndex = 9; Parent = SI })
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, SO) end
        function Slider:UpdateColors() Fill.BackgroundColor3 = Library.AccentColor end
        function Slider:Display()
            local SF = Info.Suffix or ''
            if Info.Compact then DL.Text = Info.Text .. ': ' .. Slider.Value .. SF
            elseif Info.HideMax then DL.Text = string.format('%s', Slider.Value .. SF)
            else DL.Text = string.format('%s/%s', Slider.Value .. SF, Slider.Max .. SF) end
            local W = SI.AbsoluteSize.X
            if W <= 0 then W = 232 end
            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, W))
            Fill.Size = UDim2.new(0, X, 1, 0)
        end
        function Slider:OnChanged(f) Slider.Changed = f f(Slider.Value) end
        local function Rnd(v) if Slider.Rounding == 0 then return math.floor(v) end return tonumber(string.format('%.' .. Slider.Rounding .. 'f', v)) end
        function Slider:GetValueFromXOffset(X)
            local W = SI.AbsoluteSize.X
            if W <= 0 then W = 232 end
            return Rnd(Library:MapValue(X, 0, W, Slider.Min, Slider.Max))
        end
        function Slider:SetValue(s)
            local n = tonumber(s)
            if not n then return end
            n = math.clamp(n, Slider.Min, Slider.Max)
            Slider.Value = n; Slider:Display()
            Library:SafeCallback(Slider.Callback, n); Library:SafeCallback(Slider.Changed, n)
        end
        SI.InputBegan:Connect(function(Inp)
            if Inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local W = SI.AbsoluteSize.X; if W <= 0 then W = 232 end
                local mP = Mouse.X; local gP = Fill.Size.X.Offset
                local D = mP - (Fill.AbsolutePosition.X + gP)
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMP = Mouse.X
                    local nX = math.clamp(gP + (nMP - mP) + D, 0, W)
                    local nV = Slider:GetValueFromXOffset(nX)
                    local old = Slider.Value
                    Slider.Value = nV; Slider:Display()
                    if nV ~= old then Library:SafeCallback(Slider.Callback, nV) Library:SafeCallback(Slider.Changed, nV) end
                    RenderStepped:Wait()
                end
                Library:AttemptSave()
            elseif Inp.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                Library.BindSystem:Open(Slider)
            end
        end)
        Slider:Display()
        Slider.Container = Container
        if SI then SI:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() Slider:Display() end) end
        Groupbox:AddBlank(Info.BlankSize or 6); Groupbox:Resize()
        Options[Idx] = Slider
        return Slider
    end

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then Info.Values = GetPlayersString() Info.AllowNull = true
        elseif Info.SpecialType == 'Team' then Info.Values = GetTeamsString() Info.AllowNull = true end
        assert(Info.Values, 'AddDropdown: Missing dropdown value list.')
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value.')
        if not Info.Text then Info.Compact = true end
        local D = { Values = Info.Values; Value = Info.Multi and {}; Multi = Info.Multi; Type = 'Dropdown'; Text = Info.Text or ''; SpecialType = Info.SpecialType; Callback = Info.Callback or function() end }
        local Groupbox = self; local Container = Groupbox.Container
        if not Info.Compact then
            Library:CreateLabel({ Size = UDim2.new(1,0,0,14); TextSize = 14; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Bottom; StartImage = Info.StartImage; EndImage = Info.EndImage; StartImageColor = Info.StartImageColor; EndImageColor = Info.EndImageColor; StartImageOffset = Info.StartImageOffset; EndImageOffset = Info.EndImageOffset; ZIndex = 7; Parent = Container })
            Groupbox:AddBlank(3)
        end
        local DO = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,-4,0,20); ZIndex = 5; Active = true; Parent = Container })
        local DI = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 6; Parent = DO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Dropdown); Parent = DI }), 'Dropdown')
        Library:CreateStroke({ Parent = DI })
        Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212)) }); Rotation = 90; Parent = DI })
        Library:AddToRegistry(DI, { BackgroundColor3 = 'MainColor' })
        local DA = Library:Create('ImageLabel', { AnchorPoint = Vector2.new(0,0.5); BackgroundTransparency = 1; Position = UDim2.new(1,-16,0.5,0); Size = UDim2.new(0,12,0,12); Image = 'http://www.roblox.com/asset/?id=6282522798'; ZIndex = 8; Parent = DI })
        local IL = Library:CreateLabel({ Position = UDim2.new(0,5,0,0); Size = UDim2.new(1,-5,1,0); TextSize = 14; Text = '--'; TextXAlignment = Enum.TextXAlignment.Left; TextWrapped = true; ZIndex = 7; Parent = DI })
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, DO) end
        local MDI = 8
        local LO = Library:Create('Frame', { BackgroundTransparency = 1; ZIndex = 220; Visible = false; Parent = getScreenGui(DO) })
        local function RLP() LO.Position = UDim2.fromOffset(DO.AbsolutePosition.X, DO.AbsolutePosition.Y + DO.Size.Y.Offset + 1) end
        local function RLS(y) LO.Size = UDim2.fromOffset(DO.AbsoluteSize.X, y or (MDI*20+2)) end
        RLP(); RLS()
        DO:GetPropertyChangedSignal('AbsolutePosition'):Connect(RLP)
        DO:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() RLS(math.clamp(#D.Values*20, 0, MDI*20)+1) end)
        local LI = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 221; Parent = LO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.DropdownList); Parent = LI }), 'DropdownList')
        Library:CreateStroke({ Parent = LI })
        Library:AddToRegistry(LI, { BackgroundColor3 = 'MainColor' })
        local Sc = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; CanvasSize = UDim2.new(0,0,0,0); Size = UDim2.new(1,0,1,0); ZIndex = 221; Parent = LI; TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png'; BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png'; ScrollBarThickness = 3; ScrollBarImageColor3 = Library.AccentColor })
        Library:AddToRegistry(Sc, { ScrollBarImageColor3 = 'AccentColor' })
        Library:Create('UIListLayout', { Padding = UDim.new(0,0); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Sc })
        function D:Display()
            local V = D.Values; local s = ''
            if Info.Multi then
                for _, v in next, V do if D.Value[v] then s = s .. v .. ', ' end end
                s = s:sub(1, #s - 2)
            else s = D.Value or '' end
            IL.Text = (s == '' and '--' or s)
        end
        function D:GetActiveValues()
            if Info.Multi then local t = {} for v, _ in next, D.Value do table.insert(t, v) end return t
            else return D.Value and 1 or 0 end
        end
        function D:BuildDropdownList()
            local V = D.Values; local Buttons = {}
            for _, E in next, Sc:GetChildren() do if not E:IsA('UIListLayout') then E:Destroy() end end
            local C = 0
            for _, Value in next, V do
                local T = {}; C = C + 1
                local B = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,-1,0,20); ZIndex = 223; Active = true; Parent = Sc })
                local BL = Library:CreateLabel({ Active = false; Size = UDim2.new(1,-6,1,0); Position = UDim2.new(0,6,0,0); TextSize = 14; Text = Value; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 225; Parent = B })
                Library:OnHighlight(B, BL, { TextColor3 = 'AccentColor' }, { TextColor3 = 'FontColor' })
                local S
                if Info.Multi then S = D.Value[Value] else S = D.Value == Value end
                function T:UpdateButton()
                    if Info.Multi then S = D.Value[Value] else S = D.Value == Value end
                    BL.TextColor3 = S and Library.AccentColor or Library.FontColor
                    Library.RegistryMap[BL].Properties.TextColor3 = S and 'AccentColor' or 'FontColor'
                end
                BL.InputBegan:Connect(function(Inp)
                    if Inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        local Try = not S
                        if D:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then S = Try if S then D.Value[Value] = true else D.Value[Value] = nil end
                            else
                                S = Try
                                if S then D.Value = Value else D.Value = nil end
                                for _, OB in next, Buttons do OB:UpdateButton() end
                            end
                            T:UpdateButton(); D:Display()
                            Library:SafeCallback(D.Callback, D.Value); Library:SafeCallback(D.Changed, D.Value); Library:AttemptSave()
                        end
                    end
                end)
                T:UpdateButton(); D:Display(); Buttons[B] = T
            end
            Sc.CanvasSize = UDim2.fromOffset(0, (C*20)+1)
            RLS(math.clamp(C*20, 0, MDI*20)+1)
        end
        function D:SetValues(NV) if NV then D.Values = NV end D:BuildDropdownList() end
        function D:OpenDropdown() LO.Visible = true Library.OpenedFrames[LO] = true DA.Rotation = 180 RLS(math.clamp(#D.Values*20, 0, MDI*20)+1) end
        function D:CloseDropdown() LO.Visible = false Library.OpenedFrames[LO] = nil DA.Rotation = 0 end
        function D:OnChanged(f) D.Changed = f f(D.Value) end
        function D:SetValue(V)
            if D.Multi then
                local nt = {}
                for v, _ in next, V do if table.find(D.Values, v) then nt[v] = true end end
                D.Value = nt
            else
                if not V then D.Value = nil
                elseif table.find(D.Values, V) then D.Value = V end
            end
            D:BuildDropdownList()
            Library:SafeCallback(D.Callback, D.Value); Library:SafeCallback(D.Changed, D.Value)
        end
        DO.InputBegan:Connect(function(Inp)
            if Inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if LO.Visible then D:CloseDropdown() else D:OpenDropdown() end
            elseif Inp.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then Library.BindSystem:Open(D) end
        end)
        InputService.InputBegan:Connect(function(Inp)
            if Inp.UserInputType == Enum.UserInputType.MouseButton1 then
                local ap, as = LO.AbsolutePosition, LO.AbsoluteSize
                if Mouse.X < ap.X or Mouse.X > ap.X+as.X or Mouse.Y < (ap.Y-21) or Mouse.Y > ap.Y+as.Y then D:CloseDropdown() end
            end
        end)
        D.Container = Container
        D:BuildDropdownList(); D:Display()
        local Def = {}
        if type(Info.Default) == 'string' then local i = table.find(D.Values, Info.Default) if i then table.insert(Def, i) end
        elseif type(Info.Default) == 'table' then for _, v in next, Info.Default do local i = table.find(D.Values, v) if i then table.insert(Def, i) end end
        elseif type(Info.Default) == 'number' and D.Values[Info.Default] ~= nil then table.insert(Def, Info.Default) end
        if next(Def) then
            for i = 1, #Def do
                local ix = Def[i]
                if Info.Multi then D.Value[D.Values[ix]] = true else D.Value = D.Values[ix] end
                if not Info.Multi then break end
            end
            D:BuildDropdownList(); D:Display()
        end
        Groupbox:AddBlank(Info.BlankSize or 5); Groupbox:Resize()
        Options[Idx] = D
        return D
    end

    function Funcs:AddDependencyBox()
        local Dep = { Dependencies = {} }
        local Groupbox = self; local Container = Groupbox.Container
        local Holder = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,0,0,0); Visible = false; Parent = Container })
        local Frame = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,0,1,0); Visible = true; Parent = Holder })
        local Layout = Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Frame })
        function Dep:Resize() Holder.Size = UDim2.new(1,0,0, Layout.AbsoluteContentSize.Y) Groupbox:Resize() end
        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Dep:Resize() end)
        Holder:GetPropertyChangedSignal('Visible'):Connect(function() Dep:Resize() end)
        function Dep:Update()
            for _, Dp in next, Dep.Dependencies do
                local E, V = Dp[1], Dp[2]
                if E.Type == 'Toggle' and E.Value ~= V then Holder.Visible = false Dep:Resize() return end
            end
            Holder.Visible = true; Dep:Resize()
        end
        function Dep:SetupDependencies(D)
            for _, d in next, D do assert(type(d) == 'table' and d[1] and d[2] ~= nil, 'SetupDependencies: bad format.') end
            Dep.Dependencies = D; Dep:Update()
        end
        Dep.Container = Frame
        setmetatable(Dep, BaseGroupbox)
        table.insert(Library.DependencyBoxes, Dep)
        return Dep
    end

    function Funcs:AddKeybind(Idx, Info)
        assert(Info.Text, 'AddKeybind: Missing `Text` string.')
        local K = { Value = Info.Default or 'None'; Type = 'Keybind'; Text = Info.Text; ChangedCallback = Info.ChangedCallback or function() end; Callback = Info.Callback or function() end }
        local Groupbox = self; local Container = Groupbox.Container
        Library:CreateLabel({ Size = UDim2.new(1,0,0,14); TextSize = 14; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Bottom; StartImage = Info.StartImage; EndImage = Info.EndImage; StartImageColor = Info.StartImageColor; EndImageColor = Info.EndImageColor; StartImageOffset = Info.StartImageOffset; EndImageOffset = Info.EndImageOffset; ZIndex = 7; Parent = Container })
        Groupbox:AddBlank(3)
        local BO = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,-4,0,20); ZIndex = 5; Active = true; Parent = Container })
        local BI = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 6; Active = true; ClipsDescendants = true; Parent = BO })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Keybind); Parent = BI }), 'Keybind')
        Library:CreateStroke({ Parent = BI })
        Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212,212,212)) }); Rotation = 90; Parent = BI })
        Library:AddToRegistry(BI, { BackgroundColor3 = 'MainColor' })
        local L = Library:CreateLabel({ Position = UDim2.new(0,6,0,0); Size = UDim2.new(1,-12,1,0); TextSize = 14; Text = K.Value; TextXAlignment = Enum.TextXAlignment.Left; TextTruncate = Enum.TextTruncate.AtEnd; ZIndex = 8; Parent = BI })
        function K:SetValue(key) K.Value = key L.Text = key Library:SafeCallback(K.Callback, key) Library:SafeCallback(K.ChangedCallback, key) end
        function K:OnChanged(f) K.ChangedCallback = f f(K.Value) end
        function K:OnClick(f) K.Callback = f end
        local picking = false
        BI.InputBegan:Connect(function(Inp)
            if Inp.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then Library.BindSystem:Open(K) return end
            if Inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if picking then return end
            picking = true; L.Text = '...'
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do RenderStepped:Wait() end
            local done = false; local cn
            cn = InputService.InputBegan:Connect(function(i)
                if done then return end
                local key
                if i.UserInputType == Enum.UserInputType.Keyboard then
                    if i.KeyCode == Enum.KeyCode.Escape then key = 'None' else key = i.KeyCode.Name end
                elseif i.UserInputType == Enum.UserInputType.MouseButton1 then key = 'MB1'
                elseif i.UserInputType == Enum.UserInputType.MouseButton2 then key = 'MB2'
                elseif i.UserInputType == Enum.UserInputType.MouseButton3 then key = 'MB3' end
                if key then done = true cn:Disconnect() picking = false K:SetValue(key) end
            end)
        end)
        K.Container = Container
        Groupbox:AddBlank(5); Groupbox:Resize()
        Options[Idx] = K
        return K
    end

    BaseGroupbox.__index = Funcs
    BaseGroupbox.__namecall = function(t, k, ...) return Funcs[k](...) end

    function Library:CreateMiniGroupbox(parent, title)
        local Outer = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; Size = UDim2.new(1,0,0,0); ZIndex = 210; Parent = parent })
        Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Groupbox); Parent = Outer }), 'Groupbox')
        Library:CreateStroke({ Parent = Outer })
        local Inner = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,0,1,0); Position = UDim2.fromOffset(0,0); ZIndex = 211; Parent = Outer })
        if title then Library:CreateLabel({ Size = UDim2.new(1,0,0,18); Position = UDim2.fromOffset(4,2); TextSize = 14; Text = title; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 213; Parent = Inner }) end
        local Container = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0,4,0, title and 20 or 4); Size = UDim2.new(1,-4,1, title and -20 or -4); ZIndex = 211; Parent = Inner })
        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Container })
        local GB = { Container = Container; Outer = Outer }
        setmetatable(GB, BaseGroupbox)
        function GB:Resize()
            local S = 0
            for _, E in next, Container:GetChildren() do if not E:IsA('UIListLayout') and E.Visible then S = S + E.Size.Y.Offset end end
            Outer.Size = UDim2.new(1,0,0, (title and 20 or 4) + S + 4)
        end
        GB:AddBlank(3); GB:Resize()
        return GB
    end
end

Library.BindSystem = Library.BindSystem or {}
local BindSystem = Library.BindSystem
BindSystem.Windows = {}; BindSystem.AllBindings = {}; BindSystem._idxCounter = 0
local function NBI() BindSystem._idxCounter = BindSystem._idxCounter + 1 return 'Bind_' .. BindSystem._idxCounter end
local function GBIN(Inp)
    if Inp.UserInputType == Enum.UserInputType.Keyboard then return Inp.KeyCode.Name
    elseif Inp.UserInputType == Enum.UserInputType.MouseButton1 then return 'MB1'
    elseif Inp.UserInputType == Enum.UserInputType.MouseButton2 then return 'MB2'
    elseif Inp.UserInputType == Enum.UserInputType.MouseButton3 then return 'MB3' end
end
BindSystem.GetKeyName = GBIN
function BindSystem:IsKeyDown(n)
    if n == 'MB1' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    if n == 'MB2' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    if n == 'MB3' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3) end
    local k = Enum.KeyCode[n] return k and InputService:IsKeyDown(k) or false
end
function BindSystem:GetDefaultValue(c)
    if c.Type == 'Toggle' then return not c.Value end
    if c.Type == 'Dropdown' then if c.Values and #c.Values > 0 then return c.Values[1] end return nil end
    if c.Type == 'Slider' then return c.Value end
    return nil
end
function BindSystem:ApplyTrigger(b, p)
    local c = b.Control; if not c then return end
    local v = b.Value; local m = b.Mode
    if c.Type == 'Button' then if p then Library:SafeCallback(c.Func) end return end
    if c.Type == 'Keybind' then if p then Library:SafeCallback(c.Callback, true) end return end
    if c.Type == 'Toggle' then
        if m == 'Hold' then
            if p then b._prevValue = c.Value c:SetValue(v)
            else if b._prevValue ~= nil then c:SetValue(b._prevValue) b._prevValue = nil end end
        elseif m == 'Always' then if p then c:SetValue(v) end
        else
            if p then
                if c.Value == v then
                    if b._prevValue ~= nil then c:SetValue(b._prevValue) b._prevValue = nil
                    else c:SetValue(not v) end
                else b._prevValue = c.Value c:SetValue(v) end
            end
        end
    elseif c.Type == 'Slider' then
        if m == 'Hold' then
            if p then b._prevValue = c.Value c:SetValue(v)
            else if b._prevValue ~= nil then c:SetValue(b._prevValue) b._prevValue = nil end end
        else if p then c:SetValue(v) end end
    elseif c.Type == 'Dropdown' then
        if m == 'Hold' then
            if p then b._prevValue = c.Value c:SetValue(v)
            else if b._prevValue ~= nil then c:SetValue(b._prevValue) b._prevValue = nil end end
        elseif m == 'Toggle' then
            if p then
                if c.Value == v then if b._prevValue ~= nil then c:SetValue(b._prevValue) b._prevValue = nil else c:SetValue(nil) end
                else b._prevValue = c.Value c:SetValue(v) end
            end
        else if p then c:SetValue(v) end end
    end
    Library:AttemptSave()
end
function BindSystem:HandleInput(Inp, p)
    local n = GBIN(Inp); if not n then return end
    for _, b in ipairs(self.AllBindings) do
        if b.Key == n then
            if p then if not b._down then b._down = true self:ApplyTrigger(b, true) end
            else if b._down then b._down = false if b.Mode == 'Hold' then self:ApplyTrigger(b, false) end end end
        end
    end
end
function BindSystem:CloseWindow(c) local w = self.Windows[c] if w then if w.Parent then w:Destroy() end self.Windows[c] = nil end end
function BindSystem:CloseAllWindows() local k = {} for kk in pairs(self.Windows) do table.insert(k, kk) end for _, v in ipairs(k) do self:CloseWindow(v) end end
function BindSystem:BuildBindCard(Sc, AB, c, eb)
    local b = eb or { Control = c, Key = 'None', Mode = 'Toggle', Value = self:GetDefaultValue(c) }
    if not eb then table.insert(self.AllBindings, b) end
    local mo = 0
    for _, ch in ipairs(Sc:GetChildren()) do
        if ch:IsA('GuiObject') and ch ~= AB then local lo = ch.LayoutOrder or 0 if lo > mo and lo < (AB.LayoutOrder or 999999) then mo = lo end end
    end
    local bc = 0
    for _, bb in ipairs(self.AllBindings) do if bb.Control == c then bc = bc + 1 end end
    local gb = Library:CreateMiniGroupbox(Sc, 'Bind #' .. tostring(bc))
    gb.Outer.LayoutOrder = mo + 1
    gb:AddKeybind(NBI(), { Text = 'Key'; Default = b.Key; ChangedCallback = function(k) b.Key = k end })
    gb:AddDropdown(NBI(), { Text = 'Mode'; Values = { 'Toggle', 'Hold' }; Default = b.Mode; Callback = function(v) if v then b.Mode = v end end })
    if c.Type == 'Toggle' then gb:AddToggle(NBI(), { Text = 'Value'; Default = (type(b.Value) == 'boolean') and b.Value or true; Callback = function(v) b.Value = v end })
    elseif c.Type == 'Slider' then gb:AddSlider(NBI(), { Text = 'Value'; Min = c.Min; Max = c.Max; Rounding = c.Rounding; Default = (type(b.Value) == 'number') and b.Value or c.Value; Suffix = ''; Callback = function(v) b.Value = v end })
    elseif c.Type == 'Dropdown' then gb:AddDropdown(NBI(), { Text = 'Value'; Values = c.Values; AllowNull = true; Default = b.Value; Callback = function(v) b.Value = v end })
    elseif c.Type == 'Button' then gb:AddLabel('Triggers button callback', true) end
    gb:AddButton('Remove bind', function()
        for i, bb in ipairs(self.AllBindings) do if bb == b then table.remove(self.AllBindings, i) break end end
        gb.Outer:Destroy()
        Sc.CanvasSize = UDim2.fromOffset(0, Sc.UIListLayout.AbsoluteContentSize.Y + 4)
    end)
    return b
end
function BindSystem:Open(c)
    local ar = c.TextLabel or c.Container or c.Outer or c.DisplayFrame
    if ar and getScreenGui(ar) == BindGui then return end
    if self.Windows[c] then self:CloseWindow(c) return end
    self:CloseAllWindows()
    local wW, wH = 260, 260
    local vX = workspace.CurrentCamera.ViewportSize.X
    local vY = workspace.CurrentCamera.ViewportSize.Y
    local pX = math.clamp(Mouse.X + 5, 0, math.max(0, vX - wW))
    local pY = math.clamp(Mouse.Y + 5, 0, math.max(0, vY - wH))
    local O = Library:Create('Frame', { Name = 'BindWindow'; BackgroundColor3 = Library.BackgroundColor; BorderSizePixel = 0; Position = UDim2.fromOffset(pX, pY); Size = UDim2.fromOffset(wW, wH); ZIndex = 200; Parent = BindGui })
    Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Groupbox); Parent = O }), 'Groupbox')
    Library:CreateStroke({ Parent = O })
    local Sc = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; Position = UDim2.fromOffset(4,4); Size = UDim2.new(1,-8,1,-8); CanvasSize = UDim2.new(0,0,0,0); ScrollBarThickness = 3; ScrollBarImageColor3 = Library.AccentColor; TopImage = ''; BottomImage = ''; ZIndex = 202; Parent = O })
    Library:AddToRegistry(Sc, { ScrollBarImageColor3 = 'AccentColor' })
    local L = Library:Create('UIListLayout', { Padding = UDim.new(0,6); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Sc })
    L.Name = 'UIListLayout'
    Library:Create('UIPadding', { PaddingLeft = UDim.new(0,2); PaddingRight = UDim.new(0,2); PaddingTop = UDim.new(0,2); Parent = Sc })
    L:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Sc.CanvasSize = UDim2.fromOffset(0, L.AbsoluteContentSize.Y + 4) end)
    local AB = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,-4,0,20); LayoutOrder = 999999; ZIndex = 203; Active = true; Parent = Sc })
    local AI = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 204; Parent = AB })
    Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = AI }), 'Button')
    Library:CreateStroke({ Parent = AI })
    Library:AddToRegistry(AI, { BackgroundColor3 = 'MainColor' })
    Library:CreateLabel({ Size = UDim2.new(1,0,1,0); Text = '+ Add keybind'; TextSize = 13; ZIndex = 205; Parent = AI })
    Library:OnHighlight(AI, AI, { BackgroundColor3 = 'AccentColor' }, { BackgroundColor3 = 'MainColor' })
    AI.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then self:BuildBindCard(Sc, AB, c) end end)
    Library:MakeDraggable(O, 20)
    for _, b in ipairs(self.AllBindings) do if b.Control == c then self:BuildBindCard(Sc, AB, c, b) end end
    self.Windows[c] = O
end
Library:GiveSignal(InputService.InputBegan:Connect(function(Inp, gp) if gp then return end BindSystem:HandleInput(Inp, true) end))
Library:GiveSignal(InputService.InputEnded:Connect(function(Inp) BindSystem:HandleInput(Inp, false) end))
Library:GiveSignal(InputService.InputBegan:Connect(function(Inp)
    if Inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local k = {} for kk in pairs(BindSystem.Windows) do table.insert(k, kk) end
    for _, c in ipairs(k) do
        local w = BindSystem.Windows[c]
        if w and w.Parent then
            local ap, as = w.AbsolutePosition, w.AbsoluteSize
            if Mouse.X < ap.X or Mouse.X > ap.X+as.X or Mouse.Y < ap.Y or Mouse.Y > ap.Y+as.Y then BindSystem:CloseWindow(c) end
        end
    end
end))

local NC = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0.5,0,1,0); Size = UDim2.new(0,0,0,0); AnchorPoint = Vector2.new(0.5,1); ZIndex = 100; Parent = OverlayGui })
local activeNotifications = {}
local function PNS()
    local s = Instance.new('Sound'); s.SoundId = 'rbxassetid://' .. Library.NotifySoundId; s.Volume = 0.5; s.Parent = OverlayGui
    if s.IsLoaded then s:Play() else s.Loaded:Connect(function() s:Play() end) end
    s.Ended:Connect(function() s:Destroy() end)
end
function Library:Notify(Text, Time)
    Time = Time or 5; PNS()
    local XS = Library:GetTextBounds(Text, Library.Font, 14) + 24
    local YS = 32; local p = 8; local tH = 0
    for _, n in ipairs(activeNotifications) do if n.Outer and n.Outer.Parent then tH = tH + n.Outer.AbsoluteSize.Y + p end end
    local tY = -tH - YS - p
    local O = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(0,XS,0,YS); Position = UDim2.new(0.5,-XS/2,1,0); ZIndex = 100; Parent = NC })
    table.insert(activeNotifications, { Outer = O, Time = Time })
    TweenService:Create(O, TweenInfo.new(NOTIFY_ANIMATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, -XS/2, 1, tY) }):Play()
    local I = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 101; Parent = O })
    Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = I }), 'Button')
    Library:CreateStroke({ Parent = I })
    Library:AddToRegistry(I, { BackgroundColor3 = 'MainColor' }, true)
    local IF = Library:Create('Frame', { BackgroundColor3 = Color3.new(1,1,1); BorderSizePixel = 0; Position = UDim2.new(0,1,0,1); Size = UDim2.new(1,-2,1,-2); ZIndex = 102; ClipsDescendants = true; Parent = I })
    Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, math.max(Library.UICorner.Button - 1, 0)); Parent = IF }), 'Button')
    Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)), ColorSequenceKeypoint.new(1, Library.MainColor) }); Rotation = -90; Parent = IF })
    Library:CreateLabel({ Position = UDim2.new(0,8,0,0); Size = UDim2.new(1,-16,1,0); Text = Text; TextXAlignment = Enum.TextXAlignment.Center; TextSize = 14; ZIndex = 103; Parent = IF })
    local LB = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0.5,0,0,2); Position = UDim2.new(0.5,0,1,-2); AnchorPoint = Vector2.new(1,0); ZIndex = 104; Parent = O })
    local RB = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0.5,0,0,2); Position = UDim2.new(0.5,0,1,-2); AnchorPoint = Vector2.new(0,0); ZIndex = 104; Parent = O })
    TweenService:Create(LB, TweenInfo.new(Time, Enum.EasingStyle.Linear), { Size = UDim2.new(0,0,0,2) }):Play()
    TweenService:Create(RB, TweenInfo.new(Time, Enum.EasingStyle.Linear), { Size = UDim2.new(0,0,0,2) }):Play()
    task.delay(Time, function()
        local tO = TweenService:Create(O, TweenInfo.new(NOTIFY_ANIMATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, -XS/2, 1, 0) })
        tO:Play()
        tO.Completed:Connect(function()
            O:Destroy()
            for i, n in ipairs(activeNotifications) do if n.Outer == O then table.remove(activeNotifications, i) break end end
            local cy = 0
            for _, n in ipairs(activeNotifications) do
                n.Outer:TweenPosition(UDim2.new(0.5, -n.Outer.AbsoluteSize.X/2, 1, -cy - n.Outer.AbsoluteSize.Y - p), 'Out', 'Quad', NOTIFY_ANIMATION_SPEED)
                cy = cy + n.Outer.AbsoluteSize.Y + p
            end
        end)
    end)
end
local cuc = nil
local function UC() pcall(function() local m = LocalPlayer:GetMouse() if m then m.Icon = 'rbxassetid://' .. Library.CursorImageId end end) end
task.spawn(function()
    if cuc then cuc:Disconnect() cuc = nil end
    UC()
    cuc = RunService.Heartbeat:Connect(UC)
    LocalPlayer.CharacterAdded:Connect(UC)
end)
function Library:SetNotifySoundId(id) Library.NotifySoundId = id end
getgenv().SetNotifySoundId = Library.SetNotifySoundId
function Library:SetCursorImageId(id) Library.CursorImageId = id UC() end
getgenv().SetCursorImageId = Library.SetCursorImageId

local WO = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0,100,0,-25); Size = UDim2.new(0,213,0,20); ZIndex = 200; Visible = false; Parent = OverlayGui })
local WI = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 201; Parent = WO })
Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Button); Parent = WI }), 'Button')
Library:Create('UIStroke', { Color = Library.AccentColor; Thickness = 1; ApplyStrokeMode = Enum.ApplyStrokeMode.Border; Parent = WI })
Library:AddToRegistry(WI, { BorderColor3 = 'AccentColor' })
local IF = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0,0,0,0); Size = UDim2.new(1,0,1,0); ZIndex = 202; Parent = WI })
local WL = Library:CreateLabel({ Position = UDim2.new(0,5,0,0); Size = UDim2.new(1,-4,1,0); TextSize = 14; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 203; Parent = IF })
Library.Watermark = WO
Library.WatermarkText = WL
Library:MakeDraggable(Library.Watermark)

local KO = Library:Create('Frame', { BackgroundTransparency = 1; AnchorPoint = Vector2.new(0,0.5); Position = UDim2.new(0,10,0.5,0); Size = UDim2.new(0,210,0,44); Visible = false; ZIndex = 100; Parent = OverlayGui })
local KI = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1,0,1,0); ZIndex = 101; Parent = KO })
Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Groupbox); Parent = KI }), 'Groupbox')
Library:CreateStroke({ Parent = KI })
Library:AddToRegistry(KI, { BackgroundColor3 = 'MainColor' }, true)
local CF = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1,0,0,2); ZIndex = 102; Parent = KI })
Library:AddToRegistry(CF, { BackgroundColor3 = 'AccentColor' }, true)
Library:CreateLabel({ Size = UDim2.new(1,0,0,18); Position = UDim2.fromOffset(5,4); TextXAlignment = Enum.TextXAlignment.Left; Text = 'Keybinds'; ZIndex = 103; Parent = KI })
local KC = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1,0,1,-22); Position = UDim2.new(0,0,0,22); ZIndex = 105; Parent = KI })
Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = KC })
Library:Create('UIPadding', { PaddingLeft = UDim.new(0,5); Parent = KC })
Library.KeybindFrame = KO
Library.KeybindContainer = KC
Library:MakeDraggable(KO)

function Library:SetWatermarkVisibility(b) Library.Watermark.Visible = b end
function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14)
    Library.Watermark.Size = UDim2.new(0, X+15, 0, (Y*1.5)+3)
    Library:SetWatermarkVisibility(true)
    Library.WatermarkText.Text = Text
end

function Clear3DObjects()
    if Current3DPart then Current3DPart:Destroy() end
    if Current3DSurface then Current3DSurface:Destroy() end
    Current3DPart, Current3DSurface = nil, nil
    if Library.MainFrame and Library.MainFrame.Parent then
        pcall(function() if Library.MainFrame.Parent ~= ScreenGui then Library.MainFrame.Parent = ScreenGui end end)
    end
end
function Create3DObjects()
    Clear3DObjects()
    local C = workspace.CurrentCamera; if not C then return end
    local wS = Library.MainFrame and Library.MainFrame.Size or UDim2.fromOffset(550,600)
    local pX = math.max(wS.X.Offset/PPU, 0.1); local pY = math.max(wS.Y.Offset/PPU, 0.1)
    local P = Instance.new('Part'); P.Name = 'Linoria3DPart'; P.Size = Vector3.new(pX, pY, 0.1); P.Transparency = 1; P.CanCollide = false; P.Anchored = true; P.CFrame = C.CFrame * CFrame.new(0,0,-THREED_DISTANCE); P.Parent = workspace; Current3DPart = P
    local S = Instance.new('SurfaceGui'); S.Name = 'Linoria3DSurface'; S.Face = Enum.NormalId.Front; S.PixelsPerStud = PPU; S.CanvasSize = Vector2.new(wS.X.Offset, wS.Y.Offset); S.AlwaysOnTop = true; S.Parent = P; Current3DSurface = S
    if Library.MainFrame and Library.MainFrame.Parent then pcall(function() if Library.MainFrame.Parent ~= S then Library.MainFrame.Parent = S end end) end
end

function Library:CreateWindow(...)
    local Args = { ... }; local Config = { AnchorPoint = Vector2.zero }
    if type(...) == 'table' then Config = ... else Config.Title = Args[1] Config.AutoShow = Args[2] or false end
    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end
    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175,50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550,600) end
    if Config.BackgroundImage == nil then Config.BackgroundImage = '' end
    if type(Config.BackgroundImageTransparency) ~= 'number' then Config.BackgroundImageTransparency = 0.5 end
    if typeof(Config.BackgroundImageColor) ~= 'Color3' then Config.BackgroundImageColor = Color3.new(1,1,1) end
    if Config.Resizable == nil then Config.Resizable = false end
    if typeof(Config.MinSize) ~= 'UDim2' then Config.MinSize = UDim2.fromOffset(300,200) end
    if Config.CenterTitle == nil then Config.CenterTitle = false end
    if type(Config.TitleOffset) ~= 'number' then Config.TitleOffset = 0 end
    if Config.CenterTabs == nil then Config.CenterTabs = false end
    if type(Config.TabsOffset) ~= 'number' then Config.TabsOffset = 0 end
    if Config.Center then Config.AnchorPoint = Vector2.new(0.5,0.5) Config.Position = UDim2.fromScale(0.5,0.5) end

    local W = { Tabs = {} }
    local Outer = Library:Create('Frame', { AnchorPoint = Config.AnchorPoint; BackgroundTransparency = 1; BorderSizePixel = 0; Position = Config.Position; Size = Config.Size; Visible = false; ZIndex = 1; Parent = ScreenGui })
    Library.MainFrame = Outer
    local OuterCorner = Library:Create('UICorner', { CornerRadius = UDim.new(0, math.max(Library.UICorner.Groupbox, Library.UICornerRadius * 10)); Parent = Outer })
    Library:RegisterWindowCorner(OuterCorner)
    Library:MakeDraggable(Outer, 25)
    local Inner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Position = UDim2.new(0,0,0,0); Size = UDim2.new(1,0,1,0); ZIndex = 1; ClipsDescendants = true; Parent = Outer })
    local InnerCorner = Library:Create('UICorner', { CornerRadius = UDim.new(0, math.max(Library.UICorner.Groupbox, Library.UICornerRadius * 10)); Parent = Inner })
    Library:RegisterWindowCorner(InnerCorner)
    Library:CreateStroke({ Color = Library.AccentColor; Parent = Inner })
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor' })

    local tH = 25; local tS = Config.TitleTextSize or 16
    local WL = Library:CreateLabel({ Position = UDim2.new(0, 7 + Config.TitleOffset, 0, 0); Size = UDim2.new(1, -14, 0, tH); TextSize = tS; Text = Config.Title or ''; TextXAlignment = Config.CenterTitle and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left; ZIndex = 2; Parent = Inner })

    local MSO = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0,8,0,25); Size = UDim2.new(1,-16,1,-33); ZIndex = 1; Parent = Inner })
    local MSI = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0,0,0,0); Size = UDim2.new(1,0,1,0); ZIndex = 1; ClipsDescendants = true; Parent = MSO })
    local MSICorner = Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Groupbox); Parent = MSI })
    Library:RegisterWindowCorner(MSICorner)

    local BI = Library:Create('ImageLabel', { Name = 'BackgroundImage'; BackgroundTransparency = 1; BorderSizePixel = 0; Size = UDim2.new(1,0,1,0); Position = UDim2.fromOffset(0,0); Image = Config.BackgroundImage or ''; ImageTransparency = Config.BackgroundImageTransparency or 0.5; ImageColor3 = Config.BackgroundImageColor; ScaleType = Enum.ScaleType.Crop; ZIndex = 1; Visible = (Config.BackgroundImage and Config.BackgroundImage ~= '') or false; Parent = MSI })
    local BICorner = Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Groupbox); Parent = BI })
    Library:RegisterWindowCorner(BICorner)
    W.BackgroundImage = BI
    local BgO = Library:Create('Frame', { Name = 'BackgroundOverlay'; BackgroundColor3 = Color3.new(0,0,0); BackgroundTransparency = 1; BorderSizePixel = 0; Size = UDim2.new(1,0,1,0); ZIndex = 2; Parent = BI })
    local BgOCorner = Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Groupbox); Parent = BgO })
    Library:RegisterWindowCorner(BgOCorner)
    W.BackgroundOverlay = BgO

    local TA = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 8 + Config.TabsOffset, 0, 8); Size = UDim2.new(1,-16,0,21); ZIndex = 100; Parent = MSI })
    local TLL = Library:Create('UIListLayout', { Padding = UDim.new(0, Config.TabPadding); FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Config.CenterTabs and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left; SortOrder = Enum.SortOrder.LayoutOrder; Parent = TA })
    local TC = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0,8,0,30); Size = UDim2.new(1,-16,1,-38); ZIndex = 2; ClipsDescendants = true; Parent = MSI })

    function W:SetWindowTitle(t) WL.Text = t end
    function W:SetWindowOpacity(t)
        t = math.clamp(t or 0, 0, 1)
        Inner.BackgroundTransparency = t
    end
    function W:SetBackgroundImage(id, tr)
        local b = W.BackgroundImage; if not b then return end
        id = id or ''
        if id == '' then b.Visible = false b.Image = ''
        else b.Image = id b.Visible = true if type(tr) == 'number' then b.ImageTransparency = math.clamp(tr, 0, 1) end end
    end
    function W:SetBackgroundTransparency(t) if W.BackgroundImage then W.BackgroundImage.ImageTransparency = math.clamp(t or 0, 0, 1) end end
    function W:SetBackgroundScaleType(s) if W.BackgroundImage then W.BackgroundImage.ScaleType = s or Enum.ScaleType.Crop end end
    function W:SetBackgroundColor(c) if W.BackgroundImage then W.BackgroundImage.ImageColor3 = c or Color3.new(1,1,1) end end
    function W:SetOverlayTransparency(t) if W.BackgroundOverlay then W.BackgroundOverlay.BackgroundTransparency = math.clamp(t or 1, 0, 1) end end

    function W:AddTab(Name)
        if W.Tabs[Name] then return W.Tabs[Name] end
        local Tb = { Groupboxes = {}; Tabboxes = {} }
        local TBW = Library:GetTextBounds(Name, Library.Font, 16)
        local TB = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(0, TBW + 8 + 4, 1, 0); ZIndex = 150; Active = true; Parent = TA })
        Library:CreateLabel({ Position = UDim2.new(0,0,0,0); Size = UDim2.new(1,0,1,-1); Text = Name; ZIndex = 151; Parent = TB })
        local Blk = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Position = UDim2.new(0,0,1,0); Size = UDim2.new(1,0,0,1); BackgroundTransparency = 1; ZIndex = 152; Parent = TB })
        Library:AddToRegistry(Blk, { BackgroundColor3 = 'AccentColor' })
        local TF = Library:Create('Frame', { Name = 'TabFrame'; BackgroundTransparency = 1; Position = UDim2.new(0,0,0,0); Size = UDim2.new(1,0,1,0); Visible = false; ZIndex = 2; Parent = TC })
        local LS = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; Position = UDim2.new(0,7,0,7); Size = UDim2.new(0.5,-10,1,-16); CanvasSize = UDim2.new(0,0,0,0); BottomImage = ''; TopImage = ''; ScrollBarThickness = 0; ZIndex = 5; Parent = TF })
        local RS = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; Position = UDim2.new(0.5,5,0,7); Size = UDim2.new(0.5,-10,1,-16); CanvasSize = UDim2.new(0,0,0,0); BottomImage = ''; TopImage = ''; ScrollBarThickness = 0; ZIndex = 5; Parent = TF })
        Library:Create('UIListLayout', { Padding = UDim.new(0,8); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; HorizontalAlignment = Enum.HorizontalAlignment.Center; Parent = LS })
        Library:Create('UIListLayout', { Padding = UDim.new(0,8); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; HorizontalAlignment = Enum.HorizontalAlignment.Center; Parent = RS })
        for _, S in next, { LS, RS } do S:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() S.CanvasSize = UDim2.fromOffset(0, S.UIListLayout.AbsoluteContentSize.Y) end) end
        function Tb:ShowTab()
            for _, t in next, W.Tabs do t:HideTab() end
            Blk.BackgroundTransparency = 0
            TB.BackgroundColor3 = Library.BackgroundColor
            TB.BackgroundTransparency = 0
            TF.Visible = true
        end
        function Tb:HideTab()
            Blk.BackgroundTransparency = 1
            TB.BackgroundColor3 = Library.BackgroundColor
            TB.BackgroundTransparency = 1
            TF.Visible = false
        end
        function Tb:SetLayoutOrder(p) TB.LayoutOrder = p TLL:ApplyLayout() end
        function Tb:AddGroupbox(Info)
            local GB = {}
            local BO = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BackgroundTransparency = 0.15; Size = UDim2.new(1,0,0,507+2); ZIndex = 6; Parent = Info.Side == 1 and LS or RS })
            Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Groupbox); Parent = BO }), 'Groupbox')
            Library:CreateStroke({ Parent = BO })
            Library:AddToRegistry(BO, { BackgroundColor3 = 'BackgroundColor' })
            local C = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0,4,0,2); Size = UDim2.new(1,-8,1,-4); ZIndex = 10; Parent = BO })
            Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = C })
            function GB:Resize()
                local s = 0
                for _, e in next, GB.Container:GetChildren() do if not e:IsA('UIListLayout') and e.Visible then s = s + e.Size.Y.Offset end end
                BO.Size = UDim2.new(1,0,0, 4 + s + 4)
            end
            GB.Container = C
            setmetatable(GB, BaseGroupbox)
            GB:AddBlank(3); GB:Resize()
            Tb.Groupboxes[Info.Name] = GB
            return GB
        end
        function Tb:AddLeftGroupbox(n) return Tb:AddGroupbox({ Side = 1; Name = n }) end
        function Tb:AddRightGroupbox(n) return Tb:AddGroupbox({ Side = 2; Name = n }) end
        function Tb:AddTabbox(Info)
            local Tbox = { Tabs = {} }
            local BO = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BackgroundTransparency = 0.15; Size = UDim2.new(1,0,0,0); ZIndex = 6; Parent = Info.Side == 1 and LS or RS })
            Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICorner.Groupbox); Parent = BO }), 'Groupbox')
            Library:CreateStroke({ Parent = BO })
            Library:AddToRegistry(BO, { BackgroundColor3 = 'BackgroundColor' })
            local TBs = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0,0,0,0); Size = UDim2.new(1,0,0,18); ZIndex = 5; Parent = BO })
            Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Enum.HorizontalAlignment.Left; SortOrder = Enum.SortOrder.LayoutOrder; Parent = TBs })
            function Tbox:AddTab(N)
                local T = {}
                local B = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BackgroundTransparency = 1; Size = UDim2.new(0.5,0,1,0); ZIndex = 150; Active = true; Parent = TBs })
                Library:CreateLabel({ Size = UDim2.new(1,0,1,0); TextSize = 14; Text = N; TextXAlignment = Enum.TextXAlignment.Center; ZIndex = 151; Parent = B })
                local Blk = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Position = UDim2.new(0,0,1,0); Size = UDim2.new(1,0,0,1); Visible = false; ZIndex = 9; Parent = B })
                Library:AddToRegistry(Blk, { BackgroundColor3 = 'AccentColor' })
                local C = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0,4,0,20); Size = UDim2.new(1,-4,1,-20); ZIndex = 10; Visible = false; Parent = BO })
                Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = C })
                function T:Show() for _, t in next, Tbox.Tabs do t:Hide() end C.Visible = true Blk.Visible = true B.BackgroundTransparency = 0 T:Resize() end
                function T:Hide() C.Visible = false Blk.Visible = false B.BackgroundTransparency = 1 end
                function T:Resize()
                    local tc = 0 for _ in next, Tbox.Tabs do tc = tc + 1 end
                    for _, b in next, TBs:GetChildren() do if not b:IsA('UIListLayout') then b.Size = UDim2.new(1/tc, 0, 1, 0) end end
                    if not C.Visible then return end
                    local s = 0
                    for _, e in next, T.Container:GetChildren() do if not e:IsA('UIListLayout') and e.Visible then s = s + e.Size.Y.Offset end end
                    BO.Size = UDim2.new(1,0,0, 20 + s + 4)
                end
                B.InputBegan:Connect(function(Inp) if Inp.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then T:Show() T:Resize() end end)
                T.Container = C; Tbox.Tabs[N] = T
                setmetatable(T, BaseGroupbox)
                T:AddBlank(3); T:Resize()
                if #TBs:GetChildren() == 2 then T:Show() end
                return T
            end
            Tb.Tabboxes[Info.Name or ''] = Tbox
            return Tbox
        end
        function Tb:AddLeftTabbox(n) return Tb:AddTabbox({ Name = n; Side = 1 }) end
        function Tb:AddRightTabbox(n) return Tb:AddTabbox({ Name = n; Side = 2 }) end
        TB.InputBegan:Connect(function(Inp) if Inp.UserInputType == Enum.UserInputType.MouseButton1 then Tb:ShowTab() end end)
        if #TC:GetChildren() == 0 then Tb:ShowTab() end
        W.Tabs[Name] = Tb
        return Tb
    end

    local ME = Library:Create('TextButton', { BackgroundTransparency = 1; Size = UDim2.new(0,0,0,0); Visible = true; Text = ''; Modal = false; Parent = ScreenGui })
    local TCache = {}; local Tog = false; local Fading = false
    function Library:Toggle()
        if Fading then return end
        local FT = Config.MenuFadeTime; Fading = true; Tog = not Tog; ME.Modal = Tog
        if ThreeDMode then Outer.Visible = Tog
        else
            if not Tog then for f, _ in pairs(Library.OpenedFrames) do f.Visible = false end table.clear(Library.OpenedFrames) end
            if Tog then Outer.Visible = true end
            for _, D in next, Outer:GetDescendants() do
                local P = {}
                if D:IsA('ImageLabel') then table.insert(P, 'ImageTransparency') table.insert(P, 'BackgroundTransparency')
                elseif D:IsA('TextLabel') or D:IsA('TextBox') then table.insert(P, 'TextTransparency')
                elseif D:IsA('Frame') or D:IsA('ScrollingFrame') then table.insert(P, 'BackgroundTransparency')
                elseif D:IsA('UIStroke') then table.insert(P, 'Transparency') end
                local C = TCache[D]; if not C then C = {} TCache[D] = C end
                for _, p in next, P do
                    if not C[p] then C[p] = D[p] end
                    if C[p] == 1 then continue end
                    TweenService:Create(D, TweenInfo.new(FT, Enum.EasingStyle.Linear), { [p] = Tog and C[p] or 1 }):Play()
                end
            end
        end
        task.wait(FT)
        if not Tog and not ThreeDMode then Outer.Visible = false end
        if not Tog and Library.BindSystem then Library.BindSystem:CloseAllWindows() end
        Fading = false
    end
    Library.ToggleMenu = Library.Toggle
    function Library:Set3DEnabled(en)
        if en == ThreeDMode then return end
        ThreeDMode = en
        if en then Create3DObjects() Outer.Visible = true ME.Modal = true Tog = true
        else Clear3DObjects() if Tog then Outer.Visible = true ME.Modal = true else Outer.Visible = false ME.Modal = false end end
    end
    getgenv().Set3DEnabled = Library.Set3DEnabled
    Library:GiveSignal(InputService.InputBegan:Connect(function(Inp, Pr)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Inp.UserInputType == Enum.UserInputType.Keyboard and Inp.KeyCode.Name == Library.ToggleKeybind.Value then task.spawn(Library.Toggle) end
        elseif Inp.KeyCode == Enum.KeyCode.RightControl or (Inp.KeyCode == Enum.KeyCode.RightShift and not Pr) then task.spawn(Library.Toggle) end
    end))
    if Config.AutoShow then task.spawn(Library.Toggle) end

    if Config.Resizable then
        local th, cs = 8, 16
        local handles = {}
        local function mkH(name)
            local h = Library:Create('TextButton', { Name = name; BackgroundColor3 = Library.AccentColor; BackgroundTransparency = 1; BorderSizePixel = 0; Text = ''; AutoButtonColor = false; Active = false; ZIndex = 9999; Parent = Outer })
            Library:RegisterCorner(Library:Create('UICorner', { CornerRadius = UDim.new(0,2); Parent = h }), 'Button')
            handles[name] = h
            h.MouseEnter:Connect(function() Library._hoveredResizeHandle = h end)
            h.MouseLeave:Connect(function() if Library._hoveredResizeHandle == h then Library._hoveredResizeHandle = nil end end)
            local dr = false; local sMX, sMY, sPX, sPY, sWX, sWY
            h.MouseButton1Down:Connect(function()
                dr = true; Library._resizing = true
                local aX = Outer.AbsolutePosition.X; local aY = Outer.AbsolutePosition.Y
                Outer.AnchorPoint = Vector2.new(0, 0)
                Outer.Position = UDim2.fromOffset(aX, aY)
                local m = LocalPlayer:GetMouse()
                sMX = m.X; sMY = m.Y; sPX = aX; sPY = aY
                sWX = Outer.Size.X.Offset; sWY = Outer.Size.Y.Offset
            end)
            Library:GiveSignal(RunService.RenderStepped:Connect(function()
                if not dr then return end
                if not InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    dr = false; Library._resizing = false; return
                end
                local m = LocalPlayer:GetMouse(); if not m then return end
                local dx = m.X - sMX; local dy = m.Y - sMY
                local nX, nY, nW, nH = sPX, sPY, sWX, sWY
                local iL = name:find('W') ~= nil
                local iR = name:find('E') ~= nil
                local iT = name:find('N') ~= nil
                local iB = name:find('S') ~= nil
                if iR then nW = sWX + dx end
                if iL then nW = sWX - dx nX = sPX + dx end
                if iB then nH = sWY + dy end
                if iT then nH = sWY - dy nY = sPY + dy end
                local mW = Config.MinSize.X.Offset; local mH = Config.MinSize.Y.Offset
                if nW < mW then if iL then nX = sPX + (sWX - mW) end nW = mW end
                if nH < mH then if iT then nY = sPY + (sWY - mH) end nH = mH end
                Outer.Position = UDim2.fromOffset(nX, nY)
                Outer.Size = UDim2.fromOffset(nW, nH)
            end))
        end
        local function upd()
            local t, c = th, cs
            local function sH(n, p, s) if handles[n] then handles[n].Position = p handles[n].Size = s end end
            sH('N', UDim2.new(0,c,0,0), UDim2.new(1,-c*2,0,t))
            sH('S', UDim2.new(0,c,1,-t), UDim2.new(1,-c*2,0,t))
            sH('W', UDim2.new(0,0,0,c), UDim2.new(0,t,1,-c*2))
            sH('E', UDim2.new(1,-t,0,c), UDim2.new(0,t,1,-c*2))
            sH('NW', UDim2.new(0,0,0,0), UDim2.fromOffset(c,c))
            sH('NE', UDim2.new(1,-c,0,0), UDim2.fromOffset(c,c))
            sH('SW', UDim2.new(0,0,1,-c), UDim2.fromOffset(c,c))
            sH('SE', UDim2.new(1,-c,1,-c), UDim2.fromOffset(c,c))
        end
        mkH('N') mkH('S') mkH('W') mkH('E') mkH('NW') mkH('NE') mkH('SW') mkH('SE')
        upd()
        Library:GiveSignal(Outer:GetPropertyChangedSignal('AbsoluteSize'):Connect(upd))
    end

    W.Holder = Outer
    return W
end

local function OnPlayerChange()
    local PL = GetPlayersString()
    for _, V in next, Options do if V.Type == 'Dropdown' and V.SpecialType == 'Player' then V:SetValues(PL) end end
end
Players.PlayerAdded:Connect(OnPlayerChange)
Players.PlayerRemoving:Connect(OnPlayerChange)

getgenv().Library = Library
return Library
