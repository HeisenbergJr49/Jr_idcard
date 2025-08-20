-- Player Interactions Handler for Jr_IDCard Client
-- Manages player-to-player interactions, targeting, and ox_target integrations

local Interactions = {}
local targetPrompts = {}
local isShowingCard = false

-- Initialize interaction systems
Interactions.Init = function()
    if Config.UseOxTarget then
        Interactions.SetupOxTargetInteractions()
    end
    
    Interactions.SetupPlayerTargeting()
    
    if Config.Debug then
        print('^2[Jr_IDCard]^7 Player interactions initialized')
    end
end

-- Setup ox_target interactions for desks/terminals
Interactions.SetupOxTargetInteractions = function()
    if not exports.ox_target then
        if Config.Debug then
            print('^1[Jr_IDCard]^7 ox_target not available')
        end
        return
    end
    
    -- ID Card issuing desk/terminal
    exports.ox_target:addModel({
        'prop_cs_documents_01',
        'prop_laptop_01a',
        'prop_laptop_02_closed'
    }, {
        {
            name = 'jr_idcard_desk',
            icon = 'fas fa-id-card',
            label = lib.getLocale('action_issue'),
            distance = 2.0,
            onSelect = function()
                Interactions.OpenIssueCardMenu()
            end,
            canInteract = function()
                return Interactions.CanIssueCards()
            end
        },
        {
            name = 'jr_idcard_verify',
            icon = 'fas fa-shield-check',
            label = lib.getLocale('action_verify'),
            distance = 2.0,
            onSelect = function()
                Interactions.OpenVerifyCardMenu()
            end,
            canInteract = function()
                return Interactions.CanVerifyCards()
            end
        }
    })
end

-- Setup player targeting for card verification
Interactions.SetupPlayerTargeting = function()
    CreateThread(function()
        while true do
            Wait(0)
            
            if IsControlJustPressed(0, 74) then -- H key
                local targetPlayer = Interactions.GetTargetPlayer()
                if targetPlayer then
                    Interactions.ShowPlayerCardMenu(targetPlayer)
                end
            end
        end
    end)
end

-- Get targeted player
Interactions.GetTargetPlayer = function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local forwardVector = GetEntityForwardVector(playerPed)
    
    -- Raycast forward to find player
    local rayHandle = StartShapeTestRay(
        playerCoords.x, playerCoords.y, playerCoords.z,
        playerCoords.x + forwardVector.x * Config.ShowRange,
        playerCoords.y + forwardVector.y * Config.ShowRange,
        playerCoords.z + forwardVector.z * Config.ShowRange,
        12, -- Player flag
        playerPed,
        0
    )
    
    local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)
    
    if hit and entityHit and IsPedAPlayer(entityHit) then
        local targetPlayerId = NetworkGetPlayerIndexFromPed(entityHit)
        if targetPlayerId ~= -1 then
            return {
                serverId = GetPlayerServerId(targetPlayerId),
                name = GetPlayerName(targetPlayerId),
                ped = entityHit
            }
        end
    end
    
    return nil
end

-- Show player card interaction menu
Interactions.ShowPlayerCardMenu = function(targetPlayer)
    local playerData = GetCurrentPlayerData()
    if not playerData then return end
    
    -- Check if player can verify cards
    local canVerify = Interactions.CanVerifyCards()
    local options = {}
    
    if canVerify then
        table.insert(options, {
            title = lib.getLocale('action_verify'),
            description = lib.getLocale('verify_player_cards'),
            icon = 'shield-check',
            onSelect = function()
                Interactions.RequestPlayerCards(targetPlayer.serverId)
            end
        })
    end
    
    -- Show context menu if there are options
    if #options > 0 then
        lib.registerContext({
            id = 'jr_idcard_player_menu',
            title = string.format('%s - %s', lib.getLocale('card_management'), targetPlayer.name),
            options = options
        })
        
        lib.showContext('jr_idcard_player_menu')
    end
end

