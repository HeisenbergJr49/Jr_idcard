-- Inventory Integration for Jr_IDCard Client
-- Handles ox_inventory integration and card item management

local Inventory = {}
local cardItems = {}

-- Initialize inventory integration
Inventory.Init = function()
    if Config.UseOxInventory then
        Inventory.RegisterCardItem()
        Inventory.SetupItemHandlers()
    end
    
    if Config.Debug then
        print('^2[Jr_IDCard]^7 Inventory integration initialized')
    end
end

-- Register the ID card item with ox_inventory
Inventory.RegisterCardItem = function()
    if not exports.ox_inventory then
        if Config.Debug then
            print('^1[Jr_IDCard]^7 ox_inventory not available')
        end
        return
    end
    
    -- Register the base card item
    exports.ox_inventory:registerItem(Config.CardItem.name, {
        label = Config.CardItem.label,
        weight = Config.CardItem.weight,
        stack = Config.CardItem.stack,
        close = Config.CardItem.close,
        description = 'Official identification card - Right click to view details',
        client = {
            image = 'id_card.png' -- Should be placed in ox_inventory/web/images/
        }
    })
    
    if Config.Debug then
        print('^2[Jr_IDCard]^7 ID card item registered with ox_inventory')
    end
end

-- Setup item use handlers
Inventory.SetupItemHandlers = function()
    -- Handle card item usage
    exports.ox_inventory:registerItem(Config.CardItem.name, {
        use = function(data, slot)
            Inventory.UseCardItem(data, slot)
        end,
        canUse = function(data, slot)
            return Inventory.CanUseCard(data, slot)
        end
    })
    
    -- Context menu for card items
    exports.ox_inventory:registerContextMenu(Config.CardItem.name, {
        {
            label = lib.getLocale('action_view'),
            icon = 'eye',
            action = function(data, slot)
                Inventory.ViewCardDetails(data, slot)
            end
        },
        {
            label = lib.getLocale('action_show'),
            icon = 'share',
            action = function(data, slot)
                Inventory.ShowCardToNearby(data, slot)
            end,
            canInteract = function(data, slot)
                return Inventory.CanShowCard(data, slot)
            end
        },
        {
            label = lib.getLocale('action_verify'),
            icon = 'shield-check',
            action = function(data, slot)
                Inventory.VerifyCard(data, slot)
            end,
            canInteract = function(data, slot)
                local playerData = GetCurrentPlayerData()
                return playerData and Inventory.CanVerifyCards(playerData)
            end
        }
    })
end

-- Use card item (double-click or use key)
Inventory.UseCardItem = function(data, slot)
    if not data.metadata or not data.metadata.card_id then
        lib.notify({
            title = 'ID Cards',
            description = lib.getLocale('error_invalid_card'),
            type = 'error'
        })
        return
    end
    
    -- Show card details by default
    Inventory.ViewCardDetails(data, slot)
end

-- Check if card can be used
Inventory.CanUseCard = function(data, slot)
    if not data.metadata or not data.metadata.card_id then
        return false
    end
    
    -- Check if player is in valid state
    local isValid, _ = ValidatePlayerState()
    return isValid
end

-- View card details
Inventory.ViewCardDetails = function(data, slot)
    if not data.metadata or not data.metadata.card_id then
        return
    end
    
    local cardId = data.metadata.card_id
    
    -- Request card details from server
    TriggerServerEvent('jr_idcard:getCardDetails', cardId, function(card)
        if card then
            -- Show card detail modal
            SendNUIMessage({
                type = 'showCardModal',
                card = card,
                source = 'inventory'
            })
            SetNuiFocus(true, true)
        else
            lib.notify({
                title = 'ID Cards',
                description = lib.getLocale('error_card_not_found'),
                type = 'error'
            })
        end
    end)
end

-- Show card to nearby players
Inventory.ShowCardToNearby = function(data, slot)
    if not data.metadata or not data.metadata.card_id then
        return
    end
    
    local cardId = data.metadata.card_id
    local nearbyPlayers = GetNearbyPlayers()
    
    if #nearbyPlayers == 0 then
        lib.notify({
            title = 'ID Cards',
            description = lib.getLocale('no_nearby_players'),
            type = 'error'
        })
        return
    end
    
    -- Show player selection
    local options = {}
    for _, player in ipairs(nearbyPlayers) do
        table.insert(options, {
            title = player.name,
            description = string.format('Distance: %.1fm', player.distance),
            icon = 'user',
            onSelect = function()
                TriggerServerEvent('jr_idcard:showCard', cardId, player.serverId)
            end
        })
    end
    
    lib.registerContext({
        id = 'jr_idcard_show_to_player',
        title = lib.getLocale('select_player'),
        options = options
    })
    
    lib.showContext('jr_idcard_show_to_player')
end

-- Check if card can be shown
Inventory.CanShowCard = function(data, slot)
    if not data.metadata or not data.metadata.card_id then
        return false
    end
    
    -- Check player state and cooldown
    local isValid, _ = ValidatePlayerState()
    if not isValid then
        return false
    end
    
    -- Check cooldown
    local currentTime = GetGameTimer()
    local lastShow = cardItems[data.metadata.card_id] or 0
    return (currentTime - lastShow) >= Config.ShowCooldown
end

-- Verify card
Inventory.VerifyCard = function(data, slot)
    if not data.metadata or not data.metadata.card_id then
        return
    end
    
    local cardId = data.metadata.card_id
    TriggerServerEvent('jr_idcard:verifyCard', cardId)
end

