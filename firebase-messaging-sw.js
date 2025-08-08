// Importa lo script di Firebase Messaging
importScripts('https://www.gstatic.com/firebasejs/11.8.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.8.1/firebase-messaging-compat.js');

// Configurazione del tuo progetto Firebase
firebase.initializeApp({
  apiKey: "INSERISCI_API_KEY",
  authDomain: "INSERISCI_DOMINIO.firebaseapp.com",
  projectId: "INSERISCI_PROJECT_ID",
  storageBucket: "INSERISCI_BUCKET.appspot.com",
  messagingSenderId: "INSERISCI_SENDER_ID",
  appId: "INSERISCI_APP_ID",
});

// Inizializza Messaging
const messaging = firebase.messaging();

// Gestione messaggi in background
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Messaggio ricevuto in background:', payload);

  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: '/icona.png' // opzionale
  });
});
