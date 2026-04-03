local httpService = game:GetService('HttpService')

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if Toggles[idx] then 
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},
		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end
			table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end
			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, 'no config file is selected'
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, 'decode error' end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end)
			end
		end

		return true
	end

	-- НОВАЯ ФУНКЦИЯ: Экспорт выбранного конфига в буфер обмена
	function SaveManager:ExportConfig(name)
		if not name then
			return false, 'no config selected'
		end
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then
			return false, 'config file not found'
		end
		local content = readfile(file)
		if not content then
			return false, 'failed to read file'
		end
		-- Копируем в буфер обмена (если поддерживается)
		local success = pcall(function()
			setclipboard(content)
		end)
		if success then
			self.Library:Notify(string.format('Config "%s" copied to clipboard', name))
			return true
		else
			return false, 'clipboard not supported'
		end
	end

	-- НОВАЯ ФУНКЦИЯ: Импорт конфига из JSON-строки
	function SaveManager:ImportFromString(jsonString)
		if not jsonString or jsonString:gsub(' ', '') == '' then
			return false, 'empty string'
		end
		local success, decoded = pcall(httpService.JSONDecode, httpService, jsonString)
		if not success then
			return false, 'invalid JSON'
		end
		if not decoded.objects or type(decoded.objects) ~= 'table' then
			return false, 'invalid config structure'
		end
		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end)
			end
		end
		self.Library:Notify('Config imported from string')
		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor",
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName',
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings'
		}
		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/settings')
		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				local pos = file:find('.json', 1, true)
				local start = pos
				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end
				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')
			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load autoload config: ' .. err)
			end
			self.Library:Notify(string.format('Auto loaded config %q', name))
		end
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local section = tab:AddRightGroupbox('Configuration')

		section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
		section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

		section:AddDivider()

		-- Кнопка создания конфига
		section:AddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value
			if name:gsub(' ', '') == '' then 
				return self.Library:Notify('Invalid config name (empty)', 2)
			end
			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. err)
			end
			self.Library:Notify(string.format('Created config %q', name))
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		-- Кнопка загрузки конфига
		section:AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value
			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. err)
			end
			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		-- Кнопка перезаписи конфига
		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value
			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. err)
			end
			self.Library:Notify(string.format('Overwrote config %q', name))
		end)

		-- Кнопка обновления списка
		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		-- Кнопка экспорта (копирует содержимое выбранного конфига в буфер)
		section:AddButton('Export config ', function()
			local name = Options.SaveManager_ConfigList.Value
			if not name then
				return self.Library:Notify('Select a config first', 2)
			end
			local success, err = self:ExportConfig(name)
			if not success then
				self.Library:Notify('Export failed: ' .. err, 3)
			end
		end)

		-- Поле для импорта JSON строки
		section:AddInput('SaveManager_ImportString', { Text = ' ', Placeholder = 'Paste config  here' })
		section:AddButton('Import config ', function()
			local json = Options.SaveManager_ImportString.Value
			if not json or json:gsub(' ', '') == '' then
				return self.Library:Notify('Empty import string', 2)
			end
			local success, err = self:ImportFromString(json)
			if not success then
				self.Library:Notify('Import failed: ' .. err, 3)
			else
				Options.SaveManager_ImportString:SetValue('')  -- очистить поле после успешного импорта
			end
		end)

		section:AddButton('Set as autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. '/settings/autoload.txt', name)
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end)

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)
		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
		end

		-- Игнорируем элементы управления конфигами
		self:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName', 'SaveManager_ImportString' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
