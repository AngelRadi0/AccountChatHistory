local ADDON = ...

local f = CreateFrame("Frame")

-- ===== Config =====

local CFG = {
    GlobalChannelName = "Global",
    MaxLines = 3000,
    ReplayOnLogin = true,
}

local ReplayCurrentView

-- ===== Simple timer (3.3.5-safe) =====

local _timers = {}
local _timerFrame = CreateFrame("Frame")

_timerFrame:SetScript("OnUpdate", function(_, elapsed)
    for i = #_timers, 1, -1 do
        local t = _timers[i]
        t.rem = t.rem - elapsed
        if t.rem <= 0 then
            table.remove(_timers, i)
            pcall(t.fn)
        end
    end
    if #_timers == 0 then
        _timerFrame:Hide()
    end
end)

_timerFrame:Hide()

local function After(seconds, fn)
    if type(fn) ~= "function" then return end
    table.insert(_timers, { rem = seconds or 0, fn = fn })
    _timerFrame:Show()
end

-- ===== DB helpers =====

local function Now() return time() end

local function InitDB()
    if type(ACH_DB) ~= "table" then ACH_DB = {} end
    if type(ACH_DB.realms) ~= "table" then ACH_DB.realms = {} end
    
    if type(ACH_DB.settings) ~= "table" then
        ACH_DB.settings = {
            color = { r = 176/255, g = 96/255, b = 255/255 },
            -- Per-channel text colors - each gets its own unique table
            globalColor      = { r = 176/255, g = 96/255, b = 255/255 },
            generalColor     = { r = 176/255, g = 96/255, b = 255/255 },
            partyColor       = { r = 176/255, g = 96/255, b = 255/255 },
            partyLeaderColor = { r = 176/255, g = 96/255, b = 255/255 },
            filterColor = { r = 1, g = 1, b = 1 },
            filterAlpha = 1.0, -- NEW: Transparency value for filter text (1.0 = fully opaque, 0.0 = fully transparent)
            filter = "",
            recordGlobal = true,
            recordGeneral = true,
            recordParty = true,
            retentionSeconds = 3600,
            timezoneOffset = 0,
        }
    else
        -- Ensure each color setting has its own table
        if type(ACH_DB.settings.color) ~= "table" then
            ACH_DB.settings.color = { r = 176/255, g = 96/255, b = 255/255 }
        end
        
        if type(ACH_DB.settings.globalColor) ~= "table" then
            ACH_DB.settings.globalColor = { r = 176/255, g = 96/255, b = 255/255 }
        else
            -- Make sure it's not sharing a reference with other color tables
            local g = ACH_DB.settings.globalColor
            ACH_DB.settings.globalColor = { r = g.r or 176/255, g = g.g or 96/255, b = g.b or 255/255 }
        end
        
        if type(ACH_DB.settings.generalColor) ~= "table" then
            ACH_DB.settings.generalColor = { r = 176/255, g = 96/255, b = 255/255 }
        else
            -- Make sure it's not sharing a reference with other color tables
            local g = ACH_DB.settings.generalColor
            ACH_DB.settings.generalColor = { r = g.r or 176/255, g = g.g or 96/255, b = g.b or 255/255 }
        end
        
        if type(ACH_DB.settings.partyColor) ~= "table" then
            ACH_DB.settings.partyColor = { r = 176/255, g = 96/255, b = 255/255 }
        else
            -- Make sure it's not sharing a reference with other color tables
            local p = ACH_DB.settings.partyColor
            ACH_DB.settings.partyColor = { r = p.r or 176/255, g = p.g or 96/255, b = p.b or 255/255 }
        end
        
        if type(ACH_DB.settings.partyLeaderColor) ~= "table" then
            ACH_DB.settings.partyLeaderColor = { r = 176/255, g = 96/255, b = 255/255 }
        else
            -- Make sure it's not sharing a reference with other color tables
            local p = ACH_DB.settings.partyLeaderColor
            ACH_DB.settings.partyLeaderColor = { r = p.r or 176/255, g = p.g or 96/255, b = p.b or 255/255 }
        end
        
        if type(ACH_DB.settings.filterColor) ~= "table" then
            ACH_DB.settings.filterColor = { r = 1, g = 1, b = 1 }
        else
            -- Make sure it's not sharing a reference with other color tables
            local f = ACH_DB.settings.filterColor
            ACH_DB.settings.filterColor = { r = f.r or 1, g = f.g or 1, b = f.b or 1 }
        end
        
        -- NEW: Ensure filterAlpha exists
        if type(ACH_DB.settings.filterAlpha) ~= "number" then
            ACH_DB.settings.filterAlpha = 1.0
        end
        
        if type(ACH_DB.settings.filter) ~= "string" then
            ACH_DB.settings.filter = ""
        end
        
        if type(ACH_DB.settings.recordGlobal) ~= "boolean" then
            ACH_DB.settings.recordGlobal = true
        end
        
        if type(ACH_DB.settings.recordGeneral) ~= "boolean" then
            ACH_DB.settings.recordGeneral = true
        end
        
        if type(ACH_DB.settings.recordParty) ~= "boolean" then
            ACH_DB.settings.recordParty = true
        end
        
        if type(ACH_DB.settings.retentionSeconds) ~= "number" then
            ACH_DB.settings.retentionSeconds = 3600
        end
        
        if type(ACH_DB.settings.timezoneOffset) ~= "number" then
            ACH_DB.settings.timezoneOffset = 0
        end
    end
