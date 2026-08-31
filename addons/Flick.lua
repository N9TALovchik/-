local FlickManager = {}

function FlickManager:Init(Window, Tabs)
    -- Проверяем, что это игра Flick
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local bulletHandlerModule = replicatedStorage:FindFirstChild("ModuleScripts") 
        and replicatedStorage.ModuleScripts:FindFirstChild("GunModules") 
        and replicatedStorage.ModuleScripts.GunModules:FindFirstChild("BulletHandler")

    if not bulletHandlerModule then
        warn("[Flick] Not a Flick game, skipping...")
        return false
    end

    -- Создаём вкладку Flick (если её нет)
    local flickTab
    for _, tab in ipairs(Window:GetTabs()) do
        if tab.Name == 'Flick' then
            flickTab = tab
            break
        end
    end
    if not flickTab then
        flickTab = Window:AddTab('Flick')
    end

    local settingsGroup = flickTab:AddLeftGroupbox('Silent Aim Settings')

    -- Глобальные настройки (используются в ядре)
    if not _G.FlickSilentAim_Enabled then _G.FlickSilentAim_Enabled = false end
    if not _G.FlickSilentAim_AutoFire then _G.FlickSilentAim_AutoFire = false end
    if not _G.FlickSilentAim_FOV then _G.FlickSilentAim_FOV = 180 end
    if not _G.FlickSilentAim_ShowFOV then _G.FlickSilentAim_ShowFOV = false end
    if not _G.FlickSilentAim_Priority then _G.FlickSilentAim_Priority = "Crosshair" end
    _G.FlickSilentAim_Target = nil

    -- UI
    settingsGroup:AddToggle('FlickSilentAimEnabled', {
        Text = 'Enable Silent Aim',
        Default = _G.FlickSilentAim_Enabled,
        Callback = function(v) _G.FlickSilentAim_Enabled = v end
    })

    settingsGroup:AddToggle('FlickSilentAimAutoFire', {
        Text = 'Auto Fire',
        Default = _G.FlickSilentAim_AutoFire,
        Callback = function(v) _G.FlickSilentAim_AutoFire = v end
    })

    settingsGroup:AddSlider('FlickSilentAimFOV', {
        Text = 'FOV Radius',
        Min = 1,
        Max = 360,
        Default = _G.FlickSilentAim_FOV,
        Rounding = 0,
        Suffix = '°',
        Callback = function(v) _G.FlickSilentAim_FOV = v end
    })

    settingsGroup:AddToggle('FlickSilentAimShowFOV', {
        Text = 'Show FOV Circle',
        Default = _G.FlickSilentAim_ShowFOV,
        Callback = function(v) _G.FlickSilentAim_ShowFOV = v end
    })

    settingsGroup:AddDropdown('FlickSilentAimPriority', {
        Text = 'Target Priority',
        Values = {'Crosshair', 'Distance', 'HP'},
        Default = _G.FlickSilentAim_Priority,
        Callback = function(v) _G.FlickSilentAim_Priority = v end
    })

    -- ============================================================
    -- ЯДРО РАБОТЫ
    -- ============================================================

    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local localPlayer = Players.LocalPlayer
    local camera = workspace.CurrentCamera

    -- Безопасные вызовы mouse1
    local function safeMouse1Press()
        if type(mouse1press) == "function" then
            pcall(mouse1press)
        end
    end
    local function safeMouse1Release()
        if type(mouse1release) == "function" then
            pcall(mouse1release)
        end
    end

    local bulletHandler = require(bulletHandlerModule)
    local originalFire = bulletHandler.Fire
    local isMouseHeld = false
    local fovCircle = nil

    -- Visible Check (всегда включён)
    local function isTargetVisible(targetPart)
        if not targetPart then return false end
        local character = localPlayer.Character
        if not character then return false end

        local origin = camera.CFrame.Position
        local direction = (targetPart.Position - origin).Unit
        local distance = (targetPart.Position - origin).Magnitude

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {character}
        rayParams.IgnoreWater = true

        local result = workspace:Raycast(origin, direction * distance, rayParams)
        if not result then return true end
        local hit = result.Instance

        if hit:IsDescendantOf(targetPart.Parent) then
            return true
        end
        if hit:IsA("BasePart") then
            if hit.Transparency >= 0.9 or hit.CanCollide == false then
                return true
            end
        end
        return false
    end

    -- Поиск лучшей цели
    local function getBestTarget()
        if not _G.FlickSilentAim_Enabled then return nil end
        local character = localPlayer.Character
        if not character then return nil end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end

        local mousePos = UserInputService:GetMouseLocation()
        local fov = _G.FlickSilentAim_FOV
        local fovLimit = math.min(fov, 180)

        local bestTarget = nil
        local bestScore = math.huge

        for _, player in ipairs(Players:GetPlayers()) do
            if player == localPlayer then continue end
            local pChar = player.Character
            if not pChar then continue end
            local hum = pChar:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then continue end

            local targetPart = pChar:FindFirstChild("Head") or pChar:FindFirstChild("HumanoidRootPart") or pChar:FindFirstChild("Torso") or pChar:FindFirstChild("UpperTorso")
            if not targetPart then continue end

            -- FOV
            local direction = (targetPart.Position - camera.CFrame.Position).Unit
            local angle = math.deg(math.acos(camera.CFrame.LookVector:Dot(direction)))
            if angle > fovLimit then continue end

            -- Visible Check (всегда включён)
            if not isTargetVisible(targetPart) then continue end

            -- Приоритет
            local screenPoint = camera:WorldToScreenPoint(targetPart.Position)
            if screenPoint.Z <= 0 then continue end
            local screenPos = Vector2.new(screenPoint.X, screenPoint.Y)
            local distToMouse = (screenPos - mousePos).Magnitude
            local distToPlayer = (targetPart.Position - hrp.Position).Magnitude

            local score
            if _G.FlickSilentAim_Priority == "Crosshair" then
                score = distToMouse
            elseif _G.FlickSilentAim_Priority == "Distance" then
                score = distToPlayer
            elseif _G.FlickSilentAim_Priority == "HP" then
                score = hum.Health
            else
                score = distToMouse
            end

            if score < bestScore then
                bestScore = score
                bestTarget = targetPart
            end
        end
        return bestTarget
    end

    -- FOV Circle
    local function updateFOVCircle()
        if not _G.FlickSilentAim_ShowFOV or not camera then
            if fovCircle then
                fovCircle:Remove()
                fovCircle = nil
            end
            return
        end
        if not fovCircle then
            fovCircle = Drawing.new("Circle")
            fovCircle.Visible = true
            fovCircle.Filled = false
            fovCircle.Thickness = 1
            fovCircle.Color = Color3.fromRGB(255, 255, 255)
            fovCircle.Transparency = 0.8
        end
        local mousePos = UserInputService:GetMouseLocation()
        local fov = _G.FlickSilentAim_FOV
        local radius = (fov / 2) * (camera.ViewportSize.Y / 70)
        fovCircle.Position = mousePos
        fovCircle.Radius = radius
    end

    -- AutoFire
    local function updateAutoFire()
        if not _G.FlickSilentAim_AutoFire or not _G.FlickSilentAim_Enabled then
            if isMouseHeld then
                safeMouse1Release()
                isMouseHeld = false
            end
            return
        end

        local target = _G.FlickSilentAim_Target
        local character = localPlayer.Character
        local tool = character and character:FindFirstChildWhichIsA("Tool")

        if target and tool and isTargetVisible(target) then
            if not isMouseHeld then
                safeMouse1Press()
                isMouseHeld = true
            end
        else
            if isMouseHeld then
                safeMouse1Release()
                isMouseHeld = false
            end
        end
    end

    -- Цикл Heartbeat
    local heartbeatConnection = RunService.Heartbeat:Connect(function()
        if _G.FlickSilentAim_Enabled then
            _G.FlickSilentAim_Target = getBestTarget()
        else
            _G.FlickSilentAim_Target = nil
            if isMouseHeld then
                safeMouse1Release()
                isMouseHeld = false
            end
        end
        updateFOVCircle()
        updateAutoFire()
    end)

    -- Silent Aim (перехват BulletHandler.Fire)
    bulletHandler.Fire = function(p6)
        if _G.FlickSilentAim_Enabled then
            local targetPart = _G.FlickSilentAim_Target
            if targetPart and targetPart.Parent then
                local origin = p6.Origin
                local newDirection = (targetPart.Position - origin).Unit
                p6.Direction = newDirection
            end
        end
        return originalFire(p6)
    end

    _G.FlickSilentAim_OriginalFire = originalFire

    -- Очистка при выгрузке
    local unloadFunc = function()
        if heartbeatConnection then heartbeatConnection:Disconnect() end
        if fovCircle then fovCircle:Remove() end
        if bulletHandler and _G.FlickSilentAim_OriginalFire then
            bulletHandler.Fire = _G.FlickSilentAim_OriginalFire
        end
        if isMouseHeld then
            safeMouse1Release()
            isMouseHeld = false
        end
    end

    -- Регистрируем очистку
    if Library and Library.OnUnload then
        Library:OnUnload(unloadFunc)
    end

    Library:Notify("Flick Silent Aim loaded! (Visible Check always ON)", 2)
    return true
end

return FlickManager
