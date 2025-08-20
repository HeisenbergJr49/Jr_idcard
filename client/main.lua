-- Main Client Script for Jr_IDCard
-- Handles keybind registration, player state management, and core client logic

local ESX = nil
local QBCore = nil
local playerCards = {}
local nearbyPlayers = {}
local isNUIOpen = false
local lastCardShow = 0

-- Framework Detection and Initialization
local function InitializeFramework()
    if Config.Framework == 'ESX' then
        ESX = exports['es_extended']:getSharedObject()
        RegisterNetEvent('esx:playerLoaded')
        AddEventHandler('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
            RefreshPlayerCards()
        end)
    elseif Config.Framework == 'QBCore' then
        QBCore = exports['qb-core']:GetCoreObject()
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            RefreshPlayerCards()
        end)
    end
end

-- Get current player data
local function GetCurrentPlayerData()
    if ESX and ESX.GetPlayerData then
        return ESX.GetPlayerData()
    elseif QBCore and QBCore.Functions.GetPlayerData then
        return QBCore.Functions.GetPlayerData()
    end
    return nil
end

-- Check if player meets requirements for card actions
local function ValidatePlayerState()
    local playerPed = PlayerPedId()
    
    -- Check if player is alive
    if Config.RequireAlive and IsEntityDead(playerPed) then
        return false, 'error_not_alive'
    end
    
    -- Check if player is conscious (not incapacitated)
    if Config.RequireConscious then
        -- This would need to be framework-specific
        -- For now, just check if player is not ragdolled
        if IsPedRagdoll(playerPed) then
            return false, 'error_not_conscious'
        end
    end
    
    -- Check if player is restrained
    if Config.PreventRestrained then
        -- This would be framework-specific
        if IsPedCuffed(playerPed) then
            return false, 'error_restrained'
        end
    end
    
    return true, nil
end

-- Get nearby players within range
local function GetNearbyPlayers()
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
                    local playerName = GetPlayerName(playerId) or 'Unknown'
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

-- Refresh player's cards from server
function RefreshPlayerCards()
    TriggerServerEvent('jr_idcard:getPlayerCards')
end

-- Open/Close NUI
local function ToggleNUI()
    local isValid, errorKey = ValidatePlayerState()
    if not isValid then
        lib.notify({
            title = 'ID Cards',
            description = lib.getLocale(errorKey),
            type = 'error'
        })
        return
    end
    
    isNUIOpen = not isNUIOpen
    SetNuiFocus(isNUIOpen, isNUIOpen)
    
    if isNUIOpen then
        -- Get fresh data when opening
        nearbyPlayers = GetNearbyPlayers()
        SendNUIMessage({
            type = 'showUI',
            cards = playerCards,
            nearbyPlayers = nearbyPlayers,
            locales = lib.getLocales(),
            config = {
                showPhotos = Config.ShowPhotos,
                showQRCodes = Config.ShowQRCodes,
                showHologram = Config.ShowHologram,
                theme = Config.Theme
            }
        })
    else
        SendNUIMessage({
            type = 'hideUI'
        })
    end
end

-- Notification helper
local function ShowNotification(key, type, ...)
    local message = lib.getLocale(key, ...)
    
    if Config.NotifyType == 'ox_lib' then
        lib.notify({
            title = 'ID Cards',
            description = message,
            type = type,
            duration = Config.NotifyDuration
        })
    else
        -- Fallback to basic notification
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(false, false)
    end
end

-- Initialize client
CreateThread(function()
    InitializeFramework()
    
    -- Register keybind with lib or fallback
    if lib and lib.registerKeybind then
        lib.registerKeybind({
            name = 'jr_idcard_toggle',
            description = 'Open ID Card Management',
            defaultKey = Config.Keybind,
            onPressed = ToggleNUI
        })
    else
        -- Fallback to manual keybind detection
        CreateThread(function()
            local lastKeyPress = 0
            while true do
                Wait(0)
                
                if IsControlJustPressed(0, 166) then -- F5 key
                    local currentTime = GetGameTimer()
                    if currentTime - lastKeyPress > 500 then -- Prevent spam
                        ToggleNUI()
                        lastKeyPress = currentTime
                    end
                end
            end
        end)
    end
    
    -- Initial card refresh after a delay
    Wait(2000)
    RefreshPlayerCards()
    
    if Config.Debug then
        print('^2[Jr_IDCard]^7 Client initialized successfully')
    end
end)

