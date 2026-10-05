--[[
	bag.lua
		A bag button object for Bagnon
--]]

local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')
local L = LibStub('AceLocale-3.0'):GetLocale('Bagnon')
local GuildTab = Bagnon.Classy:New('CheckButton')
Bagnon.GuildTab = GuildTab

--constants
local SIZE = 32
local NORMAL_TEXTURE_SIZE = 64 * (SIZE/36)


--[[ Constructor ]]--

function GuildTab:New(tabID, frameID, parent)
	local tab = self:Create(tabID, parent)
	tab:SetFrameID(frameID)

	tab:SetScript('OnEnter', tab.OnEnter)
	tab:SetScript('OnLeave', tab.OnLeave)
	tab:SetScript('OnClick', tab.OnClick)
	tab:SetScript('OnDragStart', tab.OnDrag)
	tab:SetScript('OnReceiveDrag', tab.OnClick)
	tab:SetScript('OnEvent', tab.OnEvent)
	tab:SetScript('OnShow', tab.OnShow)
	tab:SetScript('OnHide', tab.OnHide)

	return tab
end

function GuildTab:Create(tabID, parent)
	local tab = self:Bind(CreateFrame('CheckButton', 'BagnonGuildTab' .. self:GetNextID(), parent))
	tab:SetWidth(SIZE)
	tab:SetHeight(SIZE)
	tab:SetID(tabID)

	local name = tab:GetName()
	local icon = tab:CreateTexture(name .. 'IconTexture', 'BORDER')
	icon:SetAllPoints(tab)

	local count = tab:CreateFontString(name .. 'Count', 'OVERLAY')
	count:SetFontObject('NumberFontNormalSmall')
	count:SetJustifyH('RIGHT')
	count:SetPoint('BOTTOMRIGHT', -2, 2)

	local nt = tab:CreateTexture(name .. 'NormalTexture')
	nt:SetTexture([[Interface\Buttons\UI-Quickslot2]])
	nt:SetWidth(NORMAL_TEXTURE_SIZE)
	nt:SetHeight(NORMAL_TEXTURE_SIZE)
	nt:SetPoint('CENTER', 0, -1)
	tab:SetNormalTexture(nt)

	local pt = tab:CreateTexture()
	pt:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	pt:SetAllPoints(tab)
	tab:SetPushedTexture(pt)

	local ht = tab:CreateTexture()
	ht:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	ht:SetAllPoints(tab)
	tab:SetHighlightTexture(ht)

	local ct = tab:CreateTexture()
	ct:SetTexture([[Interface\Buttons\CheckButtonHilight]])
	ct:SetAllPoints(tab)
	ct:SetBlendMode('ADD')
	tab:SetCheckedTexture(ct)

	tab:RegisterForClicks('anyUp')
	tab:RegisterForDrag('LeftButton')

	return tab
end

do
	local id = 0
	function GuildTab:GetNextID()
		id = id + 1
		return id
	end
end


--[[ Events ]]--

function GuildTab:OnEvent(event, ...)
	local action = self[event]
	if action then
		action(self, event, ...)
	end
end

function GuildTab:UpdateEvents()
	self:UnregisterAllEvents()
	self:UnregisterAllMessages()

	if self:IsVisible() then
		self:RegisterMessage('GUILD_BANK_TAB_CHANGE')
		self:RegisterEvent('GUILDBANK_UPDATE_TABS')
		self:RegisterEvent('GUILDBANKBAGSLOTS_CHANGED')
	end
end


--[[ Messages ]]--

function GuildTab:GUILDBANK_UPDATE_TABS()
	self:Update()
end

function GuildTab:GUILD_BANK_TAB_CHANGE(msg, tabID)
	self:UpdateChecked()
end

function GuildTab:GUILDBANKBAGSLOTS_CHANGED()
	self:UpdateCount()
end

--[[ Frame Events ]]--

function GuildTab:OnShow()
	self:UpdateEverything()
end

function GuildTab:OnHide()
	self:UpdateEvents()
end

function GuildTab:OnClick(button)
	if button == 'RightButton' then
		Bagnon.GuildTabEditor:Open(self:GetID(), self)
		return
	end

	if self:IsPurchasable() then
		self:PurchaseTab()
		return
	end

	if not self:IsPurchased() then
		return
	end

	SetCurrentGuildBankTab(self:GetID())
	QueryGuildBankTab(self:GetID())
	self:SendMessage('GUILD_BANK_TAB_CHANGE', self:GetID())
end

function GuildTab:OnDrag()
	--on drag
end

function GuildTab:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	else
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	end

	self:UpdateTooltip()
end

function GuildTab:OnLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end


--[[ Actions ]]--

function GuildTab:UpdateEverything()
	self:UpdateEvents()
	self:Update()
	self:UpdateChecked()
end

function GuildTab:Update()
	local name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals = GetGuildBankTabInfo(self:GetID())
	SetItemButtonTexture(self, icon or [[Interface\PaperDoll\UI-PaperDoll-Slot-Bag]])
	
	self:UpdateCount(remainingWithdrawals)
	
	--color red if the bag can be purchased
	if not isViewable then
		SetItemButtonTextureVertexColor(self, 1, 0.1, 0.1)
	else
		SetItemButtonTextureVertexColor(self, 1, 1, 1)
	end