-- Request to see another player's cards for verification
Interactions.RequestPlayerCards = function(targetServerId)
    TriggerServerEvent('jr_idcard:requestPlayerCards', targetServerId)
end

-- Open card issuing menu (for authorized personnel)
Interactions.OpenIssueCardMenu = function()
    if not Interactions.CanIssueCards() then
        lib.notify({
            title = 'ID Cards',
            description = lib.getLocale('error_not_authorized'),
            type = 'error'
        })
        return
    end
    
    -- Get nearby players for issuing
    local nearbyPlayers = GetNearbyPlayers()
    local options = {}
    
    for _, player in ipairs(nearbyPlayers) do
        table.insert(options, {
            title = player.name,
            description = string.format('Distance: %.1fm', player.distance),
            icon = 'user',
            onSelect = function()
                Interactions.ShowCardTypeMenu(player.serverId, player.name)
            end
        })
    end
    
    if #options == 0 then
        lib.notify({
            title = 'ID Cards',
            description = lib.getLocale('no_nearby_players'),
            type = 'error'
        })
        return
    end
    
    lib.registerContext({
        id = 'jr_idcard_issue_players',
        title = lib.getLocale('select_player'),
        options = options
    })
    
    lib.showContext('jr_idcard_issue_players')
end

-- Show card type selection menu
Interactions.ShowCardTypeMenu = function(targetServerId, targetName)
    local playerData = GetCurrentPlayerData()
    if not playerData then return end
    
    local authorizedCards = Interactions.GetAuthorizedCardTypes(playerData.job.name, playerData.job.grade)
    local options = {}
    
    for _, cardType in ipairs(authorizedCards) do
        local cardConfig = Config.CardTypes[cardType]
        if cardConfig then
            table.insert(options, {
                title = cardConfig.label,
                description = string.format('Issue %s card', cardConfig.label),
                icon = cardConfig.icon,
                iconColor = cardConfig.color,
                onSelect = function()
                    Interactions.ShowCardDataForm(targetServerId, targetName, cardType)
                end
            })
        end
    end
    
    if #options == 0 then
        lib.notify({
            title = 'ID Cards',
            description = lib.getLocale('error_not_authorized'),
            type = 'error'
        })
        return
    end
    
    lib.registerContext({
        id = 'jr_idcard_card_types',
        title = string.format('%s - %s', lib.getLocale('action_issue'), targetName),
        options = options
    })
    
    lib.showContext('jr_idcard_card_types')
end

-- Show card data input form
Interactions.ShowCardDataForm = function(targetServerId, targetName, cardType)
    local input = lib.inputDialog(lib.getLocale('action_issue'), {
        {
            type = 'input',
            label = lib.getLocale('form_first_name'),
            description = lib.getLocale('form_required_field'),
            required = true,
            min = 1,
            max = 50
        },
        {
            type = 'input',
            label = lib.getLocale('form_last_name'),
            description = lib.getLocale('form_required_field'),
            required = true,
            min = 1,
            max = 50
        },
        {
            type = 'date',
            label = lib.getLocale('form_date_of_birth'),
            required = true,
            default = '1990-01-01'
        },
        {
            type = 'select',
            label = lib.getLocale('form_gender'),
            required = true,
            options = {
                {value = 'M', label = lib.getLocale('gender_male')},
                {value = 'F', label = lib.getLocale('gender_female')},
                {value = 'O', label = lib.getLocale('gender_other')}
            }
        },
        {
            type = 'input',
            label = lib.getLocale('form_address'),
            description = 'Optional',
            required = false,
            max = 200
        },
        {
            type = 'input',
            label = lib.getLocale('form_photo'),
            description = 'Optional photo URL',
            required = false,
            max = 500
        }
    })
    
    if not input then return end
    
    local cardData = {
        firstName = input[1],
        lastName = input[2],
        dateOfBirth = input[3],
        gender = input[4],
        address = input[5] or '',
        photoHash = input[6] or ''
    }
    
    -- Get target player identifier
    TriggerServerEvent('jr_idcard:getPlayerIdentifier', targetServerId, function(identifier)
        if identifier then
            cardData.targetIdentifier = identifier
            TriggerServerEvent('jr_idcard:issueCard', identifier, cardType, cardData)
        else
            lib.notify({
                title = 'ID Cards',
                description = lib.getLocale('error_player_not_found'),
                type = 'error'
            })
        end
    end)
