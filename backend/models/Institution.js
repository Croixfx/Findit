const mongoose = require('mongoose');

const institutionSchema = new mongoose.Schema({
  name: { type: String, required: true },
  type: {
    type: String,
    enum: ['hotel', 'university', 'hospital', 'office', 'other'],
    required: true
  },
  address: { type: String },
  email: { type: String },
  phone: { type: String },
  logoUrl: { type: String },
  status: { type: String, enum: ['active', 'suspended'], default: 'active' }
}, { timestamps: true });

module.exports = mongoose.model('Institution', institutionSchema);