end

function GuildTab:SetCount(count)
	local text = _G[self:GetName() .. 'Count']
	local count = count or 0

	if count > 1 then
		if count > 999 then
			text:SetFormattedText('%.1fk', count/1000)
		else
			text:SetText(count)
		end
		text:Show()
	else
		text:Hide()
	end
end

function GuildTab:UpdateChecked()
	self:SetChecked(self:IsCurrentTab())
end

function GuildTab:UpdateCount(count)
	--hack, since the amount of withdrawls seems to only be correct when we're looking at the current tab
	if not self:IsCurrentTab()  then 
		return 
	end
	
	if not count then
		local name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals = GetGuildBankTabInfo(self:GetID())
		count = remainingWithdrawals
	end

	self:SetCount(count)
end

function GuildTab:IsCurrentTab()
	return self:GetID() == GetCurrentGuildBankTab()
end


--[[ Purchasing ]]--

function GuildTab:IsPurchased()
	return self:GetID() <= GetNumGuildBankTabs()
end

--only the guild leader can buy tabs, and only the next one in line
function GuildTab:IsPurchasable()
	local cost = GetGuildBankTabCost()
	return IsGuildLeader() and self:GetID() == GetNumGuildBankTabs() + 1 and cost and cost > 0
end

--shows the standard red "not enough money" error, returns true if we can pay for the next tab
local function canAffordTab()
	if GetMoney() < (GetGuildBankTabCost() or 0) then
		UIErrorsFrame:AddMessage(ERR_NOT_ENOUGH_MONEY or L.NotEnoughMoney, 1, 0.1, 0.1, 1)
		return false
	end
	return true
end

function GuildTab:PurchaseTab()
	if not canAffordTab() then
		return
	end

	if not StaticPopupDialogs['CONFIRM_BUY_GUILDBANK_TAB_BAGNON'] then
		StaticPopupDialogs['CONFIRM_BUY_GUILDBANK_TAB_BAGNON'] = {
			text = CONFIRM_BUY_GUILDBANK_TAB or L.TipPurchaseGuildTab,
			button1 = YES,
			button2 = NO,

			OnAccept = function()
				--money may have changed while the popup was shown
				if canAffordTab() then
					BuyGuildBankTab()
				end
			end,

			OnShow = function(self)
				MoneyFrame_Update(self:GetName() .. 'MoneyFrame', GetGuildBankTabCost())
			end,

			hasMoneyFrame = 1,
			timeout = 0,
			hideOnEscape = 1,
		}
	end

	StaticPopup_Show('CONFIRM_BUY_GUILDBANK_TAB_BAGNON')
end


--[[ Tooltip Methods ]]--

function GuildTab:UpdateTooltip()
	if self:IsPurchasable() then
		GameTooltip:SetText(BUY_GUILDBANK_TAB or L.TipPurchaseGuildTab, 1, 1, 1)
		GameTooltip:AddLine(L.TipPurchaseGuildTab)
		SetTooltipMoney(GameTooltip, GetGuildBankTabCost())
		if GetMoney() < GetGuildBankTabCost() then
			GameTooltip:AddLine(ERR_NOT_ENOUGH_MONEY or L.NotEnoughMoney, 1, 0.1, 0.1)
		end
		GameTooltip:Show()
		return
	end

	local name, icon, isViewable, canDeposit, numWithdrawals, remainingWithdrawals = GetGuildBankTabInfo(self:GetID())

	if name then
		GameTooltip:SetText(name)

		local access
		if not canDeposit and numWithdrawals == 0 then
			access = RED_FONT_COLOR_CODE .. "(" .. GUILDBANK_TAB_LOCKED .. ")" .. FONT_COLOR_CODE_CLOSE;
		elseif not canDeposit then
			access = RED_FONT_COLOR_CODE .."(" .. GUILDBANK_TAB_WITHDRAW_ONLY .. ")" .. FONT_COLOR_CODE_CLOSE;
		elseif numWithdrawals == 0 then
			access = RED_FONT_COLOR_CODE .."(" .. GUILDBANK_TAB_DEPOSIT_ONLY .. ")" .. FONT_COLOR_CODE_CLOSE;
		else
			access = GREEN_FONT_COLOR_CODE .. "(" .. GUILDBANK_TAB_FULL_ACCESS .. ")" .. FONT_COLOR_CODE_CLOSE;
		end

		GameTooltip:AddLine(access)

		if Bagnon.GuildTabEditor:CanEdit(self:GetID()) then
			GameTooltip:AddLine(L.TipEditGuildTab)
		end
	else
		GameTooltip:SetText('Unavailable')
	end

	GameTooltip:Show()
end


--[[ Accessor Functions ]]--


--returns the bagnon frame we're attached to
function GuildTab:SetFrameID(frameID)
	if self:GetFrameID() ~= frameID then
		self.frameID = frameID
		self:UpdateEverything()
	end
end

function GuildTab:GetFrameID()
	return self.frameID
end

--return the settings object associated with this frame
function GuildTab:GetSettings()
	return Bagnon.FrameSettings:Get(self:GetFrameID())
end