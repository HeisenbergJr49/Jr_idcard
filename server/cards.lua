-- Card Management Server Functions
-- Specialized functions for card operations and management

local Database = exports[GetCurrentResourceName()]:Database()
local Audit = exports[GetCurrentResourceName()]:Audit()
local Cards = {}

-- Get framework player data helper
local function GetPlayerData(source)
    if Config.Framework == 'ESX' and ESX then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            return {
                identifier = xPlayer.identifier,
                charid = xPlayer.identifier,
                job = xPlayer.job.name,
                jobGrade = xPlayer.job.grade,
                firstName = xPlayer.get('firstName') or 'Unknown',
                lastName = xPlayer.get('lastName') or 'Unknown',
                dateOfBirth = xPlayer.get('dateofbirth') or '1990-01-01',
                sex = xPlayer.get('sex') or 'M'
            }
        end
    elseif Config.Framework == 'QBCore' and QBCore then
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

-- Create a new ID card with validation
Cards.CreateCard = function(issuerSource, targetIdentifier, cardType, cardData)
    local issuer = GetPlayerData(issuerSource)
    if not issuer then
        return false, 'Invalid issuer'
    end
    
    -- Validate card type
    local cardTypeConfig = Config.CardTypes[cardType]
    if not cardTypeConfig then
        return false, 'Invalid card type'
    end
    
    -- Check if target already has this card type
    local existingCard = Database.PlayerHasCardType(targetIdentifier, cardType)
    if existingCard then
        return false, 'Player already has this card type'
    end
    
    -- Calculate expiry date
    local expiryDate = nil
    if cardTypeConfig.expirable and cardTypeConfig.defaultExpiry then
        expiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + cardTypeConfig.defaultExpiry)
    end
    
    -- Prepare card data
    local newCardData = {
        owner_identifier = targetIdentifier,
        owner_charid = cardData.owner_charid or targetIdentifier,
        type = cardType,
        expiry_date = expiryDate,
        issuer_job = issuer.job,
        issuer_identifier = issuer.identifier,
        issuer_charid = issuer.charid,
        metadata = {
            firstName = cardData.firstName or 'Unknown',
            lastName = cardData.lastName or 'Unknown',
            dateOfBirth = cardData.dateOfBirth or '1990-01-01',
            gender = cardData.gender or 'M',
            address = cardData.address or '',
            photoHash = cardData.photoHash or '',
            issuerName = issuer.firstName .. ' ' .. issuer.lastName,
            issuerJob = issuer.job
        }
    }
    
    -- Create the card
    return Database.CreateCard(newCardData, function(success, cardId)
        if success then
            -- Log the issuance
            Audit.LogIssue(cardId, cardType, targetIdentifier, issuer.identifier, issuer.charid, issuer.job)
            
            -- Add to ox_inventory if enabled
            if Config.UseOxInventory then
                Cards.AddCardToInventory(targetIdentifier, cardId, cardType)
            end
            
            return true, cardId
        else
            return false, 'Database error'
        end
    end)
end

-- Renew an existing card
Cards.RenewCard = function(renewerSource, cardId)
    local renewer = GetPlayerData(renewerSource)
    if not renewer then
        return false, 'Invalid renewer'
    end
    
    -- Get card data
    Database.GetCardById(cardId, function(card)
        if not card then
            return false, 'Card not found'
        end
        
        -- Check authorization
        if not Cards.HasAuthorization(renewer, 'renew', card.type) then
            return false, 'Not authorized'
        end
        
        -- Calculate new expiry date
        local cardTypeConfig = Config.CardTypes[card.type]
        local newExpiryDate = nil
        if cardTypeConfig and cardTypeConfig.expirable and cardTypeConfig.defaultExpiry then
            newExpiryDate = os.date('%Y-%m-%d %H:%M:%S', os.time() + cardTypeConfig.defaultExpiry)
        end
        
        -- Renew the card
        Database.RenewCard(cardId, newExpiryDate, renewer.identifier, function(success)
            if success then
                Audit.LogRenew(cardId, card.owner_identifier, renewer.identifier, renewer.charid, newExpiryDate)
                return true, 'Card renewed successfully'
            else
                return false, 'Database error'
            end
        end)
    end)
end

-- Update card status (revoke, suspend, seize)
Cards.UpdateCardStatus = function(updaterSource, cardId, newStatus, reason)
    local updater = GetPlayerData(updaterSource)
    if not updater then
        return false, 'Invalid updater'
    end
    
    -- Validate new status
    local validStatuses = {'active', 'revoked', 'suspended', 'seized'}
    local isValid = false
    for _, status in ipairs(validStatuses) do
        if status == newStatus then
            isValid = true
            break
        end
    end
    
    if not isValid then
        return false, 'Invalid status'
    end
    
    -- Get card data
    Database.GetCardById(cardId, function(card)
        if not card then
            return false, 'Card not found'
        end
        
        -- Check authorization
        local action = newStatus == 'revoked' and 'revoke' or 
                      newStatus == 'suspended' and 'suspend' or
                      newStatus == 'seized' and 'seize' or 'update'
        
        if not Cards.HasAuthorization(updater, action, card.type) then
            return false, 'Not authorized'
        end
        
        local oldStatus = card.status
        
        -- Update the card
        Database.UpdateCardStatus(cardId, newStatus, updater.identifier, function(success)
            if success then
                Audit.LogStatusChange(cardId, card.owner_identifier, updater.identifier, updater.charid, oldStatus, newStatus, reason)
                return true, 'Card status updated'
            else
                return false, 'Database error'
            end
        end)
    end)
end

-- Check if player has authorization for action
Cards.HasAuthorization = function(playerData, action, cardType)
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

