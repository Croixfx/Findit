const express = require('express');
const router = express.Router();
const Item = require('../models/Item');
const verifyToken = require('../middleware/auth');

// POST /api/v1/items — staff only
router.post('/', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'staff') {
      return res.status(403).json({ error: 'Only staff can log items' });
    }

    const { title, category, description, color, brand, condition, dateFound, locationFound, storageReference, photos } = req.body;

    if (!title) {
      return res.status(400).json({ error: 'title is required' });
    }

    const item = await Item.create({
      institution: req.user.institution,
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

// GET /api/v1/items — public, available items with filters
router.get('/', async (req, res) => {
  try {
    const { category, keyword, dateFrom, dateTo } = req.query;
    const filter = { status: 'available' };

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
      .populate('institution', 'name')
      .sort({ createdAt: -1 });

    res.json(items);
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
