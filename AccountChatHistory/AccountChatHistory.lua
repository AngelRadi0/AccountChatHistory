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
            raidColor        = { r = 176/255, g = 96/255, b = 255/255 },
            raidLeaderColor  = { r = 176/255, g = 96/255, b = 255/255 },
            raidWarningColor = { r = 176/255, g = 96/255, b = 255/255 },
            filterColor = { r = 1, g = 1, b = 1 },
            filterAlpha = 1.0, -- NEW: Transparency value for filter text (1.0 = fully opaque, 0.0 = fully transparent)
            filter = "",
            recordGlobal = true,
            recordGeneral = true,
            recordParty = true,
            recordRaid = true,
            recordRaidWarning = true,
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
        
        -- NEW: Ensure raid and raid leader colors exist
        if type(ACH_DB.settings.raidColor) ~= "table" then
            ACH_DB.settings.raidColor = { r = 176/255, g = 96/255, b = 255/255 }
        else
            -- Make sure it's not sharing a reference with other color tables
            local r = ACH_DB.settings.raidColor
            ACH_DB.settings.raidColor = { r = r.r or 176/255, g = r.g or 96/255, b = r.b or 255/255 }
        end
        
        if type(ACH_DB.settings.raidLeaderColor) ~= "table" then
            ACH_DB.settings.raidLeaderColor = { r = 176/255, g = 96/255, b = 255/255 }
        else
            -- Make sure it's not sharing a reference with other color tables
            local r = ACH_DB.settings.raidLeaderColor
            ACH_DB.settings.raidLeaderColor = { r = r.r or 176/255, g = r.g or 96/255, b = r.b or 255/255 }
        end
        
        if type(ACH_DB.settings.raidWarningColor) ~= "table" then
            ACH_DB.settings.raidWarningColor = { r = 176/255, g = 96/255, b = 255/255 }
        else
            local r = ACH_DB.settings.raidWarningColor
            ACH_DB.settings.raidWarningColor = { r = r.r or 176/255, g = r.g or 96/255, b = r.b or 255/255 }
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
        
        -- NEW: Ensure raid recording settings exist
        if type(ACH_DB.settings.recordRaid) ~= "boolean" then
            ACH_DB.settings.recordRaid = true
        end
        
        if type(ACH_DB.settings.recordRaidWarning) ~= "boolean" then
            ACH_DB.settings.recordRaidWarning = true
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

-- FIXED: Track recently processed messages to prevent duplicates
local lastMessages = {}
local function IsDuplicateMessage(author, text, channelKey)
    local normChannel = channelKey and string.lower(channelKey) or ""
    local key = (author or "") .. "|" .. (text or "") .. "|" .. normChannel
    local currentTime = GetTime()  -- More precise time than time()

    -- Check if we've seen this exact message very recently (within 1 second)
    if lastMessages[key] and (currentTime - lastMessages[key]) < 1 then
        return true
    end
    
    -- Store this message with current time
    lastMessages[key] = currentTime
    
    -- Clean up old entries (older than 5 seconds)
    for k, v in pairs(lastMessages) do
        if currentTime - v > 5 then
            lastMessages[k] = nil
        end
    end
    
    return false
end

-- FIXED: Improved duplicate prevention with better checking
local function PushLine(streamKey, streamName, author, text, guid, src)
    local dupChannel = streamKey or src or ""
    if IsDuplicateMessage(author, text, dupChannel) then
        return false
    end

    local s = EnsureStream(streamKey, streamName)
    
    -- Check for duplicates more thoroughly
    local currentTime = Now()
    for i = #s.lines, math.max(1, #s.lines - 10), -1 do
        local line = s.lines[i]
        if line and line.from == author and line.msg == text then
            -- Check if timestamp is very close (within 2 seconds)
            if math.abs(line.t - currentTime) <= 2 then
                -- Duplicate found within 2 seconds, don't add it again
                return false
            end
        end
    end
    
    table.insert(s.lines, {
        t = currentTime,
        from = author,
        msg = text,
        guid = guid,
        src = src,
    })
    
    local beforeTrim = #s.lines
    TrimByAge(s.lines)
    Trim(s.lines, CFG.MaxLines)

    return true
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
    RemoveChatWindowMessages(id, "RAID") -- NEW: Unsubscribe from raid messages
    RemoveChatWindowMessages(id, "RAID_WARNING")
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
    elseif src == "Raid" then -- NEW: Raid channel color
        c = s.raidColor
    elseif src == "Raid Leader" then -- NEW: Raid Leader channel color
        c = s.raidLeaderColor
    elseif src == "Raid Warning" then -- NEW: Raid Warning channel color
        c = s.raidWarningColor
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
    if string.find(src, f, 1, true) then return false end
    
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

