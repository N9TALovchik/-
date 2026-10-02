local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
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
local Current3DPart = nil
local Current3DSurface = nil
local SPEED_MIN = 0.1
local SPEED_MAX = 15.0
local RainbowClock = 0
local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);
local ScreenGui = Instance.new('ScreenGui');
local OverlayGui = Instance.new('ScreenGui');
local BindGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui); ProtectGui(OverlayGui); ProtectGui(BindGui);
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
BindGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
BindGui.DisplayOrder = 10;
BindGui.ResetOnSpawn = false;
ScreenGui.Parent = CoreGui; OverlayGui.Parent = CoreGui; BindGui.Parent = CoreGui;

local function getScreenGui(obj) while obj and not obj:IsA('ScreenGui') do obj = obj.Parent end return obj or ScreenGui end
local UIRoot = ScreenGui
local Toggles = {}; local Options = {};
getgenv().Toggles = Toggles; getgenv().Options = Options;

local Library = {
    Registry = {}; RegistryMap = {}; HudRegistry = {};
    FontColor = Color3.fromRGB(255, 255, 255);
    MainColor = Color3.fromRGB(28, 28, 28);
    BackgroundColor = Color3.fromRGB(20, 20, 20);
    AccentColor = Color3.fromRGB(0, 85, 255);
    OutlineColor = Color3.fromRGB(50, 50, 50);
    RiskColor = Color3.fromRGB(255, 50, 50),
    Black = Color3.new(0, 0, 0);
    Font = Enum.Font.Code,
    OpenedFrames = {}; DependencyBoxes = {}; Signals = {};
    ScreenGui = UIRoot;
    UICornerRadius = 0.8;
    UICorners = {};
    NotifySoundId = NOTIFY_SOUND_ID;
    CursorImageId = CURSOR_IMAGE_ID;
    MainFrame = nil;
    _resizing = false;
    _hoveredResizeHandle = nil;
};
local RainbowStep = 0
local Hue = 0
table.insert(Library.Signals, RenderStepped:Connect(function(Delta) RainbowClock = RainbowClock + Delta end))
table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta
    if RainbowStep >= (1 / 60) then
        RainbowStep = 0
        Hue = Hue + (1 / 400);
        if Hue > 1 then Hue = 0; end;
        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end;
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();
    for i = 1, #PlayerList do PlayerList[i] = PlayerList[i].Name; end;
    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);
    return PlayerList;
end;
local function GetTeamsString()
    local TeamList = Teams:GetTeams();
    for i = 1, #TeamList do TeamList[i] = TeamList[i].Name; end;
    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    return TeamList;
end;
function Library:SafeCallback(f, ...)
    if (not f) then return end;
    if not Library.NotifyOnError then return f(...); end;
    local success, event = pcall(f, ...);
    if not success then
        local _, i = event:find(":%d+: ");
        if not i then return Library:Notify(event); end;
        return Library:Notify(event:sub(i + 1), 3);
    end;
end;
function Library:AttemptSave() if Library.SaveManager then Library.SaveManager:Save(); end; end;
function Library:Create(Class, Properties)
    local _Instance = Class;
    if type(Class) == 'string' then _Instance = Instance.new(Class); end;
    for Property, Value in next, Properties do _Instance[Property] = Value; end;
    return _Instance;
end;
function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;
    Library:Create('UIStroke', { Color = Color3.new(0, 0, 0); Thickness = 1; LineJoinMode = Enum.LineJoinMode.Miter; Parent = Inst; });
end;
function Library:CreateLabel(Properties, IsHud)
    local props = Properties or {}
    local startImg = props.StartImage; local endImg = props.EndImage
    local startImgColor = props.StartImageColor; local endImgColor = props.EndImageColor
    local startImgOffset = props.StartImageOffset; local endImgOffset = props.EndImageOffset
    props.StartImage = nil; props.EndImage = nil; props.StartImageColor = nil; props.EndImageColor = nil; props.StartImageOffset = nil; props.EndImageOffset = nil
    local function valid(id)
        if id == nil then return false end
        local s = tostring(id)
        if s == '' or s == '0' or s == 'rbxassetid://0' or s == 'rbxassetid://' then return false end
        return true
    end
    local hasStart = valid(startImg); local hasEnd = valid(endImg)
    local _Instance = Library:Create('TextLabel', { BackgroundTransparency = 1; Font = Library.Font; TextColor3 = Library.FontColor; TextSize = 16; TextStrokeTransparency = 0; RichText = true; });
    Library:ApplyTextStroke(_Instance); Library:AddToRegistry(_Instance, { TextColor3 = 'FontColor'; }, IsHud);
    if not (hasStart or hasEnd) then return Library:Create(_Instance, props) end
    local wrapper = Library:Create('Frame', { BackgroundTransparency = 1; Position = props.Position or UDim2.new(); Size = props.Size or UDim2.new(1, 0, 0, 16); AnchorPoint = props.AnchorPoint or Vector2.new(); ZIndex = props.ZIndex; Parent = props.Parent; })
    local textSize = props.TextSize or 16; local px = textSize; local pad = 4
    local leftPad = hasStart and (px + pad) or 0; local rightPad = hasEnd and (px + pad) or 0
    local zidx = (props.ZIndex or 1) + 1
    if hasStart then
        local sx = startImgOffset and startImgOffset.X or 0; local sy = startImgOffset and startImgOffset.Y or 0
        Library:Create('ImageLabel', { BackgroundTransparency = 1; Position = UDim2.fromOffset(sx, sy); Size = UDim2.fromOffset(px, px); Image = startImg; ImageColor3 = startImgColor or Color3.new(1, 1, 1); ZIndex = zidx; Parent = wrapper; })
    end
    if hasEnd then
        local ex = endImgOffset and endImgOffset.X or 0; local ey = endImgOffset and endImgOffset.Y or 0
        Library:Create('ImageLabel', { BackgroundTransparency = 1; AnchorPoint = Vector2.new(1, 0); Position = UDim2.new(1, ex, 0, ey); Size = UDim2.fromOffset(px, px); Image = endImg; ImageColor3 = endImgColor or Color3.new(1, 1, 1); ZIndex = zidx; Parent = wrapper; })
    end
    props.Parent = wrapper; props.Position = UDim2.fromOffset(leftPad, 0); props.Size = UDim2.new(1, -leftPad - rightPad, 1, 0); props.AnchorPoint = nil; props.ZIndex = zidx
    Library:Create(_Instance, props)
    return _Instance
end;

-- [FIX] MakeDraggable — через global InputBegan, не блокирует resize
function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = false
    local dragging = false
    local startMX, startMY, startPX, startPY
    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, gp)
        if gp then return end
        if Library._resizing then return end
        if Library._hoveredResizeHandle then return end
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local aPos, aSize = Instance.AbsolutePosition, Instance.AbsoluteSize
        if Mouse.X < aPos.X or Mouse.X > aPos.X + aSize.X or Mouse.Y < aPos.Y or Mouse.Y > aPos.Y + aSize.Y then return end
        local relY = Input.Position.Y - aPos.Y
        if relY > (Cutoff or 40) then return end
        dragging = true
        startMX = Input.Position.X
        startMY = Input.Position.Y
        startPX = Instance.Position.X.Offset
        startPY = Instance.Position.Y.Offset
    end))
    Library:GiveSignal(InputService.InputChanged:Connect(function(Input)
        if not dragging then return end
        if Library._resizing then dragging = false return end
        if Input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local dx = Input.Position.X - startMX
        local dy = Input.Position.Y - startMY
        Instance.Position = UDim2.fromOffset(startPX + dx, startPY + dy)
    end))
    Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', { BackgroundColor3 = Library.MainColor, BorderColor3 = Library.OutlineColor, Size = UDim2.fromOffset(X + 5, Y + 4), ZIndex = 100, Parent = getScreenGui(HoverInstance), Visible = false, })
    local Label = Library:CreateLabel({ Position = UDim2.fromOffset(3, 1), Size = UDim2.fromOffset(X, Y); TextSize = 14; Text = InfoStr, TextColor3 = Library.FontColor, TextXAlignment = Enum.TextXAlignment.Left; ZIndex = Tooltip.ZIndex + 1, Parent = Tooltip; });
    Library:AddToRegistry(Tooltip, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
    Library:AddToRegistry(Label, { TextColor3 = 'FontColor', });
    local IsHovering = false
    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then return end
        IsHovering = true
        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12); Tooltip.Visible = true
        while IsHovering do RunService.Heartbeat:Wait() Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12) end
    end)
    HoverInstance.MouseLeave:Connect(function() IsHovering = false Tooltip.Visible = false end)
end;
function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];
        for Property, ColorIdx in next, Properties do Instance[Property] = Library[ColorIdx] or ColorIdx; if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx; end; end;
    end)
    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];
        for Property, ColorIdx in next, PropertiesDefault do Instance[Property] = Library[ColorIdx] or ColorIdx; if Reg and Reg.Properties[Property] then Reg.Properties[Property] = ColorIdx; end; end;
    end)
end;
function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        if Frame and Frame.Parent then
            local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
            if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then return true; end;
        end;
    end;
end;
function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;
    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then return true; end;
end;
function Library:UpdateDependencyBoxes() for _, Depbox in next, Library.DependencyBoxes do Depbox:Update(); end; end;
function Library:MapValue(Value, MinA, MaxA, MinB, MaxB) return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB; end;
function Library:GetTextBounds(Text, Font, Size, Resolution) local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080)) return Bounds.X, Bounds.Y end;
function Library:GetDarkerColor(Color) local H, S, V = Color3.toHSV(Color); return Color3.fromHSV(H, S, V / 1.5); end;
Library.AccentColorDark = Library:GetDarkerColor(Library.AccentColor);
function Library:SetUICornerRadius(radius)
    Library.UICornerRadius = radius
    for _, corner in ipairs(Library.UICorners) do if corner then corner.CornerRadius = UDim.new(0, radius * 10) end end
end
getgenv().SetUICornerRadius = Library.SetUICornerRadius
function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = { Instance = Instance; Properties = Properties; Idx = Idx; };
    table.insert(Library.Registry, Data); Library.RegistryMap[Instance] = Data;
    if IsHud then table.insert(Library.HudRegistry, Data); end;
end;
function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];
    if Data then
        for Idx = #Library.Registry, 1, -1 do if Library.Registry[Idx] == Data then table.remove(Library.Registry, Idx); end; end;
        for Idx = #Library.HudRegistry, 1, -1 do if Library.HudRegistry[Idx] == Data then table.remove(Library.HudRegistry, Idx); end; end;
        Library.RegistryMap[Instance] = nil;
    end;
end;
function Library:UpdateColorsUsingRegistry()
    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then Object.Instance[Property] = ColorIdx() end
        end
    end;
end;
function Library:GiveSignal(Signal) table.insert(Library.Signals, Signal) end
function Library:Unload()
    for Idx = #Library.Signals, 1, -1 do local Connection = table.remove(Library.Signals, Idx) Connection:Disconnect() end
    if Library.OnUnload then Library.OnUnload() end
    ScreenGui:Destroy(); OverlayGui:Destroy(); BindGui:Destroy();
end
function Library:OnUnload(Callback) Library.OnUnload = Callback end
Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance) if Library.RegistryMap[Instance] then Library:RemoveFromRegistry(Instance); end; end))

