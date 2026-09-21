# Discord Web

A real browser-based Discord-style chat application.

## Current architecture

- GitHub Pages hosts the web application.
- Supabase handles accounts, profiles, servers, channels, messages, and realtime chat.
- MQTT handles voice-room signaling and can later handle presence and realtime events.
- WebRTC handles direct browser voice connections.
- TURN is recommended for reliable voice connections across restrictive networks.

## Run it

The site is static and can be deployed with GitHub Pages.

Before voice works, edit `mqtt-config.js` with a WebSocket MQTT broker. Do not put a permanent production secret in a public repository. For production, use short-lived/authenticated broker credentials.

## Important

WebRTC mesh is intended for small voice rooms. A large Discord-scale voice system should use an SFU rather than a peer-to-peer connection between every user.

Supabase Row Level Security should be enabled and configured so users can only read/write data they are allowed to access.
