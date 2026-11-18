(function () {
    const button = document.getElementById('submit-btn');
    const input = document.getElementById('user-input');
    const container = document.getElementById('message-container');

    if (!button || !input || !container) {
        console.error("DOM elements missing! Check your element IDs.");
        return;
    }

    button.addEventListener('click', async () => {
        const promptText = input.value.trim();
        if (!promptText) return;

        // Optional: Remove the initial placeholder text if it's still there
        const placeholder = container.querySelector('div[style*="color: #64748b"]');
        if (placeholder) {
            placeholder.remove();
        }

        // Add a prompt separator header so you can distinguish new runs in the chat history
        const promptHeader = document.createElement('div');
        promptHeader.style.cssText = 'margin: 16px 0 8px 0; font-size: 0.85rem; font-weight: bold; color: #38bdf8; border-top: 1px dashed #334155; padding-top: 12px;';
        promptHeader.textContent = `Prompt: "${promptText}"`;
        container.appendChild(promptHeader);

        // Clear input field for the next query
        input.value = '';

        try {
            const response = await fetch('/chat/stream', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ prompt: promptText })
            });

            if (!response.ok) {
                throw new Error(`Server returned status ${response.status}`);
            }

            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let buffer = '';

            while (true) {
                const { value, done } = await reader.read();
                if (done) break;

                // Decode and normalize CRLF (\r\n) to LF (\n)
                buffer += decoder.decode(value, { stream: true }).replace(/\r\n/g, '\n');

                const messages = buffer.split('\n\n');
                buffer = messages.pop(); // Retain incomplete chunk

                for (const message of messages) {
                    if (!message.trim()) continue;

                    let eventType = 'message';
                    let eventData = '';

                    const lines = message.split('\n');
                    for (const rawLine of lines) {
                        const line = rawLine.trim();
                        if (line.startsWith('event:')) {
                            eventType = line.substring(6).trim();
                        } else if (line.startsWith('data:')) {
                            eventData = line.substring(5).trim();
                        }
                    }

                    // Create message card container
                    const msgDiv = document.createElement('div');
                    msgDiv.className = 'sse-message';

                    // 1. Generate timestamp as the message arrives
                    const timestamp = new Date().toLocaleTimeString();
                    const timeSpan = document.createElement('span');
                    timeSpan.style.cssText = 'font-size: 0.7rem; color: #94a3b8; display: block; margin-bottom: 4px; font-family: sans-serif;';
                    timeSpan.textContent = `Received at ${timestamp}`;
                    msgDiv.appendChild(timeSpan);

                    // 2. Set message content based on event type
                    const contentDiv = document.createElement('div');
                    if (eventType === 'number') {
                        contentDiv.textContent = eventData;
                    } else if (eventType === 'done') {
                        msgDiv.style.borderColor = '#22c55e';
                        contentDiv.style.color = '#22c55e';
                        contentDiv.textContent = `[Complete]: ${eventData}`;
                    } else {
                        contentDiv.textContent = eventData || message;
                    }
                    msgDiv.appendChild(contentDiv);

                    container.appendChild(msgDiv);
                    
                    // Auto-scroll to the bottom of the history container
                    container.scrollTop = container.scrollHeight;
                }
            }
        } catch (err) {
            console.error("Stream error:", err);
            const errDiv = document.createElement('div');
            errDiv.className = 'sse-message';
            errDiv.style.borderColor = '#ef4444';
            errDiv.style.color = '#ef4444';
            errDiv.textContent = 'Network error / Stream failed';
            container.appendChild(errDiv);
        }
    });
})();