// screencapture live SDK, original MIT license in screencapture-LICENSE.txt
(()=>{
const HEARTBEAT_INTERVAL = 15_000;
const MAX_RECONNECT_ATTEMPTS = 3;
const REQUEST_TIMEOUT = 10_000;
class ScreenCaptureViewerError extends Error {
    code;
    constructor(code, message){
        super(message), this.code = code;
        this.name = 'ScreenCaptureViewerError';
    }
}
class ScreenCaptureViewer {
    streamId;
    #endpoint;
    #viewerToken;
    #autoReconnect;
    #state = 'idle';
    #quality = 'auto';
    #peerConnection = null;
    #mediaStream = new MediaStream();
    #videoElement = null;
    #viewerId = null;
    #viewerSessionToken = null;
    #heartbeatInterval = null;
    #expiryTimeout = null;
    #reconnectTimeout = null;
    #reconnectAttempts = 0;
    #connectionGeneration = 0;
    #manualDisconnect = false;
    #listeners = new Map();
    constructor(options){
        this.#endpoint = normalizeEndpoint(options.endpoint);
        if (!/^[A-Za-z0-9_-]{20,64}$/.test(options.streamId)) {
            throw new ScreenCaptureViewerError('configuration', 'Invalid stream ID');
        }
        if (!options.viewerToken) {
            throw new ScreenCaptureViewerError('configuration', 'Viewer token is required');
        }
        this.streamId = options.streamId;
        this.#viewerToken = options.viewerToken;
        this.#autoReconnect = options.autoReconnect ?? true;
    }
    get state() {
        return this.#state;
    }
    get stream() {
        return this.#mediaStream;
    }
    on(eventName, listener) {
        const wrappedListener = (event)=>listener(event);
        const listeners = this.#listeners.get(eventName) ?? new Set();
        listeners.add(wrappedListener);
        this.#listeners.set(eventName, listeners);
        return ()=>listeners.delete(wrappedListener);
    }
    async connect() {
        if (this.#state === 'connected' || this.#state === 'connecting') return this.#mediaStream;
        this.#manualDisconnect = false;
        this.setState('connecting');
        try {
            await this.connectPeer(false);
            return this.#mediaStream;
        } catch (error) {
            const viewerError = toViewerError(error, 'signaling');
            this.emit('error', {
                error: viewerError
            });
            this.setState('failed');
            this.closeLocalConnection();
            await this.disconnectRemote();
            throw viewerError;
        }
    }
    async attach(videoElement) {
        this.#videoElement = videoElement;
        videoElement.srcObject = this.#mediaStream;
        try {
            await videoElement.play();
        } catch  {
            const error = new ScreenCaptureViewerError('autoplay', 'Browser autoplay was blocked; call attach() from a user interaction or mute the video element');
            this.emit('error', {
                error
            });
            throw error;
        }
    }
    async setQuality(quality) {
        this.#quality = quality;
        if (!this.#viewerId || !this.#viewerSessionToken) return;
        await this.requestJson(`${this.viewerPath()}/quality`, {
            method: 'PUT',
            body: JSON.stringify({
                quality
            })
        }, this.#viewerSessionToken);
    }
    async getStats() {
        if (!this.#peerConnection) {
            throw new ScreenCaptureViewerError('connection', 'Viewer is not connected');
        }
        return this.#peerConnection.getStats();
    }
    async disconnect() {
        this.#manualDisconnect = true;
        this.stopHeartbeat();
        this.clearTimers();
        this.closeLocalConnection();
        try {
            await this.disconnectRemote();
        } finally{
            this.#viewerId = null;
            this.#viewerSessionToken = null;
            this.#viewerToken = '';
            this.setState('disconnected');
        }
    }
    async connectPeer(reconnect) {
        const generation = ++this.#connectionGeneration;
        this.closeLocalConnection();
        this.#mediaStream = new MediaStream();
        if (this.#videoElement) this.#videoElement.srcObject = this.#mediaStream;
        const peerConnection = new RTCPeerConnection();
        this.#peerConnection = peerConnection;
        peerConnection.addEventListener('track', (event)=>{
            if (generation !== this.#connectionGeneration) return;
            if (!this.#mediaStream.getTracks().some((track)=>track.id === event.track.id)) {
                this.#mediaStream.addTrack(event.track);
            }
            this.emit('track', {
                track: event.track,
                stream: this.#mediaStream
            });
            if (this.#videoElement) {
                this.#videoElement.srcObject = this.#mediaStream;
                void this.#videoElement.play().catch(()=>{
                    this.emit('error', {
                        error: new ScreenCaptureViewerError('autoplay', 'Browser autoplay was blocked')
                    });
                });
            }
        });
        peerConnection.addEventListener('connectionstatechange', ()=>{
            if (generation === this.#connectionGeneration) void this.handleConnectionState();
        });
        const response = reconnect ? await this.requestJson(`${this.viewerPath()}/reconnect`, {
            method: 'POST'
        }, this.requireViewerSessionToken()) : await this.requestJson(`${this.streamPath()}/viewers/connect`, {
            method: 'POST'
        }, this.#viewerToken);
        if (!isSessionDescription(response.sessionDescription, 'offer')) {
            throw new ScreenCaptureViewerError('signaling', 'Signaling service returned an invalid viewer offer');
        }
        if (!response.viewerId || !response.viewerSessionToken || !Number.isFinite(response.expiresAt)) {
            throw new ScreenCaptureViewerError('signaling', 'Signaling service returned an invalid viewer session');
        }
        this.#viewerId = response.viewerId;
        this.#viewerSessionToken = response.viewerSessionToken;
        await peerConnection.setRemoteDescription(response.sessionDescription);
        const answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        await waitForIceGathering(peerConnection);
        const localDescription = peerConnection.localDescription;
        if (!localDescription?.sdp) throw new ScreenCaptureViewerError('connection', 'Could not create a viewer answer');
        await this.requestJson(`${this.viewerPath()}/answer`, {
            method: 'PUT',
            body: JSON.stringify({
                type: localDescription.type,
                sdp: localDescription.sdp
            })
        }, this.#viewerSessionToken);
        this.scheduleExpiry(response.expiresAt);
    }
    async handleConnectionState() {
        const connectionState = this.#peerConnection?.connectionState;
        if (this.#manualDisconnect) return;
        if (connectionState === 'connected') {
            this.#reconnectAttempts = 0;
            this.setState('connected');
            this.startHeartbeat();
            if (this.#quality !== 'auto') {
                try {
                    await this.setQuality(this.#quality);
                } catch (error) {
                    this.emit('error', {
                        error: toViewerError(error, 'signaling')
                    });
                }
            }
            return;
        }
        if (connectionState === 'failed' || connectionState === 'disconnected') {
            this.scheduleReconnect();
        }
    }
    scheduleReconnect() {
        if (this.#manualDisconnect || !this.#autoReconnect || this.#reconnectTimeout) return;
        if (!this.#viewerId || !this.#viewerSessionToken || this.#reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            void this.failConnection(new ScreenCaptureViewerError('connection', 'The viewer connection could not be restored'));
            return;
        }
        this.stopHeartbeat();
        this.setState('reconnecting');
        const delay = 1_000 * 2 ** this.#reconnectAttempts++;
        this.#reconnectTimeout = setTimeout(()=>{
            this.#reconnectTimeout = null;
            void this.connectPeer(true).catch((error)=>{
                this.emit('error', {
                    error: toViewerError(error, 'connection')
                });
                this.scheduleReconnect();
            });
        }, delay);
    }
    startHeartbeat() {
        if (this.#heartbeatInterval) return;
        this.#heartbeatInterval = setInterval(()=>{
            if (!this.#viewerSessionToken) return;
            void this.requestJson(`${this.viewerPath()}/heartbeat`, {
                method: 'POST'
            }, this.#viewerSessionToken).catch((error)=>{
                this.emit('error', {
                    error: toViewerError(error, 'connection')
                });
                this.scheduleReconnect();
            });
        }, HEARTBEAT_INTERVAL);
    }
    stopHeartbeat() {
        if (this.#heartbeatInterval) clearInterval(this.#heartbeatInterval);
        this.#heartbeatInterval = null;
    }
    scheduleExpiry(expiresAt) {
        if (this.#expiryTimeout) clearTimeout(this.#expiryTimeout);
        this.#expiryTimeout = setTimeout(()=>{
            void this.disconnect();
        }, Math.max(0, expiresAt - Date.now()));
    }
    clearTimers() {
        if (this.#expiryTimeout) clearTimeout(this.#expiryTimeout);
        if (this.#reconnectTimeout) clearTimeout(this.#reconnectTimeout);
        this.#expiryTimeout = null;
        this.#reconnectTimeout = null;
    }
    closeLocalConnection() {
        this.#peerConnection?.close();
        this.#peerConnection = null;
        for (const track of this.#mediaStream.getTracks())track.stop();
    }
    async disconnectRemote() {
        if (!this.#viewerId || !this.#viewerSessionToken) return;
        try {
            await this.requestJson(this.viewerPath(), {
                method: 'DELETE'
            }, this.#viewerSessionToken);
        } catch  {}
    }
    async failConnection(error) {
        if (this.#state === 'failed') return;
        this.#manualDisconnect = true;
        this.stopHeartbeat();
        this.clearTimers();
        this.closeLocalConnection();
        this.setState('failed');
        this.emit('error', {
            error
        });
        try {
            await this.disconnectRemote();
        } finally{
            this.#viewerId = null;
            this.#viewerSessionToken = null;
            this.#viewerToken = '';
        }
    }
    setState(state) {
        if (this.#state === state) return;
        this.#state = state;
        this.emit('state', {
            state
        });
    }
    emit(eventName, event) {
        for (const listener of this.#listeners.get(eventName) ?? [])listener(event);
    }
    streamPath() {
        return `${this.#endpoint}/v1/streams/${encodeURIComponent(this.streamId)}`;
    }
    viewerPath() {
        if (!this.#viewerId) throw new ScreenCaptureViewerError('connection', 'Viewer session is unavailable');
        return `${this.streamPath()}/viewers/${encodeURIComponent(this.#viewerId)}`;
    }
    requireViewerSessionToken() {
        if (!this.#viewerSessionToken) {
            throw new ScreenCaptureViewerError('connection', 'Viewer session is unavailable');
        }
        return this.#viewerSessionToken;
    }
    async requestJson(url, init, token) {
        const abortController = new AbortController();
        const timeout = setTimeout(()=>abortController.abort(), REQUEST_TIMEOUT);
        try {
            const response = await fetch(url, {
                ...init,
                cache: 'no-store',
                credentials: 'omit',
                signal: abortController.signal,
                headers: {
                    Authorization: `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    ...init.headers
                }
            });
            const result = await response.json().catch(()=>({}));
            if (!response.ok) {
                throw new ScreenCaptureViewerError('signaling', result.error ?? `Signaling request failed with status ${response.status}`);
            }
            return result;
        } catch (error) {
            if (error instanceof Error && error.name === 'AbortError') {
                throw new ScreenCaptureViewerError('signaling', 'Signaling request timed out');
            }
            throw error;
        } finally{
            clearTimeout(timeout);
        }
    }
}
function normalizeEndpoint(endpoint) {
    try {
        const url = new URL(endpoint);
        const isLocalDevelopment = url.hostname === 'localhost' || url.hostname === '127.0.0.1';
        if (url.protocol !== 'https:' && !isLocalDevelopment) throw new Error();
        return url.toString().replace(/\/$/, '');
    } catch  {
        throw new ScreenCaptureViewerError('configuration', 'Viewer endpoint must be a valid HTTPS URL');
    }
}
function isSessionDescription(value, type) {
    if (!value || typeof value !== 'object') return false;
    const description = value;
    return description.type === type && typeof description.sdp === 'string' && description.sdp.length > 0;
}
function waitForIceGathering(peerConnection) {
    if (peerConnection.iceGatheringState === 'complete') return Promise.resolve();
    return new Promise((resolve)=>{
        const timeout = setTimeout(finish, 10_000);
        function finish() {
            clearTimeout(timeout);
            peerConnection.removeEventListener('icegatheringstatechange', handleStateChange);
            resolve();
        }
        function handleStateChange() {
            if (peerConnection.iceGatheringState === 'complete') finish();
        }
        peerConnection.addEventListener('icegatheringstatechange', handleStateChange);
    });
}
function toViewerError(error, fallbackCode) {
    if (error instanceof ScreenCaptureViewerError) return error;
    return new ScreenCaptureViewerError(fallbackCode, error instanceof Error ? error.message : 'Unknown viewer error');
}

window.CrimsonLiveSDK={ScreenCaptureViewer};})();
