Locales['de'] = {
    -- General
    ['id_card'] = 'Ausweis',
    ['my_cards'] = 'Meine Ausweise',
    ['card_management'] = 'Ausweisverwaltung',
    ['no_cards'] = 'Sie haben keine Ausweise',
    ['loading'] = 'Laden...',
    ['close'] = 'Schließen',
    ['confirm'] = 'Bestätigen',
    ['cancel'] = 'Abbrechen',
    ['yes'] = 'Ja',
    ['no'] = 'Nein',
    ['ok'] = 'OK',
    
    -- Card Status
    ['status_active'] = 'Aktiv',
    ['status_revoked'] = 'Widerrufen',
    ['status_suspended'] = 'Gesperrt',
    ['status_expired'] = 'Abgelaufen',
    ['status_seized'] = 'Beschlagnahmt',
    
    -- Card Types
    ['type_id'] = 'Personalausweis',
    ['type_driver'] = 'Führerschein',
    ['type_weapon_permit'] = 'Waffenschein',
    ['type_job_id_police'] = 'Polizeiausweis',
    ['type_job_id_ambulance'] = 'Sanitäterausweis',
    ['type_job_id_mechanic'] = 'Mechanikerlizenz',
    ['type_residence'] = 'Aufenthaltserlaubnis',
    
    -- Actions
    ['action_show'] = 'Spieler zeigen',
    ['action_view'] = 'Details anzeigen',
    ['action_issue'] = 'Ausweis ausstellen',
    ['action_renew'] = 'Ausweis erneuern',
    ['action_revoke'] = 'Ausweis widerrufen',
    ['action_suspend'] = 'Ausweis sperren',
    ['action_seize'] = 'Ausweis beschlagnahmen',
    ['action_verify'] = 'Ausweis prüfen',
    
    -- Interface
    ['filter_all'] = 'Alle Ausweise',
    ['filter_valid'] = 'Gültige Ausweise',
    ['filter_expired'] = 'Abgelaufene Ausweise',
    ['filter_suspended'] = 'Gesperrte Ausweise',
    ['search_placeholder'] = 'Ausweise suchen...',
    ['nearby_players'] = 'Spieler in der Nähe',
    ['select_player'] = 'Wählen Sie einen Spieler aus',
    ['no_nearby_players'] = 'Keine Spieler in der Nähe',
    ['card_details'] = 'Ausweis Details',
    ['front_side'] = 'Vorderseite',
    ['back_side'] = 'Rückseite',
    
    -- Card Information
    ['card_id'] = 'Ausweis-ID',
    ['card_type'] = 'Typ',
    ['card_status'] = 'Status',
    ['issue_date'] = 'Ausstellungsdatum',
    ['expiry_date'] = 'Ablaufdatum',
    ['issued_by'] = 'Ausgestellt von',
    ['first_name'] = 'Vorname',
    ['last_name'] = 'Nachname',
    ['date_of_birth'] = 'Geburtsdatum',
    ['gender'] = 'Geschlecht',
    ['address'] = 'Adresse',
    ['signature_valid'] = 'Signatur gültig',
    ['signature_invalid'] = 'Signatur ungültig',
    
    -- Notifications
    ['card_shown_success'] = 'Ausweis an %s gezeigt',
    ['card_received'] = 'Sie haben einen Ausweis von %s erhalten',
    ['card_issued_success'] = 'Ausweis erfolgreich ausgestellt',
    ['card_renewed_success'] = 'Ausweis erfolgreich erneuert',
    ['card_revoked_success'] = 'Ausweis erfolgreich widerrufen',
    ['card_suspended_success'] = 'Ausweis erfolgreich gesperrt',
    ['card_seized_success'] = 'Ausweis erfolgreich beschlagnahmt',
    
    -- Errors
    ['error_not_authorized'] = 'Sie sind nicht berechtigt',
    ['error_player_not_found'] = 'Spieler nicht gefunden',
    ['error_card_not_found'] = 'Ausweis nicht gefunden',
    ['error_invalid_card'] = 'Ungültiger Ausweis',
    ['error_card_expired'] = 'Dieser Ausweis ist abgelaufen',
    ['error_card_revoked'] = 'Dieser Ausweis wurde widerrufen',
    ['error_card_suspended'] = 'Dieser Ausweis ist gesperrt',
    ['error_card_seized'] = 'Dieser Ausweis wurde beschlagnahmt',
    ['error_too_far'] = 'Spieler ist zu weit entfernt',
    ['error_no_line_of_sight'] = 'Keine Sichtverbindung zum Spieler',
    ['error_on_cooldown'] = 'Bitte warten Sie vor dem nächsten Ausweis',
    ['error_invalid_signature'] = 'Ausweissignatur ist ungültig',
    ['error_database'] = 'Datenbankfehler aufgetreten',
    ['error_already_has_card'] = 'Spieler hat bereits diesen Ausweistyp',
    
    -- Admin Commands
    ['admin_card_created'] = 'Testausweis für %s erstellt',
    ['admin_signature_renewed'] = 'Ausweissignatur erneuert',
    ['admin_cards_cleaned'] = '%d abgelaufene Ausweise bereinigt',
    ['admin_invalid_player'] = 'Ungültiger Spieler angegeben',
    ['admin_invalid_card_type'] = 'Ungültiger Ausweistyp angegeben',
    
    -- Tooltips
    ['tooltip_show_card'] = 'Diesen Ausweis Spielern in der Nähe zeigen',
    ['tooltip_view_details'] = 'Detaillierte Informationen zu diesem Ausweis anzeigen',
    ['tooltip_expired_card'] = 'Dieser Ausweis ist abgelaufen und muss erneuert werden',
    ['tooltip_suspended_card'] = 'Dieser Ausweis ist gesperrt und kann nicht verwendet werden',
    ['tooltip_revoked_card'] = 'Dieser Ausweis wurde dauerhaft widerrufen',
    ['tooltip_seized_card'] = 'Dieser Ausweis wurde von den Behörden beschlagnahmt',
    
    -- Forms
    ['form_first_name'] = 'Vorname',
    ['form_last_name'] = 'Nachname',
    ['form_date_of_birth'] = 'Geburtsdatum',
    ['form_gender'] = 'Geschlecht',
    ['form_address'] = 'Adresse',
    ['form_photo'] = 'Foto-URL',
    ['form_notes'] = 'Notizen',
    ['form_expiry_date'] = 'Ablaufdatum',
    ['form_required_field'] = 'Dieses Feld ist erforderlich',
    
    -- Gender Options
    ['gender_male'] = 'Männlich',
    ['gender_female'] = 'Weiblich',
    ['gender_other'] = 'Andere',
    
    -- Time
    ['never_expires'] = 'Läuft nie ab',
    ['expires_in_days'] = 'Läuft in %d Tagen ab',
    ['expired_days_ago'] = 'Vor %d Tagen abgelaufen',
    ['today'] = 'Heute',
    ['tomorrow'] = 'Morgen',
    ['yesterday'] = 'Gestern',
}