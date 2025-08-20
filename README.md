# Jr_IDCard - Comprehensive FiveM ID Card Management System

A modern, secure, and feature-rich ID card management system for FiveM servers with comprehensive integration for ESX/QBCore frameworks.

## 🌟 Features

### Core Functionality
- **Multiple Card Types**: ID cards, driver licenses, weapon permits, job IDs, residence permits
- **Professional Authority System**: Job-based permissions for issuing, renewing, revoking cards
- **Digital Card Display**: Modern NUI interface with F5 keybind access
- **Nearby Player Interaction**: Show cards to players within configurable range with line-of-sight validation
- **Comprehensive Security**: Server-side validation, signature verification, audit logging

### Advanced Features
- **ox_inventory Integration**: Cards as physical items with metadata
- **ox_target Support**: Interactive desks/terminals for card management
- **Multi-language Support**: English and German localization included
- **Admin Tools**: Commands for testing, verification, bulk operations
- **Discord Logging**: Optional webhook integration for audit trails
- **Anti-abuse Systems**: Cooldowns, distance validation, state checking

### Technical Excellence
- **Framework Agnostic**: Compatible with both ESX and QBCore
- **Database Optimization**: Efficient MySQL schemas with proper indexing
- **Modern NUI**: Responsive interface with accessibility support
- **Security First**: HMAC signatures, input sanitization, server-side validation
- **Performance Optimized**: Client-side caching, efficient database queries

## 📋 Requirements

### Dependencies
- **Required**:
  - ESX Legacy or QBCore
  - oxmysql
  - ox_lib
  - ox_inventory

### Server Requirements
- FiveM server build 2802 or newer
- MySQL 5.7+ or MariaDB 10.2+
- Lua 5.4 support

## 🚀 Installation

### 1. Download and Setup
```bash
# Clone or download the resource
git clone https://github.com/HeisenbergJr49/Jr_idcard.git
# Place in your resources folder
cp -r Jr_idcard [server-data]/resources/
```

### 2. Database Setup
```sql
-- Execute the migration script
source Jr_idcard/sql/migration.sql
```

### 3. Configuration
1. Edit `config/config.lua`:
   - Set your framework (`ESX` or `QBCore`)
   - Configure job permissions
   - Update security settings (change the secret key!)
   - Set Discord webhook if desired

2. Key settings to customize:
```lua
Config.Framework = 'ESX' -- or 'QBCore'
Config.SecretKey = 'your_unique_secret_key_here' -- CHANGE THIS!
Config.Keybind = 'F5' -- Key to open card interface
Config.ShowRange = 3.0 -- Distance for showing cards
```

### 4. Add to server.cfg
```cfg
ensure Jr_idcard
```

### 5. Restart Server
```bash
restart Jr_idcard
```

## 🎮 Usage

### Player Usage
- **Open Card Interface**: Press F5 (configurable)
- **View Cards**: Browse your ID cards with filtering options
- **Show to Players**: Select nearby players to display your cards
- **Inventory Integration**: Use cards directly from ox_inventory

### Authority Personnel
- **Issue Cards**: Use ox_target on desks or `/idcard_create` command
- **Renew Cards**: Extend expiry dates for valid cards
- **Revoke/Suspend**: Change card status with audit trail
- **Verification**: Check card authenticity and status

### Admin Commands
```bash
# Create test card
/idcard_create [player_id] [card_type] [first_name] [last_name]

# Renew card signature
/idcard_renew_signature [card_id]

# Clean old audit logs
/idcard_cleanup [days_old]

# Get statistics
/idcard_stats

# Inspect specific card
/idcard_inspect [card_id]

# View player history
/idcard_history [player_identifier]

# Bulk revoke player's cards
/idcard_bulk_revoke [player_identifier] [reason]
```

## 🔧 Configuration Guide

### Card Types
Define available card types in `config/config.lua`:
```lua
Config.CardTypes = {
    ['id'] = {
        label = 'Identification Card',
        icon = 'id-card',
        color = '#3b82f6',
        expirable = true,
        defaultExpiry = 365 * 24 * 60 * 60 -- 1 year
    }
}
```

