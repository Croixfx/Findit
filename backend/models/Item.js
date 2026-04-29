const mongoose = require('mongoose');

const itemSchema = new mongoose.Schema({
  institution: { type: mongoose.Schema.Types.ObjectId, ref: 'Institution', required: true },
  loggedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true },
  description: { type: String },
  category: { type: String },
  color: { type: String },
  brand: { type: String },
  condition: { type: String },
  locationFound: { type: String },
  dateFound: { type: Date },
  storageReference: { type: String },
  photos: [{ type: String }],
  status: {
    type: String,
    enum: ['available', 'claimed', 'ready_for_pickup', 'returned', 'discarded'],
    default: 'available'
  }
}, { timestamps: true });

module.exports = mongoose.model('Item', itemSchema);
