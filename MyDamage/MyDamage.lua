local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
EventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
EventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

local MyDamageVersion="1.2.1"
local myDamageTable={}
local tick={}
local mapped=false
local BTtable, ABTable, ABobjects  = {}, {}, {}
local debugEnabled
local full="full"
local periodic="periodic"
local colorPrefix="|cff"
local colorSuffix="|r"
local healColor="00ff00"
local damageColor="ff0000"
local absorbColor="ffff00"
local barColor="ffffff"
local DMG={}
local timeLastEvent
local lastChange
local delay=10
local lastSpell
local lastSpellTime
local lastSpellType

local OptionFrame = CreateFrame("Frame", "OptionFrame", UIParent)
local Display = CreateFrame("Frame", "Display", OptionFrame)
local resetButton = CreateFrame("Button", "ResetButton", OptionFrame,"UIPanelButtonTemplate")

local currentSpec 
local currentSpecName 
local damageTableSpec 

local AUTO_ATTACK_ID = 6603
local AUTO_ATTACK = GetSpellInfo(AUTO_ATTACK_ID)

local fullNumber=0	
local fullHeal = 0
local periodicNumber=0
local stringButton=""

------------------------------------------------------------
-- debugPrint: Print messages when debug mode is on       --
-- Parameter: message - message to be shown               --
------------------------------------------------------------
local function debugPrint(message)	
	if ((debugEnabled==true) and message) then
		DEFAULT_CHAT_FRAME:AddMessage(message,1,1,0)
	end
end

------------------------------------------------------------
-- shortNumber: Convert huge numbers in a short form      --
--              higher than 1000 turn 1k                  --
--				higher than 1000000 turn 1m               --
-- Number: Number                   					  --
-- Return: string with number in short form               --
------------------------------------------------------------
local function shortNumber(number)
	local sNumber
	if (number>=1000000) then
		sNumber= string.format("%.1fm",number/1000000)
	else
		if (number>=1000) then
			sNumber= string.format("%.1fk",number/1000)
		else
			sNumber=number
		end
	end
	return sNumber
end

------------------------------------------------------------
-- createDisplay:  Creates display frame                   --
-- 
------------------------------------------------------------
local function createDisplay()
	Display:SetBackdrop({
		edgeSize = 16,
		tile = true,
		tileSize= 16,
		insets = { left = 0, right = 0, top = 0, bottom = 0}
	})
	Display:SetWidth(250) 
	Display:SetHeight(300)
	Display:SetBackdropBorderColor(.8, .8, .8, .9)	
	Display:SetPoint("TOPLEFT",20,-40)	
	Display.text = Display:CreateFontString(nil, nil, "GameFontNormalLeft")
	Display.text:SetFont("Fonts\\FRIZQT__.TTF",11,"THICKOUTLINE")
	Display.text:SetPoint("TOP",0,0)	
	Display.text:SetPoint("LEFT",10,0)	
	Display.text:SetTextColor(255,255,255,1)		
	Display:Show()	
end 

-- pairsByKeys: sort a table
function pairsByKeys (t, f)
	local a = {}
		for n in pairs(t) do table.insert(a, n) end
		table.sort(a, f)
		local i = 0      
		local iter = function () 
			i = i + 1
			if a[i] == nil then return nil
			else return a[i], t[a[i]]
			end
		end
	return iter
end

-- formatDisplayText: Format text to display the damage table
function formatDisplayText(fullDamage, periodicDamage, fullHeal, periodicHeal, absorb)
	local colorHeal=colorPrefix..healColor
	local colorDamage = colorPrefix..damageColor
	local colorAbsorb = colorPrefix..absorbColor
	local colorEnd = colorSuffix
	local damageText=""
	local healText=""
	local absorbText=""

	if ((fullDamage>0) or (periodicDamage>0)) then
		damageText = colorDamage
		if (fullDamage>0) then
			damageText = damageText .. fullDamage 
		end
		if (periodicDamage>0) then
			damageText = damageText.." ("..periodicDamage ..")"
		end
		damageText = damageText .. colorEnd
	end

	if ((fullHeal>0) or (periodicHeal>0)) then
		healText = colorHeal
		if (fullHeal>0) then
			healText = healText .. fullHeal 
		end
		if (periodicHeal>0) then
			healText = healText.." ("..periodicHeal ..") "
		end
		healText = healText .. colorEnd
	end
	
	if ((absorb) and (absorb>0)) then
		absorbText= string.format("%s%s%s",colorAbsorb,absorb,colorEnd)		
	end	
		
	return (damageText or " ").." "..(healText or " ").." "..(absorbText or " ")
