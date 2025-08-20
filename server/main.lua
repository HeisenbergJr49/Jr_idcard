-- Main Server Script for Jr_IDCard
-- Handles framework initialization, events, and core server logic

local ESX = nil
local QBCore = nil

-- Initialize modules
local Database = nil
local Audit = nil

-- Framework Detection and Initialization
local function InitializeFramework()
    if Config.Framework == 'ESX' then
        ESX = exports['es_extended']:getSharedObject()
        if Config.Debug then
            print('^2[Jr_IDCard]^7 ESX Framework detected and loaded')
        end
    elseif Config.Framework == 'QBCore' then
        QBCore = exports['qb-core']:GetCoreObject()
        if Config.Debug then
            print('^2[Jr_IDCard]^7 QBCore Framework detected and loaded')
        end
    else
        print('^1[Jr_IDCard]^7 No supported framework detected!')
    end
end

-- Get player data based on framework
local function GetPlayerData(source)
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            return {
                identifier = xPlayer.identifier,
                charid = xPlayer.identifier, -- ESX uses identifier as character ID
                job = xPlayer.job.name,
                jobGrade = xPlayer.job.grade,
                firstName = xPlayer.get('firstName') or 'Unknown',
                lastName = xPlayer.get('lastName') or 'Unknown',
                dateOfBirth = xPlayer.get('dateofbirth') or '1990-01-01',
                sex = xPlayer.get('sex') or 'M'
            }
        end
    elseif QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            return {
                identifier = Player.PlayerData.license,
                charid = Player.PlayerData.citizenid,
                job = Player.PlayerData.job.name,
                jobGrade = Player.PlayerData.job.grade.level,
                firstName = Player.PlayerData.charinfo.firstname,
                lastName = Player.PlayerData.charinfo.lastname,
                dateOfBirth = Player.PlayerData.charinfo.birthdate,
                sex = Player.PlayerData.charinfo.gender == 0 and 'M' or 'F'
            }
        end
    end
    return nil
end

-- Check if player has authorization for action
local function HasAuthorization(playerData, action, cardType)
    if not playerData or not playerData.job then
        return false
    end
    
    local jobConfig = Config.AuthorizedJobs[playerData.job]
    if not jobConfig then
        return false
    end
    
    -- Check grade requirement
    if jobConfig.requireGrade and playerData.jobGrade < jobConfig.requireGrade then
        return false
    end
    
    -- Check specific action authorization
    if action == 'verify' then
        return jobConfig.canVerify == true
    end
    
    local actionKey = 'can' .. action:sub(1,1):upper() .. action:sub(2)
    local authorizedTypes = jobConfig[actionKey]
    
    if not authorizedTypes then
        return false
    end
    
    -- Check if authorized for this card type
    for _, authorizedType in ipairs(authorizedTypes) do
        if authorizedType == cardType then
            return true
        end
    end
    
    return false
end

-- Validate player distance and line of sight
local function ValidatePlayerInteraction(source, targetSource)
    if not Config.ValidateDistance and not Config.ValidateLineOfSight then
        return true, nil
    end
    
    local sourceCoords = GetEntityCoords(GetPlayerPed(source))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetSource))
    
    if Config.ValidateDistance then
        local distance = #(sourceCoords - targetCoords)
        if distance > Config.ShowRange then
            return false, 'error_too_far'
        end
    end
    
    -- Line of sight validation would require raycast - simplified for now
    if Config.ValidateLineOfSight then
        -- This is a simplified check - in production you'd use raycasting
        local distance = #(sourceCoords - targetCoords)
        if distance > Config.ShowRange then
            return false, 'error_no_line_of_sight'
        end
    end
    
    return true, nil
end

-- Player cooldown management
local playerCooldowns = {}

local function IsOnCooldown(source)
    local currentTime = GetGameTimer()
    local lastAction = playerCooldowns[source]
    
    if lastAction and (currentTime - lastAction) < Config.ShowCooldown then
        return true
    end
    
    return false
end

local function SetCooldown(source)
    playerCooldowns[source] = GetGameTimer()
end

-- Initialize system
CreateThread(function()
    InitializeFramework()
    
    -- Load modules after framework initialization
    Database = LoadResourceFile(GetCurrentResourceName(), 'server/database.lua')
    if Database then
        Database = load(Database)()
        Database.Init()
    end
    
    Audit = LoadResourceFile(GetCurrentResourceName(), 'server/audit.lua')
    if Audit then
        Audit = load(Audit)()
    end
    
    if Config.Debug then
        print('^2[Jr_IDCard]^7 System initialized successfully')
    end
end)

