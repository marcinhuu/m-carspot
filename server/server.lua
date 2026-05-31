local function InitDatabase()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'carspot.sql')
    if not sql or sql == '' then
        print('^1[carspot] carspot.sql not found — import it manually^0')
        return false
    end

    for statement in sql:gmatch('[^;]+') do
        statement = statement:match('^%s*(.-)%s*$')
        if statement and statement ~= '' then
            MySQL.query.await(statement)
        end
    end

    print('^2[carspot] Database tables ready^0')
    return true
end

MySQL.ready(function()
    InitDatabase()
end)

local function GetCitizenId(source)
    local Player = Bridge.GetPlayer(source)
    if not Player then return nil end
    return Bridge.GetPlayerIdentifier(Player)
end

local function GetName(source)
    local Player = Bridge.GetPlayer(source)
    if not Player then return 'Unknown' end
    return Bridge.GetPlayerName(Player)
end

local function SendEventReminder(source, eventName, location, minutesLeft)
    local content = T('event_reminder_content', eventName, minutesLeft)
    if location and location ~= '' then
        content = content .. ' · ' .. location
    end
    exports['lb-phone']:SendNotification(source, {
        app = Config.AppIdentifier,
        title = T('event_reminder_title'),
        content = content,
    })
end

CreateThread(function()
    local minutes = Config.EventReminderMinutes or 5
    while true do
        Wait(60000)
        local rows = MySQL.query.await([[
            SELECT a.citizenid, e.id AS event_id, e.name, e.location
            FROM carspot_event_attendees a
            INNER JOIN carspot_events e ON e.id = a.event_id
            WHERE a.notify = 1 AND a.reminder_sent = 0
              AND e.event_time >= DATE_ADD(NOW(), INTERVAL ? MINUTE)
              AND e.event_time <= DATE_ADD(NOW(), INTERVAL ? MINUTE)
        ]], { minutes - 1, minutes + 1 })

        for _, row in ipairs(rows or {}) do
            local src = Bridge.GetSourceByCitizenId(row.citizenid)
            if src then
                SendEventReminder(src, row.name, row.location, minutes)
            end
            MySQL.update.await(
                'UPDATE carspot_event_attendees SET reminder_sent = 1 WHERE event_id = ? AND citizenid = ?',
                { row.event_id, row.citizenid }
            )
        end
    end
end)

local function EnsureProfile(citizenid, name)
    local existing = MySQL.single.await(
        'SELECT id FROM carspot_profiles WHERE citizenid = ?',
        { citizenid }
    )
    if not existing then
        local base = name:gsub('%s+', '_'):lower():gsub('[^%w_]', '')
        local username = base
        local suffix = 1
        while MySQL.single.await('SELECT id FROM carspot_profiles WHERE username = ?', { username }) do
            username = base .. suffix
            suffix = suffix + 1
        end
        MySQL.insert.await(
            'INSERT INTO carspot_profiles (citizenid, username) VALUES (?, ?)',
            { citizenid, username }
        )
    end
end

lib.callback.register('carspot:getProfile', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return nil end

    local targetCid = data.citizenid or citizenid
    EnsureProfile(citizenid, GetName(source))

    local profile = MySQL.single.await(
        'SELECT * FROM carspot_profiles WHERE citizenid = ?',
        { targetCid }
    )
    if not profile then return nil end

    local isFollowing = false
    if targetCid ~= citizenid then
        local follow = MySQL.single.await(
            'SELECT id FROM carspot_followers WHERE follower_citizenid = ? AND following_citizenid = ?',
            { citizenid, targetCid }
        )
        isFollowing = follow ~= nil
    end

    profile.isFollowing = isFollowing
    profile.isOwn = (targetCid == citizenid)
    return profile
end)

