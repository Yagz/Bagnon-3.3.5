--[[
	tabEditor.lua
		A popup for renaming a guild bank tab and changing its icon
		(replaces the Blizzard GuildBankPopupFrame, which is never loaded with Bagnon)
--]]

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local L = LibStub('AceLocale-3.0'):GetLocale('Bagnon')
local TabEditor = {}
Bagnon.GuildTabEditor = TabEditor

--constants
local ICON_SIZE = 36
local ICON_SPACING = 6
local ICONS_PER_ROW = 5
local ICON_ROWS = 4
local MAX_NAME_LETTERS = 15


--[[ Construction ]]--

local function iconButton_OnClick(self)
	TabEditor.selectedIcon = self.index
	TabEditor:UpdateIcons()
end

local function createIconButton(parent, i)
	local b = CreateFrame('CheckButton', nil, parent)
	b:SetWidth(ICON_SIZE)
	b:SetHeight(ICON_SIZE)

	local icon = b:CreateTexture(nil, 'BORDER')
	icon:SetAllPoints(b)
	b.icon = icon

	local ht = b:CreateTexture()
	ht:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	ht:SetAllPoints(b)
	b:SetHighlightTexture(ht)

	local ct = b:CreateTexture()
	ct:SetTexture([[Interface\Buttons\CheckButtonHilight]])
	ct:SetAllPoints(b)
	ct:SetBlendMode('ADD')
	b:SetCheckedTexture(ct)

	b:SetScript('OnClick', iconButton_OnClick)

	return b
end

function TabEditor:Create()
	local f = CreateFrame('Frame', 'BagnonGuildTabEditor', UIParent)
	f:SetFrameStrata('DIALOG')
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:Hide()

	f:SetBackdrop{
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true, tileSize = 32, edgeSize = 32,
		insets = {left = 11, right = 12, top = 12, bottom = 11}
	}

	local gridWidth = ICONS_PER_ROW * (ICON_SIZE + ICON_SPACING) - ICON_SPACING
	local gridHeight = ICON_ROWS * (ICON_SIZE + ICON_SPACING) - ICON_SPACING
	f:SetWidth(gridWidth + 70)
	f:SetHeight(gridHeight + 130)

	--name
	local nameLabel = f:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
	nameLabel:SetPoint('TOPLEFT', 24, -20)
	nameLabel:SetText(NAME)

	local editBox = CreateFrame('EditBox', 'BagnonGuildTabEditorName', f, 'InputBoxTemplate')
	editBox:SetHeight(20)
	editBox:SetPoint('TOPLEFT', nameLabel, 'BOTTOMLEFT', 6, -2)
	editBox:SetPoint('RIGHT', -24, 0)
	editBox:SetAutoFocus(false)
	editBox:SetMaxLetters(MAX_NAME_LETTERS)
	editBox:SetScript('OnTextChanged', function() TabEditor:UpdateOkayButton() end)
	editBox:SetScript('OnEnterPressed', function() TabEditor:Save() end)
	editBox:SetScript('OnEscapePressed', function() f:Hide() end)
	f.editBox = editBox

	--icons
	local iconLabel = f:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
	iconLabel:SetPoint('TOPLEFT', nameLabel, 'BOTTOMLEFT', 0, -28)
	iconLabel:SetText(L.GuildTabIcon)

	f.icons = {}
	for i = 1, ICONS_PER_ROW * ICON_ROWS do
		local b = createIconButton(f, i)
		local row = math.floor((i - 1) / ICONS_PER_ROW)
		local col = (i - 1) % ICONS_PER_ROW
		b:SetPoint('TOPLEFT', iconLabel, 'BOTTOMLEFT', col * (ICON_SIZE + ICON_SPACING), -6 - row * (ICON_SIZE + ICON_SPACING))
		f.icons[i] = b
	end

	local scroll = CreateFrame('ScrollFrame', 'BagnonGuildTabEditorScroll', f, 'FauxScrollFrameTemplate')
	scroll:SetPoint('TOPLEFT', f.icons[1], 'TOPLEFT', 0, 0)
	scroll:SetPoint('BOTTOMRIGHT', f.icons[#f.icons], 'BOTTOMRIGHT', 0, 0)
	scroll:SetScript('OnVerticalScroll', function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, ICON_SIZE + ICON_SPACING, function() TabEditor:UpdateIcons() end)
	end)
	f.scroll = scroll

	--buttons
	local cancel = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate')
	cancel:SetWidth(80)
	cancel:SetHeight(22)
	cancel:SetPoint('BOTTOMRIGHT', -16, 16)
	cancel:SetText(CANCEL)
	cancel:SetScript('OnClick', function() f:Hide() end)

	local okay = CreateFrame('Button', nil, f, 'UIPanelButtonTemplate')
	okay:SetWidth(80)
	okay:SetHeight(22)
	okay:SetPoint('RIGHT', cancel, 'LEFT', -4, 0)
	okay:SetText(OKAY)
	okay:SetScript('OnClick', function() TabEditor:Save() end)
	f.okay = okay

	--close with escape, and when the guild bank closes
	tinsert(UISpecialFrames, f:GetName())
	f:RegisterEvent('GUILDBANKFRAME_CLOSED')
	f:SetScript('OnEvent', function(self) self:Hide() end)

	self.frame = f
	return f
end

function TabEditor:GetFrame()
	return self.frame or self:Create()
end


--[[ Actions ]]--

function TabEditor:CanEdit(tabID)
	return IsGuildLeader() and tabID <= GetNumGuildBankTabs()
end

function TabEditor:Open(tabID, anchor)
	if not self:CanEdit(tabID) then
		return
	end

	local f = self:GetFrame()
	local name, icon = GetGuildBankTabInfo(tabID)

	self.tabID = tabID
	self.selectedIcon = self:FindIconIndex(icon)

	f:ClearAllPoints()
	f:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -4)
	f.editBox:SetText(name or '')
	f:Show()
	f.editBox:SetFocus()
	f.editBox:HighlightText()

	self:UpdateIcons()
	self:ScrollToSelected()
