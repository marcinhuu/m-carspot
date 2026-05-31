Bridge = {}

local function InitFramework()
    if GetResourceState('qb-core') == 'started' or GetResourceState('qbx_core') == 'started' then
        Config.Framework = 'qbcore'
        return true
    elseif GetResourceState('es_extended') == 'started' then
        Config.Framework = 'esx'
        return true
    end
    return false
end

CreateThread(function()
    if not InitFramework() then
        print('^1[m-carspot] No compatible framework found!^0')
    else
        print('^2[m-carspot] Framework detected: ' .. Config.Framework .. '^0')
    end
end)

if IsDuplicityVersion() then
    function Bridge.GetPlayer(source) return nil end
    function Bridge.GetPlayerName(Player) return 'Unknown' end
    function Bridge.GetPlayerIdentifier(Player) return nil end
    function Bridge.GetSourceByCitizenId(citizenid) return nil end
    function Bridge.Notify(source, message, ntype) end
else
    function Bridge.GetPlayerData() return nil end
    function Bridge.Notify(message, ntype) end
    function Bridge.GetPlayerIdentifier() return nil end
    function Bridge.GetPlayerName() return 'Unknown' end
end
