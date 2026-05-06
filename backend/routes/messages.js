const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const Claim = require('../models/Claim');
const Item = require('../models/Item');
const verifyToken = require('../middleware/auth');

async function canAccessClaim(user, claim) {
  if (claim.claimant.toString() === user._id.toString()) return true;
  if (user.role === 'staff' && user.institution) {
    const item = await Item.findById(claim.item).select('institution');
    if (item && user.institution.equals(item.institution)) return true;
  }
  return false;
}

// GET /api/v1/messages/:claimId — claimant or institution staff only
router.get('/:claimId', verifyToken, async (req, res) => {
  try {
    const claim = await Claim.findById(req.params.claimId);
    if (!claim) return res.status(404).json({ error: 'Claim not found' });

    if (!await canAccessClaim(req.user, claim)) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const messages = await Message.find({ claim: req.params.claimId })
      .populate('sender', 'fullName profilePictureUrl role')
      .sort({ createdAt: 1 });

    res.json(messages);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/v1/messages/:claimId — approved claims only
router.post('/:claimId', verifyToken, async (req, res) => {
  try {
    const claim = await Claim.findById(req.params.claimId);
    if (!claim) return res.status(404).json({ error: 'Claim not found' });

    if (claim.status !== 'approved') {
      return res.status(403).json({ error: 'Messaging is only available for approved claims' });
    }

    if (!await canAccessClaim(req.user, claim)) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const { content } = req.body;
    if (!content) return res.status(400).json({ error: 'content is required' });

    const message = await Message.create({
      claim: req.params.claimId,
      sender: req.user._id,
      content
    });

    await message.populate('sender', 'fullName profilePictureUrl role');
    res.status(201).json(message);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