-- BASE ADDONS
local BaseAddons = {};
do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        assert(Info.Default, 'AddColorPicker: Missing default value.');
        local OnlyStandart = (Info.OnlyStandart == 1)
        local ColorPicker = {
            Value = Info.Default; Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
            Mode = 'Standard'; OnlyStandart = OnlyStandart;
            RainbowSpeed = 1; RainbowBrightness = 1; GradientSpeed = 1;
            GradientColorA = Info.Default; GradientColorB = Color3.fromRGB(255, 0, 0);
            GradientEditTarget = 'A';
        };
        function ColorPicker:SetHSVFromRGB(Color) local H, S, V = Color3.toHSV(Color); ColorPicker.Hue = H; ColorPicker.Sat = S; ColorPicker.Vib = V; end;
        ColorPicker:SetHSVFromRGB(ColorPicker.Value);
        local function PickerHeight(mode)
            if mode == 'Rainbow' then return Info.Transparency and 160 or 132
            elseif mode == 'Gradient' then return Info.Transparency and 384 or 362
            else return Info.Transparency and 322 or 297 end
        end
        local DisplayFrame = Library:Create('Frame', { BackgroundColor3 = ColorPicker.Value; BorderColor3 = Library:GetDarkerColor(ColorPicker.Value); BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(0, 28, 0, 14); ZIndex = 6; Active = true; Parent = ToggleLabel; });
        local CheckerFrame = Library:Create('ImageLabel', { BorderSizePixel = 0; Size = UDim2.new(0, 27, 0, 13); ZIndex = 5; Image = 'http://www.roblox.com/asset/?id=12977615774'; Visible = not not Info.Transparency; Parent = DisplayFrame; });
        local PickerFrameOuter = Library:Create('Frame', { Name = 'Color'; BackgroundColor3 = Color3.new(1, 1, 1); BorderColor3 = Library.OutlineColor; Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18), Size = UDim2.fromOffset(230, PickerHeight(ColorPicker.Mode)); Visible = false; ZIndex = 15; Parent = getScreenGui(ToggleLabel), });
        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function() PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18); end)
        local PickerFrameInner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 16; Parent = PickerFrameOuter; });
        local Highlight = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1, 0, 0, 2); ZIndex = 17; Parent = PickerFrameInner; });
        Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 14); Position = UDim2.fromOffset(5, 5); TextXAlignment = Enum.TextXAlignment.Left; TextSize = 14; Text = ColorPicker.Title; TextWrapped = false; ZIndex = 16; Parent = PickerFrameInner; });
        local ModeBtn = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(4, 25); Size = UDim2.new(1, -8, 0, 18); ZIndex = 30; Active = true; Parent = PickerFrameInner; });
        Library:AddToRegistry(ModeBtn, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        local ModeBtnLabel = Library:CreateLabel({ Size = UDim2.new(1, -22, 1, 0); Position = UDim2.fromOffset(4, 0); Text = 'Standard'; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 31; Parent = ModeBtn; });
        Library:CreateLabel({ Size = UDim2.new(0, 20, 1, 0); Position = UDim2.new(1, -22, 0, 0); Text = 'v'; TextSize = 12; ZIndex = 31; Parent = ModeBtn; });
        local ModeList = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(4, 45); Size = UDim2.new(1, -8, 0, 0); Visible = false; ZIndex = 32; Parent = PickerFrameInner; });
        Library:AddToRegistry(ModeList, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = ModeList; });
        local CONTENT_Y = 68
        local StdContent = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.fromOffset(0, CONTENT_Y); Size = UDim2.new(1, 0, 0, 220); ZIndex = 17; Parent = PickerFrameInner; });
        local SatVibMapOuter = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.new(0, 4, 0, 0); Size = UDim2.new(0, 200, 0, 200); ZIndex = 17; Parent = StdContent; });
        local SatVibMapInner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 18; Active = true; Parent = SatVibMapOuter; });
        local SatVibMap = Library:Create('ImageLabel', { BorderSizePixel = 0; Size = UDim2.new(1, 0, 1, 0); ZIndex = 18; Image = 'rbxassetid://4155801252'; Parent = SatVibMapInner; });
        local CursorOuter = Library:Create('ImageLabel', { AnchorPoint = Vector2.new(0.5, 0.5); Size = UDim2.new(0, 6, 0, 6); BackgroundTransparency = 1; Image = 'http://www.roblox.com/asset/?id=9619665977'; ImageColor3 = Color3.new(0, 0, 0); ZIndex = 19; Parent = SatVibMap; });
        Library:Create('ImageLabel', { Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2); Position = UDim2.new(0, 1, 0, 1); BackgroundTransparency = 1; Image = 'http://www.roblox.com/asset/?id=9619665977'; ZIndex = 20; Parent = CursorOuter; })
        local HueSelectorOuter = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.new(0, 208, 0, 0); Size = UDim2.new(0, 15, 0, 200); ZIndex = 17; Parent = StdContent; });
        local HueSelectorInner = Library:Create('Frame', { BackgroundColor3 = Color3.new(1, 1, 1); BorderSizePixel = 0; Size = UDim2.new(1, 0, 1, 0); ZIndex = 18; Active = true; Parent = HueSelectorOuter; });
        local HueCursor = Library:Create('Frame', { BackgroundColor3 = Color3.new(1, 1, 1); AnchorPoint = Vector2.new(0, 0.5); BorderColor3 = Color3.new(0, 0, 0); Size = UDim2.new(1, 0, 0, 1); ZIndex = 18; Parent = HueSelectorInner; });
        local HueBoxOuter = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.fromOffset(4, 203), Size = UDim2.new(0.5, -6, 0, 20), ZIndex = 18, Parent = StdContent, });
        local HueBoxInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 18, Parent = HueBoxOuter; });
        Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) }); Rotation = 90; Parent = HueBoxInner; });
        local HueBox = Library:Create('TextBox', { BackgroundTransparency = 1; Position = UDim2.new(0, 5, 0, 0); Size = UDim2.new(1, -5, 1, 0); Font = Library.Font; PlaceholderColor3 = Color3.fromRGB(190, 190, 190); PlaceholderText = 'Hex color', Text = '#FFFFFF', TextColor3 = Library.FontColor; TextSize = 14; TextStrokeTransparency = 0; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 20, Parent = HueBoxInner; });
        Library:ApplyTextStroke(HueBox);
        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), { Position = UDim2.new(0.5, 2, 0, 203), Size = UDim2.new(0.5, -6, 0, 20), Parent = StdContent });
        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), { Text = '255, 255, 255', PlaceholderText = 'RGB color', TextColor3 = Library.FontColor });
        local RainContent = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.fromOffset(0, CONTENT_Y); Size = UDim2.new(1, 0, 0, 70); Visible = false; ZIndex = 17; Parent = PickerFrameInner; });
        local RSpeedLabel = Library:CreateLabel({ Position = UDim2.fromOffset(5, 0); Size = UDim2.new(1, -10, 0, 14); Text = 'Rainbow Speed: 1.0'; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 18; Parent = RainContent; });
        local RSpeedOuter = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(5, 16); Size = UDim2.new(1, -10, 0, 12); ZIndex = 18; Active = true; Parent = RainContent; });
        Library:AddToRegistry(RSpeedOuter, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        local RSpeedFill = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0.2, 0, 1, 0); ZIndex = 19; Parent = RSpeedOuter; });
        Library:AddToRegistry(RSpeedFill, { BackgroundColor3 = 'AccentColor'; });
        local RBrightLabel = Library:CreateLabel({ Position = UDim2.fromOffset(5, 34); Size = UDim2.new(1, -10, 0, 14); Text = 'Brightness: 1.00'; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 18; Parent = RainContent; });
        local RBrightOuter = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(5, 50); Size = UDim2.new(1, -10, 0, 12); ZIndex = 18; Active = true; Parent = RainContent; });
        Library:AddToRegistry(RBrightOuter, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        local RBrightFill = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0.9, 0, 1, 0); ZIndex = 19; Parent = RBrightOuter; });
        Library:AddToRegistry(RBrightFill, { BackgroundColor3 = 'AccentColor'; });
        local GradContent = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.fromOffset(0, CONTENT_Y); Size = UDim2.new(1, 0, 0, 290); Visible = false; ZIndex = 17; Parent = PickerFrameInner; });
        local GradColorABtn = Library:Create('Frame', { BackgroundColor3 = ColorPicker.GradientColorA; BorderColor3 = Library.AccentColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(4, 2); Size = UDim2.new(0.5, -6, 0, 22); ZIndex = 18; Active = true; Parent = GradContent; });
        Library:CreateLabel({ Size = UDim2.new(1, 0, 1, 0); Text = 'A'; TextSize = 13; TextColor3 = Color3.new(1,1,1); TextStrokeTransparency = 0; TextStrokeColor3 = Color3.new(0,0,0); ZIndex = 19; Parent = GradColorABtn; });
        local GradColorBBtn = Library:Create('Frame', { BackgroundColor3 = ColorPicker.GradientColorB; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.new(0.5, 2, 0, 2); Size = UDim2.new(0.5, -6, 0, 22); ZIndex = 18; Active = true; Parent = GradContent; });
        Library:CreateLabel({ Size = UDim2.new(1, 0, 1, 0); Text = 'B'; TextSize = 13; TextColor3 = Color3.new(1,1,1); TextStrokeTransparency = 0; TextStrokeColor3 = Color3.new(0,0,0); ZIndex = 19; Parent = GradColorBBtn; });
        local GSatVibMapOuter = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.new(0, 4, 0, 28); Size = UDim2.new(0, 200, 0, 200); ZIndex = 17; Parent = GradContent; });
        local GSatVibMapInner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 18; Active = true; Parent = GSatVibMapOuter; });
        local GSatVibMap = Library:Create('ImageLabel', { BorderSizePixel = 0; Size = UDim2.new(1, 0, 1, 0); ZIndex = 18; Image = 'rbxassetid://4155801252'; Parent = GSatVibMapInner; });
        local GCursorOuter = Library:Create('ImageLabel', { AnchorPoint = Vector2.new(0.5, 0.5); Size = UDim2.new(0, 6, 0, 6); BackgroundTransparency = 1; Image = 'http://www.roblox.com/asset/?id=9619665977'; ImageColor3 = Color3.new(0, 0, 0); ZIndex = 19; Parent = GSatVibMap; });
        Library:Create('ImageLabel', { Size = UDim2.new(0, GCursorOuter.Size.X.Offset - 2, 0, GCursorOuter.Size.Y.Offset - 2); Position = UDim2.new(0, 1, 0, 1); BackgroundTransparency = 1; Image = 'http://www.roblox.com/asset/?id=9619665977'; ZIndex = 20; Parent = GCursorOuter; })
        local GHueOuter = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.new(0, 208, 0, 28); Size = UDim2.new(0, 15, 0, 200); ZIndex = 17; Parent = GradContent; });
        local GHueInner = Library:Create('Frame', { BackgroundColor3 = Color3.new(1, 1, 1); BorderSizePixel = 0; Size = UDim2.new(1, 0, 1, 0); ZIndex = 18; Active = true; Parent = GHueOuter; });
        local GHueCursor = Library:Create('Frame', { BackgroundColor3 = Color3.new(1, 1, 1); AnchorPoint = Vector2.new(0, 0.5); BorderColor3 = Color3.new(0, 0, 0); Size = UDim2.new(1, 0, 0, 1); ZIndex = 18; Parent = GHueInner; });
        local GSpeedLabel = Library:CreateLabel({ Position = UDim2.fromOffset(5, 235); Size = UDim2.new(1, -10, 0, 14); Text = 'Gradient Speed: 1.0'; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 18; Parent = GradContent; });
        local GSpeedOuter = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.fromOffset(5, 252); Size = UDim2.new(1, -10, 0, 12); ZIndex = 18; Active = true; Parent = GradContent; });
        Library:AddToRegistry(GSpeedOuter, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        local GSpeedFill = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0.2, 0, 1, 0); ZIndex = 19; Parent = GSpeedOuter; });
        Library:AddToRegistry(GSpeedFill, { BackgroundColor3 = 'AccentColor'; });
        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        local function getTransY()
            if ColorPicker.Mode == 'Rainbow' then return CONTENT_Y + 70
            elseif ColorPicker.Mode == 'Gradient' then return CONTENT_Y + 290
            else return CONTENT_Y + 228 end
        end
        if Info.Transparency then
            TransparencyBoxOuter = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.fromOffset(4, getTransY()); Size = UDim2.new(1, -8, 0, 15); ZIndex = 30; Parent = PickerFrameInner; });
            TransparencyBoxInner = Library:Create('Frame', { BackgroundColor3 = ColorPicker.Value; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 30; Active = true; Parent = TransparencyBoxOuter; });
            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });
            Library:Create('ImageLabel', { BackgroundTransparency = 1; Size = UDim2.new(1, 0, 1, 0); Image = 'http://www.roblox.com/asset/?id=12978095818'; ZIndex = 31; Parent = TransparencyBoxInner; });
            TransparencyCursor = Library:Create('Frame', { BackgroundColor3 = Color3.new(1, 1, 1); AnchorPoint = Vector2.new(0.5, 0); BorderColor3 = Color3.new(0, 0, 0); Size = UDim2.new(0, 1, 1, 0); ZIndex = 32; Parent = TransparencyBoxInner; });
        end
        local SequenceTable = {};
        for Hue = 0, 1, 0.1 do table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1))); end;
        Library:Create('UIGradient', { Color = ColorSequence.new(SequenceTable); Rotation = 90; Parent = HueSelectorInner; });
        Library:Create('UIGradient', { Color = ColorSequence.new(SequenceTable); Rotation = 90; Parent = GHueInner; });
        ColorPicker._rainbowPhase = 0
        ColorPicker._gradientPhase = 0
        ColorPicker._lastTick = tick()
        function ColorPicker:GetEffectiveColor()
            if ColorPicker.Mode == 'Standard' then return Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)
            elseif ColorPicker.Mode == 'Rainbow' then local t = RainbowClock * ColorPicker.RainbowSpeed return Color3.fromHSV(t % 1, 1, ColorPicker.RainbowBrightness)
            elseif ColorPicker.Mode == 'Gradient' then local t = (math.sin(RainbowClock * ColorPicker.GradientSpeed) + 1) * 0.5 return ColorPicker.GradientColorA:Lerp(ColorPicker.GradientColorB, t) end
            return ColorPicker.Value
        end
        local function updateRainbowSliders()
            local s = math.clamp((ColorPicker.RainbowSpeed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), 0, 1)
            RSpeedFill.Size = UDim2.new(s, 0, 1, 0)
            RSpeedLabel.Text = string.format('Rainbow Speed: %.1f', ColorPicker.RainbowSpeed)
            local b = math.clamp(ColorPicker.RainbowBrightness, 0.05, 1)
            RBrightFill.Size = UDim2.new(b, 0, 1, 0)
            RBrightLabel.Text = string.format('Brightness: %.2f', ColorPicker.RainbowBrightness)
        end
        local function updateGradientSpeed()
            local s = math.clamp((ColorPicker.GradientSpeed - SPEED_MIN) / (SPEED_MAX - SPEED_MIN), 0, 1)
            GSpeedFill.Size = UDim2.new(s, 0, 1, 0)
            GSpeedLabel.Text = string.format('Gradient Speed: %.1f', ColorPicker.GradientSpeed)
        end
        function ColorPicker:Display()
            if ColorPicker.Mode == 'Standard' then
                ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)
                SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)
                CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0)
                HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0)
                HueBox.Text = '#' .. ColorPicker.Value:ToHex()
                RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R*255), math.floor(ColorPicker.Value.G*255), math.floor(ColorPicker.Value.B*255) }, ', ')
            elseif ColorPicker.Mode == 'Gradient' then
                local newColor = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)
                if ColorPicker.GradientEditTarget == 'A' then ColorPicker.GradientColorA = newColor else ColorPicker.GradientColorB = newColor end
                GradColorABtn.BackgroundColor3 = ColorPicker.GradientColorA
                GradColorBBtn.BackgroundColor3 = ColorPicker.GradientColorB
                GradColorABtn.BorderColor3 = (ColorPicker.GradientEditTarget == 'A') and Library.AccentColor or Library.OutlineColor
                GradColorBBtn.BorderColor3 = (ColorPicker.GradientEditTarget == 'B') and Library.AccentColor or Library.OutlineColor
                GSatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)
                GCursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0)
                GHueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0)
                ColorPicker.Value = ColorPicker.GradientColorA
            end
            updateRainbowSliders()
            updateGradientSpeed()
            local dispColor = ColorPicker:GetEffectiveColor()
            DisplayFrame.BackgroundColor3 = dispColor
            DisplayFrame.BorderColor3 = Library:GetDarkerColor(dispColor)
            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0)
            end
            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value, ColorPicker.Transparency);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value, ColorPicker.Transparency);
        end
        function ColorPicker:GetSaveData() return { value = ColorPicker.Value:ToHex(), transparency = ColorPicker.Transparency, mode = ColorPicker.Mode, hue = ColorPicker.Hue, sat = ColorPicker.Sat, vib = ColorPicker.Vib, rainbowSpeed = ColorPicker.RainbowSpeed, rainbowBrightness = ColorPicker.RainbowBrightness, gradientSpeed = ColorPicker.GradientSpeed, gradientColorA = ColorPicker.GradientColorA:ToHex(), gradientColorB = ColorPicker.GradientColorB:ToHex(), gradientEditTarget = ColorPicker.GradientEditTarget } end
        function ColorPicker:LoadSaveData(data)
            if type(data) ~= 'table' then return end
            if data.hue ~= nil then ColorPicker.Hue = data.hue end
            if data.sat ~= nil then ColorPicker.Sat = data.sat end
            if data.vib ~= nil then ColorPicker.Vib = data.vib end
            if data.transparency ~= nil then ColorPicker.Transparency = data.transparency end
            if data.rainbowSpeed ~= nil then ColorPicker.RainbowSpeed = data.rainbowSpeed end
            if data.rainbowBrightness ~= nil then ColorPicker.RainbowBrightness = data.rainbowBrightness end
            if data.gradientSpeed ~= nil then ColorPicker.GradientSpeed = data.gradientSpeed end
            if data.gradientColorA then local ok, c = pcall(Color3.fromHex, data.gradientColorA) if ok then ColorPicker.GradientColorA = c end end
            if data.gradientColorB then local ok, c = pcall(Color3.fromHex, data.gradientColorB) if ok then ColorPicker.GradientColorB = c end end
            if data.gradientEditTarget then ColorPicker.GradientEditTarget = data.gradientEditTarget end
            if data.mode then ColorPicker:SetMode(data.mode) else ColorPicker:Display() end
        end
        local savedStandardHSV = nil
        local function SetMode(newMode)
            if ColorPicker.OnlyStandart and newMode ~= 'Standard' then return end
            local prev = ColorPicker.Mode
            if prev == 'Standard' and newMode ~= 'Standard' then savedStandardHSV = {ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib} end
            ColorPicker.Mode = newMode
            ModeBtnLabel.Text = newMode
            StdContent.Visible = (newMode == 'Standard')
            RainContent.Visible = (newMode == 'Rainbow')
            GradContent.Visible = (newMode == 'Gradient')
            ModeList.Visible = false
            PickerFrameOuter.Size = UDim2.fromOffset(230, PickerHeight(newMode))
            if TransparencyBoxOuter then TransparencyBoxOuter.Position = UDim2.fromOffset(4, getTransY()) end
            if newMode == 'Gradient' then
                if ColorPicker.GradientEditTarget == 'A' then ColorPicker:SetHSVFromRGB(ColorPicker.GradientColorA) else ColorPicker:SetHSVFromRGB(ColorPicker.GradientColorB) end
            elseif newMode == 'Standard' then
                if savedStandardHSV then ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = savedStandardHSV[1], savedStandardHSV[2], savedStandardHSV[3] end
            end
            ColorPicker:Display()
        end
        local modeOptions = {'Standard', 'Rainbow', 'Gradient'}
        for _, opt in ipairs(modeOptions) do
            local OptBtn = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Size = UDim2.new(1, 0, 0, 18); ZIndex = 33; Active = true; Parent = ModeList; });
            local OptLbl = Library:CreateLabel({ Size = UDim2.new(1, -6, 1, 0); Position = UDim2.fromOffset(6, 0); Text = opt; TextXAlignment = Enum.TextXAlignment.Left; TextSize = 13; ZIndex = 34; Parent = OptBtn; });
            if ColorPicker.OnlyStandart and opt ~= 'Standard' then OptLbl.TextColor3 = Color3.fromRGB(100, 100, 100)
            else
                Library:OnHighlight(OptBtn, OptBtn, { BackgroundColor3 = 'AccentColor' }, { BackgroundColor3 = 'MainColor' })
                OptBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then SetMode(opt) end end)
            end
        end
        ModeList.Size = UDim2.new(1, -8, 0, 18 * #modeOptions + 2)
        ModeBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then ModeList.Visible = not ModeList.Visible end end)
        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; ZIndex = 14, Visible = false, Parent = getScreenGui(ToggleLabel), })
            ContextMenu.Inner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.fromScale(1, 1); ZIndex = 15; Parent = ContextMenu.Container; });
            Library:Create('UIListLayout', { Name = 'Layout', FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = ContextMenu.Inner; });
            Library:Create('UIPadding', { Name = 'Padding', PaddingLeft = UDim.new(0, 4), Parent = ContextMenu.Inner, });
            local function updateMenuPosition() ContextMenu.Container.Position = UDim2.fromOffset((DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4, DisplayFrame.AbsolutePosition.Y + 1) end
            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do if label:IsA('TextLabel') then menuWidth = math.max(menuWidth, label.TextBounds.X) end end
                ContextMenu.Container.Size = UDim2.fromOffset(menuWidth + 8, ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4)
            end
            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)
            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)
            Library:AddToRegistry(ContextMenu.Inner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
            function ContextMenu:Show() self.Container.Visible = true end
            function ContextMenu:Hide() self.Container.Visible = false end
            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then Callback = function() end end
                local Button = Library:CreateLabel({ Active = false; Size = UDim2.new(1, 0, 0, 15); TextSize = 13; Text = Str; ZIndex = 16; Parent = self.Inner; TextXAlignment = Enum.TextXAlignment.Left, });
                Library:OnHighlight(Button, Button, { TextColor3 = 'AccentColor' }, { TextColor3 = 'FontColor' });
                Button.InputBegan:Connect(function(Input) if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end Callback() end)
            end
            ContextMenu:AddOption('Copy color', function() Library.ColorClipboard = ColorPicker.Value Library:Notify('Copied color!', 2) end)
            ContextMenu:AddOption('Paste color', function() if not Library.ColorClipboard then return Library:Notify('You have not copied a color!', 2) end ColorPicker:SetValueRGB(Library.ColorClipboard) end)
            ContextMenu:AddOption('Copy HEX', function() pcall(setclipboard, ColorPicker.Value:ToHex()) Library:Notify('Copied hex code to clipboard!', 2) end)
            ContextMenu:AddOption('Copy RGB', function() pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R*255), math.floor(ColorPicker.Value.G*255), math.floor(ColorPicker.Value.B*255) }, ', ')) Library:Notify('Copied RGB values to clipboard!', 2) end)
        end
        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });
        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result) end
            end
            ColorPicker:Display()
        end)
        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b)) end
            end
            ColorPicker:Display()
        end)
        RSpeedOuter.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local minX = RSpeedOuter.AbsolutePosition.X; local maxX = minX + RSpeedOuter.AbsoluteSize.X
                    local mx = math.clamp(Mouse.X, minX, maxX)
                    ColorPicker.RainbowSpeed = SPEED_MIN + ((mx - minX) / (maxX - minX)) * (SPEED_MAX - SPEED_MIN)
                    updateRainbowSliders() ColorPicker:Display() RenderStepped:Wait()
                end
            end
        end)
        RBrightOuter.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local minX = RBrightOuter.AbsolutePosition.X; local maxX = minX + RBrightOuter.AbsoluteSize.X
                    local mx = math.clamp(Mouse.X, minX, maxX)
                    ColorPicker.RainbowBrightness = math.clamp(0.05 + ((mx - minX) / (maxX - minX)) * 0.95, 0.05, 1)
                    updateRainbowSliders() ColorPicker:Display() RenderStepped:Wait()
                end
            end
        end)
        GSpeedOuter.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local minX = GSpeedOuter.AbsolutePosition.X; local maxX = minX + GSpeedOuter.AbsoluteSize.X
                    local mx = math.clamp(Mouse.X, minX, maxX)
                    ColorPicker.GradientSpeed = SPEED_MIN + ((mx - minX) / (maxX - minX)) * (SPEED_MAX - SPEED_MIN)
                    updateGradientSpeed() ColorPicker:Display() RenderStepped:Wait()
                end
            end
        end)
        GradColorABtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then ColorPicker.GradientEditTarget = 'A' ColorPicker:SetHSVFromRGB(ColorPicker.GradientColorA) ColorPicker:Display() end end)
        GradColorBBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then ColorPicker.GradientEditTarget = 'B' ColorPicker:SetHSVFromRGB(ColorPicker.GradientColorB) ColorPicker:Display() end end)
        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = SatVibMap.AbsolutePosition.X; local MaxX = MinX + SatVibMap.AbsoluteSize.X
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX)
                    local MinY = SatVibMap.AbsolutePosition.Y; local MaxY = MinY + SatVibMap.AbsoluteSize.Y
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY)
                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX)
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY))
                    ColorPicker:Display() RenderStepped:Wait()
                end
                Library:AttemptSave()
            end
        end)
        GSatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = GSatVibMap.AbsolutePosition.X; local MaxX = MinX + GSatVibMap.AbsoluteSize.X
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX)
                    local MinY = GSatVibMap.AbsolutePosition.Y; local MaxY = MinY + GSatVibMap.AbsoluteSize.Y
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY)
                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX)
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY))
                    ColorPicker:Display() RenderStepped:Wait()
                end
            end
        end)
        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y; local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY)
                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY))
                    ColorPicker:Display() RenderStepped:Wait()
                end
                Library:AttemptSave()
            end
        end)
        GHueInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = GHueInner.AbsolutePosition.Y; local MaxY = MinY + GHueInner.AbsoluteSize.Y
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY)
                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY))
                    ColorPicker:Display() RenderStepped:Wait()
                end
            end
        end)
        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then ColorPicker:Hide() else ContextMenu:Hide() ColorPicker:Show() end
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then ContextMenu:Show() ColorPicker:Hide() end
        end)
        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X; local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX)
                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX))
                        ColorPicker:Display() RenderStepped:Wait()
                    end
                    Library:AttemptSave()
                end
            end)
        end
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then ColorPicker:Hide() end
                if not Library:IsMouseOverFrame(ContextMenu.Container) then ContextMenu:Hide() end
            end
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then ContextMenu:Hide() end
            end
        end))
        function ColorPicker:OnChanged(Func) ColorPicker.Changed = Func Func(ColorPicker.Value) end
        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do if Frame.Name == 'Color' then Frame.Visible = false Library.OpenedFrames[Frame] = nil end end
            PickerFrameOuter.Visible = true Library.OpenedFrames[PickerFrameOuter] = true
        end
        function ColorPicker:Hide() PickerFrameOuter.Visible = false Library.OpenedFrames[PickerFrameOuter] = nil ModeList.Visible = false end
        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3])
            ColorPicker.Transparency = Transparency or 0
            ColorPicker:SetHSVFromRGB(Color) ColorPicker:Display()
        end
        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0
            ColorPicker:SetHSVFromRGB(Color) ColorPicker:Display()
        end
        function ColorPicker:SetMode(mode) SetMode(mode) end
        ColorPicker:Display()
        ColorPicker.DisplayFrame = DisplayFrame
        Library:GiveSignal(RenderStepped:Connect(function()
            if ColorPicker.Mode == 'Standard' then return end
            local c
            if ColorPicker.Mode == 'Rainbow' then
                local t = RainbowClock * ColorPicker.RainbowSpeed
                c = Color3.fromHSV(t % 1, 1, ColorPicker.RainbowBrightness)
            elseif ColorPicker.Mode == 'Gradient' then
                local t = (math.sin(RainbowClock * ColorPicker.GradientSpeed) + 1) * 0.5
                c = ColorPicker.GradientColorA:Lerp(ColorPicker.GradientColorB, t)
            else return end
            ColorPicker.Value = c
            DisplayFrame.BackgroundColor3 = c
            DisplayFrame.BorderColor3 = Library:GetDarkerColor(c)
            if TransparencyBoxInner then TransparencyBoxInner.BackgroundColor3 = c end
            Library:SafeCallback(ColorPicker.Callback, c, ColorPicker.Transparency)
            Library:SafeCallback(ColorPicker.Changed, c, ColorPicker.Transparency)
        end))
        Options[Idx] = ColorPicker;
        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;
        assert(Info.Default, 'AddKeyPicker: Missing default value.');
        local KeyPicker = {
            Value = Info.Default; Toggled = false; Mode = Info.Mode or 'Toggle';
            Type = 'KeyPicker'; Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;
            SyncToggleState = Info.SyncToggleState or false;
        };
        if KeyPicker.SyncToggleState then Info.Modes = { 'Toggle' } Info.Mode = 'Toggle' end
        local PickOuter = Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(0, 52, 0, 15); ZIndex = 6; Active = true; Parent = ToggleLabel; });
        local PickInner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 7; ClipsDescendants = true; Parent = PickOuter; });
        Library:AddToRegistry(PickInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        local DisplayLabel = Library:CreateLabel({ Size = UDim2.new(1, 0, 1, 0); TextSize = 13; Text = Info.Default; TextWrapped = false; TextTruncate = Enum.TextTruncate.AtEnd; ZIndex = 8; Parent = PickInner; });
        local ModeSelectOuter = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1); Size = UDim2.new(0, 60, 0, 32); Visible = false; ZIndex = 14; Parent = getScreenGui(ToggleLabel), });
        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function() ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1); end);
        local ModeSelectInner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 15; Parent = ModeSelectOuter; });
        Library:AddToRegistry(ModeSelectInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = ModeSelectInner; });
        local ContainerLabel = Library:Create('TextLabel', { BackgroundTransparency = 1; Font = Library.Font; TextColor3 = Library.FontColor; TextSize = 13; TextStrokeTransparency = 0; RichText = false; TextXAlignment = Enum.TextXAlignment.Left; Size = UDim2.new(1, 0, 0, 18); Visible = false; ZIndex = 200; Parent = Library.KeybindContainer; });
        Library:ApplyTextStroke(ContainerLabel);
        Library:AddToRegistry(ContainerLabel, { TextColor3 = 'FontColor'; }, true);
        local Modes = Info.Modes or { 'Toggle', 'Hold' };
        local ModeButtons = {};
        for _, Mode in next, Modes do
            local ModeButton = {};
            local Label = Library:CreateLabel({ Active = false; Size = UDim2.new(1, 0, 0, 15); TextSize = 13; Text = Mode; ZIndex = 16; Parent = ModeSelectInner; });
            function ModeButton:Select()
                for _, Button in next, ModeButtons do Button:Deselect() end
                KeyPicker.Mode = Mode
                Label.TextColor3 = Library.AccentColor
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor'
                ModeSelectOuter.Visible = false
            end
            function ModeButton:Deselect() KeyPicker.Mode = nil Label.TextColor3 = Library.FontColor Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor' end
            Label.InputBegan:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseButton1 then ModeButton:Select() Library:AttemptSave() end end)
            if Mode == KeyPicker.Mode then ModeButton:Select() end
            ModeButtons[Mode] = ModeButton
        end
        local modeCount = 0
        for _ in next, Modes do modeCount = modeCount + 1 end
        ModeSelectOuter.Size = UDim2.new(0, 60, 0, (15 * modeCount) + 2)
        function KeyPicker:Update()
            if Info.NoUI then return end
            local State = KeyPicker:GetState()
            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode)
            ContainerLabel.Visible = true
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor
            local Reg = Library.RegistryMap[ContainerLabel]
            if Reg and Reg.Properties then Reg.Properties.TextColor3 = State and 'AccentColor' or 'FontColor' end
            local YSize = 0; local XSize = 0; local hasVisible = false
            for _, Label in next, Library.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    hasVisible = true
                    YSize = YSize + 18
                    local tb = TextService:GetTextSize(Label.Text, Label.TextSize, Label.Font, Vector2.new(math.huge, math.huge))
                    if tb.X > XSize then XSize = tb.X end
                end
            end
            if hasVisible then Library.KeybindFrame.Visible = true Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 45, 220), 0, YSize + 28)
            else Library.KeybindFrame.Visible = false end
        end
        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then return false end
                local Key = KeyPicker.Value
                if Key == 'MB1' or Key == 'MB2' then return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                else return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]) end
            else return KeyPicker.Toggled end
        end
        function KeyPicker:SetValue(Data) local Key, Mode = Data[1], Data[2] DisplayLabel.Text = Key KeyPicker.Value = Key if ModeButtons[Mode] then ModeButtons[Mode]:Select() end KeyPicker:Update() end
        function KeyPicker:OnClick(Callback) KeyPicker.Clicked = Callback end
        function KeyPicker:OnChanged(Callback) KeyPicker.Changed = Callback Callback(KeyPicker.Value) end
        if ParentObj.Addons then table.insert(ParentObj.Addons, KeyPicker) end
        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then ParentObj:SetValue(not ParentObj.Value) end
            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end
        local Picking = false
        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if Picking then return end
                Picking = true
                DisplayLabel.Text = ''
                local Break
                local Text = ''
                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then Text = '' end
                        Text = Text .. '.'
                        DisplayLabel.Text = Text
                        wait(0.4)
                    end
                end)
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do RenderStepped:Wait() end
                local Event
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key
                    if Input.KeyCode == Enum.KeyCode.Escape then Key = 'None'
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then Key = Input.KeyCode.Name
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then Key = 'MB1'
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then Key = 'MB2' end
                    Break = true Picking = false
                    if Key then
                        DisplayLabel.Text = Key
                        KeyPicker.Value = Key
                        Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                        Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)
                    end
                    Library:AttemptSave()
                    Event:Disconnect()
                end)
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = not ModeSelectOuter.Visible
            end
        end)
        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value
                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1 or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled KeyPicker:DoClick()
                        end
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard and Key ~= 'None' then
                        if Input.KeyCode.Name == Key then KeyPicker.Toggled = not KeyPicker.Toggled KeyPicker:DoClick() end
                    end
                end
                KeyPicker:Update()
            end
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and ModeSelectOuter.Visible then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then ModeSelectOuter.Visible = false end
            end
        end))
        Library:GiveSignal(InputService.InputEnded:Connect(function(Input) if (not Picking) then KeyPicker:Update() end end))
        KeyPicker:Update()
        Options[Idx] = KeyPicker
        return self
    end

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...) return Funcs[Key](...); end;
end;
-- BASE GROUPBOX
local BaseGroupbox = {};
do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1, 0, 0, Size); ZIndex = 1; Parent = self.Container; });
    end;

    function Funcs:AddLabel(Text, DoesWrap, StartImage, EndImage, StartImageColor, EndImageColor, StartImageOffset, EndImageOffset)
        local Label = {}; local Groupbox = self; local Container = Groupbox.Container;
        if type(DoesWrap) == 'table' then
            local opts = DoesWrap
            DoesWrap = opts.Wrap; StartImage = opts.StartImage; EndImage = opts.EndImage
            StartImageColor = opts.StartImageColor; EndImageColor = opts.EndImageColor
            StartImageOffset = opts.StartImageOffset; EndImageOffset = opts.EndImageOffset
        end
        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15); TextSize = 14; Text = Text;
            TextWrapped = DoesWrap or false, TextXAlignment = Enum.TextXAlignment.Left;
            StartImage = StartImage; EndImage = EndImage;
            StartImageColor = StartImageColor; EndImageColor = EndImageColor;
            StartImageOffset = StartImageOffset; EndImageOffset = EndImageOffset;
            ZIndex = 5; Parent = Container;
        });
        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', { Padding = UDim.new(0, 4); FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Enum.HorizontalAlignment.Right; SortOrder = Enum.SortOrder.LayoutOrder; Parent = TextLabel; });
        end
        Label.TextLabel = TextLabel; Label.Container = Container;
        function Label:SetText(Text)
            TextLabel.Text = Text
            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end
            Groupbox:Resize();
        end
        if (not DoesWrap) then setmetatable(Label, BaseAddons) end;
        Groupbox:AddBlank(5); Groupbox:Resize();
        return Label;
    end;

    function Funcs:AddButton(...)
        local Button = {}; local Idx = nil
        local function ProcessButtonParams(Obj, ...)
            local first = select(1, ...); local second = select(2, ...)
            if type(first) == 'string' and type(second) == 'table' then
                Idx = first
                Obj.Text = second.Text or first; Obj.Func = second.Func
                Obj.DoubleClick = second.DoubleClick; Obj.Tooltip = second.Tooltip
                Obj.SaveState = second.SaveState; Obj.Value = second.Default
                Obj.StartImage = second.StartImage; Obj.EndImage = second.EndImage
                Obj.StartImageColor = second.StartImageColor; Obj.EndImageColor = second.EndImageColor
                Obj.StartImageOffset = second.StartImageOffset; Obj.EndImageOffset = second.EndImageOffset
            elseif type(first) == 'table' then
                Obj.Text = first.Text; Obj.Func = first.Func
                Obj.DoubleClick = first.DoubleClick; Obj.Tooltip = first.Tooltip
                Obj.SaveState = first.SaveState; Obj.Value = first.Default
                Obj.StartImage = first.StartImage; Obj.EndImage = first.EndImage
                Obj.StartImageColor = first.StartImageColor; Obj.EndImageColor = first.EndImageColor
                Obj.StartImageOffset = first.StartImageOffset; Obj.EndImageOffset = first.EndImageOffset
            else Obj.Text = first; Obj.Func = second end
            local third = select(3, ...)
            if type(third) == 'table' then
                Obj.SaveState = third.SaveState
                Obj.StartImage = third.StartImage; Obj.EndImage = third.EndImage
                Obj.StartImageColor = third.StartImageColor; Obj.EndImageColor = third.EndImageColor
                Obj.StartImageOffset = third.StartImageOffset; Obj.EndImageOffset = third.EndImageOffset
                if third.Default ~= nil then Obj.Value = third.Default end
            end
        end
        ProcessButtonParams(Button, ...)
        Button.Type = 'Button'
        if Button.SaveState == nil then Button.SaveState = false end
        if Button.Value == nil then Button.Value = false end
        assert(type(Button.Func) == 'function', 'AddButton: `Func` callback is missing.');
        local Groupbox = self; local Container = Groupbox.Container;
        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(1, -4, 0, 20); ZIndex = 5; Active = true; });
            local Inner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; ClipsDescendants = true; Parent = Outer; });
            local Ripple = Library:Create('Frame', { BackgroundColor3 = Color3.new(1, 1, 1); BackgroundTransparency = 1; BorderSizePixel = 0; AnchorPoint = Vector2.new(0.5, 0.5); Position = UDim2.new(0.5, 0, 0.5, 0); Size = UDim2.new(0, 0, 0, 0); ZIndex = 7; Parent = Inner; });
            Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = Ripple });
            local Label = Library:CreateLabel({ Size = UDim2.new(1, 0, 1, 0); TextSize = 14; Text = Button.Text; StartImage = Button.StartImage; EndImage = Button.EndImage; StartImageColor = Button.StartImageColor; EndImageColor = Button.EndImageColor; StartImageOffset = Button.StartImageOffset; EndImageOffset = Button.EndImageOffset; ZIndex = 6; Parent = Inner; });
            Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) }); Rotation = 90; Parent = Inner; });
            Library:AddToRegistry(Outer, { BorderColor3 = 'OutlineColor'; });
            Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
            Library:OnHighlight(Outer, Outer, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'OutlineColor' });
            return Outer, Inner, Label, Ripple
        end
        local function PlayRipple(Ripple)
            if not Ripple or not Ripple.Parent then return end
            local parent = Ripple.Parent; local maxSize = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y)
            Ripple.Size = UDim2.fromOffset(0, 0); Ripple.BackgroundTransparency = 0.35
            TweenService:Create(Ripple, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(maxSize * 1.4, maxSize * 1.4), BackgroundTransparency = 1 }):Play()
        end
        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...) if type(validator) == 'function' and validator(...) then bindable:Fire(true) else bindable:Fire(false) end end)
                task.delay(timeout, function() connection:disconnect() bindable:Fire(false) end)
                return bindable.Event:Wait()
            end
            local function ValidateClick(Input) if Library:MouseIsOverOpenedFrame() then return false end if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return false end return true end
            Button.Outer.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then Library.BindSystem:Open(Button) return end
                if not ValidateClick(Input) then return end
                if Button.Locked then return end
                PlayRipple(Button.Ripple)
                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label); Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })
                    Button.Label.TextColor3 = Library.AccentColor; Button.Label.Text = 'Are you sure?'; Button.Locked = true
                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)
                    Library:RemoveFromRegistry(Button.Label); Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })
                    Button.Label.TextColor3 = Library.FontColor; Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)
                    if clicked then PlayRipple(Button.Ripple) Library:SafeCallback(Button.Func) end
                    return
                end
                if Button.SaveState then Button:SetValue(not Button.Value) end
                Library:SafeCallback(Button.Func)
            end)
        end
        Button.Outer, Button.Inner, Button.Label, Button.Ripple = CreateBaseButton(Button)
        Button.Outer.Parent = Container
        function Button:SetValue(Bool)
            Bool = not not Bool; Button.Value = Bool
            local Reg = Library.RegistryMap[Button.Inner]
            if Reg then Reg.Properties.BackgroundColor3 = Bool and 'AccentColor' or 'MainColor' end
            Button.Inner.BackgroundColor3 = Bool and Library.AccentColor or Library.MainColor
            Library:SafeCallback(Button.Callback, Bool); Library:SafeCallback(Button.Changed, Bool)
        end
        function Button:OnChanged(Func) Button.Changed = Func Func(Button.Value) end
        InitEvents(Button)
        function Button:AddTooltip(tooltip) if type(tooltip) == 'string' then Library:AddToolTip(tooltip, self.Outer) end return self end
        function Button:AddButton(...)
            local SubButton = {}
            ProcessButtonParams(SubButton, ...)
            SubButton.Type = 'Button'
            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)
            SubButton.Outer, SubButton.Inner, SubButton.Label, SubButton.Ripple = CreateBaseButton(SubButton)
            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer
            function SubButton:AddTooltip(tooltip) if type(tooltip) == 'string' then Library:AddToolTip(tooltip, self.Outer) end return SubButton end
            if type(SubButton.Tooltip) == 'string' then SubButton:AddTooltip(SubButton.Tooltip) end
            InitEvents(SubButton)
            return SubButton
        end
        if type(Button.Tooltip) == 'string' then Button:AddTooltip(Button.Tooltip) end
        Groupbox:AddBlank(5); Groupbox:Resize()
        if Idx then Options[Idx] = Button end
        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self; local Container = self.Container
        Groupbox:AddBlank(2);
        local DividerOuter = Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(1, -4, 0, 5); ZIndex = 5; Parent = Container; });
        local DividerInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = DividerOuter; });
        Library:AddToRegistry(DividerOuter, { BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(DividerInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Groupbox:AddBlank(9); Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')
        local Textbox = { Value = Info.Default or ''; Numeric = Info.Numeric or false; Finished = Info.Finished or false; Type = 'Input'; Callback = Info.Callback or function(Value) end; };
        local Groupbox = self; local Container = Groupbox.Container;
        Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 15); TextSize = 14; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; StartImage = Info.StartImage; EndImage = Info.EndImage; StartImageColor = Info.StartImageColor; EndImageColor = Info.EndImageColor; StartImageOffset = Info.StartImageOffset; EndImageOffset = Info.EndImageOffset; ZIndex = 5; Parent = Container; });
        Groupbox:AddBlank(1);
        local TextBoxOuter = Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(1, -4, 0, 20); ZIndex = 5; Parent = Container; });
        local TextBoxInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = TextBoxOuter; });
        Library:AddToRegistry(TextBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:OnHighlight(TextBoxOuter, TextBoxOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'OutlineColor' });
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, TextBoxOuter) end
        Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) }); Rotation = 90; Parent = TextBoxInner; });
        local Container = Library:Create('Frame', { BackgroundTransparency = 1; ClipsDescendants = true; Position = UDim2.new(0, 5, 0, 0); Size = UDim2.new(1, -5, 1, 0); ZIndex = 7; Parent = TextBoxInner; })
        local Box = Library:Create('TextBox', { BackgroundTransparency = 1; Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 1, 0); Font = Library.Font; PlaceholderColor3 = Color3.fromRGB(190, 190, 190); PlaceholderText = Info.Placeholder or ''; Text = Info.Default or ''; TextColor3 = Library.FontColor; TextSize = 14; TextStrokeTransparency = 0; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 7; RichText = true; Parent = Container; });
        Library:ApplyTextStroke(Box);
        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then Text = Text:sub(1, Info.MaxLength) end
            if Textbox.Numeric then if (not tonumber(Text)) and Text:len() > 0 then Text = Textbox.Value end end
            Textbox.Value = Text; Box.Text = Text
            Library:SafeCallback(Textbox.Callback, Textbox.Value); Library:SafeCallback(Textbox.Changed, Textbox.Value)
        end
        if Textbox.Finished then Box.FocusLost:Connect(function(enter) if not enter then return end Textbox:SetValue(Box.Text) Library:AttemptSave() end)
        else Box:GetPropertyChangedSignal('Text'):Connect(function() Textbox:SetValue(Box.Text) Library:AttemptSave() end) end
        local function Update()
            local PADDING = 2; local reveal = Container.AbsoluteSize.X
            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X
                    local currentCursorPos = Box.Position.X.Offset + width
                    if currentCursorPos < PADDING then Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0) end
                end
            end
        end
        task.spawn(Update)
        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update); Box.Focused:Connect(Update)
        Library:AddToRegistry(Box, { TextColor3 = 'FontColor'; });
        function Textbox:OnChanged(Func) Textbox.Changed = Func Func(Textbox.Value) end
        Groupbox:AddBlank(5); Groupbox:Resize()
        Options[Idx] = Textbox
        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')
        local Toggle = { Value = Info.Default or false; Type = 'Toggle'; Callback = Info.Callback or function(Value) end; Addons = {}, Risky = Info.Risky, };
        local Groupbox = self; local Container = Groupbox.Container;
        local ToggleOuter = Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(0, 13, 0, 13); ZIndex = 5; Active = true; Parent = Container; });
        Library:AddToRegistry(ToggleOuter, { BorderColor3 = 'OutlineColor'; });
        local ToggleInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = ToggleOuter; });
        Library:AddToRegistry(ToggleInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        local ToggleLabel = Library:CreateLabel({ Size = UDim2.new(0, 216, 1, 0); Position = UDim2.new(1, 6, 0, 0); TextSize = 14; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; StartImage = Info.StartImage; EndImage = Info.EndImage; StartImageColor = Info.StartImageColor; EndImageColor = Info.EndImageColor; StartImageOffset = Info.StartImageOffset; EndImageOffset = Info.EndImageOffset; ZIndex = 6; Parent = ToggleInner; });
        Library:Create('UIListLayout', { Padding = UDim.new(0, 4); FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Enum.HorizontalAlignment.Right; SortOrder = Enum.SortOrder.LayoutOrder; Parent = ToggleLabel; });
        local ToggleRegion = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(0, 170, 1, 0); ZIndex = 8; Active = true; Parent = ToggleOuter; });
        Library:OnHighlight(ToggleRegion, ToggleOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'OutlineColor' });
        function Toggle:UpdateColors() Toggle:Display() end
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, ToggleRegion) end
        function Toggle:Display()
            ToggleInner.BackgroundColor3 = Toggle.Value and Library.AccentColor or Library.MainColor
            ToggleInner.BorderColor3 = Toggle.Value and Library.AccentColorDark or Library.OutlineColor
            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor'
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor'
        end
        function Toggle:OnChanged(Func) Toggle.Changed = Func Func(Toggle.Value) end
        function Toggle:SetValue(Bool)
            Bool = (not not Bool); Toggle.Value = Bool; Toggle:Display()
            for _, Addon in next, Toggle.Addons do if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then Addon.Toggled = Bool Addon:Update() end end
            Library:SafeCallback(Toggle.Callback, Toggle.Value); Library:SafeCallback(Toggle.Changed, Toggle.Value); Library:UpdateDependencyBoxes()
        end
        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then Toggle:SetValue(not Toggle.Value) Library:AttemptSave()
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then Library.BindSystem:Open(Toggle) end
        end)
        if Toggle.Risky then Library:RemoveFromRegistry(ToggleLabel) ToggleLabel.TextColor3 = Library.RiskColor Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' }) end
        Toggle:Display()
        Groupbox:AddBlank(Info.BlankSize or 5 + 2); Groupbox:Resize()
        Toggle.TextLabel = ToggleLabel; Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)
        Toggles[Idx] = Toggle
        Library:UpdateDependencyBoxes()
        return Toggle
    end

    -- [FIX] SLIDER — использует реальную ширину (AbsoluteSize.X), не фиксированные 232px
    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');
        local Slider = { Value = Info.Default; Min = Info.Min; Max = Info.Max; Rounding = Info.Rounding; Type = 'Slider'; Text = Info.Text; Callback = Info.Callback or function(Value) end; };
        local Groupbox = self; local Container = Groupbox.Container;
        if not Info.Compact then
            Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 10); TextSize = 14; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Bottom; StartImage = Info.StartImage; EndImage = Info.EndImage; StartImageColor = Info.StartImageColor; EndImageColor = Info.EndImageColor; StartImageOffset = Info.StartImageOffset; EndImageOffset = Info.EndImageOffset; ZIndex = 5; Parent = Container; });
            Groupbox:AddBlank(3)
        end
        local SliderOuter = Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(1, -4, 0, 13); ZIndex = 5; Active = true; Parent = Container; });
        Library:AddToRegistry(SliderOuter, { BorderColor3 = 'OutlineColor'; });
        local SliderInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Active = true; Parent = SliderOuter; });
        Library:AddToRegistry(SliderInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        local Fill = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderColor3 = Library.AccentColorDark; Size = UDim2.new(0, 0, 1, 0); ZIndex = 7; Parent = SliderInner; });
        Library:AddToRegistry(Fill, { BackgroundColor3 = 'AccentColor'; BorderColor3 = 'AccentColorDark'; });
        local HideBorderRight = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Position = UDim2.new(1, 0, 0, 0); Size = UDim2.new(0, 1, 1, 0); ZIndex = 8; Parent = Fill; });
        Library:AddToRegistry(HideBorderRight, { BackgroundColor3 = 'AccentColor'; });
        local DisplayLabel = Library:CreateLabel({ Size = UDim2.new(1, 0, 1, 0); TextSize = 14; Text = 'Infinite'; ZIndex = 9; Parent = SliderInner; });
        Library:OnHighlight(SliderOuter, SliderOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'OutlineColor' });
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, SliderOuter) end
        function Slider:UpdateColors() Fill.BackgroundColor3 = Library.AccentColor Fill.BorderColor3 = Library.AccentColorDark end
        function Slider:Display()
            local Suffix = Info.Suffix or ''
            if Info.Compact then DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix) end
            -- [FIX] используем реальную ширину, а не 232
            local actualWidth = SliderInner.AbsoluteSize.X
            if actualWidth <= 0 then actualWidth = 232 end
            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, actualWidth))
            Fill.Size = UDim2.new(0, X, 1, 0)
            HideBorderRight.Visible = not (X >= actualWidth or X == 0)
        end
        function Slider:OnChanged(Func) Slider.Changed = Func Func(Slider.Value) end
        local function Round(Value) if Slider.Rounding == 0 then return math.floor(Value) end return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value)) end
        function Slider:GetValueFromXOffset(X)
            local actualWidth = SliderInner.AbsoluteSize.X
            if actualWidth <= 0 then actualWidth = 232 end
            return Round(Library:MapValue(X, 0, actualWidth, Slider.Min, Slider.Max))
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
                local actualWidth = SliderInner.AbsoluteSize.X
                if actualWidth <= 0 then actualWidth = 232 end
                local mPos = Mouse.X
                local gPos = Fill.Size.X.Offset
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos)
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, actualWidth)
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
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                Library.BindSystem:Open(Slider)
            end
        end)
        Slider:Display()
        Slider.Container = Container
        Groupbox:AddBlank(Info.BlankSize or 6); Groupbox:Resize()
        Options[Idx] = Slider
        -- [FIX] пересчёт при ресайзе окна
        if SliderInner then
            SliderInner:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() Slider:Display() end)
        end
        return Slider
    end

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then Info.Values = GetPlayersString() Info.AllowNull = true
        elseif Info.SpecialType == 'Team' then Info.Values = GetTeamsString() Info.AllowNull = true end
        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value.')
        if (not Info.Text) then Info.Compact = true end
        local Dropdown = { Values = Info.Values; Value = Info.Multi and {}; Multi = Info.Multi; Type = 'Dropdown'; Text = Info.Text or ''; SpecialType = Info.SpecialType; Callback = Info.Callback or function(Value) end; };
        local Groupbox = self; local Container = Groupbox.Container;
        if not Info.Compact then
            Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 10); TextSize = 14; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Bottom; StartImage = Info.StartImage; EndImage = Info.EndImage; StartImageColor = Info.StartImageColor; EndImageColor = Info.EndImageColor; StartImageOffset = Info.StartImageOffset; EndImageOffset = Info.EndImageOffset; ZIndex = 5; Parent = Container; });
            Groupbox:AddBlank(3)
        end
        local DropdownOuter = Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(1, -4, 0, 20); ZIndex = 5; Active = true; Parent = Container; });
        Library:AddToRegistry(DropdownOuter, { BorderColor3 = 'OutlineColor'; });
        local DropdownInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Parent = DropdownOuter; });
        Library:AddToRegistry(DropdownInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) }); Rotation = 90; Parent = DropdownInner; });
        local DropdownArrow = Library:Create('ImageLabel', { AnchorPoint = Vector2.new(0, 0.5); BackgroundTransparency = 1; Position = UDim2.new(1, -16, 0.5, 0); Size = UDim2.new(0, 12, 0, 12); Image = 'http://www.roblox.com/asset/?id=6282522798'; ZIndex = 8; Parent = DropdownInner; });
        local ItemList = Library:CreateLabel({ Position = UDim2.new(0, 5, 0, 0); Size = UDim2.new(1, -5, 1, 0); TextSize = 14; Text = '--'; TextXAlignment = Enum.TextXAlignment.Left; TextWrapped = true; ZIndex = 7; Parent = DropdownInner; });
        Library:OnHighlight(DropdownOuter, DropdownOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'OutlineColor' });
        if type(Info.Tooltip) == 'string' then Library:AddToolTip(Info.Tooltip, DropdownOuter) end
        local MAX_DROPDOWN_ITEMS = 8;
        local ListOuter = Library:Create('Frame', { BackgroundColor3 = Color3.new(0, 0, 0); BorderColor3 = Color3.new(0, 0, 0); ZIndex = 220; Visible = false; Parent = getScreenGui(DropdownOuter), });
        local function RecalculateListPosition() ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1) end
        local function RecalculateListSize(YSize) ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2)) end
        RecalculateListPosition(); RecalculateListSize()
        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition)
        local ListInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; BorderSizePixel = 0; Size = UDim2.new(1, 0, 1, 0); ZIndex = 221; Parent = ListOuter; });
        Library:AddToRegistry(ListInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        local Scrolling = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; CanvasSize = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, 0); ZIndex = 221; Parent = ListInner; TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png'; BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png'; ScrollBarThickness = 3; ScrollBarImageColor3 = Library.AccentColor, });
        Library:AddToRegistry(Scrolling, { ScrollBarImageColor3 = 'AccentColor' })
        Library:Create('UIListLayout', { Padding = UDim.new(0, 0); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Scrolling; });
        function Dropdown:Display()
            local Values = Dropdown.Values; local Str = ''
            if Info.Multi then
                for Idx, Value in next, Values do if Dropdown.Value[Value] then Str = Str .. Value .. ', ' end end
                Str = Str:sub(1, #Str - 2)
            else Str = Dropdown.Value or '' end
            ItemList.Text = (Str == '' and '--' or Str)
        end
        function Dropdown:GetActiveValues()
            if Info.Multi then local T = {} for Value, Bool in next, Dropdown.Value do table.insert(T, Value) end return T
            else return Dropdown.Value and 1 or 0 end
        end
        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values; local Buttons = {}
            for _, Element in next, Scrolling:GetChildren() do if not Element:IsA('UIListLayout') then Element:Destroy() end end
            local Count = 0
            for Idx, Value in next, Values do
                local Table = {}; Count = Count + 1
                local Button = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Middle; Size = UDim2.new(1, -1, 0, 20); ZIndex = 223; Active = true, Parent = Scrolling; });
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
                local ButtonLabel = Library:CreateLabel({ Active = false; Size = UDim2.new(1, -6, 1, 0); Position = UDim2.new(0, 6, 0, 0); TextSize = 14; Text = Value; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 225; Parent = Button; });
                Library:OnHighlight(Button, Button, { BorderColor3 = 'AccentColor', ZIndex = 224 }, { BorderColor3 = 'OutlineColor', ZIndex = 223 })
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
                            if Info.Multi then Selected = Try if Selected then Dropdown.Value[Value] = true else Dropdown.Value[Value] = nil end
                            else
                                Selected = Try
                                if Selected then Dropdown.Value = Value else Dropdown.Value = nil end
                                for _, OtherButton in next, Buttons do OtherButton:UpdateButton() end
                            end
                            Table:UpdateButton(); Dropdown:Display()
                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value); Library:SafeCallback(Dropdown.Changed, Dropdown.Value); Library:AttemptSave()
                        end
                    end
                end)
                Table:UpdateButton(); Dropdown:Display(); Buttons[Button] = Table
            end
            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1)
            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1
            RecalculateListSize(Y)
        end
        function Dropdown:SetValues(NewValues) if NewValues then Dropdown.Values = NewValues end Dropdown:BuildDropdownList() end
        function Dropdown:OpenDropdown() ListOuter.Visible = true Library.OpenedFrames[ListOuter] = true DropdownArrow.Rotation = 180 end
        function Dropdown:CloseDropdown() ListOuter.Visible = false Library.OpenedFrames[ListOuter] = nil DropdownArrow.Rotation = 0 end
        function Dropdown:OnChanged(Func) Dropdown.Changed = Func Func(Dropdown.Value) end
        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {}
                for Value, Bool in next, Val do if table.find(Dropdown.Values, Value) then nTable[Value] = true end end
                Dropdown.Value = nTable
            else
                if (not Val) then Dropdown.Value = nil
                elseif table.find(Dropdown.Values, Val) then Dropdown.Value = Val end
            end
            Dropdown:BuildDropdownList()
            Library:SafeCallback(Dropdown.Callback, Dropdown.Value); Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
        end
        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then Dropdown:CloseDropdown() else Dropdown:OpenDropdown() end
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then Library.BindSystem:Open(Dropdown) end
        end)
        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize
                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then Dropdown:CloseDropdown() end
            end
        end)
        Dropdown.Container = Container
        Dropdown:BuildDropdownList(); Dropdown:Display()
        local Defaults = {}
        if type(Info.Default) == 'string' then local Idx = table.find(Dropdown.Values, Info.Default) if Idx then table.insert(Defaults, Idx) end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do local Idx = table.find(Dropdown.Values, Value) if Idx then table.insert(Defaults, Idx) end end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then table.insert(Defaults, Info.Default) end
        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then Dropdown.Value[Dropdown.Values[Index]] = true else Dropdown.Value = Dropdown.Values[Index] end
                if (not Info.Multi) then break end
            end
            Dropdown:BuildDropdownList(); Dropdown:Display()
        end
        Groupbox:AddBlank(Info.BlankSize or 5); Groupbox:Resize()
        Options[Idx] = Dropdown
        return Dropdown
    end

    function Funcs:AddDependencyBox()
        local Depbox = { Dependencies = {}; }
        local Groupbox = self; local Container = Groupbox.Container
        local Holder = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1, 0, 0, 0); Visible = false; Parent = Container; })
        local Frame = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1, 0, 1, 0); Visible = true; Parent = Holder; })
        local Layout = Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Frame; })
        function Depbox:Resize() Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y) Groupbox:Resize() end
        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Depbox:Resize() end)
        Holder:GetPropertyChangedSignal('Visible'):Connect(function() Depbox:Resize() end)
        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1]; local Value = Dependency[2]
                if Elem.Type == 'Toggle' and Elem.Value ~= Value then Holder.Visible = false Depbox:Resize() return end
            end
            Holder.Visible = true; Depbox:Resize()
        end
        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.')
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.')
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.')
            end
            Depbox.Dependencies = Dependencies; Depbox:Update()
        end
        Depbox.Container = Frame
        setmetatable(Depbox, BaseGroupbox)
        table.insert(Library.DependencyBoxes, Depbox)
        return Depbox
    end

    function Funcs:AddKeybind(Idx, Info)
        assert(Info.Text, 'AddKeybind: Missing `Text` string.');
        local Keybind = { Value = Info.Default or 'None'; Type = 'Keybind'; Text = Info.Text; ChangedCallback = Info.ChangedCallback or function(Key) end; Callback = Info.Callback or function(Key) end; };
        local Groupbox = self; local Container = Groupbox.Container;
        Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 10); TextSize = 14; Text = Info.Text; TextXAlignment = Enum.TextXAlignment.Left; TextYAlignment = Enum.TextYAlignment.Bottom; StartImage = Info.StartImage; EndImage = Info.EndImage; StartImageColor = Info.StartImageColor; EndImageColor = Info.EndImageColor; StartImageOffset = Info.StartImageOffset; EndImageOffset = Info.EndImageOffset; ZIndex = 5; Parent = Container; })
        Groupbox:AddBlank(3)
        local BoxOuter = Library:Create('Frame', { BackgroundColor3 = Library.OutlineColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(1, -4, 0, 20); ZIndex = 5; Active = true; Parent = Container; });
        Library:AddToRegistry(BoxOuter, { BorderColor3 = 'OutlineColor'; });
        local BoxInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 6; Active = true; ClipsDescendants = true; Parent = BoxOuter; });
        Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212)) }); Rotation = 90; Parent = BoxInner; })
        local Label = Library:CreateLabel({ Position = UDim2.new(0, 6, 0, 0); Size = UDim2.new(1, -12, 1, 0); TextSize = 14; Text = Keybind.Value; TextXAlignment = Enum.TextXAlignment.Left; TextTruncate = Enum.TextTruncate.AtEnd; ZIndex = 8; Parent = BoxInner; })
        Library:OnHighlight(BoxOuter, BoxOuter, { BorderColor3 = 'AccentColor' }, { BorderColor3 = 'OutlineColor' })
        function Keybind:SetValue(Key) Keybind.Value = Key Label.Text = Key Library:SafeCallback(Keybind.Callback, Key) Library:SafeCallback(Keybind.ChangedCallback, Key) end
        function Keybind:OnChanged(Func) Keybind.ChangedCallback = Func Func(Keybind.Value) end
        function Keybind:OnClick(Func) Keybind.Callback = Func end
        local Picking = false
        BoxInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then Library.BindSystem:Open(Keybind) return end
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if Picking then return end
            Picking = true; Label.Text = '...'
            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do RenderStepped:Wait() end
            local done = false; local conn
            conn = InputService.InputBegan:Connect(function(i)
                if done then return end
                local key
                if i.UserInputType == Enum.UserInputType.Keyboard then
                    if i.KeyCode == Enum.KeyCode.Escape then key = 'None' else key = i.KeyCode.Name end
                elseif i.UserInputType == Enum.UserInputType.MouseButton1 then key = 'MB1'
                elseif i.UserInputType == Enum.UserInputType.MouseButton2 then key = 'MB2'
                elseif i.UserInputType == Enum.UserInputType.MouseButton3 then key = 'MB3' end
                if key then done = true conn:Disconnect() Picking = false Keybind:SetValue(key) end
            end)
        end)
        Keybind.Container = Container
        Groupbox:AddBlank(5); Groupbox:Resize()
        Options[Idx] = Keybind
        return Keybind
    end

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...) return Funcs[Key](...); end;

    function Library:CreateMiniGroupbox(parent, title)
        local Outer = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 0, 0); ZIndex = 210; Parent = parent; })
        local Inner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(1, -2, 1, -2); Position = UDim2.fromOffset(1, 1); ZIndex = 211; Parent = Outer; })
        local Highlight = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1, 0, 0, 2); ZIndex = 212; Parent = Inner; })
        if title then Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 18); Position = UDim2.fromOffset(4, 2); TextSize = 14; Text = title; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 213; Parent = Inner; }) end
        local Container = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 4, 0, title and 20 or 4); Size = UDim2.new(1, -4, 1, title and -20 or -4); ZIndex = 211; Parent = Inner; })
        Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Container; })
        local GB = { Container = Container; Outer = Outer; }
        setmetatable(GB, BaseGroupbox)
        function GB:Resize()
            local Size = 0
            for _, Element in next, Container:GetChildren() do if (not Element:IsA('UIListLayout')) and Element.Visible then Size = Size + Element.Size.Y.Offset end end
            Outer.Size = UDim2.new(1, 0, 0, (title and 20 or 4) + Size + 4)
        end
        GB:AddBlank(3); GB:Resize()
        return GB
    end
