-- Jr_IDCard Database Migration
-- Version: 1.0.0
-- Description: Creates tables for comprehensive ID card management system

CREATE TABLE IF NOT EXISTS `jr_idcard_cards` (
    `id` VARCHAR(36) NOT NULL PRIMARY KEY COMMENT 'UUID for the card',
    `owner_identifier` VARCHAR(50) NOT NULL COMMENT 'Player identifier (steam, license, etc)',
    `owner_charid` VARCHAR(50) NULL COMMENT 'Character/Citizen ID',
    `type` VARCHAR(50) NOT NULL COMMENT 'Card type (id, driver, weapon_permit, etc)',
    `status` ENUM('active', 'revoked', 'suspended', 'expired', 'seized') NOT NULL DEFAULT 'active',
    `issue_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expiry_date` TIMESTAMP NULL COMMENT 'NULL for non-expiring cards',
    `issuer_job` VARCHAR(50) NULL COMMENT 'Job of the person who issued the card',
    `issuer_identifier` VARCHAR(50) NULL COMMENT 'Identifier of the person who issued the card',
    `issuer_charid` VARCHAR(50) NULL COMMENT 'Character ID of the person who issued the card',
    `metadata` JSON NOT NULL COMMENT 'Card-specific data (names, DOB, photo, etc)',
    `signature` VARCHAR(255) NOT NULL COMMENT 'HMAC signature for validation',
    `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX `idx_owner_identifier` (`owner_identifier`),
    INDEX `idx_owner_charid` (`owner_charid`),
    INDEX `idx_type` (`type`),
    INDEX `idx_status` (`status`),
    INDEX `idx_expiry_date` (`expiry_date`),
    INDEX `idx_issuer_job` (`issuer_job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `jr_idcard_audit` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `card_id` VARCHAR(36) NOT NULL COMMENT 'Reference to the card',
    `action` ENUM('issued', 'renewed', 'revoked', 'suspended', 'seized', 'status_change', 'shown', 'verified') NOT NULL,
    `by_identifier` VARCHAR(50) NOT NULL COMMENT 'Who performed the action',
    `by_charid` VARCHAR(50) NULL COMMENT 'Character ID of who performed the action',
    `to_identifier` VARCHAR(50) NULL COMMENT 'Target of the action (for show/verify)',
    `to_charid` VARCHAR(50) NULL COMMENT 'Target character ID',
    `position` JSON NULL COMMENT 'World position where action occurred',
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `notes` TEXT NULL COMMENT 'Additional information about the action',
    `metadata` JSON NULL COMMENT 'Action-specific metadata',
    
    INDEX `idx_card_id` (`card_id`),
    INDEX `idx_action` (`action`),
    INDEX `idx_by_identifier` (`by_identifier`),
    INDEX `idx_to_identifier` (`to_identifier`),
    INDEX `idx_timestamp` (`timestamp`),
    
    FOREIGN KEY (`card_id`) REFERENCES `jr_idcard_cards`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create view for active cards
CREATE OR REPLACE VIEW `jr_idcard_active_cards` AS
SELECT 
    c.*,
    CASE 
        WHEN c.expiry_date IS NULL THEN 'never'
        WHEN c.expiry_date > NOW() THEN 'valid'
        ELSE 'expired'
    END as expiry_status,
    DATEDIFF(c.expiry_date, NOW()) as days_until_expiry
FROM `jr_idcard_cards` c
WHERE c.status = 'active';

-- Create view for audit summary
CREATE OR REPLACE VIEW `jr_idcard_audit_summary` AS
SELECT 
    card_id,
    COUNT(*) as total_actions,
    COUNT(CASE WHEN action = 'shown' THEN 1 END) as times_shown,
    COUNT(CASE WHEN action = 'verified' THEN 1 END) as times_verified,
    MAX(timestamp) as last_activity
FROM `jr_idcard_audit`
GROUP BY card_id;

-- Insert default admin card types if they don't exist
INSERT IGNORE INTO `jr_idcard_cards` (
    `id`, 
    `owner_identifier`, 
    `owner_charid`, 
    `type`, 
    `status`, 
    `metadata`, 
    `signature`
) VALUES (
    'admin-template-id',
    'admin',
    'admin',
    'id',
    'active',
    JSON_OBJECT(
        'firstName', 'Admin',
        'lastName', 'Template',
        'dateOfBirth', '1990-01-01',
        'gender', 'M',
        'address', 'Government Building',
        'photoHash', '',
        'isTemplate', true
    ),
    'admin_template_signature'
);

-- Stored procedure for cleanup of expired audit logs (optional)
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS CleanupAuditLogs(IN days_old INT)
BEGIN
    DELETE FROM `jr_idcard_audit` 
    WHERE `timestamp` < DATE_SUB(NOW(), INTERVAL days_old DAY)
    AND `action` IN ('shown', 'verified');
END$$
DELIMITER ;

-- Event scheduler for automatic expiry status updates (optional)
-- This would run daily to update expired cards
-- SET GLOBAL event_scheduler = ON;
-- CREATE EVENT IF NOT EXISTS UpdateExpiredCards
-- ON SCHEDULE EVERY 1 DAY
-- DO
--   UPDATE `jr_idcard_cards` 
--   SET `status` = 'expired' 
--   WHERE `expiry_date` < NOW() 
--   AND `status` = 'active';