-- Verify card validity and signature
Cards.VerifyCard = function(verifierSource, cardId)
    local verifier = GetPlayerData(verifierSource)
    if not verifier then
        return false, 'Invalid verifier'
    end
    
    -- Check if verifier can verify cards
    if not Cards.HasAuthorization(verifier, 'verify', '') then
        return false, 'Not authorized to verify cards'
    end
    
    -- Get card data
    Database.GetCardById(cardId, function(card)
        if not card then
            return false, 'Card not found'
        end
        
        -- Check card status
        if card.status ~= 'active' then
            return false, 'Card is not active'
        end
        
        -- Check expiry
        if card.expiry_date then
            local expiryTime = os.time(os.date("*t", os.time(card.expiry_date)))
            if expiryTime < os.time() then
                return false, 'Card has expired'
            end
        end
        
        -- Verify signature
        local signatureValid = Database.VerifyCardSignature(card)
        
        -- Log verification
        local position = GetEntityCoords(GetPlayerPed(verifierSource))
        Audit.LogVerify(cardId, card.owner_identifier, verifier.identifier, verifier.charid, signatureValid, {
            x = position.x,
            y = position.y,
            z = position.z
        })
        
        if signatureValid then
            return true, 'Card is valid'
        else
            return false, 'Invalid card signature'
        end
    end)
end

-- Add card to ox_inventory
Cards.AddCardToInventory = function(identifier, cardId, cardType)
    if not Config.UseOxInventory then
        return
    end
    
    -- Find player source
    local targetSource = nil
    if Config.Framework == 'ESX' and ESX then
        local xTarget = ESX.GetPlayerFromIdentifier(identifier)
        if xTarget then targetSource = xTarget.source end
    elseif Config.Framework == 'QBCore' and QBCore then
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in pairs(players) do
            local player = QBCore.Functions.GetPlayer(playerId)
            if player and player.PlayerData.license == identifier then
                targetSource = playerId
                break
            end
        end
    end
    
    if not targetSource then
        return
    end
    
    -- Get card type config
    local cardTypeConfig = Config.CardTypes[cardType] or {}
    local cardLabel = cardTypeConfig.label or Config.CardItem.label
    
    -- Add item with metadata
    local metadata = {
        card_id = cardId,
        card_type = cardType,
        label = cardLabel,
        description = 'Official identification card'
    }
    
    exports.ox_inventory:AddItem(targetSource, Config.CardItem.name, 1, metadata)
end

-- Remove card from inventory
Cards.RemoveCardFromInventory = function(identifier, cardId)
    if not Config.UseOxInventory then
        return
    end
    
    -- Find player source
    local targetSource = nil
    if Config.Framework == 'ESX' and ESX then
        local xTarget = ESX.GetPlayerFromIdentifier(identifier)
        if xTarget then targetSource = xTarget.source end
    elseif Config.Framework == 'QBCore' and QBCore then
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in pairs(players) do
            local player = QBCore.Functions.GetPlayer(playerId)
            if player and player.PlayerData.license == identifier then
                targetSource = playerId
                break
            end
        end
    end
    
    if not targetSource then
        return
    end
    
    -- Find and remove the item
    local items = exports.ox_inventory:GetInventoryItems(targetSource)
    for slot, item in pairs(items) do
        if item.name == Config.CardItem.name and item.metadata and item.metadata.card_id == cardId then
            exports.ox_inventory:RemoveItem(targetSource, Config.CardItem.name, 1, item.metadata, slot)
            break
        end
    end
end

-- Get player's cards with enhanced data
Cards.GetPlayerCards = function(identifier, includeInactive)
    local cards = Database.GetCardsByOwner(identifier)
    
    if not includeInactive then
        -- Filter out inactive cards
        local activeCards = {}
        for _, card in ipairs(cards) do
            if card.status == 'active' then
                table.insert(activeCards, card)
            end
        end
        cards = activeCards
    end
    
    -- Enhance card data with type information
    for _, card in ipairs(cards) do
        local cardTypeConfig = Config.CardTypes[card.type]
        if cardTypeConfig then
            card.type_info = cardTypeConfig
        end
        
        -- Add expiry status
        if card.expiry_date then
            local expiryTime = os.time(os.date("*t", os.time(card.expiry_date)))
            local now = os.time()
            local daysUntilExpiry = math.floor((expiryTime - now) / 86400)
            
            card.days_until_expiry = daysUntilExpiry
            card.is_expired = daysUntilExpiry < 0
            card.expires_soon = daysUntilExpiry <= 7 and daysUntilExpiry >= 0
        end
    end
    
    return cards
end

-- Bulk operations for admin
Cards.BulkRevoke = function(adminSource, cardIds, reason)
    local admin = GetPlayerData(adminSource)
    if not admin then
        return false, 'Invalid admin'
    end
    
    -- Check if admin has permission
    local isAdmin = false
    for _, group in ipairs(Config.AdminGroups) do
        if admin.group == group then
            isAdmin = true
            break
        end
    end
    
    if not isAdmin then
        return false, 'Not authorized'
    end
    
    local success = 0
    local failed = 0
    
    for _, cardId in ipairs(cardIds) do
        Database.UpdateCardStatus(cardId, 'revoked', admin.identifier, function(result)
            if result then
                success = success + 1
                
                -- Log the action
                Database.GetCardById(cardId, function(card)
                    if card then
                        Audit.LogStatusChange(cardId, card.owner_identifier, admin.identifier, admin.charid, card.status, 'revoked', reason)
                    end
                end)
            else
                failed = failed + 1
            end
        end)
    end
    
    return true, string.format('Revoked %d cards, %d failed', success, failed)
end

-- Get cards expiring soon (for notifications)
Cards.GetExpiringCards = function(daysAhead)
    return Database.GetExpiringCards(daysAhead or 7)
end

-- Export card functions
return Cards