-- Event: Get player's cards
RegisterServerEvent('jr_idcard:getPlayerCards')
AddEventHandler('jr_idcard:getPlayerCards', function()
    local source = source
    local playerData = GetPlayerData(source)
    
    if not playerData then
        TriggerClientEvent('jr_idcard:notify', source, 'error_player_not_found', 'error')
        return
    end
    
    Database.GetCardsByOwner(playerData.identifier, function(cards)
        TriggerClientEvent('jr_idcard:receivePlayerCards', source, cards)
    end)
end)

-- Event: Show card to nearby player
RegisterServerEvent('jr_idcard:showCard')
AddEventHandler('jr_idcard:showCard', function(cardId, targetServerId)
    local source = source
    local playerData = GetPlayerData(source)
    
    if not playerData then
        TriggerClientEvent('jr_idcard:notify', source, 'error_player_not_found', 'error')
        return
    end
    
    -- Check cooldown
    if IsOnCooldown(source) then
        TriggerClientEvent('jr_idcard:notify', source, 'error_on_cooldown', 'error')
        return
    end
    
    -- Validate target player
    local targetData = GetPlayerData(targetServerId)
    if not targetData then
        TriggerClientEvent('jr_idcard:notify', source, 'error_player_not_found', 'error')
        return
    end
    
    -- Validate distance and line of sight
    local isValid, errorKey = ValidatePlayerInteraction(source, targetServerId)
    if not isValid then
        TriggerClientEvent('jr_idcard:notify', source, errorKey, 'error')
        return
    end
    
    -- Get card data
    Database.GetCardById(cardId, function(card)
        if not card then
            TriggerClientEvent('jr_idcard:notify', source, 'error_card_not_found', 'error')
            return
        end
        
        -- Verify ownership
        if Config.ValidateOwnership and card.owner_identifier ~= playerData.identifier then
            TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
            return
        end
        
        -- Check card status
        if card.status ~= 'active' then
            local errorKey = 'error_card_' .. card.status
            TriggerClientEvent('jr_idcard:notify', source, errorKey, 'error')
            return
        end
        
        -- Verify signature
        if not Database.VerifyCardSignature(card) then
            TriggerClientEvent('jr_idcard:notify', source, 'error_invalid_signature', 'error')
            return
        end
        
        -- Send card to target player
        TriggerClientEvent('jr_idcard:receiveCard', targetServerId, card, playerData.firstName .. ' ' .. playerData.lastName)
        
        -- Notify sender
        TriggerClientEvent('jr_idcard:notify', source, 'card_shown_success', 'success', targetData.firstName .. ' ' .. targetData.lastName)
        
        -- Log the action
        local position = GetEntityCoords(GetPlayerPed(source))
        Audit.LogShow(cardId, playerData.identifier, targetData.identifier, targetData.charid, {
            x = position.x,
            y = position.y,
            z = position.z
        })
        
        -- Set cooldown
        SetCooldown(source)
    end)
end)

-- Event: Issue new card
RegisterServerEvent('jr_idcard:issueCard')
AddEventHandler('jr_idcard:issueCard', function(targetIdentifier, cardType, cardData)
    local source = source
    local issuerData = GetPlayerData(source)
    
    if not issuerData then
        TriggerClientEvent('jr_idcard:notify', source, 'error_player_not_found', 'error')
        return
    end
    
    -- Check authorization
    if not HasAuthorization(issuerData, 'issue', cardType) then
        TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
        return
    end
    
    -- Check if player already has this card type
    Database.PlayerHasCardType(targetIdentifier, cardType, function(hasCard)
        if hasCard then
            TriggerClientEvent('jr_idcard:notify', source, 'error_already_has_card', 'error')
            return
        end
        
        -- Calculate expiry date
        local expiryDate = nil
        local cardTypeConfig = Config.CardTypes[cardType]
        if cardTypeConfig and cardTypeConfig.expirable and cardTypeConfig.defaultExpiry then
            expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + cardTypeConfig.defaultExpiry)
        end
        
        -- Create card data
        local newCardData = {
            owner_identifier = targetIdentifier,
            owner_charid = cardData.owner_charid or targetIdentifier,
            type = cardType,
            expiry_date = expiryDate,
            issuer_job = issuerData.job,
            issuer_identifier = issuerData.identifier,
            issuer_charid = issuerData.charid,
            metadata = {
                firstName = cardData.firstName,
                lastName = cardData.lastName,
                dateOfBirth = cardData.dateOfBirth,
                gender = cardData.gender,
                address = cardData.address or '',
                photoHash = cardData.photoHash or '',
                issuerName = issuerData.firstName .. ' ' .. issuerData.lastName
            }
        }
        
        -- Create the card
        Database.CreateCard(newCardData, function(success, cardId)
            if success then
                TriggerClientEvent('jr_idcard:notify', source, 'card_issued_success', 'success')
                
                -- Log the issuance
                Audit.LogIssue(cardId, cardType, targetIdentifier, issuerData.identifier, issuerData.charid, issuerData.job)
                
                -- Add to inventory if using ox_inventory
                if Config.UseOxInventory then
                    local targetSource = nil
                    if ESX then
                        local xTarget = ESX.GetPlayerFromIdentifier(targetIdentifier)
                        if xTarget then targetSource = xTarget.source end
                    elseif QBCore then
                        local players = QBCore.Functions.GetPlayers()
                        for _, playerId in pairs(players) do
                            local player = QBCore.Functions.GetPlayer(playerId)
                            if player and player.PlayerData.license == targetIdentifier then
                                targetSource = playerId
                                break
                            end
                        end
                    end
                    
                    if targetSource then
                        TriggerClientEvent('jr_idcard:addToInventory', targetSource, cardId, cardType)
                    end
                end
            else
                TriggerClientEvent('jr_idcard:notify', source, 'error_database', 'error')
            end
        end)
    end)
