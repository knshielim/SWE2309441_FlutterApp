const admin = require('firebase-admin');
const { getMessaging } = require('firebase-admin/messaging');

// Replace with your service account key path
const serviceAccount = require('./firebase-adminsdk.json');

admin.initializeApp({
  credential: admin.cert(serviceAccount)
});

const fcmToken = 'edGKZGN0SYGFXpwy4976fp:APA91bHKnDKDkfPxCSLpXUv5dx0e5FHaRW1fKJbQFC2ZvH5CGst6izhWFeTrorHjAMeP1alPqgyrXnw7QP5Zh38ZQeL9RhycM6KDO2RnQALfqtPGLx3Ugmo';

const message = {
  notification: {
    title: 'Test Notification',
    body: 'Hello from HavaPaw! This is a test notification.'
  },
  token: fcmToken
};

getMessaging().send(message)
  .then((response) => {
    console.log('Successfully sent message:', response);
  })
  .catch((error) => {
    console.log('Error sending message:', error);
  });
