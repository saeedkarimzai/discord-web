import { initializeApp } from "https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js";
import {
  getAuth,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  updateProfile
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-auth.js";
import {
  getDatabase,
  ref,
  push,
  onValue,
  set,
  serverTimestamp
} from "https://www.gstatic.com/firebasejs/12.19.0/firebase-database.js";
import { firebaseConfig } from "./firebase-config.js";

const configured = !Object.values(firebaseConfig).some(value => String(value).includes("PASTE_YOUR_"));

let app = null;
let auth = null;
let db = null;

if (configured) {
  app = initializeApp(firebaseConfig);
  auth = getAuth(app);
  db = getDatabase(app);
}

export { configured, auth, db, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut, onAuthStateChanged, updateProfile, ref, push, onValue, set, serverTimestamp };

export function requireFirebase() {
  if (!configured) {
    throw new Error("Firebase is not configured yet. Fill in firebase-config.js.");
  }
}

export function messagesRef(serverId, channelId) {
  requireFirebase();
  return ref(db, `servers/${serverId}/channels/${channelId}/messages`);
}

export function userRef(uid) {
  requireFirebase();
  return ref(db, `users/${uid}`);
}
