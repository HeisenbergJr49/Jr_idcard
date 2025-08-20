-- Audit Logging System for Jr_IDCard
-- Tracks all card-related actions for security and compliance

local Audit = {}

-- Log an audit event
Audit.Log = function(data)
    if not Config.EnableAuditLog then
        return
    end
    
    -- Validate required fields
    if not data.card_id or not data.action or not data.by_identifier then
        if Config.Debug then
            print('^1[Jr_IDCard]^7 Invalid audit data provided')
        end
        return
    end
    
    -- Log to console if enabled
    if Config.LogToConsole then
        local logMessage = string.format(
            '[Jr_IDCard] %s: %s performed %s on card %s',
            os.date('%Y-%m-%d %H:%M:%S'),
            data.by_identifier,
            data.action,
            data.card_id
        )
        
        if data.to_identifier then
            logMessage = logMessage .. string.format(' (target: %s)', data.to_identifier)
        end
        
        if data.notes then
            logMessage = logMessage .. string.format(' - %s', data.notes)
        end
        
        print(logMessage)
    end
    
    -- Log to database if enabled
    if Config.LogToDatabase then
        local query = [[
            INSERT INTO jr_idcard_audit 
            (card_id, action, by_identifier, by_charid, to_identifier, to_charid, position, notes, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]]
        
        local position = nil
        if data.position then
            position = json.encode(data.position)
        end
        
        local metadata = nil
        if data.metadata then
            metadata = json.encode(data.metadata)
        end
        
        local params = {
            data.card_id,
            data.action,
            data.by_identifier,
            data.by_charid,
            data.to_identifier,
            data.to_charid,
            position,
            data.notes,
            metadata
        }
        
        MySQL.insert(query, params, function(insertId)
            if insertId and Config.Debug then
                print(string.format('^2[Jr_IDCard]^7 Audit log entry created: %d', insertId))
            elseif not insertId then
                print('^1[Jr_IDCard]^7 Failed to create audit log entry')
            end
        end)
    end
    
    -- Log to Discord if enabled
    if Config.LogToDiscord and Config.DiscordWebhook and Config.DiscordWebhook ~= '' then
        Audit.LogToDiscord(data)
    end
end

-- Log card issuance
Audit.LogIssue = function(cardId, cardType, ownerIdentifier, issuerIdentifier, issuerCharId, issuerJob)
    Audit.Log({
        card_id = cardId,
        action = 'issued',
        by_identifier = issuerIdentifier,
        by_charid = issuerCharId,
        to_identifier = ownerIdentifier,
        notes = string.format('Issued %s card', cardType),
        metadata = {
            card_type = cardType,
            issuer_job = issuerJob
        }
    })
end

-- Log card renewal
Audit.LogRenew = function(cardId, ownerIdentifier, issuerIdentifier, issuerCharId, newExpiryDate)
    Audit.Log({
        card_id = cardId,
        action = 'renewed',
        by_identifier = issuerIdentifier,
        by_charid = issuerCharId,
        to_identifier = ownerIdentifier,
        notes = string.format('Renewed until %s', newExpiryDate or 'never'),
        metadata = {
            new_expiry = newExpiryDate
        }
    })
end

-- Log card status change
Audit.LogStatusChange = function(cardId, ownerIdentifier, issuerIdentifier, issuerCharId, oldStatus, newStatus, reason)
    local actionMap = {
        revoked = 'revoked',
        suspended = 'suspended',
        seized = 'seized',
        active = 'status_change'
    }
    
    Audit.Log({
        card_id = cardId,
        action = actionMap[newStatus] or 'status_change',
        by_identifier = issuerIdentifier,
        by_charid = issuerCharId,
        to_identifier = ownerIdentifier,
        notes = reason or string.format('Status changed from %s to %s', oldStatus, newStatus),
        metadata = {
            old_status = oldStatus,
            new_status = newStatus,
            reason = reason
        }
    })
end

-- Log card show event
Audit.LogShow = function(cardId, ownerIdentifier, targetIdentifier, targetCharId, position)
    Audit.Log({
        card_id = cardId,
        action = 'shown',
        by_identifier = ownerIdentifier,
        to_identifier = targetIdentifier,
        to_charid = targetCharId,
        position = position,
        notes = 'Card shown to player'
    })
end

-- Log card verification
Audit.LogVerify = function(cardId, ownerIdentifier, verifierIdentifier, verifierCharId, isValid, position)
    Audit.Log({
        card_id = cardId,
        action = 'verified',
        by_identifier = verifierIdentifier,
        by_charid = verifierCharId,
        to_identifier = ownerIdentifier,
        position = position,
        notes = string.format('Card verification: %s', isValid and 'VALID' or 'INVALID'),
        metadata = {
            verification_result = isValid
        }
    })
end

-- Discord webhook logging
Audit.LogToDiscord = function(data)
    local webhook = Config.DiscordWebhook
    if not webhook or webhook == '' then
        return
    end
    
    local color = 3447003 -- Blue default
    local actionColors = {
        issued = 65280,    -- Green
        renewed = 16776960, -- Yellow
        revoked = 16711680, -- Red
        suspended = 16750848, -- Orange
        seized = 8388736,   -- Dark Red
        shown = 3447003,    -- Blue
        verified = 65535    -- Cyan
    }
    
    if actionColors[data.action] then
        color = actionColors[data.action]
    end
    
    local embed = {
        title = string.format('ID Card %s', data.action:upper()),
        color = color,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        fields = {
            {
                name = 'Card ID',
                value = data.card_id,
                inline = true
            },
            {
                name = 'Action',
                value = data.action,
                inline = true
            },
            {
                name = 'Performed By',
                value = data.by_identifier,
                inline = true
            }
        }
    }
    
    if data.to_identifier then
        table.insert(embed.fields, {
            name = 'Target Player',
            value = data.to_identifier,
            inline = true
        })
    end
    
    if data.notes then
        table.insert(embed.fields, {
            name = 'Notes',
            value = data.notes,
            inline = false
        })
    end
    
    local payload = {
        username = 'Jr IDCard System',
        avatar_url = 'https://cdn.discordapp.com/emojis/1234567890123456789.png', -- Replace with actual icon
        embeds = {embed}
    }
    
    PerformHttpRequest(webhook, function(statusCode, response)
        if Config.Debug then
            if statusCode == 204 then
                print('^2[Jr_IDCard]^7 Discord webhook sent successfully')
            else
                print(string.format('^1[Jr_IDCard]^7 Discord webhook failed: %d - %s', statusCode, response))
            end
        end
    end, 'POST', json.encode(payload), {['Content-Type'] = 'application/json'})
end

-- Get audit history for a card
Audit.GetCardHistory = function(cardId, callback)
    if not callback then return end
    
    local query = [[
        SELECT a.*, 
               DATE_FORMAT(a.timestamp, '%Y-%m-%d %H:%i:%s') as formatted_timestamp
        FROM jr_idcard_audit a
        WHERE a.card_id = ?
        ORDER BY a.timestamp DESC
        LIMIT 50
    ]]
    
    MySQL.query(query, {cardId}, function(results)
        if results then
            -- Decode JSON fields
            for _, entry in ipairs(results) do
                if entry.position then
                    entry.position = json.decode(entry.position)
                end
                if entry.metadata then
                    entry.metadata = json.decode(entry.metadata)
                end
            end
            callback(results)
        else
            callback({})
        end
    end)
end

-- Get audit history for a player
Audit.GetPlayerHistory = function(identifier, callback)
    if not callback then return end
    
    local query = [[
        SELECT a.*, c.type as card_type,
               DATE_FORMAT(a.timestamp, '%Y-%m-%d %H:%i:%s') as formatted_timestamp
        FROM jr_idcard_audit a
        LEFT JOIN jr_idcard_cards c ON a.card_id = c.id
        WHERE a.to_identifier = ? OR a.by_identifier = ?
        ORDER BY a.timestamp DESC
        LIMIT 100
    ]]
    
    MySQL.query(query, {identifier, identifier}, function(results)
        if results then
            for _, entry in ipairs(results) do
                if entry.position then
                    entry.position = json.decode(entry.position)
                end
                if entry.metadata then
                    entry.metadata = json.decode(entry.metadata)
                end
            end
            callback(results)
        else
            callback({})
        end
    end)
end

-- Clean old audit logs (admin function)
Audit.CleanOldLogs = function(daysOld, callback)
    if not daysOld or daysOld < 30 then -- Minimum 30 days retention
        if callback then callback(false, 'Minimum retention period is 30 days') end
        return
    end
    
    local query = [[
        DELETE FROM jr_idcard_audit 
        WHERE timestamp < DATE_SUB(NOW(), INTERVAL ? DAY)
        AND action IN ('shown', 'verified')
    ]]
    
    MySQL.update(query, {daysOld}, function(affectedRows)
        if Config.Debug then
            print(string.format('^2[Jr_IDCard]^7 Cleaned %d old audit entries', affectedRows or 0))
        end
        if callback then callback(true, affectedRows or 0) end
    end)
end

-- Get audit statistics
Audit.GetStats = function(callback)
    if not callback then return end
    
    local query = [[
        SELECT 
            action,
            COUNT(*) as count,
            DATE(timestamp) as date
        FROM jr_idcard_audit 
        WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        GROUP BY action, DATE(timestamp)
        ORDER BY timestamp DESC
    ]]
    
    MySQL.query(query, {}, function(results)
        if results then
            callback(results)
        else
            callback({})
        end
    end)
end

return Audit