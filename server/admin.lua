-- Admin Commands and Tools for Jr_IDCard
-- Provides administrative functions and commands for managing the ID card system

local Database = exports[GetCurrentResourceName()]:Database()
local Audit = exports[GetCurrentResourceName()]:Audit()
local Cards = exports[GetCurrentResourceName()]:Cards()
local Admin = {}

-- Check if player is admin
local function IsAdmin(source)
    local playerData = nil
    
    if Config.Framework == 'ESX' and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            playerData = {
                group = xPlayer.getGroup(),
                identifier = xPlayer.identifier
            }
        end
    elseif Config.Framework == 'QBCore' and QBCore then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            playerData = {
                group = Player.PlayerData.metadata.group or 'user',
                identifier = Player.PlayerData.license
            }
        end
    end
    
    if not playerData then
        return false
    end
    
    for _, adminGroup in ipairs(Config.AdminGroups) do
        if playerData.group == adminGroup then
            return true, playerData
        end
    end
    
    return false, playerData
end

-- Admin command: Create test card
RegisterCommand('idcard_create', function(source, args, rawCommand)
    if not Config.AdminCommands then
        return
    end
    
    local isAdmin, adminData = IsAdmin(source)
    if not isAdmin then
        TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
        return
    end
    
    if #args < 3 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Usage: /idcard_create [player_id] [card_type] [first_name] [last_name]"}
        })
        return
    end
    
    local targetId = tonumber(args[1])
    local cardType = args[2]
    local firstName = args[3]
    local lastName = args[4] or 'Doe'
    
    -- Get target player data
    local targetData = nil
    if Config.Framework == 'ESX' and ESX then
        local xTarget = ESX.GetPlayerFromId(targetId)
        if xTarget then
            targetData = {
                identifier = xTarget.identifier,
                charid = xTarget.identifier
            }
        end
    elseif Config.Framework == 'QBCore' and QBCore then
        local Target = QBCore.Functions.GetPlayer(targetId)
        if Target then
            targetData = {
                identifier = Target.PlayerData.license,
                charid = Target.PlayerData.citizenid
            }
        end
    end
    
    if not targetData then
        TriggerClientEvent('jr_idcard:notify', source, 'admin_invalid_player', 'error')
        return
    end
    
    -- Validate card type
    if not Config.CardTypes[cardType] then
        TriggerClientEvent('jr_idcard:notify', source, 'admin_invalid_card_type', 'error')
        return
    end
    
    -- Check if player already has this card type
    Database.PlayerHasCardType(targetData.identifier, cardType, function(hasCard)
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
        local cardData = {
            owner_identifier = targetData.identifier,
            owner_charid = targetData.charid,
            type = cardType,
            expiry_date = expiryDate,
            issuer_job = 'admin',
            issuer_identifier = adminData.identifier,
            issuer_charid = adminData.identifier,
            metadata = {
                firstName = firstName,
                lastName = lastName,
                dateOfBirth = '1990-01-01',
                gender = 'M',
                address = 'Admin Created',
                photoHash = '',
                issuerName = 'System Administrator'
            }
        }
        
        -- Create the card
        Database.CreateCard(cardData, function(success, cardId)
            if success then
                TriggerClientEvent('jr_idcard:notify', source, 'admin_card_created', 'success', GetPlayerName(targetId))
                
                -- Log the creation
                Audit.LogIssue(cardId, cardType, targetData.identifier, adminData.identifier, adminData.identifier, 'admin')
                
                -- Add to inventory if enabled
                if Config.UseOxInventory then
                    Cards.AddCardToInventory(targetData.identifier, cardId, cardType)
                end
                
                if Config.Debug then
                    print(string.format('^2[Jr_IDCard]^7 Admin %s created %s card for %s', adminData.identifier, cardType, targetData.identifier))
                end
            else
                TriggerClientEvent('jr_idcard:notify', source, 'error_database', 'error')
            end
        end)
    end)
end)