end;

-- BIND SYSTEM
Library.BindSystem = Library.BindSystem or {}
local BindSystem = Library.BindSystem
BindSystem.Windows = {}; BindSystem.AllBindings = {}; BindSystem._idxCounter = 0
local function NextBindIdx() BindSystem._idxCounter = BindSystem._idxCounter + 1 return 'Bind_' .. BindSystem._idxCounter end
local function GetBindInputName(Input)
    if Input.UserInputType == Enum.UserInputType.Keyboard then return Input.KeyCode.Name
    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then return 'MB1'
    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then return 'MB2'
    elseif Input.UserInputType == Enum.UserInputType.MouseButton3 then return 'MB3' end
    return nil
end
BindSystem.GetKeyName = GetBindInputName
function BindSystem:IsKeyDown(name)
    if name == 'MB1' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
    if name == 'MB2' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    if name == 'MB3' then return InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton3) end
    local kc = Enum.KeyCode[name] return kc and InputService:IsKeyDown(kc) or false
end
function BindSystem:GetDefaultValue(control)
    if control.Type == 'Toggle' then return not control.Value end
    if control.Type == 'Dropdown' then if control.Values and #control.Values > 0 then return control.Values[1] end return nil end
    if control.Type == 'Slider' then return control.Value end
    return nil
