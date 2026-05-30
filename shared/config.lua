Config = {}

-- Framework: 'qbcore', 'esx' (auto-detected, no need to change)
Config.Framework = 'qbcore'

-- Locale: 'en', 'pt', 'es', 'fr', 'de', 'it'
Config.Locale = 'en'

-- App identifier (must be unique)
Config.AppIdentifier = 'lb-phone-carspot'

Config.AppName = 'CarSpot'
Config.AppDescription = 'A car social network for vehicle lovers'
Config.AppDeveloper = 'CarSpot'
Config.AppSize = 4.5

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
Config.ClassicVehicleClasses  = { 'D', 'C' }   -- by GTA class letter or custom tag
Config.SupercarVehicleClasses = { 'S', 'X' }
Config.OffroadVehicleClasses  = { 'offroad', 'SUV', 'O' }