-- Check if player can verify cards
Inventory.CanVerifyCards = function(playerData)
    if not playerData or not playerData.job then
        return false
    end
    
    local jobConfig = Config.AuthorizedJobs[playerData.job.name]
    if not jobConfig then
        return false
    end
    
    return jobConfig.canVerify == true
end

-- Add card to inventory
Inventory.AddCard = function(cardId, cardType, metadata)
    if not Config.UseOxInventory or not exports.ox_inventory then
        return false
    end
    
    local cardConfig = Config.CardTypes[cardType] or {}
    local itemMetadata = {
        card_id = cardId,
        card_type = cardType,
        label = cardConfig.label or Config.CardItem.label,
        description = string.format('%s - %s %s', 
            cardConfig.label or 'ID Card',
            metadata.firstName or 'Unknown',
            metadata.lastName or 'Unknown'
        ),
        firstName = metadata.firstName,
        lastName = metadata.lastName,
        dateOfBirth = metadata.dateOfBirth,
        issueDate = metadata.issueDate,
        expiryDate = metadata.expiryDate
    }
    
    return exports.ox_inventory:AddItem(PlayerId(), Config.CardItem.name, 1, itemMetadata)
end

-- Remove card from inventory
Inventory.RemoveCard = function(cardId)
    if not Config.UseOxInventory or not exports.ox_inventory then
        return false
    end
    
    -- Find the card item
    local items = exports.ox_inventory:GetInventoryItems(PlayerId())
    for slot, item in pairs(items) do
        if item.name == Config.CardItem.name and item.metadata and item.metadata.card_id == cardId then
            return exports.ox_inventory:RemoveItem(PlayerId(), Config.CardItem.name, 1, item.metadata, slot)
        end
    end
    
    return false
end

-- Update card metadata in inventory
Inventory.UpdateCardMetadata = function(cardId, newMetadata)
    if not Config.UseOxInventory or not exports.ox_inventory then
        return false
    end
    
    -- Find and update the card item
    local items = exports.ox_inventory:GetInventoryItems(PlayerId())
    for slot, item in pairs(items) do
        if item.name == Config.CardItem.name and item.metadata and item.metadata.card_id == cardId then
            -- Merge metadata
            for key, value in pairs(newMetadata) do
                item.metadata[key] = value
            end
            
            return exports.ox_inventory:SetItemMetadata(PlayerId(), slot, item.metadata)
        end
    end
    
    return false
end

-- Get card items from inventory
Inventory.GetCardItems = function()
    if not Config.UseOxInventory or not exports.ox_inventory then
        return {}
    end
    
    local items = exports.ox_inventory:GetInventoryItems(PlayerId())
    local cardItems = {}
    
    for _, item in pairs(items) do
        if item.name == Config.CardItem.name and item.metadata and item.metadata.card_id then
            table.insert(cardItems, item)
        end
    end
    
    return cardItems
end

-- Handle card item drop (prevent if configured)
AddEventHandler('ox_inventory:itemDropped', function(item, coords)
    if item.name == Config.CardItem.name then
        -- Prevent card dropping (return to inventory)
        lib.notify({
            title = 'ID Cards',
            description = 'ID cards cannot be dropped',
            type = 'error'
        })
        
        -- Add back to inventory
        CreateThread(function()
            Wait(100)
            exports.ox_inventory:AddItem(PlayerId(), item.name, item.count, item.metadata)
        end)
    end
end)

-- Handle card item give (prevent if configured)
AddEventHandler('ox_inventory:itemGiven', function(fromPlayer, toPlayer, item)
    if item.name == Config.CardItem.name then
        -- Prevent card trading
        lib.notify({
            title = 'ID Cards',
            description = 'ID cards cannot be given to other players',
            type = 'error'
        })
        
        -- Return to giver
        TriggerServerEvent('jr_idcard:returnCardItem', item)
    end
end)

-- Server Events
RegisterNetEvent('jr_idcard:addCardToInventory')
AddEventHandler('jr_idcard:addCardToInventory', function(cardId, cardType, metadata)
    Inventory.AddCard(cardId, cardType, metadata)
end)

RegisterNetEvent('jr_idcard:removeCardFromInventory')
AddEventHandler('jr_idcard:removeCardFromInventory', function(cardId)
    Inventory.RemoveCard(cardId)
end)

RegisterNetEvent('jr_idcard:updateCardInInventory')
AddEventHandler('jr_idcard:updateCardInInventory', function(cardId, metadata)
    Inventory.UpdateCardMetadata(cardId, metadata)
end)

-- Helper functions
function GetCurrentPlayerData()
    if Config.Framework == 'ESX' and ESX and ESX.GetPlayerData then
        return ESX.GetPlayerData()
    elseif Config.Framework == 'QBCore' and QBCore and QBCore.Functions.GetPlayerData then
        return QBCore.Functions.GetPlayerData()
    end
    return nil
end

function ValidatePlayerState()
    local playerPed = PlayerPedId()
    
    -- Check if player is alive
    if Config.RequireAlive and IsEntityDead(playerPed) then
        return false, 'error_not_alive'
    end
    
    -- Check if player is conscious
    if Config.RequireConscious and IsPedRagdoll(playerPed) then
        return false, 'error_not_conscious'
    end
    
    -- Check if player is restrained
    if Config.PreventRestrained and IsPedCuffed(playerPed) then
        return false, 'error_restrained'
    end
    
    return true, nil
end

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
                local playerName = GetPlayerName(playerId) or ('Player ' .. GetPlayerServerId(playerId))
                table.insert(players, {
                    serverId = GetPlayerServerId(playerId),
                    name = playerName,
                    distance = distance
                })
            end
        end
    end
    
    -- Sort by distance
    table.sort(players, function(a, b) return a.distance < b.distance end)
    
    return players
end

return Inventory