end

-- fillDisplay: write the damage table in display frame
local function fillDisplay()
	local texto=""	
	local linesHeight=1
	if (myDamageTable) then
		for spellName, dTable in pairsByKeys(myDamageTable) do
			texto = string.format("%s\r\n%s - %s",texto, spellName, formatDisplayText(dTable[full].amount, dTable[periodic].amount, dTable[full].heal, dTable[periodic].heal, dTable[full].absorb))
			linesHeight=linesHeight+1
		end
		if (Display.text)  then
			height = linesHeight*12			
			Display:SetHeight(height) 
			Display.text:SetText("\r\n"..(texto or " "))			
		end		
	end
end

-- fixFrameName: Fix the button name with the actual button position
local function fixFrameName(frameName)
	local fFrame=frameName
	if (string.match(fFrame,"%a*")=="OverrideActionBarButton") then 
	end
	local playerClass, englishClass=UnitClass("player")	
	if (frameName=="OverrideActionBarButton1") then fFrame="MultiBarBottomLeftButton1" end
	if (frameName=="OverrideActionBarButton2") then fFrame="MultiBarBottomLeftButton2" end
	if (frameName=="OverrideActionBarButton3") then fFrame="MultiBarBottomLeftButton3" end
	if (frameName=="OverrideActionBarButton4") then fFrame="MultiBarBottomLeftButton4" end
	if (frameName=="OverrideActionBarButton5") then fFrame="MultiBarBottomLeftButton5" end
	if (frameName=="OverrideActionBarButton6") then fFrame="MultiBarBottomLeftButton6" end
	if (frameName=="ExtraActionButton1") then fFrame="MultiBarBottomLeftButton7" end
	if (frameName=="MultiCastActionButton1") then fFrame="MultiBarBottomLeftButton8" end
	if (frameName=="MultiCastActionButton2") then fFrame="MultiBarBottomLeftButton9" end
	if (frameName=="MultiCastActionButton3") then fFrame="MultiBarBottomLeftButton10" end
	if (frameName=="MultiCastActionButton4") then fFrame="MultiBarBottomLeftButton11" end
	if (frameName=="MultiCastActionButton5") then fFrame="MultiBarBottomLeftButton12" end
	if ((englishClass=="WARRIOR") or (englishClass=="MONK"))  then
		if (frameName=="MultiCastActionButton6") then fFrame="ActionButton1" end
		if (frameName=="MultiCastActionButton7") then fFrame="ActionButton2" end
		if (frameName=="MultiCastActionButton8") then fFrame="ActionButton3" end
		if (frameName=="MultiCastActionButton9") then fFrame="ActionButton4" end
		if (frameName=="MultiCastActionButton10") then fFrame="ActionButton5" end
		if (frameName=="MultiCastActionButton11") then fFrame="ActionButton6" end
		if (frameName=="MultiCastActionButton12") then fFrame="ActionButton7" end
	end 	
	return fFrame
end 
 
 -- clearActionBar: clear action bar text
local function clearActionBar()
	for i, button in pairs(ActionBarButtonEventsFrame.frames) do
		if (button.text) then
			button.text:SetText("")
		end
	end
	if (IsAddOnLoaded("Bartender4") or IsAddOnLoaded("ElvUI")) then
		for i, button in pairs(BTtable) do
			if (button.text) then
				button.text:SetText("")
			end
		end		
	end
end