-- Update nearby players periodically when NUI is open
CreateThread(function()
    while true do
        if isNUIOpen then
            nearbyPlayers = GetNearbyPlayers()
            SendNUIMessage({
                type = 'updateNearbyPlayers',
                nearbyPlayers = nearbyPlayers
            })
        end
        Wait(Config.ClientUpdateInterval)
    end
end)

-- Server Events
RegisterNetEvent('jr_idcard:receivePlayerCards')
AddEventHandler('jr_idcard:receivePlayerCards', function(cards)
    playerCards = cards
    
    -- Update NUI if open
    if isNUIOpen then
        SendNUIMessage({
            type = 'updateCards',
            cards = playerCards
        })
    end
end)

RegisterNetEvent('jr_idcard:receiveCard')
AddEventHandler('jr_idcard:receiveCard', function(cardData, senderName)
    -- Show card modal
    SendNUIMessage({
        type = 'showReceivedCard',
        card = cardData,
        senderName = senderName
    })
    
    -- Auto-accept or show confirmation based on config
    if Config.AutoAcceptDigital then
        ShowNotification('card_received', 'info', senderName)
    else
        -- Show confirmation dialog
        SendNUIMessage({
            type = 'showCardReceiveConfirmation',
            card = cardData,
            senderName = senderName
        })
    end
end)

RegisterNetEvent('jr_idcard:notify')
AddEventHandler('jr_idcard:notify', function(key, type, ...)
    ShowNotification(key, type, ...)
end)

RegisterNetEvent('jr_idcard:addToInventory')
AddEventHandler('jr_idcard:addToInventory', function(cardId, cardType)
    if Config.UseOxInventory then
        -- This would integrate with ox_inventory
        -- For now, just show notification
        local cardLabel = Config.CardTypes[cardType] and Config.CardTypes[cardType].label or 'ID Card'
        ShowNotification('card_added_to_inventory', 'success', cardLabel)
    end
end)

-- NUI Callbacks
RegisterNUICallback('closeUI', function(data, cb)
    isNUIOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('showCard', function(data, cb)
    local cardId = data.cardId
    local targetServerId = data.targetServerId
    
    -- Validate cooldown
    local currentTime = GetGameTimer()
    if currentTime - lastCardShow < Config.ShowCooldown then
        ShowNotification('error_on_cooldown', 'error')
        cb('error')
        return
    end
    
    -- Show card to target
    TriggerServerEvent('jr_idcard:showCard', cardId, targetServerId)
    lastCardShow = currentTime
    
    cb('ok')
end)

RegisterNUICallback('refreshCards', function(data, cb)
    RefreshPlayerCards()
    cb('ok')
end)

RegisterNUICallback('refreshNearbyPlayers', function(data, cb)
    nearbyPlayers = GetNearbyPlayers()
    cb(nearbyPlayers)
end)

RegisterNUICallback('issueCard', function(data, cb)
    TriggerServerEvent('jr_idcard:issueCard', data.targetIdentifier, data.cardType, data.cardData)
    cb('ok')
end)

RegisterNUICallback('renewCard', function(data, cb)
    TriggerServerEvent('jr_idcard:renewCard', data.cardId)
    cb('ok')
end)

RegisterNUICallback('updateCardStatus', function(data, cb)
    TriggerServerEvent('jr_idcard:updateCardStatus', data.cardId, data.status, data.reason)
    cb('ok')
end)

RegisterNUICallback('acceptCard', function(data, cb)
    ShowNotification('card_received', 'info', data.senderName)
    cb('ok')
end)

RegisterNUICallback('declineCard', function(data, cb)
    ShowNotification('card_declined', 'info')
    cb('ok')
end)

-- Exports for other resources
exports('GetPlayerCards', function()
    return playerCards
end)

exports('RefreshCards', function()
    RefreshPlayerCards()
end)

exports('OpenCardUI', function()
    if not isNUIOpen then
        ToggleNUI()
    end
end)

exports('CloseCardUI', function()
    if isNUIOpen then
        ToggleNUI()
    end
end)