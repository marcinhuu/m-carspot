if Config.Framework ~= 'qbcore' then return end

local QBCore = exports['qb-core']:GetCoreObject()

if IsDuplicityVersion() then
    function Bridge.GetPlayer(source)
        return QBCore.Functions.GetPlayer(source)
    end

    function Bridge.GetPlayerName(Player)
        return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    end

    function Bridge.GetPlayerIdentifier(Player)
        return Player.PlayerData.citizenid
    end

    function Bridge.Notify(source, message, ntype)
        TriggerClientEvent('QBCore:Notify', source, message, ntype or 'primary')
    end

    function Bridge.GetSourceByCitizenId(citizenid)
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            local Player = QBCore.Functions.GetPlayer(src)
            if Player and Player.PlayerData.citizenid == citizenid then
                return src
            end
        end
        return nil
    end
else
    function Bridge.GetPlayerData()
        return QBCore.Functions.GetPlayerData()
    end

    function Bridge.GetPlayerIdentifier()
        local data = QBCore.Functions.GetPlayerData()
        return data and data.citizenid or nil
    end

    function Bridge.GetPlayerName()
        local data = QBCore.Functions.GetPlayerData()
        if not data then return 'Unknown' end
        return data.charinfo.firstname .. ' ' .. data.charinfo.lastname
    end

    function Bridge.Notify(message, ntype)
        QBCore.Functions.Notify(message, ntype or 'primary')
    end
end
