local APP_ID = Config.AppIdentifier

local function AddApp()
    local added, err = exports['lb-phone']:AddCustomApp({
        identifier  = APP_ID,
        name        = Config.AppName,
        description = Config.AppDescription,
        developer   = Config.AppDeveloper,
        defaultApp  = false,
        size        = math.floor(Config.AppSize * 1024),
        images      = {
            'https://cfx-nui-' .. GetCurrentResourceName() .. '/ui/assets/screenshot.png',
        },
        ui   = GetCurrentResourceName() .. '/ui/index.html',
        icon = 'https://cfx-nui-' .. GetCurrentResourceName() .. '/ui/assets/carspot.png',
        fixBlur = true
    })
    if not added then
        print('^1[lb-phone-carspot] Could not register app: ' .. tostring(err) .. '^0')
    end
end

while GetResourceState('lb-phone') ~= 'started' do Wait(500) end
AddApp()
AddEventHandler('onResourceStart', function(res)
    if res == 'lb-phone' then AddApp() end
end)

local function ServerCall(callbackName, data, cb)
    lib.callback(callbackName, false, cb, data or {})
end

RegisterNUICallback('carspot:getProfile', function(data, cb)
    ServerCall('carspot:getProfile', data, function(result)
        cb(result)
    end)
end)

RegisterNUICallback('carspot:updateProfile', function(data, cb)
    ServerCall('carspot:updateProfile', data, function(ok, msg)
        cb({ success = ok, message = msg })
    end)
end)

RegisterNUICallback('carspot:followUser', function(data, cb)
    ServerCall('carspot:followUser', data, function(following, msg)
        cb({ following = following, message = msg })
    end)
end)

RegisterNUICallback('carspot:getFeed', function(data, cb)
    ServerCall('carspot:getFeed', data, function(posts)
        cb(posts or {})
    end)
end)

RegisterNUICallback('carspot:getPost', function(data, cb)
    ServerCall('carspot:getPost', data, function(post)
        cb(post)
    end)
end)

RegisterNUICallback('carspot:createPost', function(data, cb)
    ServerCall('carspot:createPost', data, function(ok, msg, id)
        cb({ success = ok, message = msg, id = id })
    end)
end)

RegisterNUICallback('carspot:deletePost', function(data, cb)
    ServerCall('carspot:deletePost', data, function(ok, msg)
        cb({ success = ok, message = msg })
    end)
end)

RegisterNUICallback('carspot:likePost', function(data, cb)
    ServerCall('carspot:likePost', data, function(liked, msg)
        cb({ liked = liked, message = msg })
    end)
end)

RegisterNUICallback('carspot:savePost', function(data, cb)
    ServerCall('carspot:savePost', data, function(saved, msg)
        cb({ saved = saved, message = msg })
    end)
end)

RegisterNUICallback('carspot:commentPost', function(data, cb)
    ServerCall('carspot:commentPost', data, function(ok, msg, comment)
        cb({ success = ok, message = msg, comment = comment })
    end)
end)

RegisterNUICallback('carspot:getSavedPosts', function(data, cb)
    ServerCall('carspot:getSavedPosts', data, function(posts)
        cb(posts or {})
    end)
end)

RegisterNUICallback('carspot:getUserPosts', function(data, cb)
    ServerCall('carspot:getUserPosts', data, function(posts)
        cb(posts or {})
    end)
end)

RegisterNUICallback('carspot:getGarage', function(data, cb)
    ServerCall('carspot:getGarage', data, function(vehicles)
        cb(vehicles or {})
    end)
end)

RegisterNUICallback('carspot:addGarageVehicle', function(data, cb)
    ServerCall('carspot:addGarageVehicle', data, function(ok, msg)
        cb({ success = ok, message = msg })
    end)
end)

RegisterNUICallback('carspot:removeGarageVehicle', function(data, cb)
    ServerCall('carspot:removeGarageVehicle', data, function(ok, msg)
        cb({ success = ok, message = msg })
    end)
end)

RegisterNUICallback('carspot:getEvents', function(data, cb)
    ServerCall('carspot:getEvents', data, function(events)
        cb(events or {})
    end)
end)

RegisterNUICallback('carspot:createEvent', function(data, cb)
    ServerCall('carspot:createEvent', data, function(ok, msg, id)
        cb({ success = ok, message = msg, id = id })
    end)
end)

RegisterNUICallback('carspot:attendEvent', function(data, cb)
    ServerCall('carspot:attendEvent', data, function(attending, msg)
        cb({ attending = attending, message = msg })
    end)
end)

RegisterNUICallback('carspot:deleteEvent', function(data, cb)
    ServerCall('carspot:deleteEvent', data, function(ok, msg)
        cb({ success = ok, message = msg })
    end)
end)

RegisterNUICallback('carspot:getWeeklyRanking', function(data, cb)
    ServerCall('carspot:getWeeklyRanking', data, function(ranking)
        cb(ranking or {})
    end)
end)

RegisterNUICallback('carspot:getOwnedVehicles', function(data, cb)
    ServerCall('carspot:getOwnedVehicles', {}, function(vehicles)
        cb(vehicles or {})
    end)
end)

RegisterNUICallback('carspot:getLocales', function(_, cb)
    cb({ locales = Locale[Config.Locale] or Locale['en'] })
end)