end)

-- Event: Renew card
RegisterServerEvent('jr_idcard:renewCard')
AddEventHandler('jr_idcard:renewCard', function(cardId)
    local source = source
    local issuerData = GetPlayerData(source)
    
    if not issuerData then
        TriggerClientEvent('jr_idcard:notify', source, 'error_player_not_found', 'error')
        return
    end
    
    Database.GetCardById(cardId, function(card)
        if not card then
            TriggerClientEvent('jr_idcard:notify', source, 'error_card_not_found', 'error')
            return
        end
        
        -- Check authorization
        if not HasAuthorization(issuerData, 'renew', card.type) then
            TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
            return
        end
        
        -- Calculate new expiry date
        local newExpiryDate = nil
        local cardTypeConfig = Config.CardTypes[card.type]
        if cardTypeConfig and cardTypeConfig.expirable and cardTypeConfig.defaultExpiry then
            newExpiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + cardTypeConfig.defaultExpiry)
        end
        
        Database.RenewCard(cardId, newExpiryDate, issuerData.identifier, function(success)
            if success then
                TriggerClientEvent('jr_idcard:notify', source, 'card_renewed_success', 'success')
                Audit.LogRenew(cardId, card.owner_identifier, issuerData.identifier, issuerData.charid, newExpiryDate)
            else
                TriggerClientEvent('jr_idcard:notify', source, 'error_database', 'error')
            end
        end)
    end)
end)

-- Event: Update card status (revoke, suspend, seize)
RegisterServerEvent('jr_idcard:updateCardStatus')
AddEventHandler('jr_idcard:updateCardStatus', function(cardId, newStatus, reason)
    local source = source
    local issuerData = GetPlayerData(source)
    
    if not issuerData then
        TriggerClientEvent('jr_idcard:notify', source, 'error_player_not_found', 'error')
        return
    end
    
    Database.GetCardById(cardId, function(card)
        if not card then
            TriggerClientEvent('jr_idcard:notify', source, 'error_card_not_found', 'error')
            return
        end
        
        -- Check authorization based on new status
        local action = newStatus == 'revoked' and 'revoke' or 
                      newStatus == 'suspended' and 'suspend' or
                      newStatus == 'seized' and 'seize' or 'update'
        
        if not HasAuthorization(issuerData, action, card.type) then
            TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
            return
        end
        
        local oldStatus = card.status
        
        Database.UpdateCardStatus(cardId, newStatus, issuerData.identifier, function(success)
            if success then
                local successKey = 'card_' .. newStatus .. '_success'
                TriggerClientEvent('jr_idcard:notify', source, successKey, 'success')
                Audit.LogStatusChange(cardId, card.owner_identifier, issuerData.identifier, issuerData.charid, oldStatus, newStatus, reason)
            else
                TriggerClientEvent('jr_idcard:notify', source, 'error_database', 'error')
            end
        end)
    end)
end)

-- Export functions for other resources
exports('GetPlayerCards', function(identifier)
    if Database then
        return Database.GetCardsByOwner(identifier)
    end
    return {}
end)

exports('GetCardById', function(cardId)
    if Database then
        return Database.GetCardById(cardId)
    end
    return nil
end)

exports('HasValidCard', function(identifier, cardType)
    if Database then
        return Database.PlayerHasCardType(identifier, cardType)
    end
    return false
end)

exports('VerifyCard', function(card)
    if Database then
        return Database.VerifyCardSignature(card)
    end
    return false
end)

-- Module exports for internal use
exports('Database', function()
    return Database
end)

exports('Audit', function()
    return Audit
end)