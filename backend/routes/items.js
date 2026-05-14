const express = require('express');
const router = express.Router();
const Item = require('../models/Item');
const Institution = require('../models/Institution');
const verifyToken = require('../middleware/auth');

// POST /api/v1/items — staff only
router.post('/', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'staff') {
      return res.status(403).json({ error: 'Only staff can log items' });
    }

    if (req.user.accountStatus === 'suspended' || req.user.accountStatus === 'rejected') {
      return res.status(403).json({ error: 'Your account has been suspended or rejected.' });
    }

    if (!req.user.institution) {
      return res.status(403).json({ error: 'You must be assigned to an institution before logging items.' });
    }

    const institution = await Institution.findById(req.user.institution);
    if (!institution) {
      return res.status(403).json({ error: 'Your assigned institution was not found.' });
    }

    if (institution.status !== 'active') {
      return res.status(403).json({ error: 'Your institution is not active. Item logging is disabled until approval.' });
    }

    const { title, category, description, color, brand, condition, dateFound, locationFound, storageReference, photos } = req.body;

    if (!title) {
      return res.status(400).json({ error: 'title is required' });
    }

    const item = await Item.create({
      institution: institution._id,
      loggedBy: req.user._id,
      title,
      category,
      description,
      color,
      brand,
      condition,
      dateFound,
      locationFound,
      storageReference,
      photos: photos || []
    });

    res.status(201).json(item);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/items/mine — staff: all items for their institution (all statuses)
router.get('/mine', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'staff') {
      return res.status(403).json({ error: 'Staff only' });
    }
    if (!req.user.institution) {
      return res.json([]);
    }
    const items = await Item.find({ institution: req.user.institution })
      .populate('institution', 'name type')
      .populate('loggedBy', 'fullName')
      .sort({ createdAt: -1 });
    res.json(items);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/items — public, available items with filters
router.get('/', async (req, res) => {
  try {
    const { category, keyword, dateFrom, dateTo, institution } = req.query;
    const filter = { status: 'available' };

    if (institution) {
      filter.institution = institution;
    }

    if (category) {
      filter.category = category;
    }

    if (keyword) {
      filter.$or = [
        { title: { $regex: keyword, $options: 'i' } },
        { description: { $regex: keyword, $options: 'i' } }
      ];
    }

    if (dateFrom || dateTo) {
      filter.dateFound = {};
      if (dateFrom) filter.dateFound.$gte = new Date(dateFrom);
      if (dateTo) filter.dateFound.$lte = new Date(dateTo);
    }

    const items = await Item.find(filter)
      .populate('institution', 'name type')
      .sort({ createdAt: -1 });

    res.json(items);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/items/:id — staff: update item for their institution
router.patch('/:id', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'staff') {
      return res.status(403).json({ error: 'Staff only' });
    }
    const item = await Item.findById(req.params.id);
    if (!item) return res.status(404).json({ error: 'Item not found' });
    if (!item.institution.equals(req.user.institution)) {
      return res.status(403).json({ error: 'You can only update items from your institution' });
    }
    const allowed = ['title', 'description', 'category', 'color', 'brand',
      'condition', 'locationFound', 'storageReference', 'status', 'photos'];
    const payload = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) payload[key] = req.body[key];
    }
    const updated = await Item.findByIdAndUpdate(req.params.id, payload, { new: true })
      .populate('institution', 'name type');
    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/items/:id
router.get('/:id', async (req, res) => {
  try {
    const item = await Item.findById(req.params.id).populate('institution');

    if (!item) {
      return res.status(404).json({ error: 'Item not found' });
    }

    res.json(item);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