-- mapBTFrames: map BT and elvUI buttons
local function mapBTFrames()
	if ((not mapped) and IsAddOnLoaded("ElvUI") ) then
		local bar = 1
		local butt =1
		for i,button in pairs(ABobjects) do			
			if (butt==13) then bar=bar+1; butt=1; end
			if (bar==2) then bar=3 end
			if (bar==4) then bar=5 end
			local elvName="ElvUI_Bar"..bar.."Button"..butt			
			local buttonName=button:GetName()
			local buttonName=button:GetName()
			if (_G[elvName]) then
				local barFrame=_G[elvName]
				BTtable[buttonName] = barFrame
				if (barFrame) then
					barFrame.text = barFrame:CreateFontString(nil, nil, "GameFontNormalLeft")
					barFrame.text:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
					barFrame.text:SetPoint("BOTTOM",0,0)	
					barFrame.text:SetPoint("CENTER",0,0)	
					barFrame.text:SetTextColor(255,255,255,1)
					--barFrame.text:SetText(bar.."-"..butt)
					barFrame.text:SetText(" ")
				end	
				mapped=true
			end
			butt=butt+1
		end
	end
	
	if ((not mapped) and IsAddOnLoaded("Bartender4")) then
		for i,button in pairs(ABobjects) do
			local buttonName=button:GetName()
			local posi=i
			local BTname
			if ((posi>=13) and (posi<=24)) then --bottomleftbar
				BTname="BT4Button"..i+48
			elseif ((posi>=25) and (posi<=36)) then -- bottomright
				BTname="BT4Button"..i+24
			elseif ((posi>=37) and (posi<=48)) then -- right
				BTname="BT4Button"..i-12
			elseif ((posi>=49) and (posi<=60)) then -- left
				BTname="BT4Button"..i - 12
			elseif ((posi>=61) and (posi<=72)) then -- bonus
				BTname="BT4Button"..i - 48
			else
				BTname="BT4Button"..i
			end
			if (_G[BTname]) then
				local barFrame=_G[BTname]
				BTtable[buttonName] = barFrame
				if (barFrame) then
					barFrame.text = barFrame:CreateFontString(nil, nil, "GameFontNormalLeft")
					barFrame.text:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
					barFrame.text:SetPoint("BOTTOM",0,0)	
					barFrame.text:SetPoint("CENTER",0,0)	
					barFrame.text:SetTextColor(255,255,255,1)
				end
				mapped=true
			end
		end		
	end	
end

-- makeButtonText: create text button text
local function makeButtonText(stringButton, damage, textColor,periodic)
	if ((damage) and (damage>0)) then	
		if(string.len(stringButton)>1) then stringButton=stringButton.."\r\n" end
		if (periodic) then
			return string.format("%s%s%s(%s)%s",stringButton,colorPrefix,textColor,shortNumber(damage),colorSuffix)	
		else
			return string.format("%s%s%s%s%s",stringButton,colorPrefix,textColor,shortNumber(damage),colorSuffix)	
		end
	else 
		return stringButton
	end
end

-- updateFrame: update button text
local function updateFrame(frameToUpdate, damage, damageOffHand, damageHeal)	
	fullNumber=0	
	fullHeal = 0
	periodicNumber=0
	stringButton=""
	if(damageOffHand) then
		if(damageOffHand[periodic].amount>0) then													
			periodicNumber=damageOffHand[periodic].amount					
		end
		fullNumber=damageOffHand[full].amount													
	end 
	if(damageHeal) then
		fullHeal = damage[full].heal + damageHeal[full].heal
	else
		fullHeal = damage[full].heal
	end
	stringButton = makeButtonText(stringButton, fullNumber+damage[full].amount, barColor)
	stringButton = makeButtonText(stringButton, periodicNumber+damage[periodic].amount, barColor,1)
	stringButton = makeButtonText(stringButton, fullHeal, healColor)
	stringButton = makeButtonText(stringButton, damage[periodic].heal, healColor,1)
	stringButton = makeButtonText(stringButton, damage[full].absorb, absorbColor)
	frameToUpdate.text:SetText(stringButton)	
	stringButton=""
end