end
function BindSystem:ApplyTrigger(binding, pressed)
    local control = binding.Control; if not control then return end
    local value = binding.Value; local mode = binding.Mode
    if control.Type == 'Button' then if pressed then Library:SafeCallback(control.Func) end return end
    if control.Type == 'Keybind' then if pressed then Library:SafeCallback(control.Callback, true) end return end
    if control.Type == 'Toggle' then
        if mode == 'Hold' then
            if pressed then binding._prevValue = control.Value control:SetValue(value)
            else if binding._prevValue ~= nil then control:SetValue(binding._prevValue) binding._prevValue = nil end end
        elseif mode == 'Always' then if pressed then control:SetValue(value) end
        else
            if pressed then
                if control.Value == value then
                    if binding._prevValue ~= nil then control:SetValue(binding._prevValue) binding._prevValue = nil
                    else control:SetValue(not value) end
                else binding._prevValue = control.Value control:SetValue(value) end
            end
        end
    elseif control.Type == 'Slider' then
        if mode == 'Hold' then
            if pressed then binding._prevValue = control.Value control:SetValue(value)
            else if binding._prevValue ~= nil then control:SetValue(binding._prevValue) binding._prevValue = nil end end
        else if pressed then control:SetValue(value) end end
    elseif control.Type == 'Dropdown' then
        if mode == 'Hold' then
            if pressed then binding._prevValue = control.Value control:SetValue(value)
            else if binding._prevValue ~= nil then control:SetValue(binding._prevValue) binding._prevValue = nil end end
        elseif mode == 'Toggle' then
            if pressed then
                if control.Value == value then
                    if binding._prevValue ~= nil then control:SetValue(binding._prevValue) binding._prevValue = nil
                    else control:SetValue(nil) end
                else binding._prevValue = control.Value control:SetValue(value) end
            end
        else if pressed then control:SetValue(value) end end
    end
    Library:AttemptSave()
