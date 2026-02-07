// AI WAF Demo - Frontend Application
// Configure your API endpoint here
const CONFIG = {
    API_ENDPOINT: 'https://your-api-endpoint.execute-api.us-east-1.amazonaws.com', // Will be auto-configured
    USER_ID: 'demo-user-' + Math.random().toString(36).substr(2, 9)
};

// Stats tracking
const stats = {
    total: 0,
    blocked: 0,
    allowed: 0,
    riskScores: []
};

// DOM Elements
const elements = {
    wafToggle: document.getElementById('wafToggle'),
    wafStatus: document.getElementById('wafStatus'),
    scenarioSelect: document.getElementById('scenarioSelect'),
    chatForm: document.getElementById('chatForm'),
    userInput: document.getElementById('userInput'),
    sendBtn: document.getElementById('sendBtn'),
    messages: document.getElementById('messages'),
    charCount: document.getElementById('charCount'),
    clearChat: document.getElementById('clearChat'),
    statsElements: {
        total: document.getElementById('totalRequests'),
        blocked: document.getElementById('blockedRequests'),
        allowed: document.getElementById('allowedRequests'),
        avgRisk: document.getElementById('avgRiskScore')
    }
};

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    loadApiEndpoint();
    setupEventListeners();
    updateWafStatus();
});

// Load API endpoint from config or local storage
function loadApiEndpoint() {
    const savedEndpoint = localStorage.getItem('apiEndpoint');
    if (savedEndpoint) {
        CONFIG.API_ENDPOINT = savedEndpoint;
    } else {
        // Try to auto-detect from deployment
        fetch('config.json')
            .then(res => res.json())
            .then(config => {
                CONFIG.API_ENDPOINT = config.apiEndpoint;
                localStorage.setItem('apiEndpoint', config.apiEndpoint);
            })
            .catch(() => {
                console.log('No config.json found, using default endpoint');
            });
    }
}

// Event Listeners
function setupEventListeners() {
    elements.wafToggle.addEventListener('change', updateWafStatus);
    elements.scenarioSelect.addEventListener('change', handleScenarioSelect);
    elements.chatForm.addEventListener('submit', handleSubmit);
    elements.userInput.addEventListener('input', updateCharCount);
    elements.clearChat.addEventListener('click', clearChat);
}

function updateWafStatus() {
    const isEnabled = elements.wafToggle.checked;
    const statusText = isEnabled ? 
        '🛡️ WAF Protection: <strong>ENABLED</strong>' :
        '⚠️ WAF Protection: <strong>DISABLED</strong>';
    
    elements.wafStatus.innerHTML = statusText;
    elements.wafStatus.classList.toggle('disabled', !isEnabled);
}

function handleScenarioSelect(e) {
    const scenario = e.target.value;
    if (scenario) {
        elements.userInput.value = scenario;
        updateCharCount();
        elements.userInput.focus();
    }
}

function updateCharCount() {
    const count = elements.userInput.value.length;
    elements.charCount.textContent = count;
}

async function handleSubmit(e) {
    e.preventDefault();
    
    const prompt = elements.userInput.value.trim();
    if (!prompt) return;
    
    // Disable input during request
    elements.sendBtn.disabled = true;
    elements.userInput.disabled = true;
    
    // Add user message to chat
    addMessage('user', prompt);
    
    // Clear input
    elements.userInput.value = '';
    updateCharCount();
    
    // Show loading indicator
    const loadingId = addLoadingMessage();
    
    try {
        // Determine endpoint based on WAF toggle
        const wafEnabled = elements.wafToggle.checked;
        const endpoint = wafEnabled ? '/chat' : '/chat-direct';
        
        const response = await sendMessage(prompt, endpoint);
        
        // Remove loading indicator
        removeMessage(loadingId);
        
        // Add assistant response
        addAssistantMessage(response, wafEnabled);
        
        // Update stats
        updateStats(response);
        
    } catch (error) {
        removeMessage(loadingId);
        addErrorMessage(error.message);
    } finally {
        // Re-enable input
        elements.sendBtn.disabled = false;
        elements.userInput.disabled = false;
        elements.userInput.focus();
    }
}

async function sendMessage(prompt, endpoint) {
    const url = CONFIG.API_ENDPOINT + endpoint;
    
    const requestBody = {
        prompt: prompt,
        user_id: CONFIG.USER_ID,
        session_id: Date.now().toString()
    };
    
    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestBody)
    });
    
    const data = await response.json();
    
    // Add HTTP status to response
    data.httpStatus = response.status;
    
    return data;
}

function addMessage(type, content) {
    const messageDiv = document.createElement('div');
    messageDiv.className = `message ${type}`;
    messageDiv.id = `msg-${Date.now()}`;
    
    const header = document.createElement('div');
    header.className = 'message-header';
    header.innerHTML = `
        <strong>${type === 'user' ? '👤 You' : '🤖 AI Assistant'}</strong>
        <span>${new Date().toLocaleTimeString()}</span>
    `;
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content';
    contentDiv.textContent = content;
    
    messageDiv.appendChild(header);
    messageDiv.appendChild(contentDiv);
    
    elements.messages.appendChild(messageDiv);
    scrollToBottom();
    
    return messageDiv.id;
}

