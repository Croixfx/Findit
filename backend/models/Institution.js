const mongoose = require('mongoose');

const institutionSchema = new mongoose.Schema({
  name: { type: String, required: true },
  type: {
    type: String,
    enum: ['hotel', 'university', 'hospital', 'office', 'other'],
    required: true
  },
  address: { type: String },
  contactEmail: { type: String },
  phone: { type: String },
  createdByStaff: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  logoUrl: { type: String },
  status: { type: String, enum: ['pending', 'active', 'suspended'], default: 'pending' }
}, { timestamps: true });

module.exports = mongoose.model('Institution', institutionSchema);
