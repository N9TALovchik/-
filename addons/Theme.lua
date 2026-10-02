local httpService = game:GetService('HttpService')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local Players = game:GetService('Players')
local CoreGui = game:GetService('CoreGui')
local Workspace = game:GetService('Workspace')
local RunService = game:GetService('RunService')
local SoundService = game:GetService('SoundService')
local Options = getgenv().Options
local Toggles = getgenv().Toggles

local ThemeManager = {} do
	ThemeManager.Folder = 'LinoriaLibSettings'

	ThemeManager.Library = nil
	ThemeManager.BuiltInThemes = {
		['Default'] 	= { 1, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1c1c1c","AccentColor":"0055ff","BackgroundColor":"141414","OutlineColor":"323232"}') },
		['Dark'] 		= { 2, httpService:JSONDecode('{"MainColor":"181818","AccentColor":"34363a","OutlineColor":"1b1b1b","BackgroundColor":"141414","FontColor":"cbcbcb"}') },
		['Fatality']	= { 3, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1842","AccentColor":"c50754","BackgroundColor":"191335","OutlineColor":"3c355d"}') },
		['Neverlose'] 	= { 4, httpService:JSONDecode('{"MainColor":"080e21","AccentColor":"120d64","OutlineColor":"100c31","BackgroundColor":"0c0a1c","FontColor":"ffffff"}') },
	}

	local CLICK_EFFECT_MAX_SIZE = 40
	local CLICK_EFFECT_GROW_TIME = 0.4
	local CLICK_EFFECT_FADE_TIME = 0.2
	local CLICK_EFFECT_INITIAL_TRANSPARENCY = 0.4
	local CLICK_EFFECT_THICKNESS = 1
	local DEBOUNCE_TIME = 0.05

	local clickEffectEnabled = true
	local inputConnection = nil
	local lastClickTime = 0
	local ClickEffectGui = nil

	local radioSound = nil
	local radioPlaying = false
	local radioUpdateConnection = nil
	local radioSoundId = ""
	local radioVolume = 0.3
	local radioName = ""
	local radioDuration = 0
	local radioLooped = false

	local bgState = {
		imageId = '',
		transparency = 0.5,
		overlay = 0.5,
		uiOpacity = 0.6,
		overlayColor = Color3.new(0, 0, 0),
	}

	local soundHistory = {}
	local historyFile = ThemeManager.Folder .. '/settings/sound_history.json'
	local bgSettingsFile = ThemeManager.Folder .. '/settings/background.json'

	local function safeOnChanged(ctrl, cb)
		if ctrl and ctrl.OnChanged then ctrl:OnChanged(cb) end
	end

	local function loadSoundHistory()
		if isfile(historyFile) then
			local success, data = pcall(httpService.JSONDecode, httpService, readfile(historyFile))
			if success and type(data) == "table" then
				soundHistory = data
				return
			end
		end
		soundHistory = {}
	end
	loadSoundHistory()

	local function saveSoundHistory()
		pcall(function()
			writefile(historyFile, httpService:JSONEncode(soundHistory))
		end)
	end

	local function loadBgSettings()
		if isfile(bgSettingsFile) then
			local ok, data = pcall(httpService.JSONDecode, httpService, readfile(bgSettingsFile))
			if ok and type(data) == "table" then
				bgState.imageId = data.imageId or ''
				bgState.transparency = data.transparency or 0.5
				bgState.overlay = data.overlay or 0.5
				bgState.uiOpacity = data.uiOpacity or 0.6
				if data.overlayColor then
					local ok2, c = pcall(Color3.fromHex, data.overlayColor)
					if ok2 then bgState.overlayColor = c end
				end
			end
		end
	end

	local function saveBgSettings()
		pcall(function()
			writefile(bgSettingsFile, httpService:JSONEncode({
				imageId = bgState.imageId,
				transparency = bgState.transparency,
				overlay = bgState.overlay,
				uiOpacity = bgState.uiOpacity,
				overlayColor = bgState.overlayColor:ToHex(),
			}))
		end)
	end
	loadBgSettings()

	local function applyBg()
		if not ThemeManager.Library then return end
		if not ThemeManager.Library.SetWindowBackground then return end
		ThemeManager.Library:SetWindowBackground(bgState.imageId, bgState.transparency)
		ThemeManager.Library:SetWindowOverlay(bgState.overlay)
		ThemeManager.Library:SetWindowOverlayColor(bgState.overlayColor)
		if ThemeManager.Library.SetUIOverlayOpacity then
			ThemeManager.Library:SetUIOverlayOpacity(bgState.uiOpacity)
		end
	end

	local function addToHistory(soundId, soundName)
		if not soundId or soundId == "" then return end
		local id = soundId
		if id:find("rbxassetid://") then
			id = id:match("rbxassetid://(%d+)") or id
		end
		if soundHistory[id] then
			soundHistory[id].lastPlayed = tick()
		else
			soundHistory[id] = {
				name = soundName or id,
				lastPlayed = tick()
			}
		end
		saveSoundHistory()
		if Options.SoundHistoryDropdown then
			Options.SoundHistoryDropdown:SetValues(ThemeManager:GetSoundHistoryList())
		end
	end

	function ThemeManager:GetSoundHistoryList()
		local list = {}
		for id, data in pairs(soundHistory) do
			local display = data.name and data.name ~= "" and data.name or id
			table.insert(list, display .. " (" .. id .. ")")
		end
		table.sort(list, function(a, b)
			local idA = a:match("%((%d+)%)$") or ""
			local idB = b:match("%((%d+)%)$") or ""
			local timeA = soundHistory[idA] and soundHistory[idA].lastPlayed or 0
			local timeB = soundHistory[idB] and soundHistory[idB].lastPlayed or 0
			return timeA > timeB
		end)
		return list
	end

	local function getSoundIdFromDisplay(display)
		return display:match("%((%d+)%)$")
	end

	local function playSoundInternal(soundId, volume, onEnd, onError, looped)
		if not soundId or soundId == "" then
			if onError then onError("No Sound ID") end
			return nil
		end
		local id = soundId
		if not id:find("rbxassetid://") then
			id = "rbxassetid://" .. id
		end

		local sound = Instance.new('Sound')
		sound.SoundId = id
		sound.Volume = volume or 0.3
		sound.Looped = looped and true or false
		sound.Parent = Workspace

		if not sound.IsLoaded then
			local timeout = tick() + 5
			while not sound.IsLoaded and tick() < timeout and sound.Parent do
				task.wait(0.05)
			end
		end

		if not sound.Parent then return nil end

		local ok = pcall(function() sound:Play() end)
		if not ok then
			sound:Destroy()
			if onError then onError("Failed to play sound (invalid ID?)") end
			return nil
		end

		local soundName = "Unknown"
		pcall(function()
			local info = SoundService:GetSoundInfo(id)
			if info and info.Name then soundName = info.Name end
		end)
		addToHistory(id, soundName)

		sound.Ended:Connect(function()
			sound:Destroy()
			if onEnd then onEnd() end
		end)

		return sound
	end

	local function playSound(soundId, volume, callback, onError)
		return playSoundInternal(soundId, volume, callback, onError, false)
	end

	local function updateRadioUI()
		if not Options.RadioStatus then return end
		local label = Options.RadioStatus
		if radioPlaying and radioSound and radioSound.Parent then
			local time = radioSound.TimePosition or 0
			local duration = radioSound.TimeLength or 0
			local displayName = radioName ~= "" and radioName or radioSoundId
			label.TextLabel.Text = string.format("%s [%.1fs/%.1fs]%s",
				displayName, time, duration, radioLooped and " [LOOP]" or "")
		else
			label.TextLabel.Text = "Idle"
		end
	end

	local function stopRadio()
		if radioSound then
			radioSound:Stop()
			radioSound:Destroy()
			radioSound = nil
		end
		radioPlaying = false
		if Options.RadioPlayButton and Options.RadioPlayButton.Label then
			Options.RadioPlayButton.Label.Text = "Play Sound"
		end
		if radioUpdateConnection then
			radioUpdateConnection:Disconnect()
			radioUpdateConnection = nil
		end
		updateRadioUI()
	end

	local function startRadio()
		stopRadio()
		local id = Options.RadioSoundId and Options.RadioSoundId.Value or ""
		if id == "" then
			if ThemeManager.Library then ThemeManager.Library:Notify("Please enter Sound ID", 2) end
			return
		end
		local volume = Options.RadioVolume and Options.RadioVolume.Value or 0.3
		radioSoundId = id
		radioVolume = volume
		radioLooped = Toggles.RadioLooped and Toggles.RadioLooped.Value or false

		local function onEnd()
			radioPlaying = false
			if Options.RadioPlayButton and Options.RadioPlayButton.Label then
				Options.RadioPlayButton.Label.Text = "Play Sound"
			end
			if radioUpdateConnection then
				radioUpdateConnection:Disconnect()
				radioUpdateConnection = nil
			end
			updateRadioUI()
		end

		local function onError(err)
			radioPlaying = false
			if Options.RadioPlayButton and Options.RadioPlayButton.Label then
				Options.RadioPlayButton.Label.Text = "Play Sound"
			end
			if ThemeManager.Library then ThemeManager.Library:Notify("Error: " .. err, 3) end
			updateRadioUI()
		end

		local sound = playSoundInternal(id, volume, onEnd, onError, radioLooped)

		if sound then
			radioSound = sound
			radioPlaying = true
			if Options.RadioPlayButton and Options.RadioPlayButton.Label then
				Options.RadioPlayButton.Label.Text = "Stop Sound"
			end
			radioName = sound.Name or id
			radioDuration = sound.TimeLength or 0
			if radioUpdateConnection then radioUpdateConnection:Disconnect() end
			radioUpdateConnection = RunService.Heartbeat:Connect(updateRadioUI)
			updateRadioUI()
		end
	end

	local function ensureClickEffectGui()
		if ClickEffectGui and ClickEffectGui.Parent then return ClickEffectGui end
		local gui = Instance.new('ScreenGui')
		gui.Name = 'LinoriaClickEffect'
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 2147483647
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
		if gethui then
			gui.Parent = gethui()
		elseif syn and syn.protect_gui then
			syn.protect_gui(gui)
			gui.Parent = CoreGui
		else
			gui.Parent = CoreGui
		end
		ClickEffectGui = gui
		return gui
	end

	function ThemeManager:InitClickEffect()
		if inputConnection then inputConnection:Disconnect() inputConnection = nil end
		lastClickTime = 0

		inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not clickEffectEnabled then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if gameProcessed then return end

			local now = tick()
			if now - lastClickTime < DEBOUNCE_TIME then return end
			lastClickTime = now

			local mousePos = UserInputService:GetMouseLocation()
			ThemeManager:CreateClickEffect(mousePos.X, mousePos.Y)

			if ThemeManager.Library and ThemeManager.Library.ClickSoundId and ThemeManager.Library.ClickSoundId ~= "" then
				local sound = playSound(ThemeManager.Library.ClickSoundId, 0.5)
				if sound then
					task.delay(sound.TimeLength or 1, function()
						pcall(function() sound:Destroy() end)
					end)
				end
			end
		end)
	end

	function ThemeManager:CreateClickEffect(x, y)
		if not ThemeManager.Library then return end

		local gui = ensureClickEffectGui()
		local color = ThemeManager.Library.ClickEffectColor
			or ThemeManager.Library.BackgroundColor
			or Color3.fromRGB(255,255,255)

		local holder = Instance.new('Frame')
		holder.Name = 'Ripple'
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromOffset(x, y)
		holder.Size = UDim2.fromOffset(0, 0)
		holder.ZIndex = 2147483647
		holder.Parent = gui

		local fill = Instance.new('Frame')
		fill.Name = 'Fill'
		fill.BackgroundColor3 = color
		fill.BackgroundTransparency = 0.85
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(1, 1)
		fill.ZIndex = holder.ZIndex
		fill.Parent = holder
		Instance.new('UICorner', { CornerRadius = UDim.new(1, 0), Parent = fill })

		local stroke = Instance.new('UIStroke')
		stroke.Color = color
		stroke.Thickness = CLICK_EFFECT_THICKNESS
		stroke.Transparency = CLICK_EFFECT_INITIAL_TRANSPARENCY
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = holder

		TweenService:Create(
			holder,
			TweenInfo.new(CLICK_EFFECT_GROW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(CLICK_EFFECT_MAX_SIZE, CLICK_EFFECT_MAX_SIZE) }
		):Play()

		TweenService:Create(
			stroke,
			TweenInfo.new(CLICK_EFFECT_GROW_TIME + CLICK_EFFECT_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = 1 }
		):Play()

		TweenService:Create(
			fill,
			TweenInfo.new(CLICK_EFFECT_GROW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		):Play()

		task.delay(CLICK_EFFECT_GROW_TIME + CLICK_EFFECT_FADE_TIME + 0.05, function()
			if holder and holder.Parent then
				holder:Destroy()
			end
		end)
	end

	function ThemeManager:ApplyTheme(theme)
		local customThemeData = ThemeManager:GetCustomTheme(theme)
		local data = customThemeData or ThemeManager.BuiltInThemes[theme]
		if not data then return end

		local scheme = data[2]
		local themeData = customThemeData or scheme

		for idx, col in next, themeData do
			if idx ~= 'ClickEffectColor' and idx ~= 'UICornerRadius' then
				ThemeManager.Library[idx] = Color3.fromHex(col)
				if Options[idx] then Options[idx]:SetValueRGB(Color3.fromHex(col)) end
			end
		end

		if themeData.ClickEffectColor then
			ThemeManager.Library.ClickEffectColor = Color3.fromHex(themeData.ClickEffectColor)
		elseif themeData.BackgroundColor then
			ThemeManager.Library.ClickEffectColor = Color3.fromHex(themeData.BackgroundColor)
		else
			ThemeManager.Library.ClickEffectColor = Color3.fromRGB(255,255,255)
		end
		if Options.ClickEffectColor then Options.ClickEffectColor:SetValueRGB(ThemeManager.Library.ClickEffectColor) end

		if themeData.UICornerRadius and Options.UICornerRadius then
			Options.UICornerRadius:SetValue(tonumber(themeData.UICornerRadius) or 0.8)
		end

		ThemeManager:ThemeUpdate()
	end

	function ThemeManager:ThemeUpdate()
		local colorFields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor", "ClickEffectColor" }
		for _, field in next, colorFields do
			if Options and Options[field] then
				ThemeManager.Library[field] = Options[field].Value
			end
		end
		ThemeManager.Library.AccentColorDark = ThemeManager.Library:GetDarkerColor(ThemeManager.Library.AccentColor)
		ThemeManager.Library:UpdateColorsUsingRegistry()

		if Options.UICornerRadius and ThemeManager.Library.SetUICornerRadius then
			ThemeManager.Library:SetUICornerRadius(Options.UICornerRadius.Value)
		end
	end

	function ThemeManager:SaveDefault(theme)
		writefile(ThemeManager.Folder .. '/themes/default.txt', theme)
	end

	function ThemeManager:LoadDefault()
		local theme = 'Default'
		local content = isfile(ThemeManager.Folder .. '/themes/default.txt') and readfile(ThemeManager.Folder .. '/themes/default.txt')
		local isDefault = true
		if content then
			if ThemeManager.BuiltInThemes[content] then
				theme = content
			elseif ThemeManager:GetCustomTheme(content) then
				theme = content
				isDefault = false
			end
		elseif ThemeManager.BuiltInThemes[ThemeManager.DefaultTheme] then
			theme = ThemeManager.DefaultTheme
		end
		if isDefault then
			if Options.ThemeManager_ThemeList then
				Options.ThemeManager_ThemeList:SetValue(theme)
			end
		else
			ThemeManager:ApplyTheme(theme)
		end
	end

	local function loadSetting(key, default)
		local path = ThemeManager.Folder .. '/settings/' .. key .. '.txt'
		if isfile(path) then return readfile(path) end
		return default
	end
	local function saveSetting(key, value)
		writefile(ThemeManager.Folder .. '/settings/' .. key .. '.txt', value)
	end

	function ThemeManager:CreateThemeManager(groupbox)
		-- BACKGROUND IMAGE
		groupbox:AddLabel('Window Background')
		groupbox:AddInput('WindowBgImage', {
			Text = 'Image ID',
			Default = bgState.imageId or '',
			Placeholder = 'rbxassetid:// or ID',
			Finished = true,
			Tooltip = 'Вставь rbxassetid:// или просто число'
		})
		safeOnChanged(Options.WindowBgImage, function()
			local v = Options.WindowBgImage.Value or ''
			if v == '' or v == 'none' or v == 'clear' then
				bgState.imageId = ''
			else
				if not v:find('rbxassetid://') and not v:find('rbxasset://') and not v:find('http') then
					local digits = v:gsub('%D', '')
					if #digits > 0 then
						v = 'rbxassetid://' .. digits
					end
				end
				bgState.imageId = v
			end
			applyBg()
			saveBgSettings()
		end)

		groupbox:AddSlider('WindowBgTransparency', {
			Text = 'Image Transparency',
			Min = 0, Max = 1, Default = bgState.transparency or 0.5, Rounding = 2,
			Suffix = '',
			Tooltip = '0 = картинка полностью видна, 1 = прозрачная'
		})
		safeOnChanged(Options.WindowBgTransparency, function()
			bgState.transparency = Options.WindowBgTransparency.Value
			applyBg()
			saveBgSettings()
		end)

		groupbox:AddSlider('WindowBgOverlay', {
			Text = 'Overlay Darkening',
			Min = 0, Max = 1, Default = bgState.overlay or 0.5, Rounding = 2,
			Suffix = '',
			Tooltip = 'Затемнение поверх картинки для читаемости'
		})
		safeOnChanged(Options.WindowBgOverlay, function()
			bgState.overlay = Options.WindowBgOverlay.Value
			applyBg()
			saveBgSettings()
		end)

		groupbox:AddSlider('WindowBgUIOpacity', {
			Text = 'UI Opacity',
			Min = 0, Max = 1, Default = bgState.uiOpacity or 0.6, Rounding = 2,
			Suffix = '',
			Tooltip = 'Насколько прозрачны панели поверх картинки'
		})
		safeOnChanged(Options.WindowBgUIOpacity, function()
			bgState.uiOpacity = Options.WindowBgUIOpacity.Value
			applyBg()
			saveBgSettings()
		end)

		groupbox:AddLabel('Overlay Color'):AddColorPicker('WindowBgOverlayColor', {
			Default = bgState.overlayColor or Color3.new(0,0,0)
		})
		safeOnChanged(Options.WindowBgOverlayColor, function()
			bgState.overlayColor = Options.WindowBgOverlayColor.Value
			applyBg()
			saveBgSettings()
		end)

		groupbox:AddButton('Clear Background', function()
			bgState.imageId = ''
			applyBg()
			saveBgSettings()
			if Options.WindowBgImage then
				Options.WindowBgImage:SetValue('')
			end
			if ThemeManager.Library then ThemeManager.Library:Notify('Background cleared') end
		end)

		groupbox:AddDivider()

		-- THEME COLORS
		groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = ThemeManager.Library.BackgroundColor })
		groupbox:AddLabel('Main color'):AddColorPicker('MainColor', { Default = ThemeManager.Library.MainColor })
		groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = ThemeManager.Library.AccentColor })
		groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = ThemeManager.Library.OutlineColor })
		groupbox:AddLabel('Font color'):AddColorPicker('FontColor', { Default = ThemeManager.Library.FontColor })
		groupbox:AddLabel('Click effect color'):AddColorPicker('ClickEffectColor', { Default = ThemeManager.Library.ClickEffectColor or ThemeManager.Library.BackgroundColor or Color3.fromRGB(255,255,255) })

		groupbox:AddDivider()
		groupbox:AddLabel('UI Corner Radius')
		groupbox:AddSlider('UICornerRadius', {
			Text = 'Corner radius',
			Min = 0,
			Max = 3,
			Default = ThemeManager.Library.UICornerRadius or 0.8,
			Rounding = 2,
			Suffix = ''
		})
		safeOnChanged(Options.UICornerRadius, function()
			ThemeManager.Library.UICornerRadius = Options.UICornerRadius.Value
			ThemeManager.Library:SetUICornerRadius(ThemeManager.Library.UICornerRadius)
		end)

		groupbox:AddDivider()
		groupbox:AddLabel('Cursor & Notify Sound')
		local cursorDefault = ThemeManager.Library.CursorImageId or "18392993708"
		groupbox:AddInput('CursorImageId', {
			Text = 'Cursor Image ID',
			Default = cursorDefault,
			Placeholder = 'Enter asset ID',
			Finished = true
		})
		safeOnChanged(Options.CursorImageId, function()
			local id = Options.CursorImageId.Value
			if id and id ~= "" then
				ThemeManager.Library:SetCursorImageId(id)
				saveSetting('cursor_id', id)
			end
		end)

		local notifyDefault = ThemeManager.Library.NotifySoundId or "132463144859699"
		groupbox:AddInput('NotifySoundId', {
			Text = 'Notify Sound ID',
			Default = notifyDefault,
			Placeholder = 'Enter asset ID',
			Finished = true
		})
		safeOnChanged(Options.NotifySoundId, function()
			local id = Options.NotifySoundId.Value
			if id and id ~= "" then
				ThemeManager.Library:SetNotifySoundId(id)
				saveSetting('notify_sound_id', id)
			end
		end)

		groupbox:AddDivider()
		groupbox:AddLabel('Radio Player')
		groupbox:AddInput('RadioSoundId', {
			Text = 'Sound ID',
			Default = "",
			Placeholder = 'Enter asset ID',
			Finished = true
		})
		groupbox:AddSlider('RadioVolume', {
			Text = 'Volume',
			Min = 0,
			Max = 1.5,
			Default = 0.3,
			Rounding = 2,
			Suffix = ''
		})
		safeOnChanged(Options.RadioVolume, function()
			if radioSound and radioPlaying then
				radioSound.Volume = Options.RadioVolume.Value
			end
		end)

		groupbox:AddToggle('RadioLooped', {
			Text = 'Looped',
			Default = false,
			Tooltip = 'Зациклить воспроизведение звука'
		})
		safeOnChanged(Toggles.RadioLooped, function()
			radioLooped = Toggles.RadioLooped.Value
			if radioSound and radioPlaying then
				radioSound.Looped = radioLooped
			end
		end)

		local statusLabel = groupbox:AddLabel("Idle")
		Options.RadioStatus = statusLabel

		local playButton = groupbox:AddButton('Play Sound', function()
			if radioPlaying then
				stopRadio()
			else
				startRadio()
			end
		end)
		Options.RadioPlayButton = playButton

		groupbox:AddDivider()
		groupbox:AddLabel('Sound History')
		local historyList = ThemeManager:GetSoundHistoryList()
		local historyDropdown = groupbox:AddDropdown('SoundHistoryDropdown', {
			Text = 'History',
			Values = #historyList > 0 and historyList or {"No history"},
			Default = 1,
			AllowNull = false
		})
		Options.SoundHistoryDropdown = historyDropdown

		safeOnChanged(historyDropdown, function(value)
			if not value or value == "No history" then return end
			local id = getSoundIdFromDisplay(value)
			if id and Options.RadioSoundId then
				Options.RadioSoundId:SetValue(id)
			end
		end)

		groupbox:AddDivider()
		groupbox:AddLabel('Themes')
		local ThemesArray = {}
		for Name, Theme in next, ThemeManager.BuiltInThemes do table.insert(ThemesArray, Name) end
		table.sort(ThemesArray, function(a,b) return ThemeManager.BuiltInThemes[a][1] < ThemeManager.BuiltInThemes[b][1] end)

		groupbox:AddDropdown('ThemeManager_ThemeList', { Text = 'Theme list', Values = ThemesArray, Default = 1 })
		groupbox:AddButton('Set as default', function()
			ThemeManager:SaveDefault(Options.ThemeManager_ThemeList.Value)
			ThemeManager.Library:Notify(string.format('Set default theme to %q', Options.ThemeManager_ThemeList.Value))
		end)
		safeOnChanged(Options.ThemeManager_ThemeList, function()
			ThemeManager:ApplyTheme(Options.ThemeManager_ThemeList.Value)
		end)

		groupbox:AddDivider()
		groupbox:AddLabel('Custom Themes')
		groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' })
		groupbox:AddDropdown('ThemeManager_CustomThemeList', { Text = 'Custom themes', Values = ThemeManager:ReloadCustomThemes(), AllowNull = true, Default = 1 })
		groupbox:AddButton('Save theme', function()
			ThemeManager:SaveCustomTheme(Options.ThemeManager_CustomThemeName.Value)
			Options.ThemeManager_CustomThemeList:SetValues(ThemeManager:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
		end):AddButton('Load theme', function()
			ThemeManager:ApplyTheme(Options.ThemeManager_CustomThemeList.Value)
		end)

		groupbox:AddButton('Refresh list', function()
			Options.ThemeManager_CustomThemeList:SetValues(ThemeManager:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
		end)

		groupbox:AddButton('Set as default', function()
			if Options.ThemeManager_CustomThemeList.Value ~= nil and Options.ThemeManager_CustomThemeList.Value ~= '' then
				ThemeManager:SaveDefault(Options.ThemeManager_CustomThemeList.Value)
				ThemeManager.Library:Notify(string.format('Set default theme to %q', Options.ThemeManager_CustomThemeList.Value))
			end
		end)

		ThemeManager:LoadDefault()

		local function UpdateTheme()
			ThemeManager:ThemeUpdate()
		end
		safeOnChanged(Options.BackgroundColor, UpdateTheme)
		safeOnChanged(Options.MainColor, UpdateTheme)
		safeOnChanged(Options.AccentColor, UpdateTheme)
		safeOnChanged(Options.OutlineColor, UpdateTheme)
		safeOnChanged(Options.FontColor, UpdateTheme)
		safeOnChanged(Options.ClickEffectColor, UpdateTheme)

		task.defer(applyBg)
	end

	function ThemeManager:GetCustomTheme(file)
		local path = ThemeManager.Folder .. '/themes/' .. file
		if not isfile(path) then return nil end
		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(path))
		if not success then return nil end
		return decoded
	end

	function ThemeManager:SaveCustomTheme(file)
		if file:gsub(' ', '') == '' then return ThemeManager.Library:Notify('Invalid file name for theme (empty)', 3) end
		local theme = {}
		local fields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor", "UICornerRadius" }
		for _, field in next, fields do
			if field == "UICornerRadius" then
				theme[field] = Options.UICornerRadius.Value
			else
				theme[field] = Options[field].Value:ToHex()
			end
		end
		theme.ClickEffectColor = Options.ClickEffectColor.Value:ToHex()
		writefile(ThemeManager.Folder .. '/themes/' .. file .. '.json', httpService:JSONEncode(theme))
		ThemeManager.Library:Notify(string.format('Theme "%s" saved', file))
	end

	function ThemeManager:ReloadCustomThemes()
		local list = listfiles(ThemeManager.Folder .. '/themes')
		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				local pos = file:find('.json', 1, true)
				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do pos = pos - 1; char = file:sub(pos, pos) end
				if char == '/' or char == '\\' then table.insert(out, file:sub(pos + 1)) end
			end
		end
		return out
	end

	function ThemeManager:CleanupClickEffect()
		if inputConnection then inputConnection:Disconnect(); inputConnection = nil end
		clickEffectEnabled = false
		if ClickEffectGui and ClickEffectGui.Parent then
			ClickEffectGui:Destroy()
			ClickEffectGui = nil
		end
	end

	function ThemeManager:SetLibrary(lib)
		ThemeManager.Library = lib
		ThemeManager:InitClickEffect()
		if lib.OnUnload then
			lib:OnUnload(function() ThemeManager:CleanupClickEffect() end)
		end
	end

	function ThemeManager:BuildFolderTree()
		local parts = {}
		for part in ThemeManager.Folder:gmatch('[^/]+') do table.insert(parts, part) end
		local path = ''
		for i = 1, #parts do
			path = path .. '/' .. parts[i]
			if not isfolder(path) then makefolder(path) end
		end
		for _, sub in next, { '/themes', '/settings' } do
			if not isfolder(ThemeManager.Folder .. sub) then makefolder(ThemeManager.Folder .. sub) end
		end
	end

	function ThemeManager:SetFolder(folder)
		ThemeManager.Folder = folder
		ThemeManager:BuildFolderTree()
	end

	function ThemeManager:CreateGroupBox(tab)
		assert(ThemeManager.Library, 'Must set ThemeManager.Library first!')
		return tab:AddLeftGroupbox('Theme Manager & Other')
	end

	function ThemeManager:ApplyToTab(tab)
		assert(ThemeManager.Library, 'Must set ThemeManager.Library first!')
		ThemeManager:CreateThemeManager(ThemeManager:CreateGroupBox(tab))
	end

	function ThemeManager:ApplyToGroupbox(groupbox)
		assert(ThemeManager.Library, 'Must set ThemeManager.Library first!')
		ThemeManager:CreateThemeManager(groupbox)
	end

	ThemeManager:BuildFolderTree()
end

return ThemeManager