end

local function GetRealmKey()
    local r = GetRealmName() or "UNKNOWN_REALM"
    return tostring(r)
end

local function GetRealmDB()
    local rk = GetRealmKey()
    local rdb = ACH_DB.realms[rk]
    
    if type(rdb) ~= "table" then
        rdb = { streams = {} }
        ACH_DB.realms[rk] = rdb
    end
    
    if type(rdb.streams) ~= "table" then rdb.streams = {} end
    return rdb
end

local function EnsureStream(streamKey, displayName)
    local rdb = GetRealmDB()
    local s = rdb.streams[streamKey]
    
    if type(s) ~= "table" then
        s = { name = displayName, lines = {} }
        rdb.streams[streamKey] = s
    end
    
    if type(s.lines) ~= "table" then s.lines = {} end
    if displayName and displayName ~= "" then s.name = displayName end
    return s
end

local function Trim(t, max)
    local n = #t
    if n <= max then return end
    
    for i = 1, (n - max) do
        table.remove(t, 1)
    end
end

local function TrimByAge(lines)
    if not ACH_DB or not ACH_DB.settings then return end
    
    local retention = ACH_DB.settings.retentionSeconds or 3600
    local cutoff = Now() - retention
    
    local i = 1
    while i <= #lines do
        if lines[i].t and lines[i].t < cutoff then
            table.remove(lines, i)
        else
            i = i + 1
        end
    end
end

local function PeriodicRetentionCleanup()
    local rdb = GetRealmDB()
    local hadChanges = false
    
    if rdb and rdb.streams then
        for _, stream in pairs(rdb.streams) do
            if stream.lines then
                local beforeCount = #stream.lines
                TrimByAge(stream.lines)
                if #stream.lines < beforeCount then
                    hadChanges = true
                end
            end
        end
    end
    
    if hadChanges then
        ReplayCurrentView()
    end
    
    After(30, PeriodicRetentionCleanup)
end

local function PushLine(streamKey, streamName, author, text, guid, src)
    local s = EnsureStream(streamKey, streamName)
    
    table.insert(s.lines, {
        t = Now(),
        from = author,
        msg = text,
        guid = guid,
        src = src,
    })
    
    local beforeTrim = #s.lines
    TrimByAge(s.lines)
    Trim(s.lines, CFG.MaxLines)
    if #s.lines < beforeTrim then
        ReplayCurrentView()
    end
end

-- ===== Class-colored, clickable names =====

local function ColoredPlayerLink(author, guid)
    if not author or author == "" then
        return "?"
    end
    
    local link = ("|Hplayer:%s|h[%s]|h"):format(author, author)
    
    if guid and guid ~= "" and GetPlayerInfoByGUID then
        local _, engClass = GetPlayerInfoByGUID(guid)
        if engClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[engClass] then
            local c = RAID_CLASS_COLORS[engClass]
            if c.colorStr then
                local rgb = string.sub(c.colorStr, 3, 8)
                return ("|cff%s%s|r"):format(rgb, link)
            end
            if c.r and c.g and c.b then
                return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, link)
            end
        end
    end
    
    return link
end

local function FormatLine(ts, src, author, text, guid)
    local offset = 0
    if ACH_DB and ACH_DB.settings and ACH_DB.settings.timezoneOffset then
        offset = ACH_DB.settings.timezoneOffset * 3600
    end
    
    local adjustedTime = (ts or Now()) + offset
    local stamp = date("%I:%M:%S %p", adjustedTime)
    
    src = src or "?"
    return ("[%s] [%s] %s: %s"):format(stamp, src, ColoredPlayerLink(author, guid), text or "")
end

-- ===== Chat frame (SINGLETON) =====

local achFrame

local function FindChatWindowByName(targetName)
    targetName = string.lower(targetName or "")
    
    -- Fixed indexing: Use 1-10 or check for valid chat frames
    for i = 1, 10 do
        local name = FCF_GetChatWindowInfo(i)
        if name and string.lower(name) == targetName then
            return _G["ChatFrame" .. i]
        end
    end
end

local function UnsubscribeRealChatFromACH()
    if not achFrame then return end
    
    local id = achFrame:GetID()
    
    if CFG.GlobalChannelName and CFG.GlobalChannelName ~= "" then
        RemoveChatWindowChannel(id, CFG.GlobalChannelName)
    end
    
    RemoveChatWindowChannel(id, "General")
    RemoveChatWindowMessages(id, "PARTY")
end

local function GetStreamColor(src)
    local s = ACH_DB and ACH_DB.settings
    if not s then
        return 176/255, 96/255, 255/255
    end
    
    local c
    if src == CFG.GlobalChannelName then
        c = s.globalColor
    elseif src == "General" then
        c = s.generalColor
    elseif src == "Party" then
        c = s.partyColor
    elseif src == "Party Leader" then
        c = s.partyLeaderColor
    else
        c = s.color
    end
    
    if not c or not c.r or not c.g or not c.b then
        return 176/255, 96/255, 255/255
    end
    
    return c.r, c.g, c.b
end

local function GetFilterColor()
    local c = ACH_DB and ACH_DB.settings and ACH_DB.settings.filterColor
    
    if not c or not c.r or not c.g or not c.b then
        return 1, 1, 1
    end
    
    return c.r, c.g, c.b
end

local function GetFilterAlpha()
    return ACH_DB and ACH_DB.settings and ACH_DB.settings.filterAlpha or 1.0