-- Admin command: Renew card signature
RegisterCommand('idcard_renew_signature', function(source, args, rawCommand)
    if not Config.AdminCommands then
        return
    end
    
    local isAdmin, adminData = IsAdmin(source)
    if not isAdmin then
        TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
        return
    end
    
    if #args < 1 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Usage: /idcard_renew_signature [card_id]"}
        })
        return
    end
    
    local cardId = args[1]
    
    Database.GetCardById(cardId, function(card)
        if not card then
            TriggerClientEvent('jr_idcard:notify', source, 'error_card_not_found', 'error')
            return
        end
        
        -- Renew signature by updating the card (this regenerates signature)
        Database.RenewCard(cardId, card.expiry_date, adminData.identifier, function(success)
            if success then
                TriggerClientEvent('jr_idcard:notify', source, 'admin_signature_renewed', 'success')
                
                -- Log the renewal
                Audit.Log({
                    card_id = cardId,
                    action = 'renewed',
                    by_identifier = adminData.identifier,
                    by_charid = adminData.identifier,
                    to_identifier = card.owner_identifier,
                    notes = 'Signature renewed by admin'
                })
            else
                TriggerClientEvent('jr_idcard:notify', source, 'error_database', 'error')
            end
        end)
    end)
end)

-- Admin command: Clean up expired cards
RegisterCommand('idcard_cleanup', function(source, args, rawCommand)
    if not Config.AdminCommands then
        return
    end
    
    local isAdmin, adminData = IsAdmin(source)
    if not isAdmin then
        TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
        return
    end
    
    local daysOld = tonumber(args[1]) or 30
    
    if daysOld < 30 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Minimum cleanup period is 30 days"}
        })
        return
    end
    
    -- Clean up old audit logs
    Audit.CleanOldLogs(daysOld, function(success, count)
        if success then
            TriggerClientEvent('jr_idcard:notify', source, 'admin_cards_cleaned', 'success', count)
        else
            TriggerClientEvent('jr_idcard:notify', source, 'error_database', 'error')
        end
    end)
end)

-- Admin command: Get card statistics
RegisterCommand('idcard_stats', function(source, args, rawCommand)
    if not Config.AdminCommands then
        return
    end
    
    local isAdmin = IsAdmin(source)
    if not isAdmin then
        TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
        return
    end
    
    -- Get statistics
    Audit.GetStats(function(stats)
        if stats and #stats > 0 then
            local message = "^2ID Card Statistics (Last 30 Days):\n"
            local actionCounts = {}
            
            -- Aggregate statistics
            for _, stat in ipairs(stats) do
                if not actionCounts[stat.action] then
                    actionCounts[stat.action] = 0
                end
                actionCounts[stat.action] = actionCounts[stat.action] + stat.count
            end
            
            for action, count in pairs(actionCounts) do
                message = message .. string.format("^3%s: ^7%d\n", action:upper(), count)
            end
            
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = true,
                args = {"ID Card Stats", message}
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 255, 0},
                multiline = true,
                args = {"System", "No statistics available"}
            })
        end
    end)
end)

-- Admin command: Bulk revoke cards
RegisterCommand('idcard_bulk_revoke', function(source, args, rawCommand)
    if not Config.AdminCommands then
        return
    end
    
    local isAdmin, adminData = IsAdmin(source)
    if not isAdmin then
        TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
        return
    end
    
    if #args < 2 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Usage: /idcard_bulk_revoke [player_identifier] [reason]"}
        })
        return
    end
    
    local targetIdentifier = args[1]
    local reason = table.concat(args, ' ', 2)
    
    -- Get all player's cards
    Database.GetCardsByOwner(targetIdentifier, function(cards)
        if not cards or #cards == 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 255, 0},
                multiline = true,
                args = {"System", "No cards found for this player"}
            })
            return
        end
        
        local cardIds = {}
        for _, card in ipairs(cards) do
            if card.status == 'active' then
                table.insert(cardIds, card.id)
            end
        end
        
        if #cardIds == 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 255, 0},
                multiline = true,
                args = {"System", "No active cards found for this player"}
            })
            return
        end
        
        Cards.BulkRevoke(source, cardIds, reason)
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"System", string.format("Bulk revoked %d cards for %s", #cardIds, targetIdentifier)}
        })
    end)