end

-- Open card verification menu
Interactions.OpenVerifyCardMenu = function()
    if not Interactions.CanVerifyCards() then
        lib.notify({
            title = 'ID Cards',
            description = lib.getLocale('error_not_authorized'),
            type = 'error'
        })
        return
    end
    
    local input = lib.inputDialog(lib.getLocale('action_verify'), {
        {
            type = 'input',
            label = lib.getLocale('card_id'),
            description = 'Enter card ID to verify',
            required = true,
            min = 1
        }
    })
    
    if not input or not input[1] then return end
    
    local cardId = input[1]
    TriggerServerEvent('jr_idcard:verifyCard', cardId)
end

-- Check if player can issue cards
Interactions.CanIssueCards = function()
    local playerData = GetCurrentPlayerData()
    if not playerData or not playerData.job then
        return false
    end
    
    local jobConfig = Config.AuthorizedJobs[playerData.job.name]
    if not jobConfig then
        return false
    end
    
    -- Check grade requirement
    if jobConfig.requireGrade and playerData.job.grade < jobConfig.requireGrade then
        return false
    end
    
    return jobConfig.canIssue and #jobConfig.canIssue > 0
end

-- Check if player can verify cards
Interactions.CanVerifyCards = function()
    local playerData = GetCurrentPlayerData()
    if not playerData or not playerData.job then
        return false
    end
    
    local jobConfig = Config.AuthorizedJobs[playerData.job.name]
    if not jobConfig then
        return false
    end
    
    return jobConfig.canVerify == true
end

-- Get authorized card types for player's job
Interactions.GetAuthorizedCardTypes = function(jobName, jobGrade)
    local jobConfig = Config.AuthorizedJobs[jobName]
    if not jobConfig then
        return {}
    end
    
    -- Check grade requirement
    if jobConfig.requireGrade and jobGrade < jobConfig.requireGrade then
        return {}
    end
    
    return jobConfig.canIssue or {}
end

-- Handle card show animation/effect
Interactions.ShowCardAnimation = function(cardData)
    isShowingCard = true
    
    -- Play card show animation
    local playerPed = PlayerPedId()
    
    -- Request animation dict
    RequestAnimDict('mp_common')
    while not HasAnimDictLoaded('mp_common') do
        Wait(0)
    end
    
    -- Play animation
    TaskPlayAnim(playerPed, 'mp_common', 'givetake1_a', 2.0, 2.0, 2000, 48, 0, false, false, false)
    
    -- Show card effect (optional)
    if Config.ShowHologram then
        CreateThread(function()
            Wait(500) -- Wait for animation to start
            
            -- Create hologram effect above player
            local coords = GetEntityCoords(playerPed)
            local cardEffect = StartParticleFxLoopedAtCoord('scr_ie_drive_shr', coords.x, coords.y, coords.z + 2.0, 0.0, 0.0, 0.0, 0.5, false, false, false)
            
            Wait(3000) -- Show for 3 seconds
            StopParticleFxLooped(cardEffect, false)
            
            isShowingCard = false
        end)
    else
        CreateThread(function()
            Wait(2000)
            isShowingCard = false
        end)
    end
end

-- Get current player data helper
function GetCurrentPlayerData()
    if Config.Framework == 'ESX' and ESX and ESX.GetPlayerData then
        return ESX.GetPlayerData()
    elseif Config.Framework == 'QBCore' and QBCore and QBCore.Functions.GetPlayerData then
        return QBCore.Functions.GetPlayerData()
    end
    return nil
end

-- Server Events
RegisterNetEvent('jr_idcard:showCardAnimation')
AddEventHandler('jr_idcard:showCardAnimation', function(cardData)
    Interactions.ShowCardAnimation(cardData)
end)

return Interactions