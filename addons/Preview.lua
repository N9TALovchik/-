--=====================================================
-- PreviewManager.lua
-- Floating ESP preview frame that syncs with the library
--=====================================================

local Players          = game:GetService('Players')
local RunService       = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local CoreGui          = game:GetService('CoreGui')
local HttpService      = game:GetService('HttpService')
local TweenService     = game:GetService('TweenService')

local PreviewManager = {} do
    PreviewManager.Folder   = 'NOTALovchik/Preview'
    PreviewManager.Library  = nil

    PreviewManager.Config = {
        Enabled                = true,
        SyncWithMenu           = true,   -- показывать только когда открыто меню
        Size                   = Vector2.new(240, 340),
        Position               = UDim2.new(0, 100, 0, 100),
        BackgroundColor        = Color3.fromRGB(22, 22, 28),
        BackgroundTransparency = 0,
        OutlineColor           = Color3.fromRGB(70, 70, 90),
        OutlineThickness       = 1,
        CornerRadius           = 6,
        ViewportBackground     = Color3.fromRGB(30, 30, 40),
        ViewportTransparency   = 0,
        CameraFOV              = 60,
        CameraYaw              = 0,
        AutoFit                = true,
        ShowGrid               = false,
    }

    PreviewManager.Gui            = nil
    PreviewManager.MainFrame      = nil
    PreviewManager.Stroke         = nil
    PreviewManager.Corner         = nil
    PreviewManager.Content        = nil   -- container for 2D/3D
    PreviewManager.ViewportFrame  = nil
    PreviewManager.WorldModel     = nil
    PreviewManager.Camera         = nil
    PreviewManager.Models         = {}
    PreviewManager.RefreshConn    = nil
    PreviewManager.VisibleConn    = nil
    PreviewManager.DragConn       = nil
    PreviewManager.OrbitState     = { dragging = false, lastX = nil }

    --========== helpers ==========--
    local function create(class, props)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do o[k] = v end
        return o
    end

    local function getGuiParent()
        local ok, res = pcall(function() return CoreGui end)
        if ok and res then return res end
        return Players.LocalPlayer:WaitForChild('PlayerGui')
    end

    local function protect(gui)
        pcall(function()
            if syn and syn.protect_gui then syn.protect_gui(gui) end
        end)
    end

    --========== build ==========--
    function PreviewManager:Build()
        if PreviewManager.Gui and PreviewManager.Gui.Parent then return end

        local gui = create('ScreenGui', {
            Name           = 'NOTALovchik_Preview',
            ResetOnSpawn   = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        protect(gui)
        gui.Parent = getGuiParent()

        local outer = create('Frame', {
            Name             = 'PreviewFrame',
            Size             = UDim2.fromOffset(PreviewManager.Config.Size.X, PreviewManager.Config.Size.Y),
            Position         = PreviewManager.Config.Position,
            BackgroundColor3 = PreviewManager.Config.BackgroundColor,
            BackgroundTransparency = PreviewManager.Config.BackgroundTransparency,
            BorderSizePixel  = 0,
            ClipsDescendants = true,
            Active           = true,
            Visible          = PreviewManager.Config.Enabled,
            Parent           = gui,
        })

        local corner = create('UICorner', {
            CornerRadius = UDim.new(0, PreviewManager.Config.CornerRadius),
            Parent = outer,
        })

        local stroke = create('UIStroke', {
            Color           = PreviewManager.Config.OutlineColor,
            Thickness       = PreviewManager.Config.OutlineThickness,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent          = outer,
        })

        local content = create('Frame', {
            Name                 = 'Content',
            Size                 = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ClipsDescendants     = true,
            Parent               = outer,
        })

        local vp = create('ViewportFrame', {
            Name                   = 'Viewport',
            Size                   = UDim2.fromScale(1, 1),
            BackgroundColor3       = PreviewManager.Config.ViewportBackground,
            BackgroundTransparency = PreviewManager.Config.ViewportTransparency,
            ClipsDescendants       = true,
            LightDirection         = Enum.NormalId.Front,
            Ambient                = Color3.fromRGB(140, 140, 140),
            LightColor             = Color3.fromRGB(255, 255, 255),
            Parent                 = content,
        })

        local world = create('WorldModel', { Parent = vp })
        local cam   = create('Camera', { FieldOfView = PreviewManager.Config.CameraFOV, Parent = vp })
        vp.CurrentCamera = cam

        PreviewManager.Gui           = gui
        PreviewManager.MainFrame     = outer
        PreviewManager.Corner        = corner
        PreviewManager.Stroke        = stroke
        PreviewManager.Content       = content
        PreviewManager.ViewportFrame = vp
        PreviewManager.WorldModel    = world
        PreviewManager.Camera        = cam

        PreviewManager:SetupDragging()
        PreviewManager:SetupOrbit()

        self:RefreshCamera()
    end

    --========== drag ==========--
    function PreviewManager:SetupDragging()
        local frame = PreviewManager.MainFrame
        if not frame then return end

        local dragging, dragStart, startPos

        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
            end
        end)

        frame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        if PreviewManager.DragConn then
            pcall(function() PreviewManager.DragConn:Disconnect() end)
        end
        PreviewManager.DragConn = UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    --========== orbit ==========--
    function PreviewManager:SetupOrbit()
        local vp = PreviewManager.ViewportFrame
        if not vp then return end

        vp.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                PreviewManager.OrbitState.dragging = true
                PreviewManager.OrbitState.lastX = input.Position.X
            end
        end)

        vp.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                PreviewManager.OrbitState.dragging = false
            end
        end)

        vp.InputChanged:Connect(function(input)
            local s = PreviewManager.OrbitState
            if s.dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local dx = input.Position.X - (s.lastX or input.Position.X)
                s.lastX = input.Position.X
                PreviewManager.Config.CameraYaw = PreviewManager.Config.CameraYaw + dx * math.rad(0.6)
                PreviewManager:RefreshCamera()
            end
        end)
    end

    --========== visibility ==========--
    function PreviewManager:SetVisible(state)
        PreviewManager.Config.Enabled = state and true or false
        if PreviewManager.MainFrame then
            PreviewManager.MainFrame.Visible = PreviewManager.Config.Enabled
                and (not PreviewManager.Config.SyncWithMenu
                     or (PreviewManager.Library and PreviewManager.Library.MainFrame
                         and PreviewManager.Library.MainFrame.Visible))
        end
    end

    function PreviewManager:SetSyncWithMenu(state)
        PreviewManager.Config.SyncWithMenu = state and true or false
        if PreviewManager.MainFrame and PreviewManager.Library and PreviewManager.Library.MainFrame then
            PreviewManager.MainFrame.Visible = PreviewManager.Config.Enabled
                and (not PreviewManager.Config.SyncWithMenu or PreviewManager.Library.MainFrame.Visible)
        end
    end

    function PreviewManager:SetupVisibilitySync()
        if not PreviewManager.Library then return end
        if not PreviewManager.Library.MainFrame then
            task.spawn(function()
                repeat task.wait() until PreviewManager.Library and PreviewManager.Library.MainFrame
                PreviewManager:SetupVisibilitySync()
            end)
            return
        end

        if PreviewManager.VisibleConn then
            pcall(function() PreviewManager.VisibleConn:Disconnect() end)
        end

        local main = PreviewManager.Library.MainFrame

        local function apply()
            if not PreviewManager.MainFrame then return end
            local visible = PreviewManager.Config.Enabled
            if PreviewManager.Config.SyncWithMenu then
                visible = visible and main.Visible
            end
            PreviewManager.MainFrame.Visible = visible
        end

        PreviewManager.VisibleConn = main:GetPropertyChangedSignal('Visible'):Connect(apply)
        apply()
    end

    --========== размер/цвет/outline ==========--
    function PreviewManager:SetSize(vec2)
        PreviewManager.Config.Size = vec2
        if PreviewManager.MainFrame then
            PreviewManager.MainFrame.Size = UDim2.fromOffset(vec2.X, vec2.Y)
        end
        self:RefreshCamera()
    end

    function PreviewManager:SetPosition(udim2)
        PreviewManager.Config.Position = udim2
        if PreviewManager.MainFrame then
            PreviewManager.MainFrame.Position = udim2
        end
    end

    function PreviewManager:SetBackgroundColor(color)
        PreviewManager.Config.BackgroundColor = color
        if PreviewManager.MainFrame then
            PreviewManager.MainFrame.BackgroundColor3 = color
        end
    end

    function PreviewManager:SetBackgroundTransparency(a)
        PreviewManager.Config.BackgroundTransparency = a
        if PreviewManager.MainFrame then
            PreviewManager.MainFrame.BackgroundTransparency = a
        end
    end

    function PreviewManager:SetOutlineColor(color)
        PreviewManager.Config.OutlineColor = color
        if PreviewManager.Stroke then PreviewManager.Stroke.Color = color end
    end

    function PreviewManager:SetOutlineThickness(t)
        PreviewManager.Config.OutlineThickness = t
        if PreviewManager.Stroke then PreviewManager.Stroke.Thickness = t end
    end

    function PreviewManager:SetCornerRadius(r)
        PreviewManager.Config.CornerRadius = r
        if PreviewManager.Corner then PreviewManager.Corner.CornerRadius = UDim.new(0, r) end
    end

    function PreviewManager:SetViewportBackground(color, transparency)
        PreviewManager.Config.ViewportBackground = color
        PreviewManager.Config.ViewportTransparency = transparency or 0
        if PreviewManager.ViewportFrame then
            PreviewManager.ViewportFrame.BackgroundColor3 = color
            PreviewManager.ViewportFrame.BackgroundTransparency = PreviewManager.Config.ViewportTransparency
        end
    end

    function PreviewManager:SetFOV(deg)
        PreviewManager.Config.CameraFOV = deg
        if PreviewManager.Camera then PreviewManager.Camera.FieldOfView = deg end
        self:RefreshCamera()
    end

    function PreviewManager:SetYaw(rad)
        PreviewManager.Config.CameraYaw = rad
        self:RefreshCamera()
    end

    --========== getters ==========--
    function PreviewManager:GetContent()      return PreviewManager.Content end
    function PreviewManager:GetViewportFrame() return PreviewManager.ViewportFrame end
    function PreviewManager:GetWorldModel()    return PreviewManager.WorldModel end
    function PreviewManager:GetCamera()        return PreviewManager.Camera end
    function PreviewManager:GetMainFrame()     return PreviewManager.MainFrame end
    function PreviewManager:GetModels()        return PreviewManager.Models end

    --========== models ==========--
    function PreviewManager:AddModel(model, offset)
        if not PreviewManager.WorldModel then self:Build() end
        if not model then return nil end

        local ok, clone = pcall(function() return model:Clone() end)
        if not ok or not clone then
            warn('[PreviewManager] cannot clone model:', model)
            return nil
        end

        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA('Script') or d:IsA('LocalScript') or d:IsA('ModuleScript')
                or d:IsA('Animator') or d:IsA('AnimationController') or d:IsA('Sound') then
                d:Destroy()
            end
        end

        clone.Parent = PreviewManager.WorldModel

        offset = offset or Vector3.new(0, 0, 0)
        local okp = pcall(function() clone:PivotTo(CFrame.new(offset)) end)
        if not okp then
            pcall(function() clone:SetPrimaryPartCFrame(CFrame.new(offset)) end)
        end

        table.insert(PreviewManager.Models, clone)
        self:RefreshCamera()
        return clone
    end

    function PreviewManager:RemoveModel(model)
        for i, m in ipairs(PreviewManager.Models) do
            if m == model then
                table.remove(PreviewManager.Models, i)
                pcall(function() m:Destroy() end)
                break
            end
        end
        self:RefreshCamera()
    end

    function PreviewManager:ClearModels()
        for _, m in ipairs(PreviewManager.Models) do
            pcall(function() m:Destroy() end)
        end
        PreviewManager.Models = {}
        self:RefreshCamera()
    end

    -- Демо-модель: копия персонажа игрока
    function PreviewManager:AddCharacterPreview(player)
        player = player or Players.LocalPlayer
        if not player or not player.Character then return nil end
        return self:AddModel(player.Character)
    end

    -- Демо-модель: заглушка (болванка из частей R6)
    function PreviewManager:AddDummy()
        local dummy = Instance.new('Model')
        dummy.Name = 'PreviewDummy'

        local function part(name, size, pos, color)
            local p = Instance.new('Part')
            p.Name = name
            p.Size = size
            p.Position = pos
            p.Color = color
            p.Anchored = true
            p.CanCollide = false
            p.Parent = dummy
            return p
        end

        local green = Color3.fromRGB(60, 200, 120)
        local grey  = Color3.fromRGB(180, 180, 180)

        part('Head',  Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.2, 0), grey)
        part('Torso', Vector3.new(1.4, 1.8, 0.8), Vector3.new(0, 2.7, 0), green)
        part('LLeg',  Vector3.new(0.6, 1.8, 0.6), Vector3.new(-0.4, 0.9, 0), green)
        part('RLeg',  Vector3.new(0.6, 1.8, 0.6), Vector3.new(0.4, 0.9, 0), green)
        part('LArm',  Vector3.new(0.5, 1.6, 0.5), Vector3.new(-1.0, 2.7, 0), green)
        part('RArm',  Vector3.new(0.5, 1.6, 0.5), Vector3.new(1.0, 2.7, 0), green)

        dummy.PrimaryPart = dummy:FindFirstChild('Torso')
        return self:AddModel(dummy, Vector3.new(0, 0, 0))
    end

    --========== камера ==========--
    function PreviewManager:RefreshCamera()
        if not PreviewManager.Camera or not PreviewManager.WorldModel then return end
        local cam = PreviewManager.Camera
        cam.FieldOfView = PreviewManager.Config.CameraFOV

        if not PreviewManager.Config.AutoFit then
            local yaw = PreviewManager.Config.CameraYaw or 0
            local dist = 8
            local offset = Vector3.new(math.sin(yaw) * dist, 0, -math.cos(yaw) * dist)
            cam.CFrame = CFrame.new(Vector3.new(0, 3, 0) + offset, Vector3.new(0, 3, 0))
            return
        end

        local minV, maxV
        for _, m in ipairs(PreviewManager.Models) do
            if m and m.Parent then
                local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
                if ok and cf and size then
                    local c = cf.Position
                    local e = size / 2
                    if not minV then
                        minV = c - e
                        maxV = c + e
                    else
                        minV = Vector3.new(
                            math.min(minV.X, c.X - e.X),
                            math.min(minV.Y, c.Y - e.Y),
                            math.min(minV.Z, c.Z - e.Z)
                        )
                        maxV = Vector3.new(
                            math.max(maxV.X, c.X + e.X),
                            math.max(maxV.Y, c.Y + e.Y),
                            math.max(maxV.Z, c.Z + e.Z)
                        )
                    end
                end
            end
        end

        if not minV then
            local yaw = PreviewManager.Config.CameraYaw or 0
            local dist = 8
            local offset = Vector3.new(math.sin(yaw) * dist, 0, -math.cos(yaw) * dist)
            cam.CFrame = CFrame.new(Vector3.new(0, 3, 0) + offset, Vector3.new(0, 3, 0))
            return
        end

        local center = (minV + maxV) / 2
        local size = (maxV - minV).Magnitude
        local aspect = PreviewManager.Config.Size.X / math.max(PreviewManager.Config.Size.Y, 1)

        local fovRad = math.rad(cam.FieldOfView)
        local dist = (size / 2) / math.tan(fovRad / 2) * 1.35
        if aspect > 1 then
            dist = dist / aspect
        end

        local yaw = PreviewManager.Config.CameraYaw or 0
        local offset = Vector3.new(math.sin(yaw) * dist, 0, -math.cos(yaw) * dist)
        cam.CFrame = CFrame.new(center + offset, center)
    end

    --========== folder ==========--
    function PreviewManager:BuildFolderTree()
        local parts = {}
        for p in PreviewManager.Folder:gmatch('[^/]+') do table.insert(parts, p) end
        local path = ''
        for i = 1, #parts do
            path = path .. '/' .. parts[i]
            if not isfolder(path) then makefolder(path) end
        end
    end

    function PreviewManager:SetFolder(folder)
        PreviewManager.Folder = folder
        PreviewManager:BuildFolderTree()
    end

    --========== library integration ==========--
    function PreviewManager:SetLibrary(lib)
        PreviewManager.Library = lib

        -- построить фрейм сразу
        PreviewManager:Build()

        -- синхронизировать видимость с меню
        PreviewManager:SetupVisibilitySync()

        -- при выгрузке библиотеки уничтожить preview
        if lib.OnUnload then
            lib:OnUnload(function() PreviewManager:Cleanup() end)
        end
    end

    function PreviewManager:Cleanup()
        if PreviewManager.RefreshConn then
            pcall(function() PreviewManager.RefreshConn:Disconnect() end)
            PreviewManager.RefreshConn = nil
        end
        if PreviewManager.VisibleConn then
            pcall(function() PreviewManager.VisibleConn:Disconnect() end)
            PreviewManager.VisibleConn = nil
        end
        if PreviewManager.DragConn then
            pcall(function() PreviewManager.DragConn:Disconnect() end)
            PreviewManager.DragConn = nil
        end
        PreviewManager:ClearModels()
        if PreviewManager.Gui then
            pcall(function() PreviewManager.Gui:Destroy() end)
            PreviewManager.Gui = nil
        end
        PreviewManager.MainFrame = nil
        PreviewManager.ViewportFrame = nil
        PreviewManager.WorldModel = nil
        PreviewManager.Camera = nil
        PreviewManager.Content = nil
    end

    --========== apply to tab (опциональный UI) ==========--
    function PreviewManager:ApplyToTab(tab)
        assert(PreviewManager.Library, 'SetLibrary first')

        PreviewManager:Build()

        local box = tab:AddLeftGroupbox('Preview Manager')

        box:AddToggle('Preview_Enabled', {
            Text = 'Show Preview',
            Default = PreviewManager.Config.Enabled,
            Callback = function(v) PreviewManager:SetVisible(v) end,
        })

        box:AddToggle('Preview_SyncMenu', {
            Text = 'Sync with Menu',
            Default = PreviewManager.Config.SyncWithMenu,
            Tooltip = 'Показывать preview только когда открыто меню',
            Callback = function(v) PreviewManager:SetSyncWithMenu(v) end,
        })

        box:AddSlider('Preview_Width', {
            Text = 'Width',
            Min = 100, Max = 600, Default = PreviewManager.Config.Size.X, Rounding = 0,
            Callback = function(v)
                local s = PreviewManager.Config.Size
                PreviewManager:SetSize(Vector2.new(v, s.Y))
            end,
        })
        box:AddSlider('Preview_Height', {
            Text = 'Height',
            Min = 100, Max = 800, Default = PreviewManager.Config.Size.Y, Rounding = 0,
            Callback = function(v)
                local s = PreviewManager.Config.Size
                PreviewManager:SetSize(Vector2.new(s.X, v))
            end,
        })
        box:AddSlider('Preview_OutlineThickness', {
            Text = 'Outline Thickness',
            Min = 0, Max = 5, Default = PreviewManager.Config.OutlineThickness, Rounding = 0,
            Callback = function(v) PreviewManager:SetOutlineThickness(v) end,
        })
        box:AddSlider('Preview_Corner', {
            Text = 'Corner Radius',
            Min = 0, Max = 20, Default = PreviewManager.Config.CornerRadius, Rounding = 0,
            Callback = function(v) PreviewManager:SetCornerRadius(v) end,
        })
        box:AddSlider('Preview_FOV', {
            Text = 'Camera FOV',
            Min = 20, Max = 120, Default = PreviewManager.Config.CameraFOV, Rounding = 0,
            Callback = function(v) PreviewManager:SetFOV(v) end,
        })

        box:AddLabel('Outline Color'):AddColorPicker('Preview_OutlineColor', {
            Default = PreviewManager.Config.OutlineColor,
            Callback = function(c) PreviewManager:SetOutlineColor(c) end,
        })
        box:AddLabel('Background Color'):AddColorPicker('Preview_BgColor', {
            Default = PreviewManager.Config.BackgroundColor,
            Callback = function(c) PreviewManager:SetBackgroundColor(c) end,
        })

        box:AddDivider()
        box:AddButton('Add Self Character', function() PreviewManager:AddCharacterPreview() end)
        box:AddButton('Add Dummy', function() PreviewManager:AddDummy() end)
        box:AddButton('Clear Models', function() PreviewManager:ClearModels() end)
    end

    PreviewManager:BuildFolderTree()
end

return PreviewManager