lib.callback.register('carspot:updateProfile', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end

    local username = tostring(data.username or ''):match('^%s*(.-)%s*$')
    local bio      = tostring(data.bio or ''):sub(1, Config.MaxBioLength)
    local avatar   = tostring(data.avatar or '')
    local banner   = tostring(data.banner or '')

    if #username < 3 or #username > Config.MaxUsernameLength or not username:match('^[%w_]+$') then
        return false, T('username_invalid')
    end

    local taken = MySQL.single.await(
        'SELECT id FROM carspot_profiles WHERE username = ? AND citizenid <> ?',
        { username, citizenid }
    )
    if taken then return false, T('username_taken') end

    MySQL.update.await(
        'UPDATE carspot_profiles SET username = ?, bio = ?, avatar = ?, banner = ? WHERE citizenid = ?',
        { username, bio, avatar, banner, citizenid }
    )
    return true, T('profile_updated')
end)

lib.callback.register('carspot:followUser', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end

    local targetCid = tostring(data.citizenid or '')
    if targetCid == '' or targetCid == citizenid then
        return false, T('cannot_follow_self')
    end

    local existing = MySQL.single.await(
        'SELECT id FROM carspot_followers WHERE follower_citizenid = ? AND following_citizenid = ?',
        { citizenid, targetCid }
    )

    if existing then
        MySQL.query.await(
            'DELETE FROM carspot_followers WHERE follower_citizenid = ? AND following_citizenid = ?',
            { citizenid, targetCid }
        )
        MySQL.query.await('UPDATE carspot_profiles SET following = GREATEST(0, following - 1) WHERE citizenid = ?', { citizenid })
        MySQL.query.await('UPDATE carspot_profiles SET followers = GREATEST(0, followers - 1) WHERE citizenid = ?', { targetCid })
        return false, T('unfollowed')
    else
        MySQL.insert.await(
            'INSERT INTO carspot_followers (follower_citizenid, following_citizenid) VALUES (?, ?)',
            { citizenid, targetCid }
        )
        MySQL.query.await('UPDATE carspot_profiles SET following = following + 1 WHERE citizenid = ?', { citizenid })
        MySQL.query.await('UPDATE carspot_profiles SET followers = followers + 1 WHERE citizenid = ?', { targetCid })
        return true, T('now_following')
    end
end)

lib.callback.register('carspot:getFeed', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return {} end
    EnsureProfile(citizenid, GetName(source))

    local offset = tonumber(data.offset) or 0
    local limit  = Config.FeedPageSize

    local posts = MySQL.query.await([[
        SELECT p.*,
               pr.username, pr.avatar AS author_avatar,
               (SELECT COUNT(*) FROM carspot_post_likes l WHERE l.post_id = p.id AND l.citizenid = ?) AS liked_by_me,
               (SELECT COUNT(*) FROM carspot_saved_posts s WHERE s.post_id = p.id AND s.citizenid = ?) AS saved_by_me
        FROM carspot_posts p
        LEFT JOIN carspot_profiles pr ON pr.citizenid = p.citizenid
        ORDER BY p.created_at DESC
        LIMIT ? OFFSET ?
    ]], { citizenid, citizenid, limit, offset })

    return posts or {}
end)

lib.callback.register('carspot:getPost', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return nil end

    local postId = tonumber(data.id)
    if not postId then return nil end

    local post = MySQL.single.await([[
        SELECT p.*,
               pr.username, pr.avatar AS author_avatar,
               (SELECT COUNT(*) FROM carspot_post_likes l WHERE l.post_id = p.id AND l.citizenid = ?) AS liked_by_me,
               (SELECT COUNT(*) FROM carspot_saved_posts s WHERE s.post_id = p.id AND s.citizenid = ?) AS saved_by_me
        FROM carspot_posts p
        LEFT JOIN carspot_profiles pr ON pr.citizenid = p.citizenid
        WHERE p.id = ?
    ]], { citizenid, citizenid, postId })

    if not post then return nil end

    local comments = MySQL.query.await(
        'SELECT * FROM carspot_post_comments WHERE post_id = ? ORDER BY created_at ASC',
        { postId }
    )
    post.comments = comments or {}
    return post
end)