end)

-- Admin command: Inspect card
RegisterCommand('idcard_inspect', function(source, args, rawCommand)
    if not Config.AdminCommands then
        return
    end
    
    local isAdmin = IsAdmin(source)
    if not isAdmin then
        TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
        return
    end
    
    if #args < 1 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Usage: /idcard_inspect [card_id]"}
        })
        return
    end
    
    local cardId = args[1]
    
    Database.GetCardById(cardId, function(card)
        if not card then
            TriggerClientEvent('jr_idcard:notify', source, 'error_card_not_found', 'error')
            return
        end
        
        local signatureValid = Database.VerifyCardSignature(card)
        local cardTypeConfig = Config.CardTypes[card.type] or {}
        
        local message = string.format([[
^2Card Inspection Report:
^3ID: ^7%s
^3Type: ^7%s (%s)
^3Owner: ^7%s
^3Status: ^7%s
^3Issue Date: ^7%s
^3Expiry Date: ^7%s
^3Issued By: ^7%s (%s)
^3Signature: ^7%s
^3Name: ^7%s %s
^3DOB: ^7%s
^3Gender: ^7%s
^3Address: ^7%s
        ]], 
        card.id,
        cardTypeConfig.label or card.type, card.type,
        card.owner_identifier,
        card.status,
        card.issue_date,
        card.expiry_date or 'Never',
        card.metadata.issuerName or 'Unknown', card.issuer_job or 'Unknown',
        signatureValid and '^2VALID' or '^1INVALID',
        card.metadata.firstName or 'Unknown',
        card.metadata.lastName or 'Unknown',
        card.metadata.dateOfBirth or 'Unknown',
        card.metadata.gender or 'Unknown',
        card.metadata.address or 'Not provided'
        )
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"Card Inspector", message}
        })
    end)
end)

-- Admin tool: Get player card history
RegisterCommand('idcard_history', function(source, args, rawCommand)
    if not Config.AdminCommands then
        return
    end
    
    local isAdmin = IsAdmin(source)
    if not isAdmin then
        TriggerClientEvent('jr_idcard:notify', source, 'error_not_authorized', 'error')
        return
    end
    
    if #args < 1 then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"System", "Usage: /idcard_history [player_identifier]"}
        })
        return
    end
    
    local identifier = args[1]
    
    Audit.GetPlayerHistory(identifier, function(history)
        if not history or #history == 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 255, 0},
                multiline = true,
                args = {"System", "No history found for this player"}
            })
            return
        end
        
        local message = string.format("^2Card History for %s (Last 10 entries):\n", identifier)
        local count = math.min(#history, 10)
        
        for i = 1, count do
            local entry = history[i]
            message = message .. string.format("^3%s: ^7%s (Card: %s)\n", 
                entry.formatted_timestamp,
                entry.action:upper(),
                entry.card_id:sub(1, 8) .. '...'
            )
        end
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"Card History", message}
        })
    end)
end)

-- Scheduled cleanup task
if Config.ServerCleanupInterval > 0 then
    CreateThread(function()
        while true do
            Wait(Config.ServerCleanupInterval)
            
            if Config.Debug then
                print('^3[Jr_IDCard]^7 Running scheduled cleanup...')
            end
            
            -- Clean up old audit logs (keep last 90 days)
            Audit.CleanOldLogs(90, function(success, count)
                if success and Config.Debug then
                    print(string.format('^2[Jr_IDCard]^7 Cleaned up %d old audit entries', count))
                end
            end)
        end
    end)
end

-- Export admin functions
Admin.IsAdmin = IsAdmin

return Admin