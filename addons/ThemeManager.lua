-- ThemeManager.lua (финальный: клик-эффект Drawing, настройки курсора, звука, Radio)
local httpService = game:GetService('HttpService')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local CoreGui = game:GetService('CoreGui')
local Workspace = game:GetService('Workspace')

local ThemeManager = {} do
	ThemeManager.Folder = 'LinoriaLibSettings'

	ThemeManager.Library = nil
	ThemeManager.BuiltInThemes = {
		['Default'] 	= { 1, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1c1c1c","AccentColor":"0055ff","BackgroundColor":"141414","OutlineColor":"323232"}') },
		['Dark'] 		= { 2, httpService:JSONDecode('{"MainColor":"181818","AccentColor":"34363a","OutlineColor":"1b1b1b","BackgroundColor":"141414","FontColor":"cbcbcb"}') },
		['Fatality']	= { 3, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1842","AccentColor":"c50754","BackgroundColor":"191335","OutlineColor":"3c355d"}') },
		['Neverlose'] 	= { 4, httpService:JSONDecode('{"MainColor":"080e21","AccentColor":"120d64","OutlineColor":"100c31","BackgroundColor":"0c0a1c","FontColor":"ffffff"}') },
	}

	-- Настройки эффекта клика (Drawing)
	local CLICK_EFFECT_MAX_SIZE = 20
	local CLICK_EFFECT_GROW_TIME = 0.4
	local CLICK_EFFECT_FADE_TIME = 0.2
	local CLICK_EFFECT_INITIAL_TRANSPARENCY = 0.4
	local DEBOUNCE_TIME = 0.05

	local clickEffectEnabled = true
	local inputConnection = nil
	local lastClickTime = 0

	-- Функция для воспроизведения звука (используется в Radio)
	local function playSound(soundId, volume)
		if not soundId or soundId == "" then return end
		local id = soundId
		if not id:find("rbxassetid://") then
			id = "rbxassetid://" .. id
		end
		local sound = Instance.new('Sound')
		sound.SoundId = id
		sound.Volume = volume or 1
		sound.Parent = Workspace
		sound:Play()
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		task.delay(10, function()
			pcall(sound.Destroy, sound)
		end)
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
			self:CreateClickEffect(mousePos.X, mousePos.Y)

			if self.Library and self.Library.ClickSoundId and self.Library.ClickSoundId ~= "" then
				playSound(self.Library.ClickSoundId, 1)
			end
		end)
	end

	function ThemeManager:CreateClickEffect(x, y)
		if not self.Library then return end
		local circle = Drawing.new("Circle")
		circle.Visible = true
		circle.Thickness = 1
		circle.Filled = false
		circle.NumSides = 32
		circle.Color = self.Library.ClickEffectColor or self.Library.BackgroundColor or Color3.fromRGB(255,255,255)
		circle.Transparency = CLICK_EFFECT_INITIAL_TRANSPARENCY
		circle.Position = Vector2.new(x, y)
		circle.Radius = 0

		local startTime = tick()
		local growDuration = CLICK_EFFECT_GROW_TIME
		local fadeDuration = CLICK_EFFECT_FADE_TIME
		local maxRadius = CLICK_EFFECT_MAX_SIZE * 2

		local connection
		connection = RunService.RenderStepped:Connect(function()
			local elapsed = tick() - startTime
			if elapsed < growDuration then
				local progress = elapsed / growDuration
				circle.Radius = maxRadius * progress
				circle.Transparency = CLICK_EFFECT_INITIAL_TRANSPARENCY * (1 - progress * 0.5)
			elseif elapsed < growDuration + fadeDuration then
				local fadeProgress = (elapsed - growDuration) / fadeDuration
				circle.Transparency = CLICK_EFFECT_INITIAL_TRANSPARENCY * 0.5 * (1 - fadeProgress)
				circle.Radius = maxRadius
			else
				circle.Visible = false
				circle:Remove()
				connection:Disconnect()
			end
		end)
	end

	function ThemeManager:ApplyTheme(theme)
		local customThemeData = self:GetCustomTheme(theme)
		local data = customThemeData or self.BuiltInThemes[theme]
		if not data then return end

		local scheme = data[2]
		local themeData = customThemeData or scheme

		for idx, col in next, themeData do
			if idx ~= 'ClickEffectColor' and idx ~= 'UICornerRadius' then
				self.Library[idx] = Color3.fromHex(col)
				if Options[idx] then Options[idx]:SetValueRGB(Color3.fromHex(col)) end
			end
		end

		if themeData.ClickEffectColor then
			self.Library.ClickEffectColor = Color3.fromHex(themeData.ClickEffectColor)
		elseif themeData.BackgroundColor then
			self.Library.ClickEffectColor = Color3.fromHex(themeData.BackgroundColor)
		else
			self.Library.ClickEffectColor = Color3.fromRGB(255,255,255)
		end
		if Options.ClickEffectColor then Options.ClickEffectColor:SetValueRGB(self.Library.ClickEffectColor) end

		if themeData.UICornerRadius and Options.UICornerRadius then
			Options.UICornerRadius:SetValue(tonumber(themeData.UICornerRadius) or 0.8)
		end

		self:ThemeUpdate()
	end

	function ThemeManager:ThemeUpdate()
		local colorFields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor", "ClickEffectColor" }
		for _, field in next, colorFields do
			if Options and Options[field] then
				self.Library[field] = Options[field].Value
			end
		end
		self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor)
		self.Library:UpdateColorsUsingRegistry()

		if Options.UICornerRadius and self.Library.SetUICornerRadius then
			self.Library:SetUICornerRadius(Options.UICornerRadius.Value)
		end
	end

	function ThemeManager:SaveDefault(theme)
		writefile(self.Folder .. '/themes/default.txt', theme)
	end

	function ThemeManager:LoadDefault()
		local theme = 'Default'
		local content = isfile(self.Folder .. '/themes/default.txt') and readfile(self.Folder .. '/themes/default.txt')
		local isDefault = true
		if content then
			if self.BuiltInThemes[content] then
				theme = content
			elseif self:GetCustomTheme(content) then
				theme = content
				isDefault = false
			end
		elseif self.BuiltInThemes[self.DefaultTheme] then
			theme = self.DefaultTheme
		end
		if isDefault then
			Options.ThemeManager_ThemeList:SetValue(theme)
		else
			self:ApplyTheme(theme)
		end
	end

	function ThemeManager:GetCustomTheme(file)
		local path = self.Folder .. '/themes/' .. file
		if not isfile(path) then return nil end
		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(path))
		if not success then return nil end
		return decoded
	end

	function ThemeManager:SaveCustomTheme(file)
		if file:gsub(' ', '') == '' then return self.Library:Notify('Invalid file name for theme (empty)', 3) end
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
		writefile(self.Folder .. '/themes/' .. file .. '.json', httpService:JSONEncode(theme))
		self.Library:Notify(string.format('Theme "%s" saved', file))
	end

	function ThemeManager:ReloadCustomThemes()
		local list = listfiles(self.Folder .. '/themes')
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
		lastClickTime = 0
	end

	function ThemeManager:SetLibrary(lib)
		self.Library = lib
		self:InitClickEffect()
		if lib.OnUnload then
			lib:OnUnload(function() self:CleanupClickEffect() end)
		end
	end

	function ThemeManager:BuildFolderTree()
		local parts = {}
		for part in self.Folder:gmatch('[^/]+') do table.insert(parts, part) end
		local path = ''
		for i = 1, #parts do
			path = path .. '/' .. parts[i]
			if not isfolder(path) then makefolder(path) end
		end
		for _, sub in next, { '/themes', '/settings' } do
			if not isfolder(self.Folder .. sub) then makefolder(self.Folder .. sub) end
		end
	end

	function ThemeManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function ThemeManager:CreateGroupBox(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		return tab:AddLeftGroupbox('Theme Manager & Other')
	end

	function ThemeManager:ApplyToTab(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		self:CreateThemeManager(self:CreateGroupBox(tab))
	end

	function ThemeManager:ApplyToGroupbox(groupbox)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		self:CreateThemeManager(groupbox)
	end

	function ThemeManager:CreateThemeManager(groupbox)
		-- Цвета
		groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = self.Library.BackgroundColor })
		groupbox:AddLabel('Main color'):AddColorPicker('MainColor', { Default = self.Library.MainColor })
		groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = self.Library.AccentColor })
		groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = self.Library.OutlineColor })
		groupbox:AddLabel('Font color'):AddColorPicker('FontColor', { Default = self.Library.FontColor })
		groupbox:AddLabel('Click effect color'):AddColorPicker('ClickEffectColor', { Default = self.Library.ClickEffectColor or self.Library.BackgroundColor or Color3.fromRGB(255,255,255) })

		groupbox:AddDivider()
		groupbox:AddLabel('UI Corner Radius')
		groupbox:AddSlider('UICornerRadius', {
			Text = 'Corner radius',
			Min = 0,
			Max = 3,
			Default = self.Library.UICornerRadius or 0.8,
			Rounding = 2,
			Suffix = ''
		})
		Options.UICornerRadius:OnChanged(function()
			self.Library.UICornerRadius = Options.UICornerRadius.Value
			self.Library:SetUICornerRadius(self.Library.UICornerRadius)
		end)

		groupbox:AddDivider()

		-- Настройки курсора
		groupbox:AddInput('CursorImageId', {
			Text = 'Cursor Image ID',
			Default = self.Library.CursorImageId or "18392993708",
			Placeholder = 'Enter image asset ID',
			Callback = function(val)
				if self.Library.SetCursorImageId then
					self.Library:SetCursorImageId(val)
				end
			end
		})

		-- Настройки звука уведомлений
		groupbox:AddInput('NotifySoundId', {
			Text = 'Notification Sound ID',
			Default = self.Library.NotifySoundId or "132463144859699",
			Placeholder = 'Enter sound asset ID',
			Callback = function(val)
				if self.Library.SetNotifySoundId then
					self.Library:SetNotifySoundId(val)
				end
			end
		})

		-- Radio для прослушивания звуков
		groupbox:AddDivider()
		
		groupbox:AddInput('RadioSoundId', {
			Text = 'Sound ID',
			Default = '',
			Placeholder = 'Enter sound asset ID',
			Finished = false,
		})
		groupbox:AddSlider('RadioVolume', {
			Text = 'Volume',
			Min = 0,
			Max = 10,
			Default = 5,
			Rounding = 1,
			Suffix = '',
		})
		groupbox:AddButton('Play Sound', function()
			local id = Options.RadioSoundId.Value
			local volume = Options.RadioVolume.Value
			if id and id ~= "" then
				playSound(id, volume)
				self.Library:Notify('Playing sound: ' .. id, 2)
			else
				self.Library:Notify('Enter a sound ID first', 3)
			end
		end)

		groupbox:AddDivider()

		-- Темы
		local ThemesArray = {}
		for Name, Theme in next, self.BuiltInThemes do table.insert(ThemesArray, Name) end
		table.sort(ThemesArray, function(a,b) return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1] end)

		groupbox:AddDropdown('ThemeManager_ThemeList', { Text = 'Theme list', Values = ThemesArray, Default = 1 })
		groupbox:AddButton('Set as default', function()
			self:SaveDefault(Options.ThemeManager_ThemeList.Value)
			self.Library:Notify(string.format('Set default theme to %q', Options.ThemeManager_ThemeList.Value))
		end)
		Options.ThemeManager_ThemeList:OnChanged(function()
			self:ApplyTheme(Options.ThemeManager_ThemeList.Value)
		end)

		groupbox:AddDivider()
		groupbox:AddInput('ThemeManager_CustomThemeName', { Text = 'Custom theme name' })
		groupbox:AddDropdown('ThemeManager_CustomThemeList', { Text = 'Custom themes', Values = self:ReloadCustomThemes(), AllowNull = true, Default = 1 })
		groupbox:AddDivider()

		groupbox:AddButton('Save theme', function() 
			self:SaveCustomTheme(Options.ThemeManager_CustomThemeName.Value)
			Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
		end):AddButton('Load theme', function() 
			self:ApplyTheme(Options.ThemeManager_CustomThemeList.Value) 
		end)

		groupbox:AddButton('Refresh list', function()
			Options.ThemeManager_CustomThemeList:SetValues(self:ReloadCustomThemes())
			Options.ThemeManager_CustomThemeList:SetValue(nil)
		end)

		groupbox:AddButton('Set as default', function()
			if Options.ThemeManager_CustomThemeList.Value ~= nil and Options.ThemeManager_CustomThemeList.Value ~= '' then
				self:SaveDefault(Options.ThemeManager_CustomThemeList.Value)
				self.Library:Notify(string.format('Set default theme to %q', Options.ThemeManager_CustomThemeList.Value))
			end
		end)

		self:LoadDefault()

		local function UpdateTheme()
			self:ThemeUpdate()
		end
		Options.BackgroundColor:OnChanged(UpdateTheme)
		Options.MainColor:OnChanged(UpdateTheme)
		Options.AccentColor:OnChanged(UpdateTheme)
		Options.OutlineColor:OnChanged(UpdateTheme)
		Options.FontColor:OnChanged(UpdateTheme)
		Options.ClickEffectColor:OnChanged(UpdateTheme)
	end

	ThemeManager:BuildFolderTree()
end

return ThemeManager
