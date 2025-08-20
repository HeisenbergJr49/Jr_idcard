-- Database Handler for Jr_IDCard
-- Handles all database operations with proper error handling and validation

local Database = {}

-- Utility function to generate UUID
local function generateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Generate HMAC signature for card validation
local function generateSignature(cardData, secretKey)
    local dataString = string.format("%s:%s:%s:%s:%s",
        cardData.id or '',
        cardData.type or '',
        cardData.owner_identifier or '',
        cardData.issue_date or '',
        json.encode(cardData.metadata or {})
    )
    
    -- Simple hash implementation - in production, use proper HMAC
    local hash = 0
    for i = 1, #dataString do
        hash = hash + string.byte(dataString, i) * i
    end
    hash = hash + #secretKey
    
    return string.format("%x", hash)
end

-- Initialize database tables
Database.Init = function()
    if Config.Debug then
        print('^3[Jr_IDCard]^7 Initializing database...')
    end
    
    -- Read and execute migration file
    local migration = LoadResourceFile(GetCurrentResourceName(), 'sql/migration.sql')
    if migration then
        local queries = {}
        for query in migration:gmatch('[^;]+') do
            query = query:match('^%s*(.-)%s*$') -- trim whitespace
            if query and query ~= '' and not query:match('^%-%-') then -- ignore comments
                table.insert(queries, query)
            end
        end
        
        for _, query in ipairs(queries) do
            if query and query ~= '' then
                MySQL.query(query, {}, function(result)
                    if Config.Debug and result == false then
                        print('^1[Jr_IDCard]^7 Database query failed: ' .. query)
                    end
                end)
            end
        end
        
        if Config.Debug then
            print('^2[Jr_IDCard]^7 Database initialized successfully')
        end
    else
        print('^1[Jr_IDCard]^7 Could not load migration file!')
    end
end

-- Create a new ID card
Database.CreateCard = function(cardData, callback)
    local id = generateUUID()
    local signature = generateSignature({
        id = id,
        type = cardData.type,
        owner_identifier = cardData.owner_identifier,
        issue_date = os.date('%Y-%m-%d %H:%M:%S'),
        metadata = cardData.metadata
    }, Config.SecretKey)
    
    local query = [[
        INSERT INTO jr_idcard_cards 
        (id, owner_identifier, owner_charid, type, status, expiry_date, 
         issuer_job, issuer_identifier, issuer_charid, metadata, signature)
        VALUES (?, ?, ?, ?, 'active', ?, ?, ?, ?, ?, ?)
    ]]
    
    local params = {
        id,
        cardData.owner_identifier,
        cardData.owner_charid,
        cardData.type,
        cardData.expiry_date,
        cardData.issuer_job,
        cardData.issuer_identifier,
        cardData.issuer_charid,
        json.encode(cardData.metadata),
        signature
    }
    
    MySQL.insert(query, params, function(insertId)
        if insertId then
            if Config.Debug then
                print(string.format('^2[Jr_IDCard]^7 Created card %s for %s', id, cardData.owner_identifier))
            end
            if callback then callback(true, id) end
        else
            print('^1[Jr_IDCard]^7 Failed to create card')
            if callback then callback(false, nil) end
        end
    end)
end

-- Get cards by owner identifier
Database.GetCardsByOwner = function(identifier, callback)
    local query = [[
        SELECT c.*, 
               CASE 
                   WHEN c.expiry_date IS NULL THEN 'never'
                   WHEN c.expiry_date > NOW() THEN 'valid'
                   ELSE 'expired'
               END as expiry_status
        FROM jr_idcard_cards c
        WHERE c.owner_identifier = ?
        ORDER BY c.issue_date DESC
    ]]
    
    MySQL.query(query, {identifier}, function(results)
        if results then
            -- Decode JSON metadata for each card
            for _, card in ipairs(results) do
                if card.metadata then
                    card.metadata = json.decode(card.metadata)
                end
            end
            if callback then callback(results) end
        else
            if callback then callback({}) end
        end
    end)
end

-- Get card by ID
Database.GetCardById = function(cardId, callback)
    local query = [[
        SELECT c.*, 
               CASE 
                   WHEN c.expiry_date IS NULL THEN 'never'
                   WHEN c.expiry_date > NOW() THEN 'valid'
                   ELSE 'expired'
               END as expiry_status
        FROM jr_idcard_cards c
        WHERE c.id = ?
    ]]
    
    MySQL.single(query, {cardId}, function(result)
        if result then
            if result.metadata then
                result.metadata = json.decode(result.metadata)
            end
            if callback then callback(result) end
        else
            if callback then callback(nil) end
        end
    end)
