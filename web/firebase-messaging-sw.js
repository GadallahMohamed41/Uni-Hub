importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDiCrvL9XDVaItRkwG7iamV7jrY5sVzHDc',
  authDomain: 'university-connect-52779.firebaseapp.com',
  projectId: 'university-connect-52779',
  storageBucket: 'university-connect-52779.firebasestorage.app',
  messagingSenderId: '201349891361',
  appId: '1:201349891361:web:351852060e565fcdd6ea60',
  measurementId: 'G-0BXGB1NC54',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(() => {});