function addAssistantMessage(response, wafEnabled) {
    const messageDiv = document.createElement('div');
    const isBlocked = response.httpStatus === 403;
    
    messageDiv.className = `message assistant ${isBlocked ? 'blocked' : 'allowed'}`;
    messageDiv.id = `msg-${Date.now()}`;
    
    const header = document.createElement('div');
    header.className = 'message-header';
    header.innerHTML = `
        <strong>🤖 AI Assistant ${wafEnabled ? '(Protected)' : '(Unprotected)'}</strong>
        <span>${new Date().toLocaleTimeString()}</span>
    `;
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content';
    
    if (isBlocked) {
        contentDiv.innerHTML = `
            <strong>🚫 Request Blocked by AI WAF</strong>
            <p style="margin-top: 0.5rem;">${response.error || 'Security violation detected'}</p>
        `;
        
        // Add security details
        const detailsDiv = document.createElement('div');
        detailsDiv.className = 'message-details';
        detailsDiv.innerHTML = `
            <div class="detail-row">
                <span class="detail-label">Violation Code:</span>
                <span class="detail-value">${response.code || 'UNKNOWN'}</span>
            </div>
            ${response.risk_score ? `
                <div class="detail-row">
                    <span class="detail-label">Risk Score:</span>
                    <span class="detail-value"><span class="risk-score ${getRiskClass(response.risk_score)}">${response.risk_score}/100</span></span>
                </div>
            ` : ''}
            ${response.reason && response.reason.length > 0 ? `
                <div class="detail-row">
                    <span class="detail-label">Reasons:</span>
                    <div>${response.reason.map(r => `<div>• ${r}</div>`).join('')}</div>
                </div>
            ` : ''}
            ${response.detected_patterns && response.detected_patterns.length > 0 ? `
                <div class="detected-patterns">
                    <span class="detail-label">Detected Patterns:</span>
                    <div>${response.detected_patterns.map(p => `<span class="pattern-tag">${p}</span>`).join('')}</div>
                </div>
            ` : ''}
        `;
        contentDiv.appendChild(detailsDiv);
    } else {
        contentDiv.innerHTML = `
            <p>${response.response || response.message || 'Request processed successfully'}</p>
        `;
        
        // Add metadata if available
        if (response.risk_score !== undefined || response.processing_time_ms) {
            const detailsDiv = document.createElement('div');
            detailsDiv.className = 'message-details';
            detailsDiv.innerHTML = `
                ${response.risk_score !== undefined ? `
                    <div class="detail-row">
                        <span class="detail-label">Risk Score:</span>
                        <span class="detail-value"><span class="risk-score ${getRiskClass(response.risk_score)}">${response.risk_score}/100</span></span>
                    </div>
                ` : ''}
                ${response.processing_time_ms ? `
                    <div class="detail-row">
                        <span class="detail-label">Processing Time:</span>
                        <span class="detail-value">${response.processing_time_ms.toFixed(0)}ms</span>
                    </div>
                ` : ''}
                ${!wafEnabled ? `
                    <div class="detail-row" style="margin-top: 0.5rem; color: var(--warning-color);">
                        ⚠️ Response generated WITHOUT security checks
                    </div>
                ` : ''}
            `;
            contentDiv.appendChild(detailsDiv);
        }
    }
    
    messageDiv.appendChild(header);
    messageDiv.appendChild(contentDiv);
    
    elements.messages.appendChild(messageDiv);
    scrollToBottom();
}

function addLoadingMessage() {
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message assistant';
    const id = `loading-${Date.now()}`;
    messageDiv.id = id;
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content';
    contentDiv.innerHTML = `
        <div class="loading">
            <div class="loading-dot"></div>
            <div class="loading-dot"></div>
            <div class="loading-dot"></div>
        </div>
    `;
    
    messageDiv.appendChild(contentDiv);
    elements.messages.appendChild(messageDiv);
    scrollToBottom();
    
    return id;
}

function addErrorMessage(error) {
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message assistant blocked';
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'message-content';
    contentDiv.innerHTML = `
        <strong>❌ Error</strong>
        <p style="margin-top: 0.5rem;">${error}</p>
    `;
    
    messageDiv.appendChild(contentDiv);
    elements.messages.appendChild(messageDiv);
    scrollToBottom();
}

function removeMessage(id) {
    const element = document.getElementById(id);
    if (element) {
        element.remove();
    }
}

function getRiskClass(score) {
    if (score >= 70) return 'risk-high';
    if (score >= 31) return 'risk-medium';
    return 'risk-low';
}

function scrollToBottom() {
    elements.messages.scrollTop = elements.messages.scrollHeight;
}

function updateStats(response) {
    stats.total++;
    
    if (response.httpStatus === 403) {
        stats.blocked++;
    } else {
        stats.allowed++;
    }
    
    if (response.risk_score !== undefined) {
        stats.riskScores.push(response.risk_score);
    }
    
    // Update display
    elements.statsElements.total.textContent = stats.total;
    elements.statsElements.blocked.textContent = stats.blocked;
    elements.statsElements.allowed.textContent = stats.allowed;
    
    if (stats.riskScores.length > 0) {
        const avgRisk = stats.riskScores.reduce((a, b) => a + b, 0) / stats.riskScores.length;
        elements.statsElements.avgRisk.textContent = avgRisk.toFixed(0);
    }
}

function clearChat() {
    if (confirm('Clear all messages and reset stats?')) {
        // Clear messages except welcome
        const welcomeMsg = elements.messages.querySelector('.welcome-message');
        elements.messages.innerHTML = '';
        if (welcomeMsg) {
            elements.messages.appendChild(welcomeMsg);
        }
        
        // Reset stats
        stats.total = 0;
        stats.blocked = 0;
        stats.allowed = 0;
        stats.riskScores = [];
        
        elements.statsElements.total.textContent = '0';
        elements.statsElements.blocked.textContent = '0';
        elements.statsElements.allowed.textContent = '0';
        elements.statsElements.avgRisk.textContent = '0';
    }
}

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    // Ctrl/Cmd + Enter to send
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
        elements.chatForm.dispatchEvent(new Event('submit'));
    }
});