end
function BindSystem:HandleInput(Input, pressed)
    local name = GetBindInputName(Input); if not name then return end
    for _, binding in ipairs(self.AllBindings) do
        if binding.Key == name then
            if pressed then if not binding._down then binding._down = true self:ApplyTrigger(binding, true) end
            else if binding._down then binding._down = false if binding.Mode == 'Hold' then self:ApplyTrigger(binding, false) end end end
        end
    end
end
function BindSystem:CloseWindow(control) local win = self.Windows[control] if win then if win.Parent then win:Destroy() end self.Windows[control] = nil end end
function BindSystem:CloseAllWindows() local keys = {} for k in pairs(self.Windows) do table.insert(keys, k) end for _, k in ipairs(keys) do self:CloseWindow(k) end end
function BindSystem:BuildBindCard(Scroll, AddBtn, control, existingBinding)
    local binding = existingBinding or { Control = control, Key = 'None', Mode = 'Toggle', Value = self:GetDefaultValue(control) }
    if not existingBinding then table.insert(self.AllBindings, binding) end
    local maxOrder = 0
    for _, child in ipairs(Scroll:GetChildren()) do
        if child:IsA('GuiObject') and child ~= AddBtn then local lo = child.LayoutOrder or 0 if lo > maxOrder and lo < (AddBtn.LayoutOrder or 999999) then maxOrder = lo end end
    end
    local bindCount = 0
    for _, b in ipairs(self.AllBindings) do if b.Control == control then bindCount = bindCount + 1 end end
    local gb = Library:CreateMiniGroupbox(Scroll, 'Bind #' .. tostring(bindCount))
    gb.Outer.LayoutOrder = maxOrder + 1
    gb:AddKeybind(NextBindIdx(), { Text = 'Key', Default = binding.Key, ChangedCallback = function(key) binding.Key = key end })
    gb:AddDropdown(NextBindIdx(), { Text = 'Mode', Values = { 'Toggle', 'Hold' }, Default = binding.Mode, Callback = function(v) if v then binding.Mode = v end end })
    if control.Type == 'Toggle' then gb:AddToggle(NextBindIdx(), { Text = 'Value', Default = (type(binding.Value) == 'boolean') and binding.Value or true, Callback = function(v) binding.Value = v end })
    elseif control.Type == 'Slider' then gb:AddSlider(NextBindIdx(), { Text = 'Value', Min = control.Min, Max = control.Max, Rounding = control.Rounding, Default = (type(binding.Value) == 'number') and binding.Value or control.Value, Suffix = '', Callback = function(v) binding.Value = v end })
    elseif control.Type == 'Dropdown' then gb:AddDropdown(NextBindIdx(), { Text = 'Value', Values = control.Values, AllowNull = true, Default = binding.Value, Callback = function(v) binding.Value = v end })
    elseif control.Type == 'Button' then gb:AddLabel('Triggers button callback', true) end
    gb:AddButton('Remove bind', function()
        for i, b in ipairs(self.AllBindings) do if b == binding then table.remove(self.AllBindings, i) break end end
        gb.Outer:Destroy()
        Scroll.CanvasSize = UDim2.fromOffset(0, Scroll.UIListLayout.AbsoluteContentSize.Y + 4)
    end)
    return binding
