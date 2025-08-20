Config = {}

-- General Settings
Config.Debug = false
Config.Framework = 'ESX' -- ESX or QBCore
Config.Keybind = 'F5'
Config.ShowRange = 3.0
Config.RequireLineOfSight = true
Config.ShowCooldown = 2000 -- milliseconds
Config.AutoAcceptDigital = false

-- Database Settings
Config.DatabasePrefix = 'jr_idcard'

-- Card Types
Config.CardTypes = {
    ['id'] = {
        label = 'Identification Card',
        icon = 'id-card',
        color = '#3b82f6',
        expirable = true,
        defaultExpiry = 365 * 24 * 60 * 60 -- 1 year in seconds
    },
    ['driver'] = {
        label = 'Driver License',
        icon = 'car',
        color = '#10b981',
        expirable = true,
        defaultExpiry = 5 * 365 * 24 * 60 * 60 -- 5 years
    },
    ['weapon_permit'] = {
        label = 'Weapon Permit',
        icon = 'shield-check',
        color = '#dc2626',
        expirable = true,
        defaultExpiry = 2 * 365 * 24 * 60 * 60 -- 2 years
    },
    ['job_id:police'] = {
        label = 'Police Service ID',
        icon = 'badge',
        color = '#1e40af',
        expirable = false
    },
    ['job_id:ambulance'] = {
        label = 'EMS Service ID',
        icon = 'heart-pulse',
        color = '#dc2626',
        expirable = false
    },
    ['job_id:mechanic'] = {
        label = 'Mechanic License',
        icon = 'wrench',
        color = '#ea580c',
        expirable = true,
        defaultExpiry = 3 * 365 * 24 * 60 * 60 -- 3 years
    },
    ['residence'] = {
        label = 'Residence Permit',
        icon = 'home',
        color = '#7c3aed',
        expirable = true,
        defaultExpiry = 10 * 365 * 24 * 60 * 60 -- 10 years
    }
}

-- Job Permissions
Config.AuthorizedJobs = {
    ['police'] = {
        canIssue = {'id', 'driver', 'weapon_permit'},
        canRenew = {'id', 'driver', 'weapon_permit'},
        canRevoke = {'id', 'driver', 'weapon_permit', 'job_id:mechanic'},
        canSuspend = {'id', 'driver', 'weapon_permit'},
        canSeize = {'id', 'driver', 'weapon_permit', 'job_id:mechanic'},
        canVerify = true,
        requireGrade = 1
    },
    ['government'] = {
        canIssue = {'id', 'driver', 'residence', 'job_id:mechanic'},
        canRenew = {'id', 'driver', 'residence', 'job_id:mechanic'},
        canRevoke = {'id', 'driver', 'residence', 'job_id:mechanic'},
        canSuspend = {'id', 'driver', 'residence'},
        canSeize = {'id', 'driver', 'residence'},
        canVerify = true,
        requireGrade = 0
    },
    ['cityhall'] = {
        canIssue = {'id', 'driver', 'residence'},
        canRenew = {'id', 'driver', 'residence'},
        canRevoke = {'id', 'driver', 'residence'},
        canSuspend = {'id', 'driver', 'residence'},
        canSeize = {'id', 'driver', 'residence'},
        canVerify = true,
        requireGrade = 0
    },
    ['ambulance'] = {
        canIssue = {'job_id:ambulance'},
        canRenew = {'job_id:ambulance'},
        canRevoke = {},
        canSuspend = {},
        canSeize = {},
        canVerify = true,
        requireGrade = 2
    }
}

-- Inventory Integration
Config.UseOxInventory = true
Config.CardItem = {
    name = 'id_card',
    label = 'ID Card',
    weight = 1,
    stack = false,
    close = true
}

-- Security Settings
Config.SecretKey = 'change_this_in_production_please' -- CHANGE THIS!
Config.ValidateDistance = true
Config.ValidateLineOfSight = true
Config.ValidateOwnership = true
Config.RequireAlive = true
Config.RequireConscious = true
Config.PreventRestrained = true

-- Audit Logging
Config.EnableAuditLog = true
Config.LogToConsole = true
Config.LogToDatabase = true
Config.LogToDiscord = false
Config.DiscordWebhook = ''

-- Admin Settings
Config.AdminCommands = true
Config.AdminGroups = {'admin', 'superadmin'}

-- NUI Settings
Config.Theme = 'modern' -- modern, classic, dark
Config.ShowPhotos = true
Config.ShowQRCodes = true
Config.ShowHologram = true
Config.EnableAccessibility = true

-- Notification Settings
Config.NotifyType = 'ox_lib' -- ox_lib, esx, qbcore, custom
Config.NotifyDuration = 5000

-- Performance Settings
Config.ClientUpdateInterval = 1000 -- milliseconds
Config.ServerCleanupInterval = 300000 -- 5 minutes
Config.CacheCards = true
Config.MaxCachedCards = 100

return Config