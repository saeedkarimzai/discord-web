# Discord Web

A browser-based Discord-style chat app built with HTML, CSS, JavaScript, Supabase, and WebRTC. It is a static site and does not require Node.js.

## Features

- Email/password accounts
- Optional Discord OAuth login (requires enabling the Discord provider in Supabase Auth)
- User profiles
- Servers and text channels
- Secure shareable invite codes
- Real-time messages
- Online presence
- One-to-one and small-room WebRTC voice

## Supabase setup

1. Restore the Supabase project configured in `supabase-config.js` if it is paused.
2. Open the Supabase SQL Editor.
3. Run the complete `supabase-schema.sql` file. It creates the app tables, RLS policies, profile trigger, message Realtime publication, and secure invite-code functions. The older `SECURITY-HARDENING.sql` and `INVITES.sql` files are deprecated; do not run them.
4. In Authentication → Providers, enable Email. Enable Discord only if you want the OAuth button to work, and configure its provider credentials and redirect URLs.
5. In Authentication → URL Configuration, add your GitHub Pages URL to the allowed redirect URLs.
6. Check Database → Replication and ensure `public.messages` is enabled for Realtime if your project does not apply the publication change automatically.

The publishable key in `supabase-config.js` is designed to be public. Never put a service-role key or secret in browser code.

## Deploy

In GitHub, open Settings → Pages, choose **Deploy from a branch**, select `main` and `/(root)`, then save. Open the published HTTPS URL to use microphone features.

## Create and join servers

Use the **+** button to create a server. Use the link button beside the server name to create an invite code, then send the generated link or code to a friend. The **↪** button lets a signed-in user join with a code. Invite creation is restricted to the server owner; invite codes can be used once per user and may be extended with expiry/use limits through the SQL function.

## Voice notes

Voice signaling uses Supabase Realtime Broadcast. No MQTT broker is required. Microphone access requires HTTPS and browser permission. WebRTC uses public STUN servers; restrictive school, corporate, or mobile networks may still require a TURN relay, so voice is not guaranteed on every network. The mesh design is intended for small rooms, not large public servers.

## Troubleshooting

- **Login or messages fail:** confirm the Supabase project is active and the URL/key match the project.
- **Missing table/function errors:** rerun `supabase-schema.sql` in SQL Editor.
- **Realtime messages do not appear:** enable `public.messages` in the Realtime publication.
- **Discord OAuth fails:** enable the Discord provider and configure the callback URL in Supabase and the Discord developer portal.
- **Voice fails:** check HTTPS, microphone permission, Supabase Realtime, and whether the current network allows WebRTC.

The app is a learning project, not a production Discord replacement. GitHub Pages is public; do not commit passwords, service-role keys, private TURN credentials, or other secrets.


**Important:** committing this SQL file does not change the live Supabase database. Back up an existing project, then review and run the current `supabase-schema.sql` in Supabase SQL Editor. Do not run the deprecated partial SQL files.
