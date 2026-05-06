const express = require('express');
const router = express.Router();
const Claim = require('../models/Claim');
const Item = require('../models/Item');
const Notification = require('../models/Notification');
const verifyToken = require('../middleware/auth');
const admin = require('../config/firebase');

// POST /api/v1/claims — owner only
router.post('/', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'owner') {
      return res.status(403).json({ error: 'Only owners can submit claims' });
    }

    const { itemId, ownershipDescription } = req.body;
    if (!itemId) return res.status(400).json({ error: 'itemId is required' });

    const item = await Item.findById(itemId);
    if (!item) return res.status(404).json({ error: 'Item not found' });

    const existing = await Claim.findOne({ item: itemId, claimant: req.user._id });
    if (existing) {
      return res.status(409).json({ error: 'You already have a claim for this item' });
    }

    const claim = await Claim.create({
      item: itemId,
      claimant: req.user._id,
      proofDescription: ownershipDescription
    });

    res.status(201).json(claim);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/claims/my — owner only
router.get('/my', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'owner') {
      return res.status(403).json({ error: 'Only owners can view their claims' });
    }

    const claims = await Claim.find({ claimant: req.user._id })
      .populate({ path: 'item', populate: { path: 'institution', select: 'name type address' } })
      .sort({ createdAt: -1 });

    res.json(claims);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/claims/institution — staff only
router.get('/institution', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'staff') {
      return res.status(403).json({ error: 'Only staff can view institution claims' });
    }

    const items = await Item.find({ institution: req.user.institution }).select('_id');
    const itemIds = items.map(i => i._id);

    const claims = await Claim.find({ item: { $in: itemIds } })
      .populate('item')
      .populate('claimant', 'fullName email phone')
      .sort({ createdAt: -1 });

    res.json(claims);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/claims/:id — authenticated
router.get('/:id', verifyToken, async (req, res) => {
  try {
    const claim = await Claim.findById(req.params.id)
      .populate('item')
      .populate('claimant', 'fullName email phone');

    if (!claim) return res.status(404).json({ error: 'Claim not found' });
    res.json(claim);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/claims/:id/status — staff only
router.patch('/:id/status', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'staff') {
      return res.status(403).json({ error: 'Only staff can update claim status' });
    }

    const { status, rejectionReason } = req.body;
    const validStatuses = ['submitted', 'under_review', 'approved', 'rejected', 'returned'];
    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({ error: `status must be one of: ${validStatuses.join(', ')}` });
    }

    const claim = await Claim.findById(req.params.id).populate('claimant');
    if (!claim) return res.status(404).json({ error: 'Claim not found' });

    const item = await Item.findById(claim.item);
    if (!item || !req.user.institution || !req.user.institution.equals(item.institution)) {
      return res.status(403).json({ error: 'You can only update claims for your institution\'s items' });
    }

    claim.status = status;
    if (status === 'rejected' && rejectionReason) claim.rejectionReason = rejectionReason;
    claim.reviewedBy = req.user._id;
    claim.reviewedAt = new Date();
    await claim.save();

    if (status === 'approved' && claim.claimant?.fcmToken) {
      try {
        const notification = await Notification.create({
          user: claim.claimant._id,
          title: 'Claim Approved',
          body: 'Your claim has been approved. You can now chat with the institution.',
          type: 'claim_approved'
        });

        await admin.messaging().send({
          token: claim.claimant.fcmToken,
          notification: { title: notification.title, body: notification.body },
          data: { type: 'claim_approved', claimId: claim._id.toString() }
        });
      } catch (fcmError) {
        console.error('FCM send error:', fcmError.message);
      }
    }

    res.json(claim);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
