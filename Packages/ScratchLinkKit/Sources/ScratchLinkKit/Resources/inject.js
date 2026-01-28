// inject.js - ScratchLink Bridge for Calliope iOS App
// Handles both direct usage and iframe bridge mode

(function() {
    'use strict';
    
    console.log('[ScratchLink] inject.js loaded');
    
    const isInIframe = window.parent !== window;
    const hasDirectWebkit = typeof webkit !== 'undefined' &&
                            webkit.messageHandlers &&
                            webkit.messageHandlers.scratchLink;
    
    console.log('[ScratchLink] Environment:', {
        isInIframe: isInIframe,
        hasDirectWebkit: hasDirectWebkit,
        href: window.location.href.substring(0, 50)
    });
    
    // ========================================
    // ScratchLinkKit Class - for direct usage
    // ========================================
    
    class ScratchLinkKit {
        static coordinator = new class {
            #socketId = 0;
            #sockets = new Map();

            addSocket(socket) {
                const socketId = this.#socketId;
                this.#sockets.set(socketId, socket);
                this.#socketId += 1;
                console.log('[ScratchLink] coordinator.addSocket, new socketId:', socketId);
                return socketId;
            }

            deleteSocket(socketId) {
                this.#sockets.delete(socketId);
                console.log('[ScratchLink] coordinator.deleteSocket:', socketId);
            }

            handleMessage(socketId, message) {
                console.log('[ScratchLink] coordinator.handleMessage, socketId:', socketId);
                const socket = this.#sockets.get(socketId);
                if (socket) {
                    socket.handleMessage(message);
                } else {
                    console.warn('[ScratchLink] No socket found for socketId:', socketId);
                }
            }
        }();

        static Socket = class {
            #type = null;
            #id = null;
            #onOpen = null;
            #onClose = null;
            #onError = null;
            #handleMessage = null;

            static isSafariHelperCompatible() {
                console.log('[ScratchLink] isSafariHelperCompatible called, returning true');
                return true;
            }

            constructor(type) {
                this.#type = type;
                console.log('[ScratchLink] Socket created with type:', type);
            }

            _postMessage(message) {
                const messageStr = JSON.stringify(message);
                console.log('[ScratchLink] _postMessage called:', messageStr.substring(0, 100));
                
                // Check if we have direct webkit access
                if (typeof webkit !== 'undefined' &&
                    webkit.messageHandlers &&
                    webkit.messageHandlers.scratchLink) {
                    console.log('[ScratchLink] Using direct webkit.messageHandlers');
                    webkit.messageHandlers.scratchLink.postMessage(messageStr);
                } else if (isInIframe) {
                    // We're in an iframe without direct webkit access - use parent bridge
                    console.log('[ScratchLink] Using postMessage bridge to parent');
                    window.parent.postMessage({
                        type: 'scratchLinkMessage',
                        payload: messageStr
                    }, '*');
                } else {
                    console.error('[ScratchLink] No message handler available!');
                }
            }

            open() {
                this.#id = ScratchLinkKit.coordinator.addSocket(this);
                console.log('[ScratchLink] Socket.open() called, assigned id:', this.#id);

                this._postMessage({
                    method: 'open',
                    socketId: this.#id,
                    type: this.#type
                });

                setTimeout(() => {
                    console.log('[ScratchLink] Calling onOpen callback');
                    if (this.#onOpen) this.#onOpen();
                }, 100);
            }

            isOpen() {
                return this.#id != null;
            }

            close() {
                if (this.isOpen()) {
                    console.log('[ScratchLink] Socket.close() called, id:', this.#id);
                    this._postMessage({
                        method: 'close',
                        socketId: this.#id
                    });

                    if (this.#onClose) this.#onClose(new CloseEvent('close'));
                    ScratchLinkKit.coordinator.deleteSocket(this.#id);
                    this.#id = null;
                }
            }

            sendMessage(messageObject) {
                if (this.isOpen()) {
                    console.log('[ScratchLink] sendMessage called for socket:', this.#id);
                    this._postMessage({
                        method: 'send',
                        socketId: this.#id,
                        jsonrpc: JSON.stringify(messageObject)
                    });
                }
            }

            setOnOpen(callback) { this.#onOpen = callback; }
            setOnClose(callback) { this.#onClose = callback; }
            setOnError(callback) { this.#onError = callback; }
            setHandleMessage(callback) { this.#handleMessage = callback; }

            handleMessage(message) {
                console.log('[ScratchLink] handleMessage received:', message.substring(0, 100));
                if (this.#handleMessage) {
                    try {
                        this.#handleMessage(JSON.parse(message));
                    } catch (e) {
                        console.error('[ScratchLink] Error parsing message:', e);
                    }
                }
            }
        };
    }

    // Make ScratchLinkKit globally available
    window.ScratchLinkKit = ScratchLinkKit;

    // ========================================
    // Register Scratch.ScratchLinkSafariSocket
    // ========================================
    
    function registerSocket() {
        self.Scratch = self.Scratch || {};
        self.Scratch.ScratchLinkSafariSocket = ScratchLinkKit.Socket;
        console.log('[ScratchLink] Registered Scratch.ScratchLinkSafariSocket');
    }
    
    // Register immediately
    registerSocket();
    
    // Also register on DOM ready and window load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', registerSocket);
    }
    window.addEventListener('load', registerSocket);
    
    // Periodically re-register for 10 seconds to override any other scripts
    let registrationCount = 0;
    const registrationInterval = setInterval(function() {
        registerSocket();
        registrationCount++;
        if (registrationCount >= 10) {
            clearInterval(registrationInterval);
            console.log('[ScratchLink] Stopped periodic registration');
        }
    }, 1000);

    // ========================================
    // Parent Frame Bridge - forward iframe messages to native
    // ========================================
    
    function isTrustedOrigin(origin) {
        return origin.includes('calliope.cc') ||
               origin.includes('calliope.pages.dev') ||
               origin.includes('scratch-calliope.pages.dev') ||
               origin.includes('localhost');
    }
    
    // Listen for messages from iframes (scratchLinkMessage) and forward to native
    window.addEventListener('message', function(event) {
        // Only process trusted origins
        if (!isTrustedOrigin(event.origin)) {
            return;
        }
        
        // Forward scratchLinkMessage from iframes to native webkit handler
        if (event.data && event.data.type === 'scratchLinkMessage') {
            console.log('[ScratchLink] Parent received scratchLinkMessage from iframe, forwarding to native');
            if (typeof webkit !== 'undefined' &&
                webkit.messageHandlers &&
                webkit.messageHandlers.scratchLink) {
                webkit.messageHandlers.scratchLink.postMessage(event.data.payload);
            }
        }
        
        // Handle responses from native (via postMessage from parent)
        if (event.data && event.data.type === 'scratchLinkResponse') {
            const { socketId, message } = event.data;
            console.log('[ScratchLink] Received scratchLinkResponse for socket:', socketId);
            if (typeof ScratchLinkKit !== 'undefined' && ScratchLinkKit.coordinator) {
                ScratchLinkKit.coordinator.handleMessage(socketId, message);
            }
        }
    }, false);

    console.log('[ScratchLink] inject.js initialization complete');
})();
