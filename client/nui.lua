-- NUI Communication Handler for Jr_IDCard Client
-- Manages all communication between the game client and the NUI interface

local NUI = {}
local nuiReady = false
local nuiVisible = false

-- Initialize NUI communication
NUI.Init = function()
    -- Wait for NUI to be ready
    CreateThread(function()
        while not nuiReady do
            Wait(100)
        end
        
        if Config.Debug then
            print('^2[Jr_IDCard]^7 NUI communication initialized')
        end
    end)
end

-- Send message to NUI
NUI.SendMessage = function(data)
    if not nuiReady then
        if Config.Debug then
            print('^1[Jr_IDCard]^7 NUI not ready, message dropped')
        end
        return false
    end
    
    SendNUIMessage(data)
    return true
end

-- Show the main UI
NUI.ShowUI = function(cards, nearbyPlayers, config)
    local locales = {}
    
    -- Get all locales for current language
    if Locales and Locales[Config.Locale or 'en'] then
        locales = Locales[Config.Locale or 'en']
    end
    
    local data = {
        type = 'showUI',
        cards = cards or {},
        nearbyPlayers = nearbyPlayers or {},
        locales = locales,
        config = config or {}
    }
    
    nuiVisible = true
    SetNuiFocus(true, true)
    return NUI.SendMessage(data)
end

-- Hide the UI
NUI.HideUI = function()
    nuiVisible = false
    SetNuiFocus(false, false)
    return NUI.SendMessage({
        type = 'hideUI'
    })
end

-- Update cards display
NUI.UpdateCards = function(cards)
    return NUI.SendMessage({
        type = 'updateCards',
        cards = cards or {}
    })
end

-- Update nearby players
NUI.UpdateNearbyPlayers = function(players)
    return NUI.SendMessage({
        type = 'updateNearbyPlayers',
        nearbyPlayers = players or {}
    })
end

-- Show received card
NUI.ShowReceivedCard = function(card, senderName, requireConfirmation)
    local data = {
        type = requireConfirmation and 'showCardReceiveConfirmation' or 'showReceivedCard',
        card = card,
        senderName = senderName
    }
    
    return NUI.SendMessage(data)
end

-- Show loading state
NUI.ShowLoading = function(show)
    return NUI.SendMessage({
        type = 'showLoading',
        visible = show == true
    })
end

-- Show notification in NUI
NUI.ShowNotification = function(title, message, type, duration)
    return NUI.SendMessage({
        type = 'showNotification',
        notification = {
            title = title,
            message = message,
            type = type or 'info',
            duration = duration or 5000
        }
    })
end

-- Check if NUI is visible
NUI.IsVisible = function()
    return nuiVisible
end

-- Toggle UI visibility
NUI.Toggle = function(cards, nearbyPlayers, config)
    if nuiVisible then
        return NUI.HideUI()
    else
        return NUI.ShowUI(cards, nearbyPlayers, config)
    end
end

-- Handle NUI ready event
RegisterNUICallback('nuiReady', function(data, cb)
    nuiReady = true
    cb('ok')
end)

-- Handle close UI callback
RegisterNUICallback('closeUI', function(data, cb)
    nuiVisible = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Handle show card callback
RegisterNUICallback('showCard', function(data, cb)
    TriggerServerEvent('jr_idcard:showCard', data.cardId, data.targetServerId)
    cb('ok')
end)

-- Handle refresh cards callback
RegisterNUICallback('refreshCards', function(data, cb)
    TriggerServerEvent('jr_idcard:getPlayerCards')
    cb('ok')
end)

-- Handle refresh nearby players callback
RegisterNUICallback('refreshNearbyPlayers', function(data, cb)
    -- Get updated nearby players list
    local nearbyPlayers = GetNearbyPlayers()
    cb(nearbyPlayers)
end)

-- Handle card acceptance/decline
RegisterNUICallback('acceptCard', function(data, cb)
    lib.notify({
        title = 'ID Cards',
        description = lib.getLocale('card_received', data.senderName),
        type = 'success'
    })
    cb('ok')
end)

RegisterNUICallback('declineCard', function(data, cb)
    lib.notify({
        title = 'ID Cards',
        description = lib.getLocale('card_declined'),
        type = 'info'
    })
    cb('ok')
end)

-- Handle issue card callback (for authorized personnel)
RegisterNUICallback('issueCard', function(data, cb)
    TriggerServerEvent('jr_idcard:issueCard', data.targetIdentifier, data.cardType, data.cardData)
    cb('ok')
end)

-- Handle renew card callback
RegisterNUICallback('renewCard', function(data, cb)
    TriggerServerEvent('jr_idcard:renewCard', data.cardId)
    cb('ok')
end)

-- Handle update card status callback
RegisterNUICallback('updateCardStatus', function(data, cb)
    TriggerServerEvent('jr_idcard:updateCardStatus', data.cardId, data.status, data.reason)
    cb('ok')
end)

-- Handle verify card callback
RegisterNUICallback('verifyCard', function(data, cb)
    TriggerServerEvent('jr_idcard:verifyCard', data.cardId)
    cb('ok')
end)

-- Get nearby players helper function
function GetNearbyPlayers()
    local players = {}
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)
            
            if distance <= Config.ShowRange then
                local hasLineOfSight = true
                
                -- Line of sight check if enabled
                if Config.RequireLineOfSight then
                    local hit, _, _, _, _ = GetShapeTestResult(StartShapeTestRay(
                        playerCoords.x, playerCoords.y, playerCoords.z + 1.0,
                        targetCoords.x, targetCoords.y, targetCoords.z + 1.0,
                        -1, playerPed, 0
                    ))
                    hasLineOfSight = hit == 0
                end
                
                if hasLineOfSight then
                    local playerName = GetPlayerName(playerId) or ('Player ' .. GetPlayerServerId(playerId))
                    table.insert(players, {
                        serverId = GetPlayerServerId(playerId),
                        name = playerName,
                        distance = distance
                    })
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(players, function(a, b) return a.distance < b.distance end)
    
    return players
end

return NUI