const express = require('express');
const router = express.Router();
const Institution = require('../models/Institution');

// POST /api/v1/institutions
router.post('/', async (req, res) => {
  try {
    const { name, type, address, email, phone } = req.body;

    if (!name || !type) {
      return res.status(400).json({ error: 'name and type are required' });
    }

    const institution = await Institution.create({ name, type, address, email, phone });
    res.status(201).json(institution);
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
