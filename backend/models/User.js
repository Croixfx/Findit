const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  firebaseUid: { type: String, required: true, unique: true },
  email: { type: String, required: true, unique: true },
  fullName: { type: String, required: true },
  phone: { type: String },
  role: { type: String, enum: ['staff', 'owner'], required: true },
  institution: { type: mongoose.Schema.Types.ObjectId, ref: 'Institution', default: null },
  profilePictureUrl: { type: String },
  fcmToken: { type: String }
}, { timestamps: true });

module.exports = mongoose.model('User', userSchema);
