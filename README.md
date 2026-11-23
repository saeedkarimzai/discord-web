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

Voice signaling uses Supabase Realtime Broadcast, so no separate MQTT broker is required. Microphone access requires HTTPS and browser permission. WebRTC uses public STUN servers; restrictive networks may still require a TURN server, so voice is not guaranteed on every network.

## Important

WebRTC mesh is intended for small voice rooms. A large Discord-scale voice system should use an SFU rather than a peer-to-peer connection between every user.

Supabase Row Level Security should be enabled and configured so users can only read/write data they are allowed to access.


## Security hardening

- Supabase Row Level Security is the actual authorization layer for the live app.
- Run `SECURITY-HARDENING.sql` in the Supabase SQL Editor on an existing database to restrict server membership creation and channel management to server owners.
- The current UI does not implement invitations or joining servers, so arbitrary UUID-based self-joining is intentionally blocked until a proper invite flow is built.
- `database.rules.json` is a legacy Firebase Realtime Database file and is deny-all; the current app uses Supabase.