-- getButtonBySpell: get the action bar button with that spell
local function getButtonBySpell(spellName)
	local listOfButton={}
	for action, spell in pairs(ABTable) do
		if (spell==spellName) then
			table.insert(listOfButton,action)
		end	
	end
	return listOfButton
end 

-- setButtonValue: set the action button text
local function setButtonValue(spellName) 
	local actionList = getButtonBySpell(spellName)	
	for _,action in pairs(actionList) do
		if(ABTable[action]) then				
			local ActionButton=_G[action]
			local damage = myDamageTable[spellName]
			local damageOffHand = myDamageTable[spellName.." Off-Hand"]	
			local damageHeal = myDamageTable[spellName.." Heal"]
			local color				
			if (damage) then		
				local damageText												
				frameToUpdate = ActionButton
				if (frameToUpdate) then					
					if (IsAddOnLoaded("Bartender4") or IsAddOnLoaded("ElvUI")) then
						frameToUpdate = BTtable[fixFrameName(ActionButton:GetName())]
						if (frameToUpdate) then	updateFrame(frameToUpdate,damage, damageOffHand, damageHeal) end
					else
						updateFrame(frameToUpdate,damage, damageOffHand, damageHeal)
					end
				end					
			end
		end
	end
end

-- mapABSpell: map action bar buttons
local function mapABSpell()
	wipe(ABTable)
	ABTable={}
	for _, ActionButton in pairs(ABobjects) do       
		local slot = ActionButton_GetPagedID(ActionButton) or ActionButton_CalculateAction(ActionButton) or ActionButton:GetAttribute('action') or 0
		if HasAction(slot) then
			local actionName, buttonName
			local actionType, id = GetActionInfo(slot)
			buttonName=ActionButton:GetName()
			if actionType == 'macro' then _, _ , id = GetMacroSpell(id) end
			if actionType == 'item' then
				actionName = GetItemInfo(id)
			elseif actionType == 'spell' or (actionType == 'macro' and id) then
				actionName = GetSpellInfo(id)
			end
			if actionName then			
				ABTable[buttonName]=actionName				
			end
		end
	end
end

-- setABValues: set text for all buttons in action bar
local function setABValues()	
	mapBTFrames()	
	mapABSpell()
	for spellName in pairs(myDamageTable) do
		setButtonValue(spellName)
	end
	
end

-- GetSpecName: get current spec
local function GetSpecName()
	local currentSpec = GetSpecialization()
	local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or "None"
	local damageTableSpec
	if (currentSpecName=="None") then
		damageTableSpec = "Mydamage-None"
	else
		damageTableSpec = "Mydamage-"..((currentSpec..currentSpecName) or "nospec")
	end
	return damageTableSpec
end

local function DetermineAB()
	ABobjects={}
	for i = 1, 6 do
		for j = 1, 12 do
			table.insert(ABobjects,_G[((select(i,"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton", "BonusActionButton"))..j)])
		end
	end
	if playerClass == "SHAMAN" then
		for i = 1, 4 do
			table.insert(ABobjects,_G[("MultiCastActionButton"..i)])
		end
	end	
	if IsAddOnLoaded("Bartender4") then

	end
	if IsAddOnLoaded("ElvUI") then
		--DEFAULT_CHAT_FRAME:AddMessage("ElvUI ligado")
	end
end 

-- loadData: load recorded data
local function loadData() 
	local spec=GetSpecName()
	if (currentSpecName ~= "Mydamage-nospec") then		
		if type(CharacterVar) ~= "table" then  
			CharacterVar = {}	
		else 					
			if ((CharacterVar["version"]) and (CharacterVar["version"]==MyDamageVersion)) then	
				if (type(CharacterVar[spec]) == "table") then
					for i,valor in pairs(CharacterVar[spec]) do
						myDamageTable[i]=valor				
					end
				end	
			else
				myDamageTable = {}
				CharacterVar = {}
			end			
		end
		debugEnabled=CharacterVar["debug"]
		if (debugEnabled~=true) then debugEnabled=false end
	end
 end 
 
 -- saveData: save recorded data
local function saveData()
	local spec=GetSpecName()
	if (currentSpecName ~= "") then
		CharacterVar["version"]=MyDamageVersion
		CharacterVar[spec]=myDamageTable
	end