end
function BindSystem:Open(control)
    local anyRef = control.TextLabel or control.Container or control.Outer or control.DisplayFrame
    if anyRef and getScreenGui(anyRef) == BindGui then return end
    if self.Windows[control] then self:CloseWindow(control) return end
    self:CloseAllWindows()
    local winWidth, winHeight = 260, 260
    local vpX = workspace.CurrentCamera.ViewportSize.X
    local vpY = workspace.CurrentCamera.ViewportSize.Y
    local posX = math.clamp(Mouse.X + 5, 0, math.max(0, vpX - winWidth))
    local posY = math.clamp(Mouse.Y + 5, 0, math.max(0, vpY - winHeight))
    local Outer = Library:Create('Frame', { Name = 'BindWindow'; BackgroundColor3 = Color3.new(0, 0, 0); BorderSizePixel = 0; Position = UDim2.fromOffset(posX, posY); Size = UDim2.fromOffset(winWidth, winHeight); ZIndex = 200; Parent = BindGui; })
    local Inner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderSizePixel = 0; Position = UDim2.fromOffset(1, 1); Size = UDim2.new(1, -2, 1, -2); ZIndex = 201; Parent = Outer; })
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'BackgroundColor' })
    local Header = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderSizePixel = 0; Position = UDim2.fromOffset(0, 0); Size = UDim2.new(1, 0, 0, 20); ZIndex = 202; Parent = Inner; })
    Library:AddToRegistry(Header, { BackgroundColor3 = 'MainColor' })
    local Scroll = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; Position = UDim2.fromOffset(4, 24); Size = UDim2.new(1, -8, 1, -28); CanvasSize = UDim2.new(0, 0, 0, 0); ScrollBarThickness = 3; ScrollBarImageColor3 = Library.AccentColor; TopImage = ''; BottomImage = ''; ZIndex = 202; Parent = Inner; })
    Library:AddToRegistry(Scroll, { ScrollBarImageColor3 = 'AccentColor' })
    local Layout = Library:Create('UIListLayout', { Padding = UDim.new(0, 6); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Scroll; })
    Layout.Name = 'UIListLayout'
    Library:Create('UIPadding', { PaddingLeft = UDim.new(0, 2); PaddingRight = UDim.new(0, 2); PaddingTop = UDim.new(0, 2); Parent = Scroll; })
    Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Scroll.CanvasSize = UDim2.fromOffset(0, Layout.AbsoluteContentSize.Y + 4) end)
    local AddBtn = Library:Create('Frame', { BackgroundColor3 = Color3.new(0, 0, 0); BorderSizePixel = 0; Size = UDim2.new(1, -4, 0, 20); LayoutOrder = 999999; ZIndex = 203; Active = true; Parent = Scroll; })
    local AddInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; Position = UDim2.fromOffset(1, 1); Size = UDim2.new(1, -2, 1, -2); ZIndex = 204; Parent = AddBtn; })
    Library:AddToRegistry(AddInner, { BackgroundColor3 = 'MainColor' })
    Library:CreateLabel({ Size = UDim2.new(1, 0, 1, 0); Text = '+ Add keybind'; TextSize = 13; ZIndex = 205; Parent = AddInner; })
    Library:OnHighlight(AddInner, AddInner, { BackgroundColor3 = 'AccentColor' }, { BackgroundColor3 = 'MainColor' })
    AddInner.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then self:BuildBindCard(Scroll, AddBtn, control) end end)
    Library:MakeDraggable(Outer, 22)
    for _, binding in ipairs(self.AllBindings) do if binding.Control == control then self:BuildBindCard(Scroll, AddBtn, control, binding) end end
    self.Windows[control] = Outer
end
Library:GiveSignal(InputService.InputBegan:Connect(function(Input, gp) if gp then return end BindSystem:HandleInput(Input, true) end))
Library:GiveSignal(InputService.InputEnded:Connect(function(Input) BindSystem:HandleInput(Input, false) end))
Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local keys = {} for k in pairs(BindSystem.Windows) do table.insert(keys, k) end
    for _, control in ipairs(keys) do
        local win = BindSystem.Windows[control]
        if win and win.Parent then
            local aPos, aSize = win.AbsolutePosition, win.AbsoluteSize
            if Mouse.X < aPos.X or Mouse.X > aPos.X + aSize.X or Mouse.Y < aPos.Y or Mouse.Y > aPos.Y + aSize.Y then BindSystem:CloseWindow(control) end
        end
    end
end))

-- NOTIFICATIONS / WATERMARK / KEYBIND HUD
local NotificationContainer = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0.5, 0, 1, 0); Size = UDim2.new(0, 0, 0, 0); AnchorPoint = Vector2.new(0.5, 1); ZIndex = 100; Parent = OverlayGui; });
local activeNotifications = {}
local function PlayNotifySound()
    local sound = Instance.new("Sound"); sound.SoundId = "rbxassetid://" .. Library.NotifySoundId; sound.Volume = 0.5; sound.Parent = OverlayGui
    if sound.IsLoaded then sound:Play() else sound.Loaded:Connect(function() sound:Play() end) end
    sound.Ended:Connect(function() sound:Destroy() end)
