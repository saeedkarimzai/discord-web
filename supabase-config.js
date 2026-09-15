// Supabase browser configuration.
// The publishable key is safe to ship in browser code; database access is protected by RLS.
export const SUPABASE_URL = "https://cdymepilkcdmelvztmoq.supabase.co";
export const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_sw5xaEZprZuDZ4JQJd5DFA_-9mBJu31";

// Guest mode: lets visitors enter the UI without creating or logging into an account.
// Guests get a local demo view and cannot write to the real database.
if (typeof document !== "undefined") {
  const setupGuestMode = () => {
    const authCard = document.querySelector('.auth-card');
    const authScreen = document.getElementById('authScreen');
    const app = document.getElementById('app');
    if (!authCard || !authScreen || !app || document.getElementById('guestButton')) return;

    const guestButton = document.createElement('button');
    guestButton.id = 'guestButton';
    guestButton.className = 'primary wide';
    guestButton.textContent = 'Continue as Guest';
    guestButton.style.marginTop = '10px';
    guestButton.style.background = '#23a559';
    authCard.insertBefore(guestButton, document.querySelector('.auth-switch'));

    guestButton.addEventListener('click', () => {
      authScreen.classList.add('hidden');
      app.classList.remove('hidden');
      app.dataset.guest = 'true';

      const servers = document.getElementById('servers');
      const channels = document.getElementById('channels');
      const messages = document.getElementById('messages');
      const serverName = document.getElementById('serverName');
      const channelName = document.getElementById('channelName');
      const messageInput = document.getElementById('messageInput');
      const send = document.getElementById('send');
      const myName = document.getElementById('myName');
      const myAvatar = document.getElementById('myAvatar');
      const members = document.getElementById('members');
      const memberCount = document.getElementById('memberCount');

      servers.innerHTML = '<button class="server active" title="Guest Demo">G</button><div class="divider"></div>';
      channels.innerHTML = '<div class="category">TEXT CHANNELS</div><div class="channel active"><span>#</span><span>general</span></div>';
      serverName.textContent = 'Guest Demo';
      channelName.textContent = 'general';
      myName.textContent = 'Guest';
      myAvatar.textContent = 'G';
      members.innerHTML = '<div class="member"><div class="avatar">G</div><span>Guest</span></div>';
      memberCount.textContent = '1';
      messages.innerHTML = '<div class="welcome"><h1>Welcome to #general!</h1><p>You are browsing as a guest. Create an account or log in to send real messages and use online features.</p></div>';
      messageInput.placeholder = 'Log in to send messages';
      messageInput.disabled = true;
      send.disabled = true;
      send.style.opacity = '0.5';

      const serverMenu = document.getElementById('serverMenu');
      const settings = document.getElementById('settings');
      if (serverMenu) serverMenu.style.display = 'none';
      if (settings) settings.style.display = 'none';

      document.addEventListener('click', event => {
        if (!app.dataset.guest) return;
        if (event.target.closest('#send,#messageInput,#serverMenu,#settings,#addChannel,.channel .x,.server.add')) {
          event.preventDefault();
          event.stopPropagation();
        }
      }, true);
    });
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupGuestMode, { once: true });
  } else {
    setupGuestMode();
  }
}
