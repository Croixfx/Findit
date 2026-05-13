const express = require('express');
const router = express.Router();
const User = require('../models/User');
const verifyToken = require('../middleware/auth');

// POST /api/v1/auth/register
router.post('/register', async (req, res) => {
  try {
    const {
      firebase_uid,
      email,
      full_name,
      fullName,
      role,
      institution_id,
      institutionId
    } = req.body;

    if (!firebase_uid || !email || !role) {
      return res.status(400).json({ error: 'firebase_uid, email, and role are required' });
    }

    if (!['staff', 'owner'].includes(role)) {
      return res.status(400).json({ error: 'role must be either staff or owner' });
    }

    let user = await User.findOne({ firebaseUid: firebase_uid });

    if (user) {
      return res.status(409).json({ error: 'User already exists', user });
    }

    const normalizedRole = String(role).toLowerCase();
    const accountStatus = normalizedRole === 'owner' ? 'active' : 'pending';

    user = await User.create({
      firebaseUid: firebase_uid,
      email,
      fullName: full_name || fullName || email.split('@')[0],
      role: normalizedRole,
      accountStatus,
      institution: institution_id || institutionId || null
    });

    res.status(201).json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/v1/auth/me
router.post('/me', verifyToken, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).populate('institution');
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