end
function Library:Notify(Text, Time)
    Time = Time or 5; PlayNotifySound()
    local XSize = Library:GetTextBounds(Text, Library.Font, 14) + 24
    local YSize = 32; local padding = 8; local totalHeight = 0
    for _, notif in ipairs(activeNotifications) do if notif.Outer and notif.Outer.Parent then totalHeight = totalHeight + notif.Outer.AbsoluteSize.Y + padding end end
    local targetY = -totalHeight - YSize - padding
    local Outer = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Size = UDim2.new(0, XSize, 0, YSize); Position = UDim2.new(0.5, -XSize/2, 1, 0); ClipsDescendants = true; ZIndex = 100; Parent = NotificationContainer; });
    table.insert(activeNotifications, { Outer = Outer, Time = Time })
    TweenService:Create(Outer, TweenInfo.new(NOTIFY_ANIMATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, -XSize/2, 1, targetY) }):Play()
    local Inner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 101; Parent = Outer; });
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);
    local InnerFrame = Library:Create('Frame', { BackgroundColor3 = Color3.new(1, 1, 1); BorderSizePixel = 0; Position = UDim2.new(0, 1, 0, 1); Size = UDim2.new(1, -2, 1, -2); ZIndex = 102; ClipsDescendants = true; Parent = Inner; });
    Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)), ColorSequenceKeypoint.new(1, Library.MainColor) }); Rotation = -90; Parent = InnerFrame; });
    Library:CreateLabel({ Position = UDim2.new(0, 8, 0, 0); Size = UDim2.new(1, -16, 1, 0); Text = Text; TextXAlignment = Enum.TextXAlignment.Center; TextSize = 14; ZIndex = 103; Parent = InnerFrame; });
    local LeftBar = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0.5, 0, 0, 2); Position = UDim2.new(0.5, 0, 1, -2); AnchorPoint = Vector2.new(1, 0); ZIndex = 104; Parent = Outer; });
    local RightBar = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(0.5, 0, 0, 2); Position = UDim2.new(0.5, 0, 1, -2); AnchorPoint = Vector2.new(0, 0); ZIndex = 104; Parent = Outer; });
    TweenService:Create(LeftBar, TweenInfo.new(Time, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
    TweenService:Create(RightBar, TweenInfo.new(Time, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
    task.delay(Time, function()
        local tweenOut = TweenService:Create(Outer, TweenInfo.new(NOTIFY_ANIMATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, -XSize/2, 1, 0) })
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            Outer:Destroy()
            for i, notif in ipairs(activeNotifications) do if notif.Outer == Outer then table.remove(activeNotifications, i) break end end
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
local function UpdateCursor() pcall(function() local mouse = LocalPlayer:GetMouse() if mouse then mouse.Icon = "rbxassetid://" .. Library.CursorImageId end end) end
local function StartCursorUpdater()
    if cursorUpdateConnection then cursorUpdateConnection:Disconnect() cursorUpdateConnection = nil end
    UpdateCursor()
    cursorUpdateConnection = RunService.Heartbeat:Connect(UpdateCursor)
    LocalPlayer.CharacterAdded:Connect(UpdateCursor)
end
task.spawn(StartCursorUpdater)
function Library:SetNotifySoundId(id) Library.NotifySoundId = id end
getgenv().SetNotifySoundId = Library.SetNotifySoundId
function Library:SetCursorImageId(id) Library.CursorImageId = id UpdateCursor() end
getgenv().SetCursorImageId = Library.SetCursorImageId

local WatermarkOuter = Library:Create('Frame', { BorderColor3 = Library.OutlineColor; Position = UDim2.new(0, 100, 0, -25); Size = UDim2.new(0, 213, 0, 20); ZIndex = 200; Visible = false; Parent = OverlayGui; });
local WatermarkInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.AccentColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 201; Parent = WatermarkOuter; });
Library:AddToRegistry(WatermarkInner, { BorderColor3 = 'AccentColor'; });
local InnerFrame = Library:Create('Frame', { BackgroundColor3 = Color3.new(1, 1, 1); BorderSizePixel = 0; Position = UDim2.new(0, 1, 0, 1); Size = UDim2.new(1, -2, 1, -2); ZIndex = 202; Parent = WatermarkInner; });
Library:Create('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Library:GetDarkerColor(Library.MainColor)), ColorSequenceKeypoint.new(1, Library.MainColor) }); Rotation = -90; Parent = InnerFrame; });
local WatermarkLabel = Library:CreateLabel({ Position = UDim2.new(0, 5, 0, 0); Size = UDim2.new(1, -4, 1, 0); TextSize = 14; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 203; Parent = InnerFrame; });
Library.Watermark = WatermarkOuter
Library.WatermarkText = WatermarkLabel
Library:MakeDraggable(Library.Watermark)

local KeybindOuter = Library:Create('Frame', { AnchorPoint = Vector2.new(0, 0.5); BorderColor3 = Library.OutlineColor; Position = UDim2.new(0, 10, 0.5, 0); Size = UDim2.new(0, 210, 0, 44); Visible = false; ZIndex = 100; Parent = OverlayGui; });
local KeybindInner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 1, 0); ZIndex = 101; Parent = KeybindOuter; });
Library:AddToRegistry(KeybindInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; }, true);
local ColorFrame = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1, 0, 0, 2); ZIndex = 102; Parent = KeybindInner; });
Library:AddToRegistry(ColorFrame, { BackgroundColor3 = 'AccentColor'; }, true);
Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 18); Position = UDim2.fromOffset(5, 4), TextXAlignment = Enum.TextXAlignment.Left, Text = 'Keybinds'; ZIndex = 103; Parent = KeybindInner; });
local KeybindContainer = Library:Create('Frame', { BackgroundTransparency = 1; Size = UDim2.new(1, 0, 1, -22); Position = UDim2.new(0, 0, 0, 22); ZIndex = 105; Parent = KeybindInner; });
Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = KeybindContainer; });
Library:Create('UIPadding', { PaddingLeft = UDim.new(0, 5), Parent = KeybindContainer; });
Library.KeybindFrame = KeybindOuter
Library.KeybindContainer = KeybindContainer
Library:MakeDraggable(KeybindOuter)

function Library:SetWatermarkVisibility(Bool) Library.Watermark.Visible = Bool end
function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 14)
    Library.Watermark.Size = UDim2.new(0, X + 15, 0, (Y * 1.5) + 3)
    Library:SetWatermarkVisibility(true)
    Library.WatermarkText.Text = Text
end

function Clear3DObjects()
    if Current3DPart then Current3DPart:Destroy() end
    if Current3DSurface then Current3DSurface:Destroy() end
    Current3DPart = nil; Current3DSurface = nil
    if Library.MainFrame and Library.MainFrame.Parent then
        pcall(function() if Library.MainFrame.Parent ~= ScreenGui then Library.MainFrame.Parent = ScreenGui end end)
    end
end
function Create3DObjects()
    Clear3DObjects()
    local Camera = workspace.CurrentCamera; if not Camera then return end
    local windowSize = Library.MainFrame and Library.MainFrame.Size or UDim2.fromOffset(550, 600)
    local partSizeX = math.max(windowSize.X.Offset / PPU, 0.1)
    local partSizeY = math.max(windowSize.Y.Offset / PPU, 0.1)
    local Part = Instance.new('Part')
    Part.Name = 'Linoria3DPart'; Part.Size = Vector3.new(partSizeX, partSizeY, 0.1)
    Part.Transparency = 1; Part.CanCollide = false; Part.Anchored = true
    Part.CFrame = Camera.CFrame * CFrame.new(0, 0, -THREED_DISTANCE)
    Part.Parent = workspace; Current3DPart = Part
    local Surface = Instance.new('SurfaceGui')
    Surface.Name = 'Linoria3DSurface'; Surface.Face = Enum.NormalId.Front
    Surface.PixelsPerStud = PPU; Surface.CanvasSize = Vector2.new(windowSize.X.Offset, windowSize.Y.Offset)
    Surface.AlwaysOnTop = true; Surface.Parent = Part; Current3DSurface = Surface
    if Library.MainFrame and Library.MainFrame.Parent then
        pcall(function() if Library.MainFrame.Parent ~= Surface then Library.MainFrame.Parent = Surface end end)
    end
end

