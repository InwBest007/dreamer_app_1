// // config เอาไว้เชื่อมกับฐานข้อมูล
// const admin = require("firebase-admin");
// const serviceAccount = require("./serviceAccountKey.json");

// admin.initializeApp({
//     credential: admin.credential.cert(serviceAccount),
// });
// const db = admin.firestore();
// module.exports = db;
// Import the functions you need from the SDKs you need

const firebase = require("firebase/compat/app");
require("firebase/compat/firestore");

const firebaseConfig = {
  apiKey: "AIzaSyBZxc5nkGDD6sC1N0eNSAy2ptJ7GB1Ya0g",
  authDomain: "dreamerdb-b0dc4.firebaseapp.com",
  projectId: "dreamerdb-b0dc4",
  storageBucket: "dreamerdb-b0dc4.appspot.com", // ✅ แก้จาก .firebasestorage.app
  messagingSenderId: "616465545953",
  appId: "1:616465545953:web:7a581f9e582b565d12d5a0"
};

if (!firebase.apps.length) {
  firebase.initializeApp(firebaseConfig);
}

const db = firebase.firestore();
module.exports = db;