end

-- resetData: wipe tabledata
local function resetData()
	CharacterVar[GetSpecName()]={}
	wipe(myDamageTable)
	myDamageTable={}
	mapped=false
	ABTable={}
	DetermineAB()
	mapABSpell()
	clearActionBar()		
	fillDisplay()		
	loadData()
end
----------
-- HandleChatCommand: handle chat commands
local function HandleChatCommand(input)

   if (not input or (input:trim() == "")) then
	
   else
		if((input=="show") or (string.match(input,"%opt*"))) then
			InterfaceOptionsFrame_OpenToCategory("MyDamage")
			InterfaceOptionsFrame_OpenToCategory("MyDamage")
		end
		if (input=="reset") then
			resetData()
		end
		if (input=="debug") then			
			if (debugEnabled==true) then
				debugPrint("debug: disable")
				debugEnabled=false
			else
				debugEnabled=true
				debugPrint("debug: enable")				
			end
			CharacterVar["debug"]=debugEnabled
		end
   end
   
end

local function setDamage(dmg, amount, multistrike)
	
	if (not dmg.amount2nd) then amount2nd=0 end
	if (not dmg.amount1st) then amount1st=0 end
	if(multistrike==1) then
		dmg.amount1st=floor(dmg.amount1st+amount)
	else
		if(dmg.amount1st==0) then
			dmg.amount1st=amount
		else
			if(dmg.amount2nd==0) then
				dmg.amount2nd=dmg.amount1st
				dmg.amount1st=amount
			else				
				dmg.amount=floor((dmg.amount2nd + dmg.amount1st + amount)/3)
				dmg.amount2nd=dmg.amount1st
				dmg.amount1st=amount				
			end
		end
	end
	debugPrint("SetDamage:"..(amount or "").." / ms:"..(multistrike or "").." / 0:"..(dmg.amount or "") .." / 1:"..(dmg.amount2nd or "") .." / 2:".. (dmg.amount1st or ""))
	return dmg
end
-- updateDamageTable: update damage table
local function updateDamageTable(spellName,amount, damageType, heal, absorb, multistrike)
	DMG={ full={amount=0, spellid=0, heal=0, amount1st=0, amount2nd=0, absorb=0}, periodic={amount=0, spellid=0, heal=0,amount1st=0, amount2nd=0} }
	if (myDamageTable[spellName]) then
		--damage
		DMG=myDamageTable[spellName]
		DMG[damageType]=setDamage(DMG[damageType], amount, multistrike)
		if ((DMG[damageType].heal==0)) then 
			DMG[damageType].heal=heal 
		elseif (heal>0) then
			DMG[damageType].heal=floor((heal + DMG[damageType].heal)/2)
		end								
		DMG[damageType].spellid=AUTO_ATTACK_ID
		if ((absorb) and (damageType=="full") and(absorb>0) ) then DMG[damageType].absorb=absorb end
		myDamageTable[spellName]= DMG	

	else
		--DMG[damageType].amount=amount
		DMG[damageType].spellid=AUTO_ATTACK_ID
		DMG[damageType].heal=heal
		if ((absorb) and (damageType=="full") and(absorb>0) ) then DMG[damageType].absorb=absorb end
		DMG[damageType]=setDamage(DMG[damageType], amount, multistrike)
		myDamageTable[spellName]= DMG	

	end
end

local function IsMyPet(flags)
	local isMyPet = CombatLog_Object_IsA(flags, COMBATLOG_FILTER_MY_PET)	
	return isMyPet	
end


local function createABFrames()	
--debugPrint("funcao("..time().."): createABFrames")
	DetermineAB()
	for _, ActionButton in pairs(ABobjects) do     
		ActionButton.text = ActionButton:CreateFontString(nil, nil, "GameFontNormalLeft")
		ActionButton.text:SetFont("Fonts\\FRIZQT__.TTF",10,"OUTLINE")
		ActionButton.text:SetPoint("BOTTOM",0,0)	
		ActionButton.text:SetPoint("CENTER",0,0)	
		ActionButton.text:SetTextColor(255,255,255,1)
	end
	mapABSpell()