-- [FIX] CreateWindow — с CenterTitle, TitleOffset, CenterTabs, TabsOffset, Reusable slider, UI opacity cap
function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }
    if type(...) == 'table' then Config = ...
    else Config.Title = Arguments[1] Config.AutoShow = Arguments[2] or false end
    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end
    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(550, 600) end
    if Config.BackgroundImage == nil then Config.BackgroundImage = '' end
    if type(Config.BackgroundImageTransparency) ~= 'number' then Config.BackgroundImageTransparency = 0.5 end
    if typeof(Config.BackgroundImageColor) ~= 'Color3' then Config.BackgroundImageColor = Color3.new(1,1,1) end
    if Config.Resizable == nil then Config.Resizable = false end
    if typeof(Config.MinSize) ~= 'UDim2' then Config.MinSize = UDim2.fromOffset(300, 200) end
    -- [FIX] новые опции
    if Config.CenterTitle == nil then Config.CenterTitle = false end
    if type(Config.TitleOffset) ~= 'number' then Config.TitleOffset = 0 end -- + вправо, - влево
    if Config.CenterTabs == nil then Config.CenterTabs = false end
    if type(Config.TabsOffset) ~= 'number' then Config.TabsOffset = 0 end -- + вправо, - влево
    if Config.Center then Config.AnchorPoint = Vector2.new(0.5, 0.5) Config.Position = UDim2.fromScale(0.5, 0.5) end

    local Window = { Tabs = {}; }
    local Outer = Library:Create('Frame', { AnchorPoint = Config.AnchorPoint, BackgroundColor3 = Library.OutlineColor; BorderSizePixel = 0; Position = Config.Position, Size = Config.Size; Visible = false; ZIndex = 1; Parent = ScreenGui; });
    Library.MainFrame = Outer
    table.insert(Library.UICorners, Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICornerRadius * 10), Parent = Outer }))
    Library:MakeDraggable(Outer, 25)
    local Inner = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.AccentColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.new(0, 1, 0, 1); Size = UDim2.new(1, -2, 1, -2); ZIndex = 1; Parent = Outer; });
    Library:AddToRegistry(Inner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'AccentColor'; });
    table.insert(Library.UICorners, Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICornerRadius * 10), Parent = Inner }))

    local titleHeight = 25
    local titleTextSize = Config.TitleTextSize or 16
    -- [FIX] Title с учётом CenterTitle и TitleOffset
    local WindowLabel = Library:CreateLabel({
        Position = UDim2.new(0, 7 + Config.TitleOffset, 0, 0);
        Size = UDim2.new(1, -14, 0, titleHeight);
        TextSize = titleTextSize;
        Text = Config.Title or '';
        TextXAlignment = Config.CenterTitle and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left;
        ZIndex = 2; Parent = Inner;
    });

    local MainSectionOuter = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; Position = UDim2.new(0, 8, 0, 25); Size = UDim2.new(1, -16, 1, -33); ZIndex = 1; Parent = Inner; });
    Library:AddToRegistry(MainSectionOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
    table.insert(Library.UICorners, Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICornerRadius * 10), Parent = MainSectionOuter }))
    local MainSectionInner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Position = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, 0); ZIndex = 1; Parent = MainSectionOuter; });
    Library:AddToRegistry(MainSectionInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
    table.insert(Library.UICorners, Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICornerRadius * 10), Parent = MainSectionInner }))

    -- Фон
    local BgImage = Library:Create('ImageLabel', {
        Name = 'BackgroundImage';
        BackgroundTransparency = 1; BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0); Position = UDim2.fromOffset(0, 0);
        Image = Config.BackgroundImage or '';
        ImageTransparency = Config.BackgroundImageTransparency or 0.5;
        ImageColor3 = Config.BackgroundImageColor;
        ScaleType = Enum.ScaleType.Crop;
        ZIndex = 1;
        Visible = (Config.BackgroundImage and Config.BackgroundImage ~= '') or false;
        Parent = MainSectionInner;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICornerRadius * 10); Parent = BgImage });
    Window.BackgroundImage = BgImage
    local BgOverlay = Library:Create('Frame', {
        Name = 'BackgroundOverlay';
        BackgroundColor3 = Color3.new(0, 0, 0);
        BackgroundTransparency = 1; BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0); ZIndex = 2; Parent = BgImage;
    })
    Library:Create('UICorner', { CornerRadius = UDim.new(0, Library.UICornerRadius * 10); Parent = BgOverlay })
    Window.BackgroundOverlay = BgOverlay

    -- [FIX] TabArea с CenterTabs и TabsOffset
    local TabArea = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 8, 0, 8); Size = UDim2.new(1, -16, 0, 21); ZIndex = 100; Parent = MainSectionInner; });
    local TabListLayout = Library:Create('UIListLayout', {
        Padding = UDim.new(0, Config.TabPadding);
        FillDirection = Enum.FillDirection.Horizontal;
        HorizontalAlignment = Config.CenterTabs and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = TabArea;
    });
    -- сдвиг табов
    TabArea.Position = UDim2.new(0, 8 + Config.TabsOffset, 0, 8)

    local TabContainer = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; Position = UDim2.new(0, 8, 0, 30); Size = UDim2.new(1, -16, 1, -38); ZIndex = 2; ClipsDescendants = true; Parent = MainSectionInner; });
    Library:AddToRegistry(TabContainer, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });

    function Window:SetWindowTitle(Title) WindowLabel.Text = Title end
    function Window:SetBackgroundImage(imageId, transparency)
        local bg = Window.BackgroundImage; if not bg then return end
        imageId = imageId or ''
        if imageId == '' then bg.Visible = false bg.Image = ''
        else bg.Image = imageId bg.Visible = true if type(transparency) == 'number' then bg.ImageTransparency = math.clamp(transparency, 0, 1) end end
    end
    function Window:SetBackgroundTransparency(t) if Window.BackgroundImage then Window.BackgroundImage.ImageTransparency = math.clamp(t or 0, 0, 1) end end
    function Window:SetBackgroundScaleType(st) if Window.BackgroundImage then Window.BackgroundImage.ScaleType = st or Enum.ScaleType.Crop end end
    function Window:SetBackgroundColor(c) if Window.BackgroundImage then Window.BackgroundImage.ImageColor3 = c or Color3.new(1,1,1) end end
    function Window:SetOverlayTransparency(t) if Window.BackgroundOverlay then Window.BackgroundOverlay.BackgroundTransparency = math.clamp(t or 1, 0, 1) end end

    function Window:AddTab(Name)
        if Window.Tabs[Name] then return Window.Tabs[Name] end
        local Tab = { Groupboxes = {}; Tabboxes = {}; };
        local TabButtonWidth = Library:GetTextBounds(Name, Library.Font, 16);
        local TabButton = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(0, TabButtonWidth + 8 + 4, 1, 0); ZIndex = 150; Active = true; Parent = TabArea; });
        Library:AddToRegistry(TabButton, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:CreateLabel({ Position = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, -1); Text = Name; ZIndex = 151; Parent = TabButton; });
        local Blocker = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderSizePixel = 0; Position = UDim2.new(0, 0, 1, 0); Size = UDim2.new(1, 0, 0, 1); BackgroundTransparency = 1; ZIndex = 152; Parent = TabButton; });
        Library:AddToRegistry(Blocker, { BackgroundColor3 = 'MainColor'; });
        local TabFrame = Library:Create('Frame', { Name = 'TabFrame'; BackgroundTransparency = 1; Position = UDim2.new(0, 0, 0, 0); Size = UDim2.new(1, 0, 1, 0); Visible = false; ZIndex = 2; Parent = TabContainer; });
        local LeftSide = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; Position = UDim2.new(0, 8 - 1, 0, 8 - 1); Size = UDim2.new(0.5, -12 + 2, 1, -16); CanvasSize = UDim2.new(0, 0, 0, 0); BottomImage = ''; TopImage = ''; ScrollBarThickness = 0; ZIndex = 5; Parent = TabFrame; });
        local RightSide = Library:Create('ScrollingFrame', { BackgroundTransparency = 1; BorderSizePixel = 0; Position = UDim2.new(0.5, 4 + 1, 0, 8 - 1); Size = UDim2.new(0.5, -12 + 2, 1, -16); CanvasSize = UDim2.new(0, 0, 0, 0); BottomImage = ''; TopImage = ''; ScrollBarThickness = 0; ZIndex = 5; Parent = TabFrame; });
        Library:Create('UIListLayout', { Padding = UDim.new(0, 8); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; HorizontalAlignment = Enum.HorizontalAlignment.Center; Parent = LeftSide; });
        Library:Create('UIListLayout', { Padding = UDim.new(0, 8); FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; HorizontalAlignment = Enum.HorizontalAlignment.Center; Parent = RightSide; });
        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function() Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y) end)
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
        function Tab:SetLayoutOrder(Position) TabButton.LayoutOrder = Position TabListLayout:ApplyLayout() end
        function Tab:AddGroupbox(Info)
            local Groupbox = {};
            local BoxOuter = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BackgroundTransparency = 1; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 0, 507 + 2); ZIndex = 6; Parent = Info.Side == 1 and LeftSide or RightSide; });
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
            local BoxInner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BackgroundTransparency = 1; BorderColor3 = Library.OutlineColor; Size = UDim2.new(1, -2, 1, -2); Position = UDim2.new(0, 1, 0, 1); ZIndex = 6; Parent = BoxOuter; });
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
            local Highlight = Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1, 0, 0, 2); ZIndex = 5; Parent = BoxInner; });
            Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
            Library:CreateLabel({ Size = UDim2.new(1, 0, 0, 18); Position = UDim2.new(0, 4, 0, 2); TextSize = 14; Text = Info.Name; TextXAlignment = Enum.TextXAlignment.Left; ZIndex = 7; Parent = BoxInner; });
            local Container = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 4, 0, 20); Size = UDim2.new(1, -4, 1, -20); ZIndex = 10; Parent = BoxInner; });
            Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Container; });
            function Groupbox:Resize()
                local Size = 0
                for _, Element in next, Groupbox.Container:GetChildren() do if (not Element:IsA('UIListLayout')) and Element.Visible then Size = Size + Element.Size.Y.Offset end end
                BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2)
            end
            Groupbox.Container = Container
            setmetatable(Groupbox, BaseGroupbox)
            Groupbox:AddBlank(3); Groupbox:Resize()
            Tab.Groupboxes[Info.Name] = Groupbox
            return Groupbox
        end
        function Tab:AddLeftGroupbox(Name) return Tab:AddGroupbox({ Side = 1; Name = Name; }) end
        function Tab:AddRightGroupbox(Name) return Tab:AddGroupbox({ Side = 2; Name = Name; }) end
        function Tab:AddTabbox(Info)
            local Tabbox = { Tabs = {}; }
            local BoxOuter = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BackgroundTransparency = 1; BorderColor3 = Library.OutlineColor; BorderMode = Enum.BorderMode.Inset; Size = UDim2.new(1, 0, 0, 0); ZIndex = 6; Parent = Info.Side == 1 and LeftSide or RightSide; });
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
            local BoxInner = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BackgroundTransparency = 1; BorderColor3 = Library.OutlineColor; Size = UDim2.new(1, -2, 1, -2); Position = UDim2.new(0, 1, 0, 1); ZIndex = 6; Parent = BoxOuter; });
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
            Library:Create('Frame', { BackgroundColor3 = Library.AccentColor; BorderSizePixel = 0; Size = UDim2.new(1, 0, 0, 2); ZIndex = 10; Parent = BoxInner; });
            local TabboxButtons = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 0, 0, 1); Size = UDim2.new(1, 0, 0, 18); ZIndex = 5; Parent = BoxInner; });
            Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal; HorizontalAlignment = Enum.HorizontalAlignment.Left; SortOrder = Enum.SortOrder.LayoutOrder; Parent = TabboxButtons; });
            function Tabbox:AddTab(Name)
                local Tab = {};
                local Button = Library:Create('Frame', { BackgroundColor3 = Library.MainColor; BorderColor3 = Library.OutlineColor; Size = UDim2.new(0.5, 0, 1, 0); ZIndex = 150; Active = true; Parent = TabboxButtons; });
                Library:AddToRegistry(Button, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
                Library:CreateLabel({ Size = UDim2.new(1, 0, 1, 0); TextSize = 14; Text = Name; TextXAlignment = Enum.TextXAlignment.Center; ZIndex = 151; Parent = Button; });
                local Block = Library:Create('Frame', { BackgroundColor3 = Library.BackgroundColor; BorderSizePixel = 0; Position = UDim2.new(0, 0, 1, 0); Size = UDim2.new(1, 0, 0, 1); Visible = false; ZIndex = 9; Parent = Button; });
                Library:AddToRegistry(Block, { BackgroundColor3 = 'BackgroundColor'; });
                local Container = Library:Create('Frame', { BackgroundTransparency = 1; Position = UDim2.new(0, 4, 0, 20); Size = UDim2.new(1, -4, 1, -20); ZIndex = 10; Visible = false; Parent = BoxInner; });
                Library:Create('UIListLayout', { FillDirection = Enum.FillDirection.Vertical; SortOrder = Enum.SortOrder.LayoutOrder; Parent = Container; });
                function Tab:Show() for _, Tab in next, Tabbox.Tabs do Tab:Hide() end Container.Visible = true Block.Visible = true Button.BackgroundColor3 = Library.BackgroundColor Library.RegistryMap[Button].Properties.BackgroundColor3 = 'BackgroundColor' Tab:Resize() end
                function Tab:Hide() Container.Visible = false Block.Visible = false Button.BackgroundColor3 = Library.MainColor Library.RegistryMap[Button].Properties.BackgroundColor3 = 'MainColor' end
                function Tab:Resize()
                    local TabCount = 0; for _, Tab in next, Tabbox.Tabs do TabCount = TabCount + 1 end
                    for _, Button in next, TabboxButtons:GetChildren() do if not Button:IsA('UIListLayout') then Button.Size = UDim2.new(1 / TabCount, 0, 1, 0) end end
                    if (not Container.Visible) then return end
                    local Size = 0
                    for _, Element in next, Tab.Container:GetChildren() do if (not Element:IsA('UIListLayout')) and Element.Visible then Size = Size + Element.Size.Y.Offset end end
                    BoxOuter.Size = UDim2.new(1, 0, 0, 20 + Size + 2 + 2)
                end
                Button.InputBegan:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then Tab:Show() Tab:Resize() end end)
                Tab.Container = Container; Tabbox.Tabs[Name] = Tab
                setmetatable(Tab, BaseGroupbox)
                Tab:AddBlank(3); Tab:Resize()
                if #TabboxButtons:GetChildren() == 2 then Tab:Show() end
                return Tab
            end
            Tab.Tabboxes[Info.Name or ''] = Tabbox
            return Tabbox
        end
        function Tab:AddLeftTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 1; }) end
        function Tab:AddRightTabbox(Name) return Tab:AddTabbox({ Name = Name, Side = 2; }) end
        TabButton.InputBegan:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseButton1 then Tab:ShowTab() end end)
        if #TabContainer:GetChildren() == 1 then Tab:ShowTab() end
        Window.Tabs[Name] = Tab
        return Tab
    end

    local ModalElement = Library:Create('TextButton', { BackgroundTransparency = 1; Size = UDim2.new(0, 0, 0, 0); Visible = true; Text = ''; Modal = false; Parent = ScreenGui; });
    local TransparencyCache = {}
    local Toggled = false; local Fading = false
    function Library:Toggle()
        if Fading then return end
        local FadeTime = Config.MenuFadeTime
        Fading = true
        Toggled = (not Toggled)
        ModalElement.Modal = Toggled
        if ThreeDMode then Outer.Visible = Toggled
        else
            if not Toggled then for frame, _ in pairs(Library.OpenedFrames) do frame.Visible = false end table.clear(Library.OpenedFrames) end
            if Toggled then Outer.Visible = true end
            for _, Desc in next, Outer:GetDescendants() do
                local Properties = {}
                if Desc:IsA('ImageLabel') then table.insert(Properties, 'ImageTransparency') table.insert(Properties, 'BackgroundTransparency')
                elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then table.insert(Properties, 'TextTransparency')
                elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then table.insert(Properties, 'BackgroundTransparency')
                elseif Desc:IsA('UIStroke') then table.insert(Properties, 'Transparency') end
                local Cache = TransparencyCache[Desc]
                if (not Cache) then Cache = {} TransparencyCache[Desc] = Cache end
                for _, Prop in next, Properties do
                    if not Cache[Prop] then Cache[Prop] = Desc[Prop] end
                    if Cache[Prop] == 1 then continue end
                    TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play()
                end
            end
        end
        task.wait(FadeTime)
        if not Toggled and not ThreeDMode then Outer.Visible = false end
        if not Toggled and Library.BindSystem then Library.BindSystem:CloseAllWindows() end
        Fading = false
    end
    Library.ToggleMenu = Library.Toggle

    function Library:Set3DEnabled(enabled)
        if enabled == ThreeDMode then return end
        ThreeDMode = enabled
        if enabled then Create3DObjects() Outer.Visible = true ModalElement.Modal = true Toggled = true
        else
            Clear3DObjects()
            if Toggled then Outer.Visible = true ModalElement.Modal = true
            else Outer.Visible = false ModalElement.Modal = false end
        end
    end
    getgenv().Set3DEnabled = Library.Set3DEnabled

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then task.spawn(Library.Toggle) end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then task.spawn(Library.Toggle) end
    end))
    if Config.AutoShow then task.spawn(Library.Toggle) end

    -- [FIX] РЕСАЙЗ — видимые хэндлы, работают через Mouse (без InputBegan конфликта)
    if Config.Resizable then
        local thickness = 8
        local cornerSize = 16
        local handles = {}

        local function makeHandle(name)
            local h = Library:Create('TextButton', {
                Name = name; BackgroundColor3 = Library.AccentColor;
                BackgroundTransparency = 0.85; BorderSizePixel = 0;
                Text = ''; AutoButtonColor = false; Active = false;
                ZIndex = 9999; Parent = Outer;
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 2); Parent = h })
            handles[name] = h

            h.MouseEnter:Connect(function()
                if not Library._resizing then h.BackgroundTransparency = 0.2 end
                Library._hoveredResizeHandle = h
            end)
            h.MouseLeave:Connect(function()
                if not Library._resizing then h.BackgroundTransparency = 0.85 end
                if Library._hoveredResizeHandle == h then Library._hoveredResizeHandle = nil end
            end)

            local dragging = false
            local startMX, startMY, startPX, startPY, startWX, startWY

            h.MouseButton1Down:Connect(function()
                dragging = true
                Library._resizing = true
                local mouse = LocalPlayer:GetMouse()
                startMX = mouse.X; startMY = mouse.Y
                startPX = Outer.Position.X.Offset; startPY = Outer.Position.Y.Offset
                startWX = Outer.Size.X.Offset; startWY = Outer.Size.Y.Offset
                h.BackgroundTransparency = 0
            end)

            Library:GiveSignal(RunService.RenderStepped:Connect(function()
                if not dragging then return end
                if not InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    dragging = false; Library._resizing = false
                    h.BackgroundTransparency = 0.85
                    return
                end
                local mouse = LocalPlayer:GetMouse()
                if not mouse then return end
                local dx = mouse.X - startMX
                local dy = mouse.Y - startMY
                local newX, newY = startPX, startPY
                local newW, newH = startWX, startWY
                local isLeft = name:find('W') ~= nil
                local isRight = name:find('E') ~= nil
                local isTop = name:find('N') ~= nil
                local isBottom = name:find('S') ~= nil
                if isRight then newW = startWX + dx end
                if isLeft then newW = startWX - dx newX = startPX + dx end
                if isBottom then newH = startWY + dy end
                if isTop then newH = startWY - dy newY = startPY + dy end
                local minW = Config.MinSize.X.Offset
                local minH = Config.MinSize.Y.Offset
                if newW < minW then if isLeft then newX = startPX + (startWX - minW) end newW = minW end
                if newH < minH then if isTop then newY = startPY + (startWY - minH) end newH = minH end
                Outer.Position = UDim2.fromOffset(newX, newY)
                Outer.Size = UDim2.fromOffset(newW, newH)
            end))
        end

        local function updHandles()
            local t = thickness; local c = cornerSize
            local function setH(name, pos, size)
                if handles[name] then handles[name].Position = pos handles[name].Size = size end
            end
            setH('N',  UDim2.new(0, c, 0, 0),   UDim2.new(1, -c*2, 0, t))
            setH('S',  UDim2.new(0, c, 1, -t),  UDim2.new(1, -c*2, 0, t))
            setH('W',  UDim2.new(0, 0, 0, c),   UDim2.new(0, t, 1, -c*2))
            setH('E',  UDim2.new(1, -t, 0, c),  UDim2.new(0, t, 1, -c*2))
            setH('NW', UDim2.new(0, 0, 0, 0),   UDim2.fromOffset(c, c))
            setH('NE', UDim2.new(1, -c, 0, 0),  UDim2.fromOffset(c, c))
            setH('SW', UDim2.new(0, 0, 1, -c),  UDim2.fromOffset(c, c))
            setH('SE', UDim2.new(1, -c, 1, -c), UDim2.fromOffset(c, c))
        end

        makeHandle('N') makeHandle('S') makeHandle('W') makeHandle('E')
        makeHandle('NW') makeHandle('NE') makeHandle('SW') makeHandle('SE')
        updHandles()
        Library:GiveSignal(Outer:GetPropertyChangedSignal('AbsoluteSize'):Connect(updHandles))
    end

    Window.Holder = Outer
    return Window
end

local function OnPlayerChange()
    local PlayerList = GetPlayersString()
    for _, Value in next, Options do if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then Value:SetValues(PlayerList) end end
end
Players.PlayerAdded:Connect(OnPlayerChange)
Players.PlayerRemoving:Connect(OnPlayerChange)

getgenv().Library = Library
return Library