end

local function Out(msg, src, r, g, b)
    if not achFrame then return end
    
    local cr, cg, cb = GetStreamColor(src)
    achFrame:AddMessage(msg, r or cr, g or cg, b or cb)
end

-- ===== Filter helpers =====

local achFilterBox
local achFilterClear
local achFilterBar
local filterBarSizeHooked = false

local function PassesFilter(p)
    if not ACH_DB or not ACH_DB.settings then return true end
    
    local f = ACH_DB.settings.filter
    if not f or f == "" then
        return true
    end
    
    f = string.lower(f)
    
    local msg = string.lower(p.msg or "")
    local from = string.lower(p.from or "")
    local src = string.lower(p.src or "")
    
    if string.find(msg, f, 1, true) then return true end
    if string.find(from, f, 1, true) then return true end
    if string.find(src, f, 1, true) then return true end
    
    return false
end

local function SyncFilterBarAlpha()
    if not achFrame or not achFilterBox or not achFilterClear then return end
    local alpha = GetFilterAlpha()
    achFilterBox:SetAlpha(alpha)
    achFilterClear:SetAlpha(alpha)
end

local function UpdateFilterBarGeometry()
    if not achFrame or not achFilterBar then return end
    achFilterBar:ClearAllPoints()
    achFilterBar:SetPoint("TOPLEFT", achFrame, "BOTTOMLEFT", -3, -7)
    achFilterBar:SetPoint("TOPRIGHT", achFrame, "BOTTOMRIGHT", 3, -7)
end

local function UpdateFilterBarVisibility()
    if not achFrame or not achFilterBar or not achFilterBox or not achFilterClear then return end

    local isVisible = achFrame:IsShown()

    if isVisible then
        achFilterBox:Show()
        achFilterClear:Show()
        achFilterBar:Show()
    else
        achFilterBox:Hide()
        achFilterClear:Hide()
        achFilterBar:Hide()
    end
end

-- ===== New functions for chronological display =====

local function GetAllLinesChronologically()
    local rdb = GetRealmDB()
    local allLines = {}
    
    -- Collect all lines from all streams
    if rdb and rdb.streams then
        for streamKey, stream in pairs(rdb.streams) do
            if stream and stream.lines then
                for _, line in ipairs(stream.lines) do
                    -- Add stream info to each line
                    local lineCopy = {
                        t = line.t,
                        from = line.from,
                        msg = line.msg,
                        guid = line.guid,
                        src = line.src,
                        streamKey = streamKey
                    }
                    table.insert(allLines, lineCopy)
                end
            end
        end
    end
    
    -- Sort by timestamp (oldest first)
    table.sort(allLines, function(a, b)
        return (a.t or 0) < (b.t or 0)
    end)
    
    return allLines
end