### Job Permissions
Configure which jobs can manage cards:
```lua
Config.AuthorizedJobs = {
    ['police'] = {
        canIssue = {'id', 'driver', 'weapon_permit'},
        canRenew = {'id', 'driver', 'weapon_permit'},
        canRevoke = {'id', 'driver', 'weapon_permit'},
        canSuspend = {'id', 'driver', 'weapon_permit'},
        canSeize = {'id', 'driver', 'weapon_permit'},
        canVerify = true,
        requireGrade = 1 -- Minimum job grade required
    }
}
```

## 🔒 Security Features

### Server-Side Validation
- All card operations validated server-side
- Distance and line-of-sight verification
- Player state validation (alive, conscious, not restrained)
- Ownership verification with HMAC signatures

### Audit Trail
- Complete audit logging for all card operations
- Database and console logging
- Optional Discord webhook integration
- Configurable log retention policies

### Anti-Abuse Measures
- Cooldown timers for card showing
- Rate limiting on card operations
- Input sanitization and XSS protection
- Signature verification for card authenticity

## 🎨 Customization

### Themes
The NUI supports different themes configured via:
```lua
Config.Theme = 'modern' -- modern, classic, dark
```

### Localization
Add new languages by creating files in `locales/` folder:
```lua
-- locales/es.lua
Locales['es'] = {
    ['my_cards'] = 'Mis Tarjetas',
    -- ... more translations
}
```

### Card Design
Customize card appearance in the NUI by modifying:
- `nui/style.css` for styling
- Card rendering functions in `nui/script.js`

## 🔌 Integration

### ox_inventory
Cards are automatically added as items when issued. Players can:
- View card details from inventory
- Show cards to nearby players
- Context menu actions for verification

### ox_target
Interactive elements for:
- Card issuing desks/terminals
- Verification stations
- Document processing areas

### Exports
Use these exports in other resources:
```lua
-- Server-side
exports['Jr_idcard']:GetPlayerCards(identifier)
exports['Jr_idcard']:GetCardById(cardId)
exports['Jr_idcard']:HasValidCard(identifier, cardType)
exports['Jr_idcard']:VerifyCard(card)

-- Client-side
exports['Jr_idcard']:GetPlayerCards()
exports['Jr_idcard']:RefreshCards()
exports['Jr_idcard']:OpenCardUI()
exports['Jr_idcard']:CloseCardUI()
```

## 📊 Database Schema

### Tables
- `jr_idcard_cards`: Main card storage with metadata
- `jr_idcard_audit`: Comprehensive audit trail
- `jr_idcard_active_cards`: View for active cards only
- `jr_idcard_audit_summary`: Aggregated audit statistics

### Maintenance
- Automatic cleanup of old audit entries
- Optimized indexes for performance
- Support for database clustering

## 🐛 Troubleshooting

### Common Issues

**Cards not showing in NUI:**
- Check console for JavaScript errors
- Verify database connection
- Ensure player has cards in database

**Permission denied errors:**
- Check job configuration in Config.AuthorizedJobs
- Verify player job grade meets requirements
- Ensure ESX/QBCore integration is working

**ox_inventory integration not working:**
- Confirm ox_inventory is installed and running
- Check that Config.UseOxInventory is true
- Verify item registration in console

### Debug Mode
Enable debug logging:
```lua
Config.Debug = true
```

## 🤝 Support & Contributing

### Support
- Check the troubleshooting section
- Review configuration carefully
- Check server console for errors
- Verify all dependencies are installed

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes with proper testing
4. Submit a pull request with detailed description

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Credits

- **Author**: HeisenbergJr49
- **Frameworks**: ESX Legacy, QBCore
- **Libraries**: ox_lib, ox_inventory, ox_target
- **Community**: FiveM Development Community

---

**Version**: 1.0.0  
**Last Updated**: 2024  
**Compatibility**: ESX Legacy, QBCore  