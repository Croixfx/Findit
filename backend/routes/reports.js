const express = require('express');
const router = express.Router();
const Report = require('../models/Report');
const verifyToken = require('../middleware/auth');

// POST /api/v1/reports
router.post('/', verifyToken, async (req, res) => {
  try {
    const { targetType, targetId, reason, description } = req.body;

    if (!targetType || !['item', 'user'].includes(targetType)) {
      return res.status(400).json({ error: 'targetType must be item or user' });
    }
    if (!targetId) return res.status(400).json({ error: 'targetId is required' });
    if (!reason) return res.status(400).json({ error: 'reason is required' });

    const report = await Report.create({
      reportedBy: req.user._id,
      targetType,
      targetId,
      reason,
      description
    });

    res.status(201).json(report);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
