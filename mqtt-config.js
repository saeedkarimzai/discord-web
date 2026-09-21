// MQTT + WebRTC configuration.
// IMPORTANT: Browser apps expose these values. For production, use short-lived broker credentials
// or an authenticated MQTT gateway instead of a permanent shared username/password.

export const MQTT_CONFIG = {
  // Example: "wss://your-broker.example.com:8084/mqtt"
  url: "wss://YOUR-MQTT-BROKER:8084/mqtt",
  username: "YOUR_MQTT_USERNAME",
  password: "YOUR_MQTT_PASSWORD",
  clientPrefix: "discord-web"
};

export const RTC_CONFIG = {
  iceServers: [
    { urls: "stun:stun.l.google.com:19302" }
    // Add your TURN server here for reliable calls across restrictive NATs:
    // {
    //   urls: "turn:your-turn.example.com:3478",
    //   username: "TURN_USERNAME",
    //   credential: "TURN_PASSWORD"
    // }
  ]
};