end

-- Update card status
Database.UpdateCardStatus = function(cardId, status, updatedBy, callback)
    local query = [[
        UPDATE jr_idcard_cards 
        SET status = ?, last_updated = NOW()
        WHERE id = ?
    ]]
    
    MySQL.update(query, {status, cardId}, function(affectedRows)
        if affectedRows > 0 then
            if Config.Debug then
                print(string.format('^2[Jr_IDCard]^7 Updated card %s status to %s', cardId, status))
            end
            if callback then callback(true) end
        else
            if callback then callback(false) end
        end
    end)
end

-- Renew card (update expiry date and signature)
Database.RenewCard = function(cardId, newExpiryDate, renewedBy, callback)
    -- First get the card data to regenerate signature
    Database.GetCardById(cardId, function(card)
        if not card then
            if callback then callback(false) end
            return
        end
        
        local newSignature = generateSignature({
            id = card.id,
            type = card.type,
            owner_identifier = card.owner_identifier,
            issue_date = card.issue_date,
            metadata = card.metadata
        }, Config.SecretKey)
        
        local query = [[
            UPDATE jr_idcard_cards 
            SET expiry_date = ?, signature = ?, status = 'active', last_updated = NOW()
            WHERE id = ?
        ]]
        
        MySQL.update(query, {newExpiryDate, newSignature, cardId}, function(affectedRows)
            if affectedRows > 0 then
                if Config.Debug then
                    print(string.format('^2[Jr_IDCard]^7 Renewed card %s', cardId))
                end
                if callback then callback(true) end
            else
                if callback then callback(false) end
            end
        end)
    end)
end

-- Verify card signature
Database.VerifyCardSignature = function(card)
    local expectedSignature = generateSignature({
        id = card.id,
        type = card.type,
        owner_identifier = card.owner_identifier,
        issue_date = card.issue_date,
        metadata = card.metadata
    }, Config.SecretKey)
    
    return card.signature == expectedSignature
end

-- Get cards by type
Database.GetCardsByType = function(cardType, callback)
    local query = [[
        SELECT c.*, 
               CASE 
                   WHEN c.expiry_date IS NULL THEN 'never'
                   WHEN c.expiry_date > NOW() THEN 'valid'
                   ELSE 'expired'
               END as expiry_status
        FROM jr_idcard_cards c
        WHERE c.type = ?
        ORDER BY c.issue_date DESC
    ]]
    
    MySQL.query(query, {cardType}, function(results)
        if results then
            for _, card in ipairs(results) do
                if card.metadata then
                    card.metadata = json.decode(card.metadata)
                end
            end
            if callback then callback(results) end
        else
            if callback then callback({}) end
        end
    end)
end

-- Delete card (for admin cleanup)
Database.DeleteCard = function(cardId, callback)
    local query = 'DELETE FROM jr_idcard_cards WHERE id = ?'
    
    MySQL.update(query, {cardId}, function(affectedRows)
        if affectedRows > 0 then
            if Config.Debug then
                print(string.format('^2[Jr_IDCard]^7 Deleted card %s', cardId))
            end
            if callback then callback(true) end
        else
            if callback then callback(false) end
        end
    end)
end

-- Check if player already has card of specific type
Database.PlayerHasCardType = function(identifier, cardType, callback)
    local query = [[
        SELECT COUNT(*) as count 
        FROM jr_idcard_cards 
        WHERE owner_identifier = ? AND type = ? AND status = 'active'
    ]]
    
    MySQL.single(query, {identifier, cardType}, function(result)
        if result then
            if callback then callback(result.count > 0) end
        else
            if callback then callback(false) end
        end
    end)
end

-- Get expiring cards (for notifications)
Database.GetExpiringCards = function(daysAhead, callback)
    local query = [[
        SELECT c.*, 
               DATEDIFF(c.expiry_date, NOW()) as days_until_expiry
        FROM jr_idcard_cards c
        WHERE c.status = 'active' 
        AND c.expiry_date IS NOT NULL
        AND c.expiry_date BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL ? DAY)
        ORDER BY c.expiry_date ASC
    ]]
    
    MySQL.query(query, {daysAhead}, function(results)
        if results then
            for _, card in ipairs(results) do
                if card.metadata then
                    card.metadata = json.decode(card.metadata)
                end
            end
            if callback then callback(results) end
        else
            if callback then callback({}) end
        end
    end)
end

return Database