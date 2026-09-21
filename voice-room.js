import mqtt from "https://cdn.jsdelivr.net/npm/mqtt@5.10.4/+esm";
import { MQTT_CONFIG, RTC_CONFIG } from "./mqtt-config.js";

export class VoiceRoom {
  constructor({ roomId, userId, username, onStatus, onPeer, onRemoteStream }) {
    this.roomId = roomId;
    this.userId = userId;
    this.username = username;
    this.onStatus = onStatus || (() => {});
    this.onPeer = onPeer || (() => {});
    this.onRemoteStream = onRemoteStream || (() => {});
    this.peers = new Map();
    this.client = null;
    this.localStream = null;
    this.topic = `discord/rooms/${roomId}/signal`;
    this.connected = false;
  }

  async connect() {
    if (!MQTT_CONFIG.url || MQTT_CONFIG.url.includes("YOUR-MQTT-BROKER")) {
      throw new Error("Set MQTT_CONFIG.url, username, and password in mqtt-config.js first.");
    }

    this.onStatus("Connecting to voice signaling...");
    const suffix = crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2);
    this.client = mqtt.connect(MQTT_CONFIG.url, {
      username: MQTT_CONFIG.username,
      password: MQTT_CONFIG.password,
      clientId: `${MQTT_CONFIG.clientPrefix}-${this.userId}-${suffix}`,
      clean: true,
      reconnectPeriod: 3000,
      connectTimeout: 10000
    });

    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("MQTT connection timed out.")), 12000);
      this.client.once("connect", () => {
        clearTimeout(timer);
        resolve();
      });
      this.client.once("error", err => {
        clearTimeout(timer);
        reject(err);
      });
    });

    this.client.subscribe(this.topic, { qos: 1 }, err => {
      if (err) this.onStatus("MQTT subscribe failed: " + err.message);
    });

    this.client.on("message", (_topic, raw) => {
      try {
        const msg = JSON.parse(raw.toString());
        if (msg.from === this.userId) return;
        this.handleSignal(msg).catch(err => this.onStatus("WebRTC error: " + err.message));
      } catch {}
    });

    this.client.on("close", () => {
      this.connected = false;
      this.onStatus("Voice signaling disconnected.");
    });

    this.connected = true;
    this.onStatus("Voice signaling connected.");
    this.publish({ type: "join", from: this.userId, username: this.username });
  }

  async startMicrophone() {
    if (!this.localStream) {
      this.localStream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
        video: false
      });
    }
    return this.localStream;
  }

  async join() {
    await this.startMicrophone();
    if (!this.connected) await this.connect();
    this.publish({ type: "join", from: this.userId, username: this.username });
  }

  async leave() {
    for (const [id, peer] of this.peers) {
      peer.pc.close();
      this.onPeer(id, null);
    }
    this.peers.clear();
    this.publish({ type: "leave", from: this.userId, username: this.username });
    this.localStream?.getTracks().forEach(t => t.stop());
    this.localStream = null;
    this.client?.end(true);
    this.client = null;
    this.connected = false;
  }

  publish(message) {
    if (!this.client || !this.connected) return;
    this.client.publish(this.topic, JSON.stringify(message), { qos: 1 });
  }

  async makePeer(peerId, peerName, initiator) {
    if (this.peers.has(peerId)) return this.peers.get(peerId);
    const pc = new RTCPeerConnection(RTC_CONFIG);
    const peer = { pc, username: peerName || "User" };
    this.peers.set(peerId, peer);

    if (this.localStream) {
      for (const track of this.localStream.getTracks()) pc.addTrack(track, this.localStream);
    }

    pc.onicecandidate = e => {
      if (e.candidate) this.publish({
        type: "candidate",
        from: this.userId,
        to: peerId,
        candidate: e.candidate
      });
    };

    pc.ontrack = e => {
      const stream = e.streams[0];
      if (stream) this.onRemoteStream(peerId, peer.username, stream);
    };

    pc.onconnectionstatechange = () => {
      const state = pc.connectionState;
      if (state === "failed" || state === "closed" || state === "disconnected") {
        this.onPeer(peerId, null);
        if (state === "closed" || state === "failed") this.peers.delete(peerId);
      }
    };

    this.onPeer(peerId, peer);

    if (initiator) {
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      this.publish({
        type: "offer",
        from: this.userId,
        to: peerId,
        username: this.username,
        sdp: pc.localDescription
      });
    }
    return peer;
  }

  async handleSignal(msg) {
    if (msg.to && msg.to !== this.userId) return;

    if (msg.type === "join") {
      // Deterministic initiator rule prevents both peers from creating offers.
      if (this.userId < msg.from) {
        await this.makePeer(msg.from, msg.username, true);
      }
      return;
    }

    if (msg.type === "leave") {
      const peer = this.peers.get(msg.from);
      peer?.pc.close();
      this.peers.delete(msg.from);
      this.onPeer(msg.from, null);
      return;
    }

    if (msg.type === "offer") {
      const peer = await this.makePeer(msg.from, msg.username, false);
      await peer.pc.setRemoteDescription(msg.sdp);
      const answer = await peer.pc.createAnswer();
      await peer.pc.setLocalDescription(answer);
      this.publish({
        type: "answer",
        from: this.userId,
        to: msg.from,
        username: this.username,
        sdp: peer.pc.localDescription
      });
      return;
    }

    if (msg.type === "answer") {
      const peer = this.peers.get(msg.from);
      if (peer) await peer.pc.setRemoteDescription(msg.sdp);
      return;
    }

    if (msg.type === "candidate") {
      const peer = this.peers.get(msg.from);
      if (peer && msg.candidate) {
        try { await peer.pc.addIceCandidate(msg.candidate); } catch {}
      }
    }
  }
}