-- FIXED: Chronological display functions
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

local refreshScheduled = false
local function ScheduleChatRefresh()
    if not achFrame then return end
    if refreshScheduled then return end
    refreshScheduled = true
    After(0, function()
        refreshScheduled = false
        if achFrame then
            ReplayCurrentView()
        end
    end)
end

-- ===== Ensure chat frame + filter bar =====

local function EnsureFilterBar()
    if achFilterBox and achFilterClear then return end
    if not achFrame then return end
    
    local bar = CreateFrame("Frame", "ACHFilterBar", achFrame:GetParent())
    bar:SetHeight(22)
    bar:SetPoint("TOPLEFT", achFrame, "BOTTOMLEFT", 0, -6)
    bar:SetPoint("TOPRIGHT", achFrame, "BOTTOMRIGHT", 0, -6)
    
    -- CHANGED: Remove the background texture creation entirely
    -- local bg = bar:CreateTexture(nil, "BACKGROUND")
    -- bg:SetAllPoints(bar)
    -- bg:SetTexture(0, 0, 0, 0.2)  -- REMOVED
    
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

local function StripACHMessageGroups(frame)
    if not frame then return end
    local chatEvents = {
        "CHAT_MSG_SAY",
        "CHAT_MSG_EMOTE",
        "CHAT_MSG_YELL",
        "CHAT_MSG_CHANNEL",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_GUILD",
        "CHAT_MSG_OFFICER",
        "CHAT_MSG_GUILD_ACHIEVEMENT",
        "CHAT_MSG_ACHIEVEMENT",
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_BN_WHISPER",
        "CHAT_MSG_BN_CONVERSATION",
        "CHAT_MSG_SYSTEM",
        "CHAT_MSG_MONSTER_SAY",
        "CHAT_MSG_MONSTER_YELL",
        "CHAT_MSG_MONSTER_EMOTE",
        "CHAT_MSG_MONSTER_PARTY",
        "CHAT_MSG_MONSTER_WHISPER",
    }
    if frame.UnregisterEvent then
        for _, evt in ipairs(chatEvents) do
            frame:UnregisterEvent(evt)
        end
    end

    if not ChatFrame_RemoveMessageGroup then return end
    local groups = {
        "SAY",
        "EMOTE",
        "YELL",
        "CHANNEL",
        "PARTY",
        "PARTY_LEADER",
        "RAID",
        "RAID_LEADER",
        "RAID_WARNING",
        "GUILD",
        "OFFICER",
        "GUILD_ACHIEVEMENT",
        "ACHIEVEMENT",
        "WHISPER",
        "BN_WHISPER",
        "BN_CONVERSATION",
        "SYSTEM",
        "MONSTER_SAY",
        "MONSTER_YELL",
        "MONSTER_EMOTE",
        "MONSTER_PARTY",
        "MONSTER_WHISPER",
    }

    for _, group in ipairs(groups) do
        ChatFrame_RemoveMessageGroup(frame, group)
    end
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

    StripACHMessageGroups(achFrame)
    
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
            raidColor = CopyTable(ACH_DB.settings.raidColor),
            raidLeaderColor = CopyTable(ACH_DB.settings.raidLeaderColor),
            raidWarningColor = CopyTable(ACH_DB.settings.raidWarningColor),
            filterColor = CopyTable(ACH_DB.settings.filterColor),
            filterAlpha = ACH_DB.settings.filterAlpha,
            filter = ACH_DB.settings.filter,
            recordGlobal = ACH_DB.settings.recordGlobal,
            recordGeneral = ACH_DB.settings.recordGeneral,
            recordParty = ACH_DB.settings.recordParty,
            recordRaid = ACH_DB.settings.recordRaid,
            recordRaidWarning = ACH_DB.settings.recordRaidWarning,
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
        ACH_DB.settings.raidColor = CopyTable(tempSettings.raidColor)
        ACH_DB.settings.raidLeaderColor = CopyTable(tempSettings.raidLeaderColor)
        ACH_DB.settings.raidWarningColor = CopyTable(tempSettings.raidWarningColor)
        ACH_DB.settings.filterColor = CopyTable(tempSettings.filterColor)
        ACH_DB.settings.filterAlpha = tempSettings.filterAlpha
        ACH_DB.settings.filter = tempSettings.filter
        ACH_DB.settings.recordGlobal = tempSettings.recordGlobal
        ACH_DB.settings.recordGeneral = tempSettings.recordGeneral
        ACH_DB.settings.recordParty = tempSettings.recordParty
        ACH_DB.settings.recordRaid = tempSettings.recordRaid
        ACH_DB.settings.recordRaidWarning = tempSettings.recordRaidWarning
        
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
    colorContainer:SetHeight(220) -- Increased height for additional color pickers
    
    -- Local references to the color swatch functions for later initialization
    local updateFunctions = {}
    
    -- Per-channel Text Color pickers (Global/General/Party/Party Leader/Raid/Raid Leader) - ALIGNED
    local function MakeColorSwatchRow(labelText, settingKey, yOffset)
        local label = colorContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", colorContainer, "TOPLEFT", 0, yOffset)
        label:SetText(labelText)
        
        -- Set specific width for each label to align color boxes
        label:SetWidth(140)  -- Increased width so longer names don't wrap
        
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
    local c5, update5 = MakeColorSwatchRow("Raid Text:",         "raidColor",       -112) -- NEW: Raid color picker
    local c6, update6 = MakeColorSwatchRow("Raid Leader Text:",  "raidLeaderColor", -140) -- NEW: Raid Leader color picker
    local c7, update7 = MakeColorSwatchRow("Raid Warning Text:", "raidWarningColor", -168) -- NEW: Raid Warning color
    
    -- NEW: Create a container for Filter Text Color and Transparency with gold border
    local filterContainer = CreateFrame("Frame", nil, panel)
    filterContainer:SetPoint("TOPLEFT", colorContainer, "BOTTOMLEFT", 0, -10)
    filterContainer:SetWidth(205)
    filterContainer:SetHeight(95)
    
    -- Blizzard-style beveled border (no background fill)
    filterContainer:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
        tile     = true,
        tileSize = 16,
        edgeSize = 16,
        insets   = { left = 4, right = 104, top = 4, bottom = 14 },
    })
    filterContainer:SetBackdropBorderColor(1, 1, 1, 1)
    filterContainer:SetBackdropColor(0, 0, 0, 0)

    -- Filter Color swatch - INSIDE THE CONTAINER
    local filterColorSwatch = CreateFrame("Button", nil, filterContainer)
    filterColorSwatch:SetSize(24, 24)
    filterColorSwatch:SetPoint("TOPLEFT", filterContainer, "TOPLEFT", 130, -10) -- Position inside container
    
    local bg2 = filterColorSwatch:CreateTexture(nil, "BACKGROUND")
    bg2:SetTexture(0, 0, 0)
    bg2:SetPoint("TOPLEFT", 1, -1)
    bg2:SetPoint("BOTTOMRIGHT", -1, 1)
    
    local filterSample = filterColorSwatch:CreateTexture(nil, "ARTWORK")
    filterSample:SetPoint("TOPLEFT", 2, -2)
    filterSample:SetPoint("BOTTOMRIGHT", -2, 2)
    
    local filterText = filterContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    filterText:SetPoint("RIGHT", filterColorSwatch, "LEFT", -4, 0)
    -- Add spaces to the beginning of the text to shift it right
    filterText:SetText("   Filter Text Color:")
    filterText:SetWidth(110)
    
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
    
    -- Transparency controls - INSIDE THE SAME CONTAINER
    local transparencySection = CreateFrame("Frame", nil, filterContainer)
    transparencySection:SetPoint("TOPLEFT", filterText, "BOTTOMLEFT", 0, -15)
    transparencySection:SetWidth(250)
    transparencySection:SetHeight(40)
    
    -- Transparency label inside the container
    local filterAlphaLabel = transparencySection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    filterAlphaLabel:SetPoint("LEFT", transparencySection, "LEFT", 0, 0)
    filterAlphaLabel:SetText("Transparency:")
    
    -- Create slider background inside the container
    local sliderFrame = CreateFrame("Frame", "ACHFilterAlphaSliderFrame", transparencySection)
    sliderFrame:SetPoint("LEFT", filterAlphaLabel, "RIGHT", 8, 0)
    sliderFrame:SetWidth(100)
    sliderFrame:SetHeight(20)
    
    -- Slider background texture
    local sliderBG = sliderFrame:CreateTexture(nil, "BACKGROUND")
    sliderBG:SetTexture(0, 0, 0, 0)
    sliderBG:SetAllPoints(sliderFrame)
    
    -- Create the actual slider inside the container
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
    
    -- Create value display inside the container
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
    
    -- Create a container for Record Channels checkboxes
    local channelContainer = CreateFrame("Frame", nil, panel)
    channelContainer:SetPoint("LEFT", colorContainer, "RIGHT", -175, 40)  -- Position this container
    channelContainer:SetWidth(200)
    channelContainer:SetHeight(150)
    
    -- Channel Recording Checkboxes - INSIDE THE CONTAINER
    local channelHeader = channelContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    channelHeader:SetPoint("TOPLEFT", channelContainer, "TOPLEFT", 0, 0)  -- Relative to container
    channelHeader:SetText("Record Channels:")
    
    local checkGlobal = CreateFrame("CheckButton", "ACHCheckGlobal", channelContainer, "UICheckButtonTemplate")
    checkGlobal:SetPoint("TOPLEFT", channelHeader, "BOTTOMLEFT", 0, -8)
    checkGlobal:SetScript("OnClick", function(self)
        tempSettings.recordGlobal = self:GetChecked()
    end)
    
    local checkGlobalLabel = channelContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkGlobalLabel:SetPoint("LEFT", checkGlobal, "RIGHT", 0, 0)
    checkGlobalLabel:SetText("Global")
    
    local checkGeneral = CreateFrame("CheckButton", "ACHCheckGeneral", channelContainer, "UICheckButtonTemplate")
    checkGeneral:SetPoint("TOPLEFT", checkGlobal, "BOTTOMLEFT", 0, -4)
    checkGeneral:SetScript("OnClick", function(self)
        tempSettings.recordGeneral = self:GetChecked()
    end)
    
    local checkGeneralLabel = channelContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkGeneralLabel:SetPoint("LEFT", checkGeneral, "RIGHT", 0, 0)
    checkGeneralLabel:SetText("General")
    
    local checkParty = CreateFrame("CheckButton", "ACHCheckParty", channelContainer, "UICheckButtonTemplate")
    checkParty:SetPoint("TOPLEFT", checkGeneral, "BOTTOMLEFT", 0, -4)
    checkParty:SetScript("OnClick", function(self)
        tempSettings.recordParty = self:GetChecked()
    end)
    
    local checkPartyLabel = channelContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkPartyLabel:SetPoint("LEFT", checkParty, "RIGHT", 0, 0)
    checkPartyLabel:SetText("Party")
    
    -- NEW: Raid Recording Checkbox - FIXED: Added missing 'end'
    local checkRaid = CreateFrame("CheckButton", "ACHCheckRaid", channelContainer, "UICheckButtonTemplate")
    checkRaid:SetPoint("TOPLEFT", checkParty, "BOTTOMLEFT", 0, -4)
    checkRaid:SetScript("OnClick", function(self)
        tempSettings.recordRaid = self:GetChecked()
    end)

    local checkRaidLabel = channelContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkRaidLabel:SetPoint("LEFT", checkRaid, "RIGHT", 0, 0)
    checkRaidLabel:SetText("Raid (includes Raid Leader)")

    local checkRaidWarning = CreateFrame("CheckButton", "ACHCheckRaidWarning", channelContainer, "UICheckButtonTemplate")
    checkRaidWarning:SetPoint("TOPLEFT", checkRaid, "BOTTOMLEFT", 0, -4)
    checkRaidWarning:SetScript("OnClick", function(self)
        tempSettings.recordRaidWarning = self:GetChecked()
    end)

    local checkRaidWarningLabel = channelContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    checkRaidWarningLabel:SetPoint("LEFT", checkRaidWarning, "RIGHT", 0, 0)
    checkRaidWarningLabel:SetText("Raid Warning")
    
    -- Message Retention Dropdown - UPDATED POSITION (moved up)
    local retentionLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    retentionLabel:SetPoint("LEFT", colorContainer, "RIGHT", 65, 94)  -- Moved up to make room for Record Channels
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
    
    -- Timezone Offset Dropdown - UPDATED POSITION (moved up)
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
        checkRaid:SetChecked(tempSettings.recordRaid)
        checkRaidWarning:SetChecked(tempSettings.recordRaidWarning)
        
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
            raidColor = { r = 176/255, g = 96/255, b = 255/255 }, -- NEW: Default raid color
            raidLeaderColor = { r = 176/255, g = 96/255, b = 255/255 }, -- NEW: Default raid leader color
            raidWarningColor = { r = 176/255, g = 96/255, b = 255/255 }, -- NEW: Default raid warning color
            filterColor = { r = 1, g = 1, b = 1 },
            filterAlpha = 1.0,
            filter = "",
            recordGlobal = true,
            recordGeneral = true,
            recordParty = true,
            recordRaid = true,
            recordRaidWarning = true,
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
        
        -- FIXED: Better channel detection based on NAME not NUMBER
        if not channelName then return end
        
        local lowerChannelName = string.lower(channelName)
        local globalChannelKey = string.lower(CFG.GlobalChannelName or "")
        
        local isGlobalChannel = false
        local isGeneralChannel = false
        
        -- Check for Global channel by NAME (not number)
        if globalChannelKey ~= "" then
            -- Check if channel name exactly matches Global channel name
            if lowerChannelName == globalChannelKey then
                isGlobalChannel = true
            -- Also check if channel name starts with Global channel name
            elseif string.find(lowerChannelName, "^" .. globalChannelKey) then
                isGlobalChannel = true
            end
        end
        
        -- Check for General channel by NAME (not number)
        if not isGlobalChannel then
            -- Check if channel name exactly matches "general"
            if lowerChannelName == "general" then
                isGeneralChannel = true
            -- Also check if channel name contains "general"
            elseif string.find(lowerChannelName, "general") then
                isGeneralChannel = true
            end
        end
        
        -- Handle Global channel messages
        if isGlobalChannel and ACH_DB.settings.recordGlobal then
            if PushLine("global", CFG.GlobalChannelName, author, msg, guid, CFG.GlobalChannelName) then
                ScheduleChatRefresh()
            end
            return  -- Important: Return early to prevent processing as General
        end
        
        -- Handle General channel messages
        if isGeneralChannel and ACH_DB.settings.recordGeneral then
            if PushLine("general", "General", author, msg, guid, "General") then
                ScheduleChatRefresh()
            end
        end
        
    elseif event == "CHAT_MSG_PARTY" then
        if ACH_DB.settings.recordParty then
            local msg, author, _, _, _, _, _, _, _, _, _, guid = ...
            if PushLine("party", "Party", author, msg, guid, "Party") then
                ScheduleChatRefresh()
            end
        end
        
    elseif event == "CHAT_MSG_PARTY_LEADER" then
        if ACH_DB.settings.recordParty then
            local msg, author, _, _, _, _, _, _, _, _, _, guid = ...
            if PushLine("party", "Party", author, msg, guid, "Party Leader") then
                ScheduleChatRefresh()
            end
        end
        
    -- NEW: Raid channel events
    elseif event == "CHAT_MSG_RAID" then
        if ACH_DB.settings.recordRaid then
            local msg, author, _, _, _, _, _, _, _, _, _, guid = ...
            if PushLine("raid", "Raid", author, msg, guid, "Raid") then
                ScheduleChatRefresh()
            end
        end
        
    elseif event == "CHAT_MSG_RAID_LEADER" then
        if ACH_DB.settings.recordRaid then
            local msg, author, _, _, _, _, _, _, _, _, _, guid = ...
            if PushLine("raid", "Raid", author, msg, guid, "Raid Leader") then
                ScheduleChatRefresh()
            end
        end
        
    elseif event == "CHAT_MSG_RAID_WARNING" then
        if ACH_DB.settings.recordRaidWarning then
            local msg, author, _, _, _, _, _, _, _, _, _, guid = ...
            if PushLine("raidWarning", "Raid Warning", author, msg, guid, "Raid Warning") then
                ScheduleChatRefresh()
            end
        end
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:RegisterEvent("CHAT_MSG_PARTY")
f:RegisterEvent("CHAT_MSG_PARTY_LEADER")
f:RegisterEvent("CHAT_MSG_RAID") -- NEW: Register raid events
f:RegisterEvent("CHAT_MSG_RAID_LEADER") -- NEW: Register raid leader events
f:RegisterEvent("CHAT_MSG_RAID_WARNING")
