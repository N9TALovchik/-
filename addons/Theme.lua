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

	local radioSound = nil
	local radioPlaying = false
	local radioUpdateConnection = nil
	local radioSoundId = ""
	local radioVolume = 0.3
	local radioName = ""
	local radioDuration = 0
	local radioLooped = false

	local soundHistory = {}
	local historyFile = ThemeManager.Folder .. '/settings/sound_history.json'
	local cornerSettingsFile = ThemeManager.Folder .. '/settings/corners.json'
	local shadowSettingsFile = ThemeManager.Folder .. '/settings/shadow.json'

	local function safeOnChanged(ctrl, cb)
		if ctrl and ctrl.OnChanged then ctrl:OnChanged(cb) end
	end

	local function loadSoundHistory()
		if isfile(historyFile) then
			local success, data = pcall(httpService.JSONDecode, httpService, readfile(historyFile))
			if success and type(data) == "table" then soundHistory = data return end
		end
		soundHistory = {}
	end
	loadSoundHistory()

	local function saveSoundHistory()
		pcall(function() writefile(historyFile, httpService:JSONEncode(soundHistory)) end)
	end

	local function loadShadowSettings()
		if isfile(shadowSettingsFile) and ThemeManager.Library and ThemeManager.Library.UIShadow then
			local ok, data = pcall(httpService.JSONDecode, httpService, readfile(shadowSettingsFile))
			if ok and type(data) == "table" then
				if data.color then
					local okC, c = pcall(Color3.fromHex, data.color)
					if okC then ThemeManager.Library.UIShadow.Color = c end
				end
				if data.radius then
					ThemeManager.Library.UIShadow.BlurRadius = UDim.new(0, data.radius)
				end
				if Options.ShadowColor then Options.ShadowColor:SetValueRGB(ThemeManager.Library.UIShadow.Color) end
				if Options.ShadowRadius and data.radius then Options.ShadowRadius:SetValue(data.radius) end
			end
		end
	end

	local function saveShadowSettings()
		if not ThemeManager.Library or not ThemeManager.Library.UIShadow then return end
		pcall(function()
			writefile(shadowSettingsFile, httpService:JSONEncode({
				color = ThemeManager.Library.UIShadow.Color:ToHex(),
				radius = ThemeManager.Library.UIShadow.BlurRadius.Offset,
			}))
		end)
	end

	local function addToHistory(soundId, soundName)
		if not soundId or soundId == "" then return end
		local id = soundId
		if id:find("rbxassetid://") then id = id:match("rbxassetid://(%d+)") or id end
		if soundHistory[id] then
			soundHistory[id].lastPlayed = tick()
		else
			soundHistory[id] = { name = soundName or id, lastPlayed = tick() }
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

	local function getSoundIdFromDisplay(display) return display:match("%((%d+)%)$") end

	local function playSoundInternal(soundId, volume, onEnd, onError, looped)
		if not soundId or soundId == "" then
			if onError then onError("No Sound ID") end
			return nil
		end
		local id = soundId
		if not id:find("rbxassetid://") then id = "rbxassetid://" .. id end

		local sound = Instance.new('Sound')
		sound.SoundId = id
		sound.Volume = volume or 0.3
		sound.Looped = looped and true or false
		sound.Parent = Workspace

		if not sound.IsLoaded then
			local timeout = tick() + 5
			while not sound.IsLoaded and tick() < timeout and sound.Parent do task.wait(0.05) end
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

	local function updateRadioUI()
		if not Options.RadioStatus then return end
		local bar = Options.RadioStatus
		if radioPlaying and radioSound and radioSound.Parent then
			local time = radioSound.TimePosition or 0
			local duration = radioSound.TimeLength or 1
			local displayName = radioName ~= "" and radioName or radioSoundId
			local percent = math.clamp((time / math.max(duration, 0.01)) * 100, 0, 100)
			bar:SetStatus(string.format("%s [%.1fs/%.1fs]%s", displayName, time, duration, radioLooped and " [LOOP]" or ""))
			bar:SetValue(percent)
		else
			bar:SetStatus("Idle")
			bar:SetValue(0)
		end
	end

	local function stopRadio()
		if radioSound then radioSound:Stop() radioSound:Destroy() radioSound = nil end
		radioPlaying = false
		if Options.RadioPlayButton and Options.RadioPlayButton.Label then Options.RadioPlayButton.Label.Text = "Play Sound" end
		if radioUpdateConnection then radioUpdateConnection:Disconnect() radioUpdateConnection = nil end
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
			if radioLooped then return end
			radioPlaying = false
			if Options.RadioPlayButton and Options.RadioPlayButton.Label then Options.RadioPlayButton.Label.Text = "Play Sound" end
			if radioUpdateConnection then radioUpdateConnection:Disconnect() radioUpdateConnection = nil end
			updateRadioUI()
		end
		local function onError(err)
			radioPlaying = false
			if Options.RadioPlayButton and Options.RadioPlayButton.Label then Options.RadioPlayButton.Label.Text = "Play Sound" end
			if ThemeManager.Library then ThemeManager.Library:Notify("Error: " .. err, 3) end
			updateRadioUI()
		end
		local sound = playSoundInternal(id, volume, onEnd, onError, radioLooped)
		if sound then
			radioSound = sound
			radioPlaying = true
			if Options.RadioPlayButton and Options.RadioPlayButton.Label then Options.RadioPlayButton.Label.Text = "Stop Sound" end
			radioName = sound.Name or id
			radioDuration = sound.TimeLength or 0
			if radioUpdateConnection then radioUpdateConnection:Disconnect() end
			radioUpdateConnection = RunService.Heartbeat:Connect(updateRadioUI)
			updateRadioUI()
		end
	end

	local function loadCornerSettings()
		if isfile(cornerSettingsFile) and ThemeManager.Library then
			local ok, data = pcall(httpService.JSONDecode, httpService, readfile(cornerSettingsFile))
			if ok and type(data) == 'table' then
				for k, v in pairs(data) do
					if ThemeManager.Library.UICorner and type(v) == 'number' then
						ThemeManager.Library:SetCornerRadius(k, v)
					end
				end
			end
		end
	end

	local function saveCornerSettings()
		if not ThemeManager.Library or not ThemeManager.Library.UICorner then return end
		pcall(function() writefile(cornerSettingsFile, httpService:JSONEncode(ThemeManager.Library.UICorner)) end)
	end

	function ThemeManager:ApplyTheme(theme)
		local customThemeData = ThemeManager:GetCustomTheme(theme)
		local data = customThemeData or ThemeManager.BuiltInThemes[theme]
		if not data then return end
		local scheme = data[2]
		local themeData = customThemeData or scheme

		for idx, col in next, themeData do
			if idx ~= 'UICornerRadius' and idx ~= 'UICorner' and idx ~= 'Shadow' then
				if type(col) == 'table' and col.type == 'ColorPicker' then
					if Options[idx] and Options[idx].LoadSaveData then Options[idx]:LoadSaveData(col) end
				elseif type(col) == 'string' then
					ThemeManager.Library[idx] = Color3.fromHex(col)
					if Options[idx] then Options[idx]:SetValueRGB(Color3.fromHex(col)) end
				end
			end
		end

		if themeData.UICornerRadius and Options.UICornerRadius then
			Options.UICornerRadius:SetValue(tonumber(themeData.UICornerRadius) or 6)
		end

		if themeData.UICorner and ThemeManager.Library.UICorner then
			for k, v in pairs(themeData.UICorner) do
				ThemeManager.Library:SetCornerRadius(k, v)
			end
		end

		if themeData.Shadow and ThemeManager.Library.UIShadow then
			if themeData.Shadow.Color and Options.ShadowColor then Options.ShadowColor:SetValueRGB(Color3.fromHex(themeData.Shadow.Color)) end
			if themeData.Shadow.Radius and Options.ShadowRadius then Options.ShadowRadius:SetValue(themeData.Shadow.Radius) end
		end

		ThemeManager:ThemeUpdate()
	end

	function ThemeManager:ThemeUpdate()
		local colorFields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor" }
		for _, field in next, colorFields do
			if Options and Options[field] then
				ThemeManager.Library[field] = Options[field].Value
			end
		end
		
		if ThemeManager.Library.SetAccentColor then
			ThemeManager.Library:SetAccentColor(ThemeManager.Library.AccentColor)
		end
		if ThemeManager.Library.SetOutlineColor then
			ThemeManager.Library:SetOutlineColor(ThemeManager.Library.OutlineColor)
		end
		
		ThemeManager.Library:UpdateColorsUsingRegistry()

		if Options.UICornerRadius and ThemeManager.Library.SetWindowCorner then
			ThemeManager.Library:SetWindowCorner(Options.UICornerRadius.Value)
		end
		
		if ThemeManager.Library.UIShadow then
			if Options.ShadowColor then ThemeManager.Library.UIShadow.Color = Options.ShadowColor.Value end
			if Options.ShadowRadius then ThemeManager.Library.UIShadow.BlurRadius = UDim.new(0, Options.ShadowRadius.Value) end
		end
	end

	function ThemeManager:SaveDefault(theme) writefile(ThemeManager.Folder .. '/themes/default.txt', theme) end

	function ThemeManager:LoadDefault()
		local theme = 'Default'
		local content = isfile(ThemeManager.Folder .. '/themes/default.txt') and readfile(ThemeManager.Folder .. '/themes/default.txt')
		local isDefault = true
		if content then
			if ThemeManager.BuiltInThemes[content] then theme = content
			elseif ThemeManager:GetCustomTheme(content) then theme = content isDefault = false end
		elseif ThemeManager.BuiltInThemes[ThemeManager.DefaultTheme] then theme = ThemeManager.DefaultTheme end
		if isDefault then
			if Options.ThemeManager_ThemeList then Options.ThemeManager_ThemeList:SetValue(theme) end
		else ThemeManager:ApplyTheme(theme) end
	end

	local function loadSetting(key, default)
		local path = ThemeManager.Folder .. '/settings/' .. key .. '.txt'
		if isfile(path) then return readfile(path) end
		return default
	end
	local function saveSetting(key, value) writefile(ThemeManager.Folder .. '/settings/' .. key .. '.txt', value) end

	function ThemeManager:CreateThemeManager(groupbox)
		groupbox:AddDivider()
		groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = ThemeManager.Library.BackgroundColor })
		groupbox:AddLabel('Main color'):AddColorPicker('MainColor', { Default = ThemeManager.Library.MainColor })
		groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = ThemeManager.Library.AccentColor })
		groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = ThemeManager.Library.OutlineColor })
		groupbox:AddLabel('Font color'):AddColorPicker('FontColor', { Default = ThemeManager.Library.FontColor })

		groupbox:AddDivider()
		groupbox:AddLabel('UI Shadow')
		groupbox:AddLabel('Shadow Color'):AddColorPicker('ShadowColor', {
			Default = ThemeManager.Library.UIShadow and ThemeManager.Library.UIShadow.Color or Color3.new(0,0,0)
		})
		safeOnChanged(Options.ShadowColor, function()
			if ThemeManager.Library and ThemeManager.Library.UIShadow then
				ThemeManager.Library.UIShadow.Color = Options.ShadowColor.Value
				saveShadowSettings()
			end
		end)

		groupbox:AddSlider('ShadowRadius', {
			Text = 'Shadow Radius', Min = 0, Max = 50, Default = ThemeManager.Library.UIShadow and ThemeManager.Library.UIShadow.BlurRadius.Offset or 0, Rounding = 0, Suffix = ' px'
		})
		safeOnChanged(Options.ShadowRadius, function()
			if ThemeManager.Library and ThemeManager.Library.UIShadow then
				ThemeManager.Library.UIShadow.BlurRadius = UDim.new(0, Options.ShadowRadius.Value)
				saveShadowSettings()
			end
		end)

		groupbox:AddDivider()
		groupbox:AddLabel('Corner Radius (px)')

		local winDefault = (ThemeManager.Library.UICorner and ThemeManager.Library.UICorner.Window) or 6
		groupbox:AddSlider('UICornerRadius', {
			Text = 'Window Corner',
			Min = 0, Max = 24, Default = winDefault, Rounding = 0, Suffix = ' px'
		})
		safeOnChanged(Options.UICornerRadius, function()
			if not ThemeManager.Library or not ThemeManager.Library.SetWindowCorner then return end
			ThemeManager.Library:SetWindowCorner(Options.UICornerRadius.Value)
			saveCornerSettings()
		end)

		local cornerItems = {
			{ 'UICornerButton',         'Button',        8 },
			{ 'UICornerToggle',         'Toggle',        3 },
			{ 'UICornerSlider',         'Slider',        8 },
			{ 'UICornerDropdown',       'Dropdown',      4 },
			{ 'UICornerDropdownList',   'DropdownList',  4 },
			{ 'UICornerGroupbox',       'Groupbox',      6 },
			{ 'UICornerKeyPicker',      'KeyPicker',     3 },
			{ 'UICornerKeybind',        'Keybind',       4 },
			{ 'UICornerNotification',   'Notification',  4 },
		}

		for _, item in ipairs(cornerItems) do
			local idx, key, default = item[1], item[2], item[3]
			local current = (ThemeManager.Library.UICorner and ThemeManager.Library.UICorner[key]) or default

			groupbox:AddSlider(idx, {
				Text = key .. ' Corner',
				Min = 0, Max = 24, Default = current, Rounding = 0, Suffix = ' px'
			})

			safeOnChanged(Options[idx], function()
				if not ThemeManager.Library then return end
				ThemeManager.Library:SetCornerRadius(key, Options[idx].Value)
				saveCornerSettings()
			end)
		end

		groupbox:AddButton('Reset All Corners', function()
			if not ThemeManager.Library then return end
			local defaults = {
				Window = 6, Button = 8, Toggle = 3, Slider = 8,
				Dropdown = 4, DropdownList = 4, Groupbox = 6,
				KeyPicker = 3, Keybind = 4, Notification = 4,
			}
			for key, val in pairs(defaults) do
				ThemeManager.Library:SetCornerRadius(key, val)
			end
			ThemeManager.Library:SetWindowCorner(6)
			local slideMap = {
				UICornerButton = 'Button', UICornerToggle = 'Toggle', UICornerSlider = 'Slider',
				UICornerDropdown = 'Dropdown', UICornerDropdownList = 'DropdownList',
				UICornerGroupbox = 'Groupbox', UICornerKeyPicker = 'KeyPicker', UICornerKeybind = 'Keybind',
				UICornerNotification = 'Notification',
			}
			for idx, key in pairs(slideMap) do
				if Options[idx] then Options[idx]:SetValue(defaults[key]) end
			end
			if Options.UICornerRadius then Options.UICornerRadius:SetValue(6) end
			if ThemeManager.Library.Notify then ThemeManager.Library:Notify('Corners reset to default') end
			saveCornerSettings()
		end)

		groupbox:AddDivider()

		groupbox:AddLabel('Animations')
		local animDefault = true
		local savedAnim = loadSetting('animations_enabled', 'true')
		if savedAnim == 'false' then animDefault = false end
		
		groupbox:AddToggle('AnimationsEnabled', { 
			Text = 'Enable UI Animations', 
			Default = animDefault, 
			Tooltip = 'Включить/выключить анимации интерфейса' 
		})
		
		safeOnChanged(Toggles.AnimationsEnabled, function()
			local enabled = Toggles.AnimationsEnabled.Value
			if ThemeManager.Library then ThemeManager.Library.AnimationsEnabled = enabled end
			saveSetting('animations_enabled', tostring(enabled))
		end)
		
		if ThemeManager.Library and Toggles.AnimationsEnabled then
			ThemeManager.Library.AnimationsEnabled = Toggles.AnimationsEnabled.Value
		end

		groupbox:AddDivider()
		groupbox:AddLabel('Cursor & Notify Sound')

		local cursorDefault = ThemeManager.Library.CursorImageId or "18392993708"
		groupbox:AddInput('CursorImageId', { Text = 'Cursor Image ID', Default = cursorDefault, Placeholder = 'Enter asset ID', Finished = true })
		safeOnChanged(Options.CursorImageId, function()
			local id = Options.CursorImageId.Value
			if id and id ~= "" then
				ThemeManager.Library:SetCursorImageId(id)
				saveSetting('cursor_id', id)
			end
		end)

		local notifyDefault = ThemeManager.Library.NotifySoundId or "132463144859699"
		groupbox:AddInput('NotifySoundId', { Text = 'Notify Sound ID', Default = notifyDefault, Placeholder = 'Enter asset ID', Finished = true })
		safeOnChanged(Options.NotifySoundId, function()
			local id = Options.NotifySoundId.Value
			if id and id ~= "" then
				ThemeManager.Library:SetNotifySoundId(id)
				saveSetting('notify_sound_id', id)
			end
		end)

		groupbox:AddDivider()
		groupbox:AddLabel('Radio Player')

		groupbox:AddInput('RadioSoundId', { Text = 'Sound ID', Default = "", Placeholder = 'Enter asset ID', Finished = true })
		groupbox:AddSlider('RadioVolume', { Text = 'Volume', Min = 0, Max = 1.5, Default = 0.3, Rounding = 2, Suffix = '' })
		safeOnChanged(Options.RadioVolume, function()
			if radioSound and radioPlaying then radioSound.Volume = Options.RadioVolume.Value end
		end)

		groupbox:AddToggle('RadioLooped', { Text = 'Looped', Default = false, Tooltip = 'Зациклить воспроизведение' })
		safeOnChanged(Toggles.RadioLooped, function()
			radioLooped = Toggles.RadioLooped.Value
			if radioSound then radioSound.Looped = radioLooped end
		end)

		local statusBar = groupbox:AddProgressBar('RadioStatus', {
			Text = 'Radio Status',
			Min = 0, Max = 100, Default = 0, CanEdit = false, HideMax = true
		})
		Options.RadioStatus = statusBar

		local playButton = groupbox:AddButton('Play Sound', function()
			if radioPlaying then stopRadio() else startRadio() end
		end)
		Options.RadioPlayButton = playButton

		groupbox:AddDivider()
		groupbox:AddLabel('Sound History')

		local historyList = ThemeManager:GetSoundHistoryList()
		local historyDropdown = groupbox:AddDropdown('SoundHistoryDropdown', {
			Text = 'History',
			Values = #historyList > 0 and historyList or {"No history"},
			Default = 1, AllowNull = false
		})
		Options.SoundHistoryDropdown = historyDropdown

		safeOnChanged(historyDropdown, function(value)
			if not value or value == "No history" then return end
			local id = getSoundIdFromDisplay(value)
			if id and Options.RadioSoundId then Options.RadioSoundId:SetValue(id) end
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

		local function UpdateTheme() ThemeManager:ThemeUpdate() end
		safeOnChanged(Options.BackgroundColor, UpdateTheme)
		safeOnChanged(Options.MainColor, UpdateTheme)
		safeOnChanged(Options.AccentColor, UpdateTheme)
		safeOnChanged(Options.OutlineColor, UpdateTheme)
		safeOnChanged(Options.FontColor, UpdateTheme)

		task.defer(loadCornerSettings)
		task.defer(loadShadowSettings)
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
		for idx, obj in pairs(Options) do
			if obj.Type == 'ColorPicker' and obj.GetSaveData then
				theme[idx] = obj:GetSaveData()
			end
		end
		if ThemeManager.Library.UICorner then
			theme.UICorner = ThemeManager.Library.UICorner
		end
		if ThemeManager.Library.UIShadow then
			theme.Shadow = {
				Color = ThemeManager.Library.UIShadow.Color:ToHex(),
				Radius = ThemeManager.Library.UIShadow.BlurRadius.Offset
			}
		end
		theme.UICornerRadius = Options.UICornerRadius and Options.UICornerRadius.Value or 6
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

	function ThemeManager:SetLibrary(lib)
		ThemeManager.Library = lib
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

	function ThemeManager:SetFolder(folder) ThemeManager.Folder = folder ThemeManager:BuildFolderTree() end
	function ThemeManager:CreateGroupBox(tab) return tab:AddLeftGroupbox('Theme Manager & Other') end
	function ThemeManager:ApplyToTab(tab) ThemeManager:CreateThemeManager(ThemeManager:CreateGroupBox(tab)) end
	function ThemeManager:ApplyToGroupbox(groupbox) ThemeManager:CreateThemeManager(groupbox) end

	ThemeManager:BuildFolderTree()
end

return ThemeManager
