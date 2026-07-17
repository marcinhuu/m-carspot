local APP_ID = Config.AppIdentifier

local function resolveUi()
    local resource = GetCurrentResourceName()
    local uiPage = GetResourceMetadata(resource, 'ui_page', 0)
    if not uiPage or uiPage == '' then
        return resource .. '/ui/index.html'
    end
    if uiPage:find('^https?://') then
        return uiPage
    end
    return resource .. '/' .. uiPage
end

local function buildAppDef()
    local resource = GetCurrentResourceName()
    return {
        identifier  = APP_ID,
        name        = Config.AppName,
        description = Config.AppDescription,
        developer   = Config.AppDeveloper,
        defaultApp  = Config.DefaultApp == true,
        size        = math.floor((Config.AppSize or 4.5) * 1024),
        images      = {
            ('https://cfx-nui-%s/ui/assets/screenshot-light.png'):format(resource),
            ('https://cfx-nui-%s/ui/assets/screenshot-dark.png'):format(resource),
        },
        ui      = resolveUi(),
        icon    = ('https://cfx-nui-%s/ui/assets/carspot.png'):format(resource),
        fixBlur = true,
    }
end

local function AddApp()
    local phone = Phone.GetResource()
    if not phone then return end

    local def = buildAppDef()
    local ok, err

    if phone == 'sd-phone' then
        local success, result, resultErr = pcall(function()
            return exports['sd-phone']:addCustomApp(def)
        end)
        if not success then
            print(('^1[m-carspot] sd-phone addCustomApp error: %s^0'):format(tostring(result)))
            return
        end
        ok, err = result, resultErr
    else
        local success, result, resultErr = pcall(function()
            return exports['lb-phone']:AddCustomApp(def)
        end)
        if not success then
            print(('^1[m-carspot] lb-phone AddCustomApp error: %s^0'):format(tostring(result)))
            return
        end
        ok, err = result, resultErr
    end

    if not ok then
        print(('^1[m-carspot] Could not register on %s: %s^0'):format(phone, tostring(err)))
    else
        print(('^2[m-carspot] Registered on %s^0'):format(phone))
    end
end

CreateThread(function()
    local phone = Phone.WaitForStart()
    Wait(1000)
    AddApp()
    print(('^2[m-carspot] Phone backend: %s^0'):format(phone))
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= 'sd-phone' and res ~= 'lb-phone' then return end
    -- Ignore the provided lb-phone alias when sd-phone is the real phone
    if res == 'lb-phone' and GetResourceState('sd-phone') ~= 'missing' then return end
    CreateThread(function()
        while not Phone.GetResource() do Wait(200) end
        Wait(1000)
        AddApp()
    end)
end)

local function ServerCall(callbackName, data, cb)
    lib.callback(callbackName, false, cb, data or {})
end

local function TrimPlate(plate)
    if type(plate) ~= 'string' then return plate end
    return plate:match('^%s*(.-)%s*$') or plate
end

local function ResolveOwnedVehicleModel(rawVehicle)
    if not rawVehicle or rawVehicle == '' then return nil end

    if type(rawVehicle) == 'string' and rawVehicle:sub(1, 1) ~= '{' then
        return rawVehicle
    end

    local props = type(rawVehicle) == 'table' and rawVehicle or nil
    if not props then
        local ok, decoded = pcall(json.decode, rawVehicle)
        if ok and type(decoded) == 'table' then props = decoded end
    end

    if not props or props.model == nil then
        return type(rawVehicle) == 'string' and rawVehicle or nil
    end

    local model = props.model
    if type(model) == 'string' and not tonumber(model) then
        return model
    end

    local hash = tonumber(model) or joaat(tostring(model))
    local display = GetLabelText(GetDisplayNameFromVehicleModel(hash))
    if not display or display == 'NULL' or display == '' then
        display = GetDisplayNameFromVehicleModel(hash)
    end
    if display and display ~= 'NULL' and display ~= '' then
        return display
    end
    return tostring(model)
end

local function NormalizeOwnedVehicles(vehicles)
    local result = {}
    for _, row in ipairs(vehicles or {}) do
        local plate = TrimPlate(row.plate)
        local model = ResolveOwnedVehicleModel(row.vehicle)

        if Config.Framework == 'esx' and type(row.vehicle) == 'string' and row.vehicle:sub(1, 1) == '{' then
            local ok, props = pcall(json.decode, row.vehicle)
            if ok and type(props) == 'table' and props.plate and (not plate or plate == '') then
                plate = TrimPlate(props.plate)
            end
        end

        if model then
            result[#result + 1] = { vehicle = model, plate = plate or '' }
        end
    end
    return result
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
        cb(NormalizeOwnedVehicles(vehicles))
    end)
end)

RegisterNUICallback('carspot:getLocales', function(_, cb)
    cb({ locales = Locale[Config.Locale] or Locale['en'] })
end)
