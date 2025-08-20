// Jr_IDCard NUI JavaScript
// Handles all UI interactions and communication with the client

class IDCardManager {
    constructor() {
        this.cards = [];
        this.nearbyPlayers = [];
        this.locales = {};
        this.config = {};
        this.currentFilter = 'all';
        this.selectedCard = null;
        
        this.init();
    }
    
    init() {
        this.bindEvents();
        this.setupEscapeKey();
        
        // Initially hide the UI
        this.hideUI();
    }
    
    bindEvents() {
        // Close buttons
        document.querySelectorAll('.btn-close, [data-modal-close]').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const modalId = e.target.closest('[data-modal-close]')?.getAttribute('data-modal-close');
                if (modalId) {
                    this.hideModal(modalId);
                } else {
                    this.closeUI();
                }
            });
        });
        
        // Filter tabs
        document.querySelectorAll('.filter-tab').forEach(tab => {
            tab.addEventListener('click', (e) => {
                const filter = e.target.getAttribute('data-filter');
                this.setFilter(filter);
            });
        });
        
        // Search input
        const searchInput = document.getElementById('searchInput');
        searchInput.addEventListener('input', (e) => {
            this.filterCards(e.target.value);
        });
        
        // Card side toggle
        document.querySelectorAll('.side-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const side = e.target.getAttribute('data-side');
                this.toggleCardSide(side);
            });
        });
        
        // Show card button
        document.getElementById('showCardBtn').addEventListener('click', () => {
            this.showNearbyPlayersModal();
        });
        
        // Accept/Decline card buttons
        document.getElementById('acceptCardBtn').addEventListener('click', () => {
            this.acceptReceivedCard();
        });
        
        document.getElementById('declineCardBtn').addEventListener('click', () => {
            this.declineReceivedCard();
        });
    }
    
    setupEscapeKey() {
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                // Close top modal or UI
                const visibleModal = document.querySelector('.modal.visible');
                if (visibleModal) {
                    this.hideModal(visibleModal.id);
                } else {
                    this.closeUI();
                }
            }
        });
    }
    
    // Message handler from client
    handleMessage(event) {
        const data = event.data;
        
        switch (data.type) {
            case 'showUI':
                this.showUI(data);
                break;
            case 'hideUI':
                this.hideUI();
                break;
            case 'updateCards':
                this.updateCards(data.cards);
                break;
            case 'updateNearbyPlayers':
                this.updateNearbyPlayers(data.nearbyPlayers);
                break;
            case 'showReceivedCard':
                this.showReceivedCard(data.card, data.senderName);
                break;
            case 'showCardReceiveConfirmation':
                this.showCardReceiveConfirmation(data.card, data.senderName);
                break;
        }
    }
    
    showUI(data) {
        this.cards = data.cards || [];
        this.nearbyPlayers = data.nearbyPlayers || [];
        this.locales = data.locales || {};
        this.config = data.config || {};
        
        this.updateLocalization();
        this.renderCards();
        
        document.getElementById('app').classList.add('visible');
    }
    
    hideUI() {
        document.getElementById('app').classList.remove('visible');
        this.hideAllModals();
    }
    
    closeUI() {
        this.postNUI('closeUI', {});
        this.hideUI();
    }
    
    updateCards(cards) {
        this.cards = cards;
        this.renderCards();
    }
    
    updateNearbyPlayers(players) {
        this.nearbyPlayers = players;
        if (document.getElementById('nearbyPlayersModal').classList.contains('visible')) {
            this.renderNearbyPlayers();
        }
    }
    
    setFilter(filter) {
        this.currentFilter = filter;
        
        // Update active tab
        document.querySelectorAll('.filter-tab').forEach(tab => {
            tab.classList.toggle('active', tab.getAttribute('data-filter') === filter);
        });
        
        this.renderCards();
    }
    
    filterCards(searchTerm = '') {
        const filteredCards = this.cards.filter(card => {
            // Apply status filter
            const statusFilter = this.getStatusFilter(card);
            if (this.currentFilter !== 'all' && !statusFilter) {
                return false;
            }
            
            // Apply search filter
            if (searchTerm) {
                const searchLower = searchTerm.toLowerCase();
                const cardType = this.getLocale('type_' + card.type).toLowerCase();
                const fullName = `${card.metadata?.firstName || ''} ${card.metadata?.lastName || ''}`.toLowerCase();
                
                return cardType.includes(searchLower) || 
                       fullName.includes(searchLower) ||
                       card.id.toLowerCase().includes(searchLower);
            }
            
            return true;
        });
        
        this.renderFilteredCards(filteredCards);
    }
    
    getStatusFilter(card) {
        switch (this.currentFilter) {
            case 'valid':
                return card.status === 'active' && (card.expiry_status === 'never' || card.expiry_status === 'valid');
            case 'expired':
                return card.expiry_status === 'expired';
            case 'suspended':
                return card.status === 'suspended' || card.status === 'seized';
            default:
                return true;
        }
    }
    
    renderCards() {
        this.filterCards(document.getElementById('searchInput').value);
    }
    
    renderFilteredCards(cards) {
        const grid = document.getElementById('cardsGrid');
        const emptyState = document.getElementById('emptyState');
        
        if (cards.length === 0) {
            grid.style.display = 'none';
            emptyState.classList.remove('hidden');
            return;
        }
        
        grid.style.display = 'grid';
        emptyState.classList.add('hidden');
        
        grid.innerHTML = cards.map(card => this.createCardElement(card)).join('');
        
        // Bind click events to cards
        grid.querySelectorAll('.card-item').forEach(cardEl => {
            cardEl.addEventListener('click', () => {
                const cardId = cardEl.getAttribute('data-card-id');
                const card = this.cards.find(c => c.id === cardId);
                if (card) {
                    this.showCardDetail(card);
                }
            });
        });
    }
    
    createCardElement(card) {
        const cardType = this.config.cardTypes?.[card.type] || {};
        const statusClass = `status-${card.status}`;
        const expiryInfo = this.getExpiryInfo(card);
        
        return `
            <div class="card-item" data-card-id="${card.id}">
                <div class="card-header">
                    <div class="card-type" style="color: ${cardType.color || '#3b82f6'}">
                        <i class="fas fa-${cardType.icon || 'id-card'}"></i>
                        ${this.getLocale('type_' + card.type)}
                    </div>
                    <div class="card-status ${statusClass}">
                        ${this.getLocale('status_' + card.status)}
                    </div>
                </div>
                <div class="card-info">
                    <p><strong>${this.getLocale('first_name')}:</strong> ${card.metadata?.firstName || 'N/A'}</p>
                    <p><strong>${this.getLocale('last_name')}:</strong> ${card.metadata?.lastName || 'N/A'}</p>
                    <p><strong>${this.getLocale('issue_date')}:</strong> ${this.formatDate(card.issue_date)}</p>
                    <p><strong>${this.getLocale('expiry_date')}:</strong> ${expiryInfo}</p>
                </div>
                <div class="card-actions">
                    <button class="btn btn-primary btn-small" onclick="event.stopPropagation(); idCardManager.showCardDetail('${card.id}')">
                        <i class="fas fa-eye"></i> ${this.getLocale('action_view')}
                    </button>
                </div>
            </div>
        `;
    }
    
    getExpiryInfo(card) {
        if (!card.expiry_date) {
            return this.getLocale('never_expires');
        }
        
        const expiryDate = new Date(card.expiry_date);
        const now = new Date();
        const diffTime = expiryDate - now;
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        
        if (diffDays < 0) {
            return this.getLocale('expired_days_ago', Math.abs(diffDays));
        } else if (diffDays === 0) {
            return this.getLocale('today');
        } else if (diffDays === 1) {
            return this.getLocale('tomorrow');
        } else {
            return this.getLocale('expires_in_days', diffDays);
        }
    }
    
    showCardDetail(cardOrId) {
        const card = typeof cardOrId === 'string' ? this.cards.find(c => c.id === cardOrId) : cardOrId;
        if (!card) return;
        
        this.selectedCard = card;
        this.renderCardDetail(card);
        this.showModal('cardDetailModal');
    }
    
    renderCardDetail(card) {
        const cardType = this.config.cardTypes?.[card.type] || {};
        
        // Render card front
        document.getElementById('cardFront').innerHTML = this.renderCardFront(card, cardType);
        
        // Render card back
        document.getElementById('cardBack').innerHTML = this.renderCardBack(card, cardType);
        
        // Render card info
        document.getElementById('cardDetailInfo').innerHTML = this.renderCardInfo(card);
        
        // Update show button visibility
        const showBtn = document.getElementById('showCardBtn');
        showBtn.style.display = card.status === 'active' ? 'flex' : 'none';
    }
    
    renderCardFront(card, cardType) {
        return `
            <div class="card-front-content">
                <div class="card-header-info">
                    <div class="card-title">
                        <i class="fas fa-${cardType.icon || 'id-card'}"></i>
                        ${this.getLocale('type_' + card.type)}
                    </div>
                    <div class="card-id">ID: ${card.id.substr(0, 8)}...</div>
                </div>
                
                <div class="card-photo-section">
                    ${card.metadata?.photoHash ? 
                        `<img src="${card.metadata.photoHash}" alt="Photo" class="card-photo">` :
                        `<div class="card-photo-placeholder"><i class="fas fa-user"></i></div>`
                    }
                    <div class="card-personal-info">
                        <h3>${card.metadata?.firstName || 'Unknown'} ${card.metadata?.lastName || ''}</h3>
                        <p>DOB: ${this.formatDate(card.metadata?.dateOfBirth)}</p>
                        <p>Gender: ${card.metadata?.gender || 'N/A'}</p>
                    </div>
                </div>
                
                <div class="card-footer-info">
                    <div class="signature-area">
                        <i class="fas fa-shield-check" style="color: #10b981;"></i>
                        ${this.getLocale('signature_valid')}
                    </div>
                </div>
            </div>
        `;
    }
    
    renderCardBack(card, cardType) {
        return `
            <div class="card-back-content">
                <div class="card-details">
                    <h4>${this.getLocale('card_details')}</h4>
                    <div class="detail-row">
                        <span>${this.getLocale('issue_date')}:</span>
                        <span>${this.formatDate(card.issue_date)}</span>
                    </div>
                    <div class="detail-row">
                        <span>${this.getLocale('expiry_date')}:</span>
                        <span>${card.expiry_date ? this.formatDate(card.expiry_date) : this.getLocale('never_expires')}</span>
                    </div>
                    <div class="detail-row">
                        <span>${this.getLocale('issued_by')}:</span>
                        <span>${card.metadata?.issuerName || 'Government'}</span>
                    </div>
                    ${card.metadata?.address ? `
                        <div class="detail-row">
                            <span>${this.getLocale('address')}:</span>
                            <span>${card.metadata.address}</span>
                        </div>
                    ` : ''}
                </div>
                
                ${this.config.showQRCodes ? `
                    <div class="qr-code-section">
                        <div class="qr-code-placeholder">
                            <i class="fas fa-qrcode"></i>
                            <p>QR Code</p>
                        </div>
                    </div>
                ` : ''}
            </div>
        `;
    }
    
    renderCardInfo(card) {
        return `
            <div class="info-section">
                <h4>${this.getLocale('card_information')}</h4>
                <div class="info-grid">
                    <div class="info-item">
                        <label>${this.getLocale('card_id')}:</label>
                        <span>${card.id}</span>
                    </div>
                    <div class="info-item">
                        <label>${this.getLocale('card_status')}:</label>
                        <span class="status-badge status-${card.status}">${this.getLocale('status_' + card.status)}</span>
                    </div>
                    <div class="info-item">
                        <label>${this.getLocale('issue_date')}:</label>
                        <span>${this.formatDateTime(card.issue_date)}</span>
                    </div>
                    <div class="info-item">
                        <label>${this.getLocale('last_updated')}:</label>
                        <span>${this.formatDateTime(card.last_updated)}</span>
                    </div>
                </div>
            </div>
        `;
    }
    
    toggleCardSide(side) {
        const cardSides = document.querySelector('.card-sides');
        const sideButtons = document.querySelectorAll('.side-btn');
        
        cardSides.classList.toggle('flipped', side === 'back');
        
        sideButtons.forEach(btn => {
            btn.classList.toggle('active', btn.getAttribute('data-side') === side);
        });
    }
    
    showNearbyPlayersModal() {
        this.renderNearbyPlayers();
        this.showModal('nearbyPlayersModal');
    }
    
    renderNearbyPlayers() {
        const list = document.getElementById('nearbyPlayersList');
        const noPlayersMsg = document.getElementById('noPlayersMessage');
        
        if (this.nearbyPlayers.length === 0) {
            list.style.display = 'none';
            noPlayersMsg.style.display = 'block';
            return;
        }
        
        list.style.display = 'block';
        noPlayersMsg.style.display = 'none';
        
        list.innerHTML = this.nearbyPlayers.map(player => `
            <div class="player-item" onclick="idCardManager.showCardToPlayer(${player.serverId})">
                <div class="player-info">
                    <div class="player-name">${player.name}</div>
                    <div class="player-distance">${player.distance.toFixed(1)}m</div>
                </div>
                <i class="fas fa-share"></i>
            </div>
        `).join('');
    }
    
    showCardToPlayer(serverId) {
        if (!this.selectedCard) return;
        
        this.postNUI('showCard', {
            cardId: this.selectedCard.id,
            targetServerId: serverId
        });
        
        this.hideModal('nearbyPlayersModal');
        this.hideModal('cardDetailModal');
    }
    
    showReceivedCard(card, senderName) {
        this.renderReceivedCard(card, senderName);
        this.showModal('receivedCardModal');
    }
    
    showCardReceiveConfirmation(card, senderName) {
        this.showReceivedCard(card, senderName);
    }
    
    renderReceivedCard(card, senderName) {
        document.getElementById('senderName').textContent = senderName;
        
        const cardType = this.config.cardTypes?.[card.type] || {};
        document.getElementById('receivedCardDisplay').innerHTML = this.renderCardFront(card, cardType);
    }
    
    acceptReceivedCard() {
        const senderName = document.getElementById('senderName').textContent;
        this.postNUI('acceptCard', { senderName });
        this.hideModal('receivedCardModal');
    }
    
    declineReceivedCard() {
        this.postNUI('declineCard', {});
        this.hideModal('receivedCardModal');
    }
    
    showModal(modalId) {
        document.getElementById(modalId).classList.add('visible');
    }
    
    hideModal(modalId) {
        document.getElementById(modalId).classList.remove('visible');
    }
    
    hideAllModals() {
        document.querySelectorAll('.modal').forEach(modal => {
            modal.classList.remove('visible');
        });
    }
    
    updateLocalization() {
        document.querySelectorAll('[data-locale]').forEach(element => {
            const key = element.getAttribute('data-locale');
            element.textContent = this.getLocale(key);
        });
        
        document.querySelectorAll('[data-locale-placeholder]').forEach(element => {
            const key = element.getAttribute('data-locale-placeholder');
            element.placeholder = this.getLocale(key);
        });
    }
    
    getLocale(key, ...args) {
        let text = this.locales[key] || key;
        
        // Simple string interpolation
        if (args.length > 0) {
            args.forEach((arg, index) => {
                text = text.replace(new RegExp(`%${index + 1}`, 'g'), arg);
            });
        }
        
        return text;
    }
    
    formatDate(dateString) {
        if (!dateString) return 'N/A';
        
        try {
            const date = new Date(dateString);
            return date.toLocaleDateString();
        } catch (e) {
            return dateString;
        }
    }
    
    formatDateTime(dateString) {
        if (!dateString) return 'N/A';
        
        try {
            const date = new Date(dateString);
            return date.toLocaleString();
        } catch (e) {
            return dateString;
        }
    }
    
    postNUI(type, data) {
        fetch(`https://${GetParentResourceName()}/${type}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        }).catch(err => {
            console.error('NUI Post Error:', err);
        });
    }
}

// Initialize the manager
const idCardManager = new IDCardManager();

// Listen for messages from client
window.addEventListener('message', (event) => {
    idCardManager.handleMessage(event);
});