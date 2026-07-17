Phone = Phone or {}

local function state(name)
    return GetResourceState(name)
end

---True when the sd-phone resource exists on this server (any state except missing).
local function sdPhonePresent()
    local s = state('sd-phone')
    return s ~= 'missing' and s ~= 'unknown'
end

---Returns the phone resource name to use, or nil if none is ready yet.
---@return string|nil
function Phone.GetResource()
    local preferred = Config.Phone or 'auto'

    -- Forced sd-phone
    if preferred == 'sd-phone' then
        return state('sd-phone') == 'started' and 'sd-phone' or nil
    end

    -- Forced lb-phone: still use sd-phone natively when it is the phone on this server
    if preferred == 'lb-phone' then
        if state('sd-phone') == 'started' then
            return 'sd-phone'
        end
        if sdPhonePresent() then
            return nil -- wait for sd-phone; do not hit the provided lb-phone alias
        end
        return state('lb-phone') == 'started' and 'lb-phone' or nil
    end

    -- auto
    if state('sd-phone') == 'started' then
        return 'sd-phone'
    end
    -- sd-phone is installing/starting: wait for it. sd-phone's `provide 'lb-phone'`
    -- can make GetResourceState('lb-phone') look started too early.
    if sdPhonePresent() then
        return nil
    end
    if state('lb-phone') == 'started' then
        return 'lb-phone'
    end
    return nil
end

---Blocks until a supported phone is started.
---@return string phoneResource
function Phone.WaitForStart()
    while true do
        local phone = Phone.GetResource()
        if phone then return phone end
        Wait(500)
    end
end

---@return boolean
function Phone.IsSd()
    return Phone.GetResource() == 'sd-phone'
end

---@return boolean
function Phone.IsLb()
    return Phone.GetResource() == 'lb-phone'
end