lib.callback.register('carspot:createPost', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end
    EnsureProfile(citizenid, GetName(source))

    local title = tostring(data.title or ''):sub(1, Config.MaxPostTitleLength):match('^%s*(.-)%s*$')
    if title == '' then return false, T('post_title_required') end

    local desc        = tostring(data.description or ''):sub(1, Config.MaxPostDescLength)
    local image       = tostring(data.image or '')
    local location    = tostring(data.location or ''):sub(1, 255)
    local vBrand      = tostring(data.vehicle_brand or ''):sub(1, 100)
    local vModel      = tostring(data.vehicle_model or ''):sub(1, 100)
    local vPlate      = tostring(data.vehicle_plate or ''):sub(1, 20)
    local vColor      = tostring(data.vehicle_color or ''):sub(1, 50)
    local vMods       = tostring(data.vehicle_mods or ''):sub(1, 1000)
    local vClass      = tostring(data.vehicle_class or ''):sub(1, 50)

    local postId = MySQL.insert.await([[
        INSERT INTO carspot_posts
        (citizenid, title, description, image, location,
         vehicle_brand, vehicle_model, vehicle_plate, vehicle_color, vehicle_mods, vehicle_class)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { citizenid, title, desc, image, location, vBrand, vModel, vPlate, vColor, vMods, vClass })

    MySQL.update.await('UPDATE carspot_profiles SET post_count = post_count + 1 WHERE citizenid = ?', { citizenid })
    return true, T('post_created'), postId
end)

lib.callback.register('carspot:deletePost', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end

    local postId = tonumber(data.id)
    if not postId then return false, T('error') end

    local post = MySQL.single.await('SELECT citizenid FROM carspot_posts WHERE id = ?', { postId })
    if not post or post.citizenid ~= citizenid then
        return false, T('post_not_found')
    end

    MySQL.query.await('DELETE FROM carspot_posts WHERE id = ?', { postId })
    MySQL.query.await('DELETE FROM carspot_post_likes WHERE post_id = ?', { postId })
    MySQL.query.await('DELETE FROM carspot_post_comments WHERE post_id = ?', { postId })
    MySQL.query.await('DELETE FROM carspot_saved_posts WHERE post_id = ?', { postId })
    MySQL.update.await('UPDATE carspot_profiles SET post_count = GREATEST(0, post_count - 1) WHERE citizenid = ?', { citizenid })
    return true, T('post_deleted')
end)

lib.callback.register('carspot:likePost', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end

    local postId = tonumber(data.id)
    if not postId then return false, T('error') end

    local existing = MySQL.single.await(
        'SELECT id FROM carspot_post_likes WHERE post_id = ? AND citizenid = ?',
        { postId, citizenid }
    )

    if existing then
        MySQL.query.await('DELETE FROM carspot_post_likes WHERE post_id = ? AND citizenid = ?', { postId, citizenid })
        MySQL.update.await('UPDATE carspot_posts SET likes_count = GREATEST(0, likes_count - 1) WHERE id = ?', { postId })
        return false, T('post_unliked')
    else
        MySQL.insert.await('INSERT INTO carspot_post_likes (post_id, citizenid) VALUES (?, ?)', { postId, citizenid })
        MySQL.update.await('UPDATE carspot_posts SET likes_count = likes_count + 1 WHERE id = ?', { postId })
        local post = MySQL.single.await('SELECT vehicle_plate, citizenid FROM carspot_posts WHERE id = ?', { postId })
        if post and post.vehicle_plate ~= '' then
            MySQL.update.await(
                'UPDATE carspot_garage SET likes_count = likes_count + 1 WHERE citizenid = ? AND vehicle_plate = ?',
                { post.citizenid, post.vehicle_plate }
            )
        end
        return true, T('post_liked')
    end
end)

lib.callback.register('carspot:savePost', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end

    local postId = tonumber(data.id)
    if not postId then return false, T('error') end

    local existing = MySQL.single.await(
        'SELECT id FROM carspot_saved_posts WHERE post_id = ? AND citizenid = ?',
        { postId, citizenid }
    )

    if existing then
        MySQL.query.await('DELETE FROM carspot_saved_posts WHERE post_id = ? AND citizenid = ?', { postId, citizenid })
        return false, T('post_unsaved')
    else
        MySQL.insert.await('INSERT INTO carspot_saved_posts (post_id, citizenid) VALUES (?, ?)', { postId, citizenid })
        return true, T('post_saved')
    end
end)

lib.callback.register('carspot:commentPost', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end
    EnsureProfile(citizenid, GetName(source))

    local postId  = tonumber(data.id)
    local content = tostring(data.content or ''):match('^%s*(.-)%s*$')

    if not postId then return false, T('error') end
    if content == '' then return false, T('comment_empty') end
    if #content > Config.MaxCommentLength then return false, T('comment_too_long') end

    local profile = MySQL.single.await('SELECT username, avatar FROM carspot_profiles WHERE citizenid = ?', { citizenid })
    local username = profile and profile.username or citizenid
    local avatar   = profile and profile.avatar or ''

    local commentId = MySQL.insert.await([[
        INSERT INTO carspot_post_comments (post_id, citizenid, username, avatar, content)
        VALUES (?, ?, ?, ?, ?)
    ]], { postId, citizenid, username, avatar, content })

    MySQL.update.await('UPDATE carspot_posts SET comments_count = comments_count + 1 WHERE id = ?', { postId })

    return true, T('comment_posted'), {
        id = commentId,
        post_id = postId,
        citizenid = citizenid,
        username = username,
        avatar = avatar,
        content = content,
        created_at = os.date('%Y-%m-%d %H:%M:%S')
    }
end)

lib.callback.register('carspot:getSavedPosts', function(source, _)
    local citizenid = GetCitizenId(source)
    if not citizenid then return {} end

    local posts = MySQL.query.await([[
        SELECT p.*,
               pr.username, pr.avatar AS author_avatar,
               1 AS liked_by_me,
               1 AS saved_by_me
        FROM carspot_saved_posts sp
        JOIN carspot_posts p ON p.id = sp.post_id
        LEFT JOIN carspot_profiles pr ON pr.citizenid = p.citizenid
        WHERE sp.citizenid = ?
        ORDER BY sp.created_at DESC
    ]], { citizenid })

    return posts or {}
end)

lib.callback.register('carspot:getUserPosts', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return {} end

    local targetCid = data.citizenid or citizenid

    local posts = MySQL.query.await([[
        SELECT p.*,
               pr.username, pr.avatar AS author_avatar,
               (SELECT COUNT(*) FROM carspot_post_likes l WHERE l.post_id = p.id AND l.citizenid = ?) AS liked_by_me,
               (SELECT COUNT(*) FROM carspot_saved_posts s WHERE s.post_id = p.id AND s.citizenid = ?) AS saved_by_me
        FROM carspot_posts p
        LEFT JOIN carspot_profiles pr ON pr.citizenid = p.citizenid
        WHERE p.citizenid = ?
        ORDER BY p.created_at DESC
    ]], { citizenid, citizenid, targetCid })

    return posts or {}
end)

lib.callback.register('carspot:getGarage', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return {} end

    local targetCid = data.citizenid or citizenid

    local vehicles = MySQL.query.await(
        'SELECT * FROM carspot_garage WHERE citizenid = ? ORDER BY created_at DESC',
        { targetCid }
    )
    return vehicles or {}
end)

lib.callback.register('carspot:addGarageVehicle', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end

    local vModel = tostring(data.vehicle_model or ''):sub(1, 100):match('^%s*(.-)%s*$')
    local vBrand = tostring(data.vehicle_brand or ''):sub(1, 100)
    local vPlate = tostring(data.vehicle_plate or ''):sub(1, 20)

    if vModel == '' then return false, T('error') end

    if vPlate ~= '' then
        local dup = MySQL.single.await(
            'SELECT id FROM carspot_garage WHERE citizenid = ? AND vehicle_plate = ?',
            { citizenid, vPlate }
        )
        if dup then return false, T('garage_vehicle_exists') end
    end

    local vColor   = tostring(data.vehicle_color or ''):sub(1, 50)
    local vMods    = tostring(data.vehicle_mods or ''):sub(1, 1000)
    local vClass   = tostring(data.vehicle_class or ''):sub(1, 50)
    local image    = tostring(data.image or '')

    MySQL.insert.await([[
        INSERT INTO carspot_garage
        (citizenid, vehicle_brand, vehicle_model, vehicle_plate, vehicle_color, vehicle_mods, vehicle_class, image)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { citizenid, vBrand, vModel, vPlate, vColor, vMods, vClass, image })

    return true, T('garage_vehicle_added')
end)

lib.callback.register('carspot:removeGarageVehicle', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end

    local vehicleId = tonumber(data.id)
    if not vehicleId then return false, T('error') end

    local vehicle = MySQL.single.await('SELECT citizenid FROM carspot_garage WHERE id = ?', { vehicleId })
    if not vehicle or vehicle.citizenid ~= citizenid then
        return false, T('error')
    end

    MySQL.query.await('DELETE FROM carspot_garage WHERE id = ?', { vehicleId })
    return true, T('garage_vehicle_removed')
end)

lib.callback.register('carspot:getEvents', function(source, _)
    local citizenid = GetCitizenId(source)
    if not citizenid then return {} end

    local events = MySQL.query.await([[
        SELECT e.*,
               pr.username AS organizer_name, pr.avatar AS organizer_avatar,
               (SELECT COUNT(*) FROM carspot_event_attendees a WHERE a.event_id = e.id AND a.citizenid = ?) AS attending
        FROM carspot_events e
        LEFT JOIN carspot_profiles pr ON pr.citizenid = e.citizenid
        WHERE e.event_time >= NOW()
        ORDER BY e.event_time ASC
    ]], { citizenid })

    return events or {}
end)

lib.callback.register('carspot:createEvent', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end
    EnsureProfile(citizenid, GetName(source))

    local name     = tostring(data.name or ''):sub(1, Config.MaxEventNameLength):match('^%s*(.-)%s*$')
    if name == '' then return false, T('event_name_required') end

    local desc      = tostring(data.description or ''):sub(1, Config.MaxEventDescLength)
    local etype     = tostring(data.type or 'car_meet'):sub(1, 50)
    local location  = tostring(data.location or ''):sub(1, 255)
    local eventTime = tostring(data.event_time or '')
    local maxPart   = tonumber(data.max_participants) or Config.DefaultMaxParticipants
    local image     = tostring(data.image or '')

    local eventId = MySQL.insert.await([[
        INSERT INTO carspot_events (citizenid, name, description, type, location, event_time, max_participants, image)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { citizenid, name, desc, etype, location, eventTime, maxPart, image })

    return true, T('event_created'), eventId
end)

lib.callback.register('carspot:attendEvent', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end

    local eventId = tonumber(data.id)
    if not eventId then return false, T('error') end

    local event = MySQL.single.await('SELECT * FROM carspot_events WHERE id = ?', { eventId })
    if not event then return false, T('event_not_found') end

    local existing = MySQL.single.await(
        'SELECT id FROM carspot_event_attendees WHERE event_id = ? AND citizenid = ?',
        { eventId, citizenid }
    )

    if existing then
        MySQL.query.await('DELETE FROM carspot_event_attendees WHERE event_id = ? AND citizenid = ?', { eventId, citizenid })
        MySQL.update.await('UPDATE carspot_events SET attendee_count = GREATEST(0, attendee_count - 1) WHERE id = ?', { eventId })
        return false, T('event_left')
    else
        if event.attendee_count >= event.max_participants then
            return false, T('event_full')
        end
        local notify = data.notify == true or data.notify == 1 or data.notify == 'true'
        MySQL.insert.await(
            'INSERT INTO carspot_event_attendees (event_id, citizenid, notify, reminder_sent) VALUES (?, ?, ?, 0)',
            { eventId, citizenid, notify and 1 or 0 }
        )
        MySQL.update.await('UPDATE carspot_events SET attendee_count = attendee_count + 1 WHERE id = ?', { eventId })
        return true, T('event_attending')
    end
end)

lib.callback.register('carspot:deleteEvent', function(source, data)
    local citizenid = GetCitizenId(source)
    if not citizenid then return false, T('error') end

    local eventId = tonumber(data.id)
    if not eventId then return false, T('error') end

    local event = MySQL.single.await('SELECT citizenid FROM carspot_events WHERE id = ?', { eventId })
    if not event or event.citizenid ~= citizenid then
        return false, T('event_not_found')
    end

    MySQL.query.await('DELETE FROM carspot_events WHERE id = ?', { eventId })
    MySQL.query.await('DELETE FROM carspot_event_attendees WHERE event_id = ?', { eventId })
    return true, T('event_deleted')
end)

lib.callback.register('carspot:getWeeklyRanking', function(source, _)
    local citizenid = GetCitizenId(source)
    if not citizenid then return {} end

    local since = os.date('%Y-%m-%d %H:%M:%S', os.time() - Config.RankingDays * 86400)

    local mostVoted = MySQL.query.await([[
        SELECT p.*, pr.username, pr.avatar AS author_avatar,
               COUNT(l.id) AS recent_likes
        FROM carspot_posts p
        LEFT JOIN carspot_post_likes l ON l.post_id = p.id AND l.created_at >= ?
        LEFT JOIN carspot_profiles pr ON pr.citizenid = p.citizenid
        GROUP BY p.id
        ORDER BY recent_likes DESC
        LIMIT 5
    ]], { since })

    local bestClassic = MySQL.query.await([[
        SELECT p.*, pr.username, pr.avatar AS author_avatar,
               COUNT(l.id) AS recent_likes
        FROM carspot_posts p
        LEFT JOIN carspot_post_likes l ON l.post_id = p.id AND l.created_at >= ?
        LEFT JOIN carspot_profiles pr ON pr.citizenid = p.citizenid
        WHERE UPPER(p.vehicle_class) IN ('D','C','CLASSIC')
        GROUP BY p.id
        ORDER BY recent_likes DESC
        LIMIT 3
    ]], { since })

    local bestSupercar = MySQL.query.await([[
        SELECT p.*, pr.username, pr.avatar AS author_avatar,
               COUNT(l.id) AS recent_likes
        FROM carspot_posts p
        LEFT JOIN carspot_post_likes l ON l.post_id = p.id AND l.created_at >= ?
        LEFT JOIN carspot_profiles pr ON pr.citizenid = p.citizenid
        WHERE UPPER(p.vehicle_class) IN ('S','X','SUPERCAR','SUPER')
        GROUP BY p.id
        ORDER BY recent_likes DESC
        LIMIT 3
    ]], { since })

    local bestOffroad = MySQL.query.await([[
        SELECT p.*, pr.username, pr.avatar AS author_avatar,
               COUNT(l.id) AS recent_likes
        FROM carspot_posts p
        LEFT JOIN carspot_post_likes l ON l.post_id = p.id AND l.created_at >= ?
        LEFT JOIN carspot_profiles pr ON pr.citizenid = p.citizenid
        WHERE UPPER(p.vehicle_class) IN ('O','OFF-ROAD','OFFROAD','SUV','MUD')
        GROUP BY p.id
        ORDER BY recent_likes DESC
        LIMIT 3
    ]], { since })

    return {
        most_voted  = mostVoted  or {},
        classic     = bestClassic  or {},
        supercar    = bestSupercar or {},
        offroad     = bestOffroad  or {}
    }
end)

lib.callback.register('carspot:getOwnedVehicles', function(source, _)
    local citizenid = GetCitizenId(source)
    if not citizenid then return {} end

    local vehicles = {}
    if Config.Framework == 'qbcore' then
        vehicles = MySQL.query.await(
            'SELECT vehicle, plate FROM player_vehicles WHERE citizenid = ?',
            { citizenid }
        ) or {}
    elseif Config.Framework == 'esx' then
        vehicles = MySQL.query.await(
            'SELECT vehicle, plate FROM owned_vehicles WHERE owner = ?',
            { citizenid }
        ) or {}
    end
    return vehicles
end)