local function FullReplay()
    achFrame:Clear()
    
    Out("----- AccountChatHistory: chronological replay (this realm) -----", nil, 0.7, 0.7, 0.7)
    
    local allLines = GetAllLinesChronologically()
    TrimByAge(allLines)
    
    if #allLines > 0 then
        Out(("Total: %d lines"):format(#allLines), nil, 0.7, 0.7, 0.7)
        
        for i = 1, #allLines do
            local p = allLines[i]
            Out(FormatLine(p.t, p.src, p.from, p.msg, p.guid), p.src)
        end
    else
        Out("(no saved history)", nil, 0.7, 0.7, 0.7)
    end
end

local function FilteredReplay()
    achFrame:Clear()
    
    Out("----- AccountChatHistory: filtered chronological replay (this realm) -----", nil, 0.7, 0.7, 0.7)
    
    local allLines = GetAllLinesChronologically()
    TrimByAge(allLines)
    
    local filteredCount = 0
    
    for i = 1, #allLines do
        local p = allLines[i]
        
        if PassesFilter(p) then
            filteredCount = filteredCount + 1
            Out(FormatLine(p.t, p.src, p.from, p.msg, p.guid), p.src)
        end
    end
    
    if filteredCount > 0 then
        Out(("Filtered: %d matching lines"):format(filteredCount), nil, 0.7, 0.7, 0.7)
    else
        Out("(no matching lines)", nil, 0.7, 0.7, 0.7)
    end
end

ReplayCurrentView = function()
    if not achFrame then return end
    if ACH_DB and ACH_DB.settings and ACH_DB.settings.filter and ACH_DB.settings.filter ~= "" then
        FilteredReplay()
    else
        FullReplay()
    end
end

-- ===== Ensure chat frame + filter bar =====

local function EnsureFilterBar()
    if achFilterBox and achFilterClear then return end
    if not achFrame then return end
    
    local bar = CreateFrame("Frame", "ACHFilterBar", achFrame:GetParent())
    bar:SetHeight(22)
    bar:SetPoint("TOPLEFT", achFrame, "BOTTOMLEFT", 0, -6)
    bar:SetPoint("TOPRIGHT", achFrame, "BOTTOMRIGHT", 0, -6)
    
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetTexture(0, 0, 0, 0.2)
    
    local eb = CreateFrame("EditBox", "ACHFilterBox", bar, "InputBoxTemplate")
    eb:SetHeight(20)
    eb:SetAutoFocus(false)
    eb:SetPoint("LEFT", bar, "LEFT", 10, 0)
    eb:SetPoint("RIGHT", bar, "RIGHT", -60, 0)
    eb:SetFontObject(GameFontNormalSmall)
    eb:SetMaxLetters(100)
    eb:SetTextInsets(4, 4, 2, 2)
    
    do
        local r, g, b = GetFilterColor()
        eb:SetTextColor(r, g, b)
    end
    
    eb:SetScript("OnEditFocusGained", function(self)
        local txt = self:GetText()
        if txt == "" then
            self:SetText("")
        end
    end)
    
    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:SetText(ACH_DB and ACH_DB.settings and ACH_DB.settings.filter or "")
    end)
    
    local function ApplyFilterFromBox()
        if not ACH_DB or not ACH_DB.settings then return end
        ACH_DB.settings.filter = eb:GetText() or ""
        if ACH_DB.settings.filter == "" then
            FullReplay()
        else
            FilteredReplay()
        end
    end
    
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    
    eb:SetScript("OnTextChanged", function(self)
        ApplyFilterFromBox()
    end)
    
    local btn = CreateFrame("Button", "ACHFilterClearButton", bar, "UIPanelButtonTemplate")
    btn:SetSize(50, 20)
    btn:SetPoint("LEFT", eb, "RIGHT", 4, 0)
    btn:SetText("Clear")
    btn:SetScript("OnClick", function()
        if ACH_DB and ACH_DB.settings then
            ACH_DB.settings.filter = ""
        end
        eb:SetText("")
        FullReplay()
    end)
    
    achFilterBar = bar
    achFilterBox = eb
    achFilterClear = btn
    UpdateFilterBarGeometry()
    
    if ACH_DB and ACH_DB.settings and ACH_DB.settings.filter then
        eb:SetText(ACH_DB.settings.filter)
    end
    
    SyncFilterBarAlpha()
    UpdateFilterBarVisibility()
end

local function EnsureChatFrame()
    if achFrame then
        EnsureFilterBar()
        SyncFilterBarAlpha()
        UpdateFilterBarVisibility()
        return
    end
    
    achFrame = FindChatWindowByName("ACH")
    
    if not achFrame then
        achFrame = FCF_OpenNewWindow("ACH")
        FCF_DockFrame(achFrame)
    end
    
    achFrame:SetFading(false)
    achFrame:SetMaxLines(2000)
    
    achFrame:HookScript("OnShow", UpdateFilterBarVisibility)
    achFrame:HookScript("OnHide", UpdateFilterBarVisibility)
    if not filterBarSizeHooked then
        achFrame:HookScript("OnSizeChanged", function()
            UpdateFilterBarGeometry()
        end)
        filterBarSizeHooked = true
    end

    UnsubscribeRealChatFromACH()
    
    EnsureFilterBar()
    SyncFilterBarAlpha()
    UpdateFilterBarVisibility()
end

local function JoinGlobal()
    if not CFG.GlobalChannelName or CFG.GlobalChannelName == "" then return end
    JoinChannelByName(CFG.GlobalChannelName)
end

local function ReplayOnLogin()
    if not CFG.ReplayOnLogin then return end
    FullReplay()
end

-- ===== Interface Options panel =====

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "ACHOptionsPanel", InterfaceOptionsFramePanelContainer)
    panel.name = "Account Chat History"
    
    -- Temporary storage for unsaved settings
    local tempSettings = {}
    
    -- Function to copy settings to temp storage
    local function CopyToTempSettings()
        tempSettings = {
            globalColor = CopyTable(ACH_DB.settings.globalColor),
            generalColor = CopyTable(ACH_DB.settings.generalColor),
            partyColor = CopyTable(ACH_DB.settings.partyColor),
            partyLeaderColor = CopyTable(ACH_DB.settings.partyLeaderColor),
            filterColor = CopyTable(ACH_DB.settings.filterColor),
            filterAlpha = ACH_DB.settings.filterAlpha,
            filter = ACH_DB.settings.filter,
            recordGlobal = ACH_DB.settings.recordGlobal,
            recordGeneral = ACH_DB.settings.recordGeneral,
            recordParty = ACH_DB.settings.recordParty,
            retentionSeconds = ACH_DB.settings.retentionSeconds,
            timezoneOffset = ACH_DB.settings.timezoneOffset,
        }
    end
    
    -- Function to apply temp settings to database
    local function ApplyTempSettings()
        ACH_DB.settings.globalColor = CopyTable(tempSettings.globalColor)
        ACH_DB.settings.generalColor = CopyTable(tempSettings.generalColor)
        ACH_DB.settings.partyColor = CopyTable(tempSettings.partyColor)
        ACH_DB.settings.partyLeaderColor = CopyTable(tempSettings.partyLeaderColor)
        ACH_DB.settings.filterColor = CopyTable(tempSettings.filterColor)
        ACH_DB.settings.filterAlpha = tempSettings.filterAlpha
        ACH_DB.settings.filter = tempSettings.filter
        ACH_DB.settings.recordGlobal = tempSettings.recordGlobal
        ACH_DB.settings.recordGeneral = tempSettings.recordGeneral
        ACH_DB.settings.recordParty = tempSettings.recordParty
        ACH_DB.settings.retentionSeconds = tempSettings.retentionSeconds
        ACH_DB.settings.timezoneOffset = tempSettings.timezoneOffset
        
        -- Update UI if chat window is visible
        if achFrame and achFrame:IsVisible() then
            if tempSettings.filter and tempSettings.filter ~= "" then
                FilteredReplay()
            else
                FullReplay()
            end
        end
        
        -- Update filter box color
        if achFilterBox then
            local r, g, b = tempSettings.filterColor.r, tempSettings.filterColor.g, tempSettings.filterColor.b
            achFilterBox:SetTextColor(r, g, b)
        end
        
        -- Update filter bar alpha
        SyncFilterBarAlpha()
    end
    
    -- Helper function to copy tables
    local function CopyTable(orig)
        local copy = {}
        for k, v in pairs(orig) do
            if type(v) == "table" then
                copy[k] = CopyTable(v)
            else
                copy[k] = v
            end
        end
        return copy
    end
    
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Account Chat History")
    
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetJustifyH("LEFT")
    desc:SetWidth(380)
    desc:SetText("Configure settings for the ACH chat window. Changes are saved when you click OK.")
    
    -- Create a container frame for aligned color pickers
    local colorContainer = CreateFrame("Frame", nil, panel)
    colorContainer:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
    colorContainer:SetWidth(380)
    colorContainer:SetHeight(140)
    
    -- Local references to the color swatch functions for later initialization
    local updateFunctions = {}
    
    -- Per-channel Text Color pickers (Global/General/Party/Party Leader) - ALIGNED
    local function MakeColorSwatchRow(labelText, settingKey, yOffset)
        local label = colorContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", colorContainer, "TOPLEFT", 0, yOffset)
        label:SetText(labelText)
        
        -- Set specific width for each label to align color boxes
        if labelText == "Global Text:" then
            label:SetWidth(110)  -- Adjusted for alignment
        elseif labelText == "General Text:" then
            label:SetWidth(110)  -- Adjusted for alignment
        elseif labelText == "Party Text:" then
            label:SetWidth(110)  -- Adjusted for alignment (same as others)
        elseif labelText == "Party Leader Text:" then
            label:SetWidth(110)  -- Adjusted for alignment (same as others)
        end
        
        local swatch = CreateFrame("Button", nil, colorContainer)
        swatch:SetSize(24, 24)
        swatch:SetPoint("LEFT", label, "RIGHT", 8, 0)
        
        local bg = swatch:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(0, 0, 0)
        bg:SetPoint("TOPLEFT", 1, -1)
        bg:SetPoint("BOTTOMRIGHT", -1, 1)
        
        local sample = swatch:CreateTexture(nil, "ARTWORK")
        sample:SetPoint("TOPLEFT", 2, -2)
        sample:SetPoint("BOTTOMRIGHT", -2, 2)
        
        local function Update()
            local c = tempSettings[settingKey]
            if not c then return end
            sample:SetTexture(c.r or 1, c.g or 1, c.b or 1)
        end
        
        -- Store the update function for later
        table.insert(updateFunctions, {func = Update, key = settingKey})
        
        swatch:SetScript("OnClick", function()
            local c = tempSettings[settingKey]
            if not c then 
                -- Create a new table for this color if it doesn't exist
                c = { r = 176/255, g = 96/255, b = 255/255 }
                tempSettings[settingKey] = c
            end
            
            -- Store the current color in local variables
            local oldR, oldG, oldB = c.r, c.g, c.b
            
            -- Create isolated callbacks for this specific color swatch
            local function OnColorChanged()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                -- Update ONLY this specific color table in temp settings
                tempSettings[settingKey].r = nr
                tempSettings[settingKey].g = ng
                tempSettings[settingKey].b = nb
                Update()
            end
            
            local function OnColorCanceled()
                -- Restore to previous values for THIS color only in temp settings
                tempSettings[settingKey].r = oldR
                tempSettings[settingKey].g = oldG
                tempSettings[settingKey].b = oldB
                Update()
            end
            
            -- Setup the color picker with isolated callbacks
            ColorPickerFrame.func = OnColorChanged
            ColorPickerFrame.cancelFunc = OnColorCanceled
            ColorPickerFrame.opacityFunc = nil
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.owner = swatch
            ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            ColorPickerFrame:SetFrameLevel(1000)
            ColorPickerFrame:SetColorRGB(oldR, oldG, oldB)
            ColorPickerFrame:Show()
            ColorPickerFrame:Raise()
        end)
        
        return swatch, Update
    end
    
    -- Create aligned color pickers with consistent vertical spacing
    local c1, update1 = MakeColorSwatchRow("Global Text:",       "globalColor",      0)
    local c2, update2 = MakeColorSwatchRow("General Text:",      "generalColor",    -28)
    local c3, update3 = MakeColorSwatchRow("Party Text:",        "partyColor",      -56)
    local c4, update4 = MakeColorSwatchRow("Party Leader Text:", "partyLeaderColor", -84)
    
    -- Filter Color swatch - positioned below the color container
    local filterColorSwatch = CreateFrame("Button", nil, panel)
    filterColorSwatch:SetSize(24, 24)
    filterColorSwatch:SetPoint("TOPLEFT", colorContainer, "BOTTOMLEFT", 0, -10)
    
    local bg2 = filterColorSwatch:CreateTexture(nil, "BACKGROUND")
    bg2:SetTexture(0, 0, 0)
    bg2:SetPoint("TOPLEFT", 1, -1)
    bg2:SetPoint("BOTTOMRIGHT", -1, 1)
    
    local filterSample = filterColorSwatch:CreateTexture(nil, "ARTWORK")
    filterSample:SetPoint("TOPLEFT", 2, -2)
    filterSample:SetPoint("BOTTOMRIGHT", -2, 2)
    
    local filterText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    filterText:SetPoint("LEFT", filterColorSwatch, "RIGHT", 4, 0)
    filterText:SetText("Filter Text Color")
    filterText:SetWidth(110)  -- Added for alignment
    
    local function UpdateFilterSwatch()
        local c = tempSettings.filterColor
        if not c then return end
        filterSample:SetTexture(c.r or 1, c.g or 1, c.b or 1)
    end
    
    -- Store the filter swatch update function
    table.insert(updateFunctions, {func = UpdateFilterSwatch, key = "filterColor"})
    
    filterColorSwatch:SetScript("OnClick", function()
        local c = tempSettings.filterColor
        if not c then 
            c = { r = 1, g = 1, b = 1 }
            tempSettings.filterColor = c
        end
        
        -- Store the current color
        local oldR, oldG, oldB = c.r, c.g, c.b
        
        -- Create isolated callbacks for filter color
        local function OnFilterColorChanged()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            tempSettings.filterColor.r = nr
            tempSettings.filterColor.g = ng
            tempSettings.filterColor.b = nb
            UpdateFilterSwatch()
        end
        
        local function OnFilterColorCanceled()
            tempSettings.filterColor.r = oldR
            tempSettings.filterColor.g = oldG
            tempSettings.filterColor.b = oldB
            UpdateFilterSwatch()
        end
        
        -- Setup the color picker with isolated callbacks
        ColorPickerFrame.func = OnFilterColorChanged
        ColorPickerFrame.cancelFunc = OnFilterColorCanceled
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.owner = filterColorSwatch
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ColorPickerFrame:SetFrameLevel(1000)
        ColorPickerFrame:SetColorRGB(oldR, oldG, oldB)
        ColorPickerFrame:Show()
        ColorPickerFrame:Raise()
    end)
    
    -- NEW: Transparency slider for filter text (to the right of filter color)
    local filterAlphaLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    filterAlphaLabel:SetPoint("LEFT", filterText, "RIGHT", 10, 0)  -- Positioned to the right of filter text
    filterAlphaLabel:SetText("Transparency:")
    
    -- Create slider background
    local sliderFrame = CreateFrame("Frame", "ACHFilterAlphaSliderFrame", panel)
    sliderFrame:SetPoint("LEFT", filterAlphaLabel, "RIGHT", 8, 0)
    sliderFrame:SetWidth(100)
    sliderFrame:SetHeight(20)
    
    -- Slider background texture
    local sliderBG = sliderFrame:CreateTexture(nil, "BACKGROUND")
    sliderBG:SetTexture(0, 0, 0, 0.5)
    sliderBG:SetAllPoints(sliderFrame)
    
    -- Create the actual slider
    local slider = CreateFrame("Slider", "ACHFilterAlphaSlider", sliderFrame, "OptionsSliderTemplate")
    slider:SetPoint("CENTER", sliderFrame, "CENTER", 0, 0)
    slider:SetWidth(80)
    slider:SetHeight(15)
    slider:SetMinMaxValues(0, 100)
    slider:SetValueStep(5)
    
    -- Remove default labels and create our own
    _G[slider:GetName() .. "Low"]:SetText("")
    _G[slider:GetName() .. "High"]:SetText("")
    _G[slider:GetName() .. "Text"]:SetText("")
    
    -- Create value display
    local sliderValueText = sliderFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sliderValueText:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    sliderValueText:SetText("100%")
    
    -- Update function for slider
    local function UpdateSliderValue()
        local alpha = tempSettings.filterAlpha or 1.0
        local percent = math.floor(alpha * 100 + 0.5)
        slider:SetValue(percent)
        sliderValueText:SetText(percent .. "%")
    end
    
    -- Store the slider update function
    table.insert(updateFunctions, {func = UpdateSliderValue, key = "filterAlpha"})
    
    -- Slider script handlers
    slider:SetScript("OnValueChanged", function(self, value)
        local step = self:GetValueStep()
        local rounded = math.floor((value + step/2) / step) * step
        self:SetValue(rounded)
        
        local alpha = rounded / 100
        tempSettings.filterAlpha = alpha
        sliderValueText:SetText(math.floor(rounded + 0.5) .. "%")
    end)
    
    slider:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetValue()
        local step = self:GetValueStep()
        if delta > 0 then
            self:SetValue(math.min(current + step, 100))
        else
            self:SetValue(math.max(current - step, 0))
        end
    end)
    
    -- Channel Recording Checkboxes
    local channelHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelHeader:SetPoint("TOPLEFT", filterColorSwatch, "BOTTOMLEFT", 0, -40)  -- Moved down to make room for slider
    channelHeader:SetText("Record Channels:")
    
    local checkGlobal = CreateFrame("CheckButton", "ACHCheckGlobal", panel, "UICheckButtonTemplate")
    checkGlobal:SetPoint("TOPLEFT", channelHeader, "BOTTOMLEFT", 0, -8)
    checkGlobal:SetScript("OnClick", function(self)
        tempSettings.recordGlobal = self:GetChecked()
    end)
    
    local checkGlobalLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkGlobalLabel:SetPoint("LEFT", checkGlobal, "RIGHT", 0, 0)
    checkGlobalLabel:SetText("Global")
    
    local checkGeneral = CreateFrame("CheckButton", "ACHCheckGeneral", panel, "UICheckButtonTemplate")
    checkGeneral:SetPoint("TOPLEFT", checkGlobal, "BOTTOMLEFT", 0, -4)
    checkGeneral:SetScript("OnClick", function(self)
        tempSettings.recordGeneral = self:GetChecked()
    end)
    
    local checkGeneralLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkGeneralLabel:SetPoint("LEFT", checkGeneral, "RIGHT", 0, 0)
    checkGeneralLabel:SetText("General")
    
    local checkParty = CreateFrame("CheckButton", "ACHCheckParty", panel, "UICheckButtonTemplate")
    checkParty:SetPoint("TOPLEFT", checkGeneral, "BOTTOMLEFT", 0, -4)
    checkParty:SetScript("OnClick", function(self)
        tempSettings.recordParty = self:GetChecked()
    end)
    
    local checkPartyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkPartyLabel:SetPoint("LEFT", checkParty, "RIGHT", 0, 0)
    checkPartyLabel:SetText("Party")
    
    -- Message Retention Dropdown - MOVED TO THE RIGHT AND ALIGNED WITH GLOBAL TEXT
    local retentionLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    retentionLabel:SetPoint("LEFT", colorContainer, "RIGHT", -175, 70)  -- Adjusted Y position up (was 0, now 8)
    retentionLabel:SetText("Message Retention:")
    
    local retentionDropdown = CreateFrame("Frame", "ACHRetentionDropdown", panel, "UIDropDownMenuTemplate")
    retentionDropdown:SetPoint("TOPLEFT", retentionLabel, "BOTTOMLEFT", -16, -4)
    
    local retentionOptions = {
        { text = "1 Hour", value = 3600 },
        { text = "45 Minutes", value = 2700 },
        { text = "30 Minutes", value = 1800 },
        { text = "15 Minutes", value = 900 },
        { text = "5 Minutes", value = 300 },
    }
    
    local function RetentionDropdown_OnClick(selfArg)
        tempSettings.retentionSeconds = selfArg.value
        UIDropDownMenu_SetSelectedValue(retentionDropdown, selfArg.value)
        UIDropDownMenu_SetText(retentionDropdown, selfArg:GetText())
    end
    
    local function RetentionDropdown_Initialize(selfArg, level)
        for _, option in ipairs(retentionOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = RetentionDropdown_OnClick
            UIDropDownMenu_AddButton(info, level)
        end
    end
    
    UIDropDownMenu_Initialize(retentionDropdown, RetentionDropdown_Initialize)
    UIDropDownMenu_SetWidth(retentionDropdown, 120)
    
    -- Timezone Offset Dropdown - MOVED TO THE RIGHT AND ALIGNED WITH GENERAL TEXT
    local timezoneLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    timezoneLabel:SetPoint("TOPLEFT", retentionDropdown, "BOTTOMLEFT", 15, -10)  -- Fixed: Position relative to retention dropdown
    timezoneLabel:SetText("Timezone Offset:")
    
    local timezoneDropdown = CreateFrame("Frame", "ACHTimezoneDropdown", panel, "UIDropDownMenuTemplate")
    timezoneDropdown:SetPoint("TOPLEFT", timezoneLabel, "BOTTOMLEFT", -16, -4)
    
    local timezoneOptions = {
        { text = "UTC-12", value = -12 }, { text = "UTC-11", value = -11 },
        { text = "UTC-10", value = -10 }, { text = "UTC-9", value = -9 },
        { text = "UTC-8", value = -8 }, { text = "UTC-7", value = -7 },
        { text = "UTC-6", value = -6 }, { text = "UTC-5", value = -5 },
        { text = "UTC-4", value = -4 }, { text = "UTC-3", value = -3 },
        { text = "UTC-2", value = -2 }, { text = "UTC-1", value = -1 },
        { text = "UTC+0", value = 0 }, { text = "UTC+1", value = 1 },
        { text = "UTC+2", value = 2 }, { text = "UTC+3", value = 3 },
        { text = "UTC+4", value = 4 }, { text = "UTC+5", value = 5 },
        { text = "UTC+6", value = 6 }, { text = "UTC+7", value = 7 },
        { text = "UTC+8", value = 8 }, { text = "UTC+9", value = 9 },
        { text = "UTC+10", value = 10 }, { text = "UTC+11", value = 11 },
        { text = "UTC+12", value = 12 },
    }
    
    local function TimezoneDropdown_OnClick(selfArg)
        tempSettings.timezoneOffset = selfArg.value
        UIDropDownMenu_SetSelectedValue(timezoneDropdown, selfArg.value)
        UIDropDownMenu_SetText(timezoneDropdown, selfArg:GetText())
    end
    
    local function TimezoneDropdown_Initialize(selfArg, level)
        for _, option in ipairs(timezoneOptions) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = TimezoneDropdown_OnClick
            UIDropDownMenu_AddButton(info, level)
        end
    end
    
    UIDropDownMenu_Initialize(timezoneDropdown, TimezoneDropdown_Initialize)
    UIDropDownMenu_SetWidth(timezoneDropdown, 120)
    
    -- Refresh function - called when panel is shown
    local function RefreshPanel()
        -- Copy current settings to temp storage
        CopyToTempSettings()
        
        -- Call all update functions to initialize the display
        for _, updateInfo in ipairs(updateFunctions) do
            if updateInfo.func then
                updateInfo.func()
            end
        end
        
        checkGlobal:SetChecked(tempSettings.recordGlobal)
        checkGeneral:SetChecked(tempSettings.recordGeneral)
        checkParty:SetChecked(tempSettings.recordParty)
        
        UIDropDownMenu_SetSelectedValue(retentionDropdown, tempSettings.retentionSeconds)
        UIDropDownMenu_SetSelectedValue(timezoneDropdown, tempSettings.timezoneOffset)
        
        for _, option in ipairs(retentionOptions) do
            if option.value == tempSettings.retentionSeconds then
                UIDropDownMenu_SetText(retentionDropdown, option.text)
                break
            end
        end
        
        for _, option in ipairs(timezoneOptions) do
            if option.value == tempSettings.timezoneOffset then
                UIDropDownMenu_SetText(timezoneDropdown, option.text)
                break
            end
        end
    end
    
    -- OK/Cancel handlers
    panel.okay = function()
        ApplyTempSettings()
    end
    
    panel.cancel = function()
        -- Nothing to do - temp settings are discarded
    end
    
    panel.default = function()
        -- Reset to defaults
        tempSettings = {
            globalColor = { r = 176/255, g = 96/255, b = 255/255 },
            generalColor = { r = 176/255, g = 96/255, b = 255/255 },
            partyColor = { r = 176/255, g = 96/255, b = 255/255 },
            partyLeaderColor = { r = 176/255, g = 96/255, b = 255/255 },
            filterColor = { r = 1, g = 1, b = 1 },
            filterAlpha = 1.0,
            filter = "",
            recordGlobal = true,
            recordGeneral = true,
            recordParty = true,
            retentionSeconds = 3600,
            timezoneOffset = 0,
        }
        RefreshPanel()
    end
    
    panel.refresh = RefreshPanel
    InterfaceOptions_AddCategory(panel)
end

-- ===== Events =====

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON then return end
        
        InitDB()
        CreateOptionsPanel()
        
    elseif event == "PLAYER_LOGIN" then
        EnsureChatFrame()
        JoinGlobal()
        
        UnsubscribeRealChatFromACH()
        After(1, UnsubscribeRealChatFromACH)
        After(3, UnsubscribeRealChatFromACH)
        
        ReplayOnLogin()
        
        if achFilterBox and ACH_DB and ACH_DB.settings then
            achFilterBox:SetText(ACH_DB.settings.filter or "")
            local r, g, b = GetFilterColor()
            achFilterBox:SetTextColor(r, g, b)
            SyncFilterBarAlpha()
        end
        
        After(30, PeriodicRetentionCleanup)
        
    elseif event == "CHAT_MSG_CHANNEL" then
        local msg, author, _, _, _, _, _, channelNumber, channelName, _, _, guid = ...
        local lowerChannelName = channelName and string.lower(channelName) or ""
        local globalChannelKey = CFG.GlobalChannelName and string.lower(CFG.GlobalChannelName) or ""

        if channelName and globalChannelKey ~= "" then
            local globalPrefixIndex = string.find(lowerChannelName, globalChannelKey, 1, true)
            if globalPrefixIndex == 1 then
                if ACH_DB.settings.recordGlobal then
                    local p = {
                        t = Now(),
                        from = author,
                        msg = msg,
                        guid = guid,
                        src = CFG.GlobalChannelName,
                    }

                    PushLine("global", CFG.GlobalChannelName, author, msg, guid, CFG.GlobalChannelName)

                    if PassesFilter(p) then
                        Out(FormatLine(p.t, p.src, p.from, p.msg, p.guid), p.src)
                    end
                end
                return
            end
        end

        local generalTag = string.lower(GENERAL or "general")
        local isGeneralChannel = channelNumber == 1
        if not isGeneralChannel and generalTag ~= "" and channelName then
            local prefixIndex = string.find(lowerChannelName, generalTag, 1, true)
            if prefixIndex == 1 then
                isGeneralChannel = true
            end
        end

        if isGeneralChannel and ACH_DB.settings.recordGeneral then
            local p = {
                t = Now(),
                from = author,
                msg = msg,
                guid = guid,
                src = "General",
            }

            PushLine("general", "General", author, msg, guid, "General")

            if PassesFilter(p) then
                Out(FormatLine(p.t, p.src, p.from, p.msg, p.guid), p.src)
            end
        end
        
    elseif event == "CHAT_MSG_PARTY" then
        if ACH_DB.settings.recordParty then
            local msg, author, _, _, _, _, _, _, _, _, _, guid = ...
            
            local p = {
                t = Now(),
                from = author,
                msg = msg,
                guid = guid,
                src = "Party",
            }
            
            PushLine("party", "Party", author, msg, guid, "Party")
            
            if PassesFilter(p) then
                Out(FormatLine(p.t, p.src, p.from, p.msg, p.guid), p.src)
            end
        end
        
    elseif event == "CHAT_MSG_PARTY_LEADER" then
        if ACH_DB.settings.recordParty then
            local msg, author, _, _, _, _, _, _, _, _, _, guid = ...
            
            local p = {
                t = Now(),
                from = author,
                msg = msg,
                guid = guid,
                src = "Party Leader",
            }
            
            PushLine("party", "Party", author, msg, guid, "Party Leader")
            
            if PassesFilter(p) then
                Out(FormatLine(p.t, p.src, p.from, p.msg, p.guid), p.src)
            end
        end
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:RegisterEvent("CHAT_MSG_PARTY")
f:RegisterEvent("CHAT_MSG_PARTY_LEADER")