end

function TabEditor:Save()
	local f = self:GetFrame()
	local name = strtrim(f.editBox:GetText() or '')

	if name ~= '' and self.selectedIcon and self:CanEdit(self.tabID) then
		SetGuildBankTabInfo(self.tabID, name, self.selectedIcon)
		f:Hide()
	end
end


--[[ Display ]]--

--macro item icons include the full texture path, tab icons may differ in case
function TabEditor:FindIconIndex(texture)
	if texture then
		texture = texture:lower()
		for i = 1, GetNumMacroItemIcons() do
			local icon = GetMacroItemIconInfo(i)
			if icon and icon:lower() == texture then
				return i
			end
		end
	end
	return 1
end

function TabEditor:ScrollToSelected()
	local f = self:GetFrame()
	local row = math.floor(((self.selectedIcon or 1) - 1) / ICONS_PER_ROW)
	local offset = math.max(0, row - ICON_ROWS + 1)

	--setting the scroll bar value triggers OnVerticalScroll, which updates the icons
	local scrollBar = _G[f.scroll:GetName() .. 'ScrollBar']
	scrollBar:SetValue(offset * (ICON_SIZE + ICON_SPACING))
	FauxScrollFrame_SetOffset(f.scroll, offset)
	self:UpdateIcons()
end

function TabEditor:UpdateIcons()
	local f = self:GetFrame()
	local numIcons = GetNumMacroItemIcons()
	local offset = FauxScrollFrame_GetOffset(f.scroll)

	for i, b in ipairs(f.icons) do
		local index = offset * ICONS_PER_ROW + i
		if index <= numIcons then
			b.index = index
			b.icon:SetTexture(GetMacroItemIconInfo(index))
			b:SetChecked(index == self.selectedIcon)
			b:Show()
		else
			b:Hide()
		end
	end

	FauxScrollFrame_Update(f.scroll, math.ceil(numIcons / ICONS_PER_ROW), ICON_ROWS, ICON_SIZE + ICON_SPACING)
	self:UpdateOkayButton()
end

function TabEditor:UpdateOkayButton()
	local f = self:GetFrame()
	if strtrim(f.editBox:GetText() or '') ~= '' and self.selectedIcon then
		f.okay:Enable()
	else
		f.okay:Disable()
	end
end
