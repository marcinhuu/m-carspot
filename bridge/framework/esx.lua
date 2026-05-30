if Config.Framework ~= 'esx' then return end

local ESX = exports['es_extended']:getSharedObject()

if IsDuplicityVersion() then
    function Bridge.GetPlayer(source)
        return ESX.GetPlayerFromId(source)
    end

    function Bridge.GetPlayerName(Player)
        return Player.getName()
    end

    function Bridge.GetPlayerIdentifier(Player)
        return Player.identifier
    end

    function Bridge.Notify(source, message, ntype)
        TriggerClientEvent('esx:showNotification', source, message)
    end

    function Bridge.GetSourceByCitizenId(citizenid)
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer and xPlayer.identifier == citizenid then
                return src
            end
        end
        return nil
    end
else
    function Bridge.GetPlayerData()
        return ESX.GetPlayerData()
    end

    function Bridge.GetPlayerIdentifier()
        local data = ESX.GetPlayerData()
        return data and data.identifier or nil
    end

    function Bridge.GetPlayerName()
        local data = ESX.GetPlayerData()
        if not data then return 'Unknown' end
        return data.firstName .. ' ' .. data.lastName
    end

    function Bridge.Notify(message, ntype)
        ESX.ShowNotification(message)
    end
end
