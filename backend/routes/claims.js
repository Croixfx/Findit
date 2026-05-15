const express = require('express');
const router = express.Router();
const Claim = require('../models/Claim');
const Item = require('../models/Item');
const User = require('../models/User');
const verifyToken = require('../middleware/auth');
const { sendNotification } = require('../utils/notify');

// Notification payloads for each claim status transition
function _claimNotif(status, itemTitle, rejectionReason) {
  const map = {
    under_review: {
      title: 'Claim Under Review',
      body: `Your claim for "${itemTitle}" is being reviewed.`,
      type: 'claim_under_review',
    },
    approved: {
      title: 'Claim Approved',
      body: `Your claim for "${itemTitle}" is approved. Chat with the institution to arrange pickup.`,
      type: 'claim_approved',
    },
    rejected: {
      title: 'Claim Rejected',
      body: rejectionReason
        ? `Your claim for "${itemTitle}" was rejected: ${rejectionReason}`
        : `Your claim for "${itemTitle}" was not approved.`,
      type: 'claim_rejected',
    },
    returned: {
      title: 'Item Ready — Confirm Receipt',
      body: `"${itemTitle}" has been handed back. Please confirm receipt in the app.`,
      type: 'claim_returned',
    },
  };
  return map[status] || null;
}

// Sync item status when a claim status changes
async function _syncItemStatus(itemId, claimStatus) {
  const itemStatusMap = {
    approved: 'ready_for_pickup',
    returned: 'returned',
  };
  const newItemStatus = itemStatusMap[claimStatus];
  if (newItemStatus) {
    await Item.findByIdAndUpdate(itemId, { status: newItemStatus });
  }
}

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

    if (['returned', 'rejected'].includes(claim.status)) {
      return res.status(400).json({ error: `Claim is already ${claim.status} and cannot be modified.` });
    }
    if (claim.ownerConfirmed) {
      return res.status(400).json({ error: 'Claim is closed — owner has already confirmed receipt.' });
    }

    const item = await Item.findById(claim.item);
    if (!item || !req.user.institution || !req.user.institution.equals(item.institution)) {
      return res.status(403).json({ error: 'You can only update claims for your institution\'s items' });
    }

    claim.status = status;
    if (status === 'rejected' && rejectionReason) claim.rejectionReason = rejectionReason;
    claim.reviewedBy = req.user._id;
    claim.reviewedAt = new Date();
    await claim.save();

    // Auto-sync item status
    await _syncItemStatus(item._id, status);

    res.json(claim);

    // Notify claim owner of the status change
    if (claim.claimant) {
      try {
        const notif = _claimNotif(status, item.title, rejectionReason);
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

// PATCH /api/v1/claims/:id/confirm — owner confirms physical receipt
router.patch('/:id/confirm', verifyToken, async (req, res) => {
  try {
    if (req.user.role !== 'owner') {
      return res.status(403).json({ error: 'Only owners can confirm receipt' });
    }

    const claim = await Claim.findById(req.params.id);
    if (!claim) return res.status(404).json({ error: 'Claim not found' });

    if (claim.claimant.toString() !== req.user._id.toString()) {
      return res.status(403).json({ error: 'You can only confirm your own claims' });
    }

    if (claim.status !== 'returned') {
      return res.status(400).json({ error: 'Item must be marked as returned before confirming receipt' });
    }

    if (claim.ownerConfirmed) {
      return res.status(409).json({ error: 'Receipt already confirmed' });
    }

    claim.ownerConfirmed = true;
    claim.confirmedAt = new Date();
    await claim.save();

    res.json(claim);

    // Notify institution staff that owner confirmed
    try {
      const item = await Item.findById(claim.item);
      const staffUsers = await User.find({ institution: item?.institution, role: 'staff' });
      await Promise.all(staffUsers.map(s =>
        sendNotification(s, {
          title: 'Receipt Confirmed',
          body: `The owner confirmed receiving "${item?.title ?? 'the item'}".`,
          type: 'owner_confirmed',
          data: { claimId: claim._id.toString() },
        })
      ));
    } catch (notifyErr) {
      console.error('Notify staff on confirm error:', notifyErr.message);
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
