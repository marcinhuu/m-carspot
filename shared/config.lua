Config = {}

-- Framework: 'qbcore' or 'esx' (must match your server)
Config.Framework = 'qbcore'

-- Locale: 'en', 'pt', 'es', 'fr', 'de', 'it'
Config.Locale = 'en'

-- Phone: 'auto' | 'lb-phone' | 'sd-phone'
-- auto = prefer sd-phone if started, otherwise lb-phone
Config.Phone = 'sd-phone'

-- App identifier (must be unique; never shown to players)
Config.AppIdentifier = 'lb-phone-carspot'

Config.AppName = 'CarSpot'
Config.AppDescription = 'A car social network for vehicle lovers'
Config.AppDeveloper = 'CarSpot'
Config.AppSize = 4.5

-- true = pre-installed; false = downloadable from the App Store
Config.DefaultApp = false

-- Feed: how many posts to load per page
Config.FeedPageSize = 10

-- Max characters
Config.MaxPostTitleLength   = 80
Config.MaxPostDescLength    = 500
Config.MaxCommentLength     = 200
Config.MaxBioLength         = 150
Config.MaxUsernameLength    = 30

-- Events
Config.MaxEventNameLength   = 80
Config.MaxEventDescLength   = 300
Config.DefaultMaxParticipants = 50
Config.EventReminderMinutes = 5

-- Weekly ranking: how many days back to count votes
Config.RankingDays = 7

-- Vehicle classes for ranking categories
Config.ClassicVehicleClasses  = { 'D', 'C' }
Config.SupercarVehicleClasses = { 'S', 'X' }
Config.OffroadVehicleClasses  = { 'offroad', 'SUV', 'O' }
