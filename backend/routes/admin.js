const express = require('express');
const router = express.Router();
const Institution = require('../models/Institution');
const Item = require('../models/Item');
const Claim = require('../models/Claim');
const User = require('../models/User');
const verifyToken = require('../middleware/auth');

function requireAdmin(req, res, next) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
}

// GET /api/v1/admin/institutions
router.get('/institutions', verifyToken, requireAdmin, async (req, res) => {
  try {
    const institutions = await Institution.find().sort({ createdAt: -1 });
    res.json(institutions);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/admin/institutions/:id
router.patch('/institutions/:id', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { status } = req.body;
    if (!status || !['active', 'suspended'].includes(status)) {
      return res.status(400).json({ error: 'status must be active or suspended' });
    }

    const institution = await Institution.findByIdAndUpdate(
      req.params.id,
      { status },
      { new: true }
    );

    if (!institution) return res.status(404).json({ error: 'Institution not found' });
    res.json(institution);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/admin/users
router.get('/users', verifyToken, requireAdmin, async (req, res) => {
  try {
    const users = await User.find()
      .populate('institution', 'name type')
      .sort({ createdAt: -1 });
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/admin/users/:id
router.patch('/users/:id', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { suspended } = req.body;
    if (typeof suspended !== 'boolean') {
      return res.status(400).json({ error: 'suspended must be a boolean' });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { suspended },
      { new: true }
    ).populate('institution', 'name type');

    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/admin/stats
router.get('/stats', verifyToken, requireAdmin, async (req, res) => {
  try {
    const [institutions, items, claims, successfulReturns, users] = await Promise.all([
      Institution.countDocuments(),
      Item.countDocuments(),
      Claim.countDocuments(),
      Claim.countDocuments({ status: 'returned' }),
      User.countDocuments()
    ]);

    res.json({ institutions, items, claims, successfulReturns, users });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
