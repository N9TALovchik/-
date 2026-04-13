local httpService = game:GetService('HttpService')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local Players = game:GetService('Players')
local CoreGui = game:GetService('CoreGui')

local ThemeManager = {} do
	ThemeManager.Folder = 'LinoriaLibSettings'

	ThemeManager.Library = nil
	ThemeManager.BuiltInThemes = {
		['Default'] 	= { 1, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1c1c1c","AccentColor":"0055ff","BackgroundColor":"141414","OutlineColor":"323232","ClickEffectColor":"ffffff"}') },
		['Fatality']	= { 2, httpService:JSONDecode('{"FontColor":"ffffff","MainColor":"1e1842","AccentColor":"c50754","BackgroundColor":"191335","OutlineColor":"3c355d","ClickEffectColor":"ffffff"}') },
		['Dark'] 		= { 3, httpService:JSONDecode('{"MainColor":"181818","AccentColor":"34363a","OutlineColor":"1b1b1b","BackgroundColor":"141414","FontColor":"cbcbcb","ClickEffectColor":"ffffff"}') },
	}

	-- Настройки эффекта клика
	local CLICK_EFFECT_MAX_SIZE = 25
	local CLICK_EFFECT_GROW_TIME = 0.4
	local CLICK_EFFECT_FADE_TIME = 0.2
	local CLICK_EFFECT_INITIAL_TRANSPARENCY = 0.4
	local DEBOUNCE_TIME = 0.1

	local clickEffectGui = nil
	local clickSoundId = ""
	local clickEffectEnabled = true
	local inputConnection = nil
	local lastClickTime = 0

	-- Инициализация GUI (CoreGui)
	function ThemeManager:InitClickEffect()
		-- Отключаем и удаляем всё старое
		if inputConnection then
			inputConnection:Disconnect()
			inputConnection = nil
		end
		if clickEffectGui then
			clickEffectGui:Destroy()
			clickEffectGui = nil
		end

		clickEffectGui = Instance.new('ScreenGui')
		clickEffectGui.Name = 'ClickEffectGUI'
		clickEffectGui.IgnoreGuiInset = true
		clickEffectGui.ResetOnSpawn = false
		clickEffectGui.DisplayOrder = 100
		clickEffectGui.Parent = CoreGui

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

			if clickSoundId and clickSoundId ~= "" then
				local sound = Instance.new('Sound')
				sound.SoundId = clickSoundId
				sound.Volume = 1
				sound.Parent = clickEffectGui
				sound:Play()
				sound.Ended:Connect(function()
					sound:Destroy()
				end)
			end
		end)
	end

	-- Создание одного круга
	function ThemeManager:CreateClickEffect(x, y)
		if not self.Library then return end

		local circle = Instance.new('Frame')
		circle.Name = 'ClickCircle'
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.BackgroundColor3 = self.Library.ClickEffectColor or Color3.fromRGB(255, 255, 255)
		circle.BackgroundTransparency = CLICK_EFFECT_INITIAL_TRANSPARENCY
		circle.BorderSizePixel = 0
		circle.Position = UDim2.new(0, x, 0, y)
		circle.Size = UDim2.new(0, 0, 0, 0)
		circle.ZIndex = 100
		circle.Parent = clickEffectGui

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = circle

		local targetSize = UDim2.new(0, CLICK_EFFECT_MAX_SIZE * 2, 0, CLICK_EFFECT_MAX_SIZE * 2)
		local growTweenInfo = TweenInfo.new(CLICK_EFFECT_GROW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local sizeTween = TweenService:Create(circle, growTweenInfo, { Size = targetSize })
		sizeTween:Play()

		sizeTween.Completed:Connect(function()
			local fadeTweenInfo = TweenInfo.new(CLICK_EFFECT_FADE_TIME, Enum.EasingStyle.Linear)
			local fadeTween = TweenService:Create(circle, fadeTweenInfo, { BackgroundTransparency = 1 })
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				circle:Destroy()
			end)
		end)
	end

	function ThemeManager:ApplyTheme(theme)
		local customThemeData = self:GetCustomTheme(theme)
		local data = customThemeData or self.BuiltInThemes[theme]
		if not data then return end

		local scheme = data[2]
		local themeData = customThemeData or scheme

		for idx, col in next, themeData do
			if idx ~= 'ClickEffectColor' then
				self.Library[idx] = Color3.fromHex(col)
				if Options[idx] then
					Options[idx]:SetValueRGB(Color3.fromHex(col))
				end
			end
		end

		if themeData.ClickEffectColor then
			self.Library.ClickEffectColor = Color3.fromHex(themeData.ClickEffectColor)
			if Options.ClickEffectColor then
				Options.ClickEffectColor:SetValueRGB(Color3.fromHex(themeData.ClickEffectColor))
			end
		end

		self:ThemeUpdate()
	end

	function ThemeManager:ThemeUpdate()
		local options = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor", "ClickEffectColor" }
		for i, field in next, options do
			if Options and Options[field] then
				self.Library[field] = Options[field].Value
			end
		end

		self.Library.AccentColorDark = self.Library:GetDarkerColor(self.Library.AccentColor)
		self.Library:UpdateColorsUsingRegistry()
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

	function ThemeManager:SaveDefault(theme)
		writefile(self.Folder .. '/themes/default.txt', theme)
	end

	function ThemeManager:CreateThemeManager(groupbox)
		groupbox:AddLabel('Background color'):AddColorPicker('BackgroundColor', { Default = self.Library.BackgroundColor })
		groupbox:AddLabel('Main color'):AddColorPicker('MainColor', { Default = self.Library.MainColor })
		groupbox:AddLabel('Accent color'):AddColorPicker('AccentColor', { Default = self.Library.AccentColor })
		groupbox:AddLabel('Outline color'):AddColorPicker('OutlineColor', { Default = self.Library.OutlineColor })
		groupbox:AddLabel('Font color'):AddColorPicker('FontColor', { Default = self.Library.FontColor })
		groupbox:AddLabel('Click effect color'):AddColorPicker('ClickEffectColor', { Default = self.Library.ClickEffectColor or Color3.fromRGB(255, 255, 255) })
		
		groupbox:AddDivider()
		groupbox:AddInput('ClickSoundId', { Text = 'Click Sound ID (rbxassetid://...)', Default = '' })
		Options.ClickSoundId:OnChanged(function()
			clickSoundId = Options.ClickSoundId.Value
		end)

		local ThemesArray = {}
		for Name, Theme in next, self.BuiltInThemes do
			table.insert(ThemesArray, Name)
		end
		table.sort(ThemesArray, function(a, b) return self.BuiltInThemes[a][1] < self.BuiltInThemes[b][1] end)

		groupbox:AddDivider()
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

		ThemeManager:LoadDefault()

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

	function ThemeManager:GetCustomTheme(file)
		local path = self.Folder .. '/themes/' .. file
		if not isfile(path) then return nil end
		local data = readfile(path)
		local success, decoded = pcall(httpService.JSONDecode, httpService, data)
		if not success then return nil end
		return decoded
	end

	function ThemeManager:SaveCustomTheme(file)
		if file:gsub(' ', '') == '' then
			return self.Library:Notify('Invalid file name for theme (empty)', 3)
		end
		local theme = {}
		local fields = { "FontColor", "MainColor", "AccentColor", "BackgroundColor", "OutlineColor", "ClickEffectColor" }
		for _, field in next, fields do
			theme[field] = Options[field].Value:ToHex()
		end
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
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end
				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1))
				end
			end
		end
		return out
	end

	function ThemeManager:SetLibrary(lib)
		self.Library = lib
		self:InitClickEffect()
	end

	function ThemeManager:BuildFolderTree()
		local paths = {}
		local parts = {}
		for part in self.Folder:gmatch('[^/]+') do
			table.insert(parts, part)
		end
		for idx = 1, #parts do
			local path = ''
			for i = 1, idx do
				if i > 1 then path = path .. '/' end
				path = path .. parts[i]
			end
			paths[#paths + 1] = path
		end
		table.insert(paths, self.Folder .. '/themes')
		table.insert(paths, self.Folder .. '/settings')
		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function ThemeManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function ThemeManager:CreateGroupBox(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		return tab:AddLeftGroupbox('Themes')
	end

	function ThemeManager:ApplyToTab(tab)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		local groupbox = self:CreateGroupBox(tab)
		self:CreateThemeManager(groupbox)
	end

	function ThemeManager:ApplyToGroupbox(groupbox)
		assert(self.Library, 'Must set ThemeManager.Library first!')
		self:CreateThemeManager(groupbox)
	end

	ThemeManager:BuildFolderTree()
end

return ThemeManager
