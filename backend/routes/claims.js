const express = require('express');
const router = express.Router();
const Claim = require('../models/Claim');
const Item = require('../models/Item');
const User = require('../models/User');
const verifyToken = require('../middleware/auth');
const { sendNotification } = require('../utils/notify');

// POST /api/v1/claims — owner only
router.post('/', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'owner') {
      return res.status(403).json({ error: 'Only owners can submit claims' });
    }

    const { itemId, ownershipDescription, proofImageUrl } = req.body;
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
      proofDescription: ownershipDescription,
      ...(proofImageUrl ? { proofImageUrl } : {}),
    });

    res.status(201).json(claim);

    // Notify all staff in the item's institution
    try {
      const staffUsers = await User.find({ institution: item.institution, role: 'staff' });
      await Promise.all(staffUsers.map(s =>
        sendNotification(s, {
          title: 'New Claim Submitted',
          body: `A claim was submitted for "${item.title}"`,
          type: 'new_claim',
          data: { claimId: claim._id.toString(), itemId: item._id.toString() },
        })
      ));
    } catch (notifyErr) {
      console.error('Notify staff error:', notifyErr.message);
    }
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

    res.json(claim);

    // Notify claim owner of the status change
    if (claim.claimant) {
      try {
        const notifications = {
          under_review: {
            title: 'Claim Under Review',
            body: `Your claim for "${item.title}" is being reviewed.`,
            type: 'claim_under_review',
          },
          approved: {
            title: 'Claim Approved',
            body: `Your claim for "${item.title}" has been approved. You can now chat with the institution.`,
            type: 'claim_approved',
          },
          rejected: {
            title: 'Claim Rejected',
            body: rejectionReason
              ? `Your claim for "${item.title}" was rejected: ${rejectionReason}`
              : `Your claim for "${item.title}" was rejected.`,
            type: 'claim_rejected',
          },
          returned: {
            title: 'Item Returned',
            body: `Congratulations! "${item.title}" has been marked as returned to you.`,
            type: 'claim_returned',
          },
        };

        const notif = notifications[status];
        if (notif) {
          await sendNotification(claim.claimant, {
            ...notif,
            data: { claimId: claim._id.toString() },
          });
        }
      } catch (notifyErr) {
        console.error('Notify owner error:', notifyErr.message);
      }
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
