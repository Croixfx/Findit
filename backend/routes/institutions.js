const express = require('express');
const router = express.Router();
const Institution = require('../models/Institution');
const User = require('../models/User');
const verifyToken = require('../middleware/auth');

// POST /api/v1/institutions
router.post('/', verifyToken, async (req, res) => {
  try {
    const { name, type, address, contactEmail, phone } = req.body;

    if (req.user.role !== 'staff') {
      return res.status(403).json({ error: 'Only staff can create institutions' });
    }

    if (req.user.institution) {
      const linkedInstitution = await Institution.findById(req.user.institution);
      return res.status(409).json({
        error: 'Staff is already linked to an institution',
        institution: linkedInstitution
      });
    }

    if (!name || !type) {
      return res.status(400).json({ error: 'name and type are required' });
    }

    const institution = await Institution.create({
      name,
      type,
      address,
      contactEmail,
      phone,
      createdByStaff: req.user._id
    });

    // Link the new institution to the requesting user
    await User.findByIdAndUpdate(req.user._id, { institution: institution._id });

    res.status(201).json(institution);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/institutions/my — staff edits own institution
router.patch('/my', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'staff') {
      return res.status(403).json({ error: 'Only staff can edit their institution' });
    }
    if (!req.user.institution) {
      return res.status(404).json({ error: 'No institution linked to your account' });
    }
    const allowed = ['name', 'type', 'address', 'contactEmail', 'phone'];
    const payload = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) payload[key] = req.body[key];
    }
    if (Object.keys(payload).length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }
    const institution = await Institution.findByIdAndUpdate(
      req.user.institution, payload, { new: true }
    );
    if (!institution) return res.status(404).json({ error: 'Institution not found' });
    res.json(institution);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/v1/institutions/my — staff deletes own institution
router.delete('/my', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'staff') {
      return res.status(403).json({ error: 'Only staff can delete their institution' });
    }
    if (!req.user.institution) {
      return res.status(404).json({ error: 'No institution linked to your account' });
    }
    await Institution.findByIdAndDelete(req.user.institution);
    await User.findByIdAndUpdate(req.user._id, { institution: null, accountStatus: 'pending' });
    res.json({ message: 'Institution deleted. Your account has been reset.' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/institutions/my
router.get('/my', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'staff') {
      return res.status(403).json({ error: 'Only staff can access linked institution' });
    }
    if (!req.user.institution) {
      return res.status(404).json({ error: 'No institution linked to this staff account' });
    }

    const institution = await Institution.findById(req.user.institution);
    if (!institution) {
      return res.status(404).json({ error: 'Linked institution not found' });
    }

    res.json(institution);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/institutions
router.get('/', async (req, res) => {
  try {
    const institutions = await Institution.find();
    res.json(institutions);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/institutions/:id
router.get('/:id', async (req, res) => {
  try {
    const institution = await Institution.findById(req.params.id);

    if (!institution) {
      return res.status(404).json({ error: 'Institution not found' });
    }

    res.json(institution);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
