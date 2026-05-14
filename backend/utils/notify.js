const admin = require('../config/firebase');
const Notification = require('../models/Notification');

async function sendNotification(user, { title, body, type, data = {} }) {
  await Notification.create({ user: user._id, title, body, type });

  if (user.fcmToken) {
    try {
      const stringData = Object.fromEntries(
        Object.entries({ type, ...data }).map(([k, v]) => [k, String(v)])
      );
      await admin.messaging().send({
        token: user.fcmToken,
        notification: { title, body },
        data: stringData,
      });
    } catch (err) {
      console.error('FCM send error:', err.message);
    }
  }
}

module.exports = { sendNotification };