end

local function combatLogPlayer(eventTime, eventType, spellId, spellName, spellSchool, amount, absorb)
	-- prevent recast to accumulate
	if (eventType=="SPELL_CAST_SUCCESS") then
		if (tick[spellName]) then
			if((tick[spellName].stat=="on") and (tick[spellName].counter>1)) then
				tick[spellName].sum=0
				tick[spellName].counter=0
			end
		end
	end
	--SWING_DAMAGE
	if (eventType=="SWING_DAMAGE") then		  
		spellName="Auto Attack"	
		updateDamageTable(spellName,spellId, full, 0,0,0)				
	end
	--RANGE_DAMAGE
	if (eventType=="RANGE_DAMAGE") then		  
	
		updateDamageTable(spellName,amount, full, 0,0,0)				
	end
	--SPELL_DAMAGE
	if (eventType=="SPELL_DAMAGE") then	
		local diffTime, multistrike
		multistrike=0
		if(not lastSpell) then
			lastSpell=spellName
			lastSpellTime=eventTime		
			lastSpellType="Damage"
		else 
			diffTime=eventTime-lastSpellTime
			if(diffTime<1 and spellName==lastSpell and lastSpellType=="Damage") then
				multistrike=1
			end
		end		
		debugPrint((diffTime or "nil")..": eventType: "..(eventType or "Null").." /spellId: "..(spellId or "Null").." /spellName: "..(spellName or "Null").." /spellSchool: "..(spellSchool or "Null").." /amount: "..(amount or "Null").." /absorb: "..(absorb or "Null"))
		lastSpell=spellName
		lastSpellTime=eventTime
		lastSpellType="Damage"
		updateDamageTable(spellName,amount, full, 0,0, multistrike)	
	end 	
	
	--SPELL_AURA_APPLIED
	if (eventType=="SPELL_AURA_APPLIED") then	
		
		if ((absorb) and (absorb>0)) then
			updateDamageTable(spellName,0, full, 0,absorb)	
		else			
			if((spellName=="Cat Form") or (spellName=="Bear Form") or (spellName=="Shadowform") or (spellName=="Stealth")) then
				clearActionBar()
				setABValues()
			else
				tick[spellName]={stat="on", counter=0, target=destGUID, sum=0, heal=0}			
			end
		end
	end 	
	--SPELL_AURA_REMOVED
	if (eventType=="SPELL_AURA_REMOVED") then	
		if((spellName=="Cat Form") or (spellName=="Bear Form")) then
			clearActionBar()
			setABValues()
		end
		if((tick[spellName]) and (tick[spellName].target==destGUID) and (tick[spellName].stat=="on") and (tick[spellName].sum>0)) then														
			if (tick[spellName].sum~=0) then
				if(tick[spellName].heal==1) then
					updateDamageTable(spellName, 0, periodic, tick[spellName].sum,0,0)
				else
					updateDamageTable(spellName, tick[spellName].sum, periodic, 0,0,0)
				end
			end					
		end
		tick[spellName]={}
	end 			
	--SPELL_PERIODIC_DAMAGE
	if (eventType=="SPELL_PERIODIC_DAMAGE") then	
		
		if((tick[spellName]) and (tick[spellName].target==destGUID) and (tick[spellName].stat=="on")) then
			tick[spellName].counter=tick[spellName].counter+1
			tick[spellName].sum=tick[spellName].sum+amount
			tick[spellName].heal=0			
		end				
		if (not(tick[spellName])) then
			updateDamageTable(spellName,amount, periodic, 0,0,0)
		end
	end			
	--SPELL_HEAL
	if (eventType=="SPELL_HEAL") then	
		local diffTime, multistrike
		multistrike=0
		if(not lastSpell) then
			lastSpell=spellName
			lastSpellTime=eventTime
			lastSpellType="Heal"
		else 
			diffTime=eventTime-lastSpellTime
			if(diffTime<1 and spellName==lastSpell and lastSpellType=="Heal") then
				multistrike=1
			end
		end		
		debugPrint((diffTime or "nil")..": eventType: "..(eventType or "Null").." /spellId: "..(spellId or "Null").." /spellName: "..(spellName or "Null").." /spellSchool: "..(spellSchool or "Null").." /amount: "..(amount or "Null").." /absorb: "..(absorb or "Null"))
		lastSpell=spellName
		lastSpellTime=eventTime
		lastSpellType="Heal"
		updateDamageTable(spellName,0, full, amount,0)
	end
	--SPELL_PERIODIC_HEAL_
	if (eventType=="SPELL_PERIODIC_HEAL") then			  
		if((tick[spellName]) and (tick[spellName].target==destGUID) and (tick[spellName].stat=="on")) then
			tick[spellName].counter=tick[spellName].counter+1
			tick[spellName].sum=tick[spellName].sum+amount
			tick[spellName].heal=1
		end
		if (not(tick[spellName])) then
			updateDamageTable(spellName,0, periodic, amount,0, multistrike)
		end
	end			


	
end 
------------------------------------------------------------
-- optionPanel: Create option panel frame                 --
------------------------------------------------------------
local function optionPanel()	
	OptionFrame.name = "MyDamage"
	InterfaceOptions_AddCategory(OptionFrame)
	OptionFrame.text = OptionFrame:CreateFontString(nil, nil, "GameFontHighlightSmall")	
	OptionFrame.text:SetPoint("TOPLEFT",20,-15)
	OptionFrame.text:SetFont("Fonts\\FRIZQT__.TTF",13,"THICKOUTLINE")
	OptionFrame.text:SetTextColor(255,255,0,1)
	OptionFrame.text:SetText("MyDamage ("..MyDamageVersion..")")
	resetButton:SetText("Reset")
	resetButton:SetPoint("BOTTOM",0,40)
	resetButton:SetWidth(80)
	resetButton:SetHeight(18)
	resetButton:SetScript("OnClick", function(self)
	resetButton:SetNormalTexture("Interface/BUTTONS/UI-DialogBox-Button-Up")
	resetData()
	end)		
end
-------------
EventFrame:SetScript("OnEvent", function(self,event,...) 		
	local changeTime=GetTime()
	if (event=="PLAYER_LOGIN") then		
		SLASH_MYDAMAGE1, SLASH_MYDAMAGE2 = "/mydamage", "/myd"
		SlashCmdList["MYDAMAGE"]=HandleChatCommand
		loadData()
		fillDisplay()
		setABValues()
	end	
	if (event=="PLAYER_REGEN_ENABLED") then
		debugPrint(changeTime..":PLAYER_REGEN_ENABLED")
	end
	if (event=="ACTIONBAR_SLOT_CHANGED") then				
		if (not lastChange) then lastChange=changeTime end
		if (changeTime>lastChange+delay) then
		end
	end
	if (event=="ACTIVE_TALENT_GROUP_CHANGED") then
		clearActionBar()
		DetermineAB()
		mapABSpell()		
	end	
	if(event=="COMBAT_LOG_EVENT_UNFILTERED") then	
		local eventTime, eventType, _, _, sourceName, sourceFlags, _, destGUID = select(1, ...) 	
		if(not timeLastEvent) then timeLastEvent=eventTime+30 end
		if (sourceName) then		
			if (UnitGUID(sourceName)) then
				if (IsMyPet(sourceFlags)) then 	
					if (eventType=="SPELL_DAMAGE") then		  
						local spellName, _ , amount = select(13, ...)								
						updateDamageTable(spellName,amount, full, 0)						
					end
				end						
			end					
		end
		if (sourceName==UnitName('Player')) then			
			local spellId, spellName, spellSchool, amount, absorb  = select(12, ...)		
			combatLogPlayer(eventTime, eventType, spellId, spellName, spellSchool, amount, tonumber(string.format("%u",absorb)))			
			saveData()
		end	
		if (eventTime>timeLastEvent) then			
			setABValues()
			fillDisplay()
			timeLastEvent=eventTime+delay
		end
		
	end	
end)

optionPanel()
createDisplay()
createABFrames()
