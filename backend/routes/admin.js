const express = require('express');
const router = express.Router();
const Institution = require('../models/Institution');
const Item = require('../models/Item');
const Claim = require('../models/Claim');
const User = require('../models/User');
const verifyToken = require('../middleware/auth');
const firebaseAdmin = require('../config/firebase');

function requireAdmin(req, res, next) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
}

const ALLOWED_ROLES = ['owner', 'staff', 'admin'];
const ALLOWED_INSTITUTION_STATUS = ['pending', 'active', 'suspended'];

// GET /api/v1/admin/institutions
router.get('/institutions', verifyToken, requireAdmin, async (req, res) => {
  try {
    const institutions = await Institution.find()
      .populate('createdByStaff', 'fullName email')
      .sort({ createdAt: -1 });
    res.json(institutions);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/v1/admin/institutions
router.post('/institutions', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { name, type, address, contactEmail, phone, status, createdByStaffId } = req.body;
    if (!name || !type) {
      return res.status(400).json({ error: 'name and type are required' });
    }
    if (status && !ALLOWED_INSTITUTION_STATUS.includes(String(status).toLowerCase())) {
      return res.status(400).json({ error: 'invalid institution status' });
    }

    let creator = null;
    if (createdByStaffId) {
      creator = await User.findById(createdByStaffId);
      if (!creator) {
        return res.status(404).json({ error: 'Creator staff user not found' });
      }
      if (creator.role !== 'staff') {
        return res.status(400).json({ error: 'createdByStaffId must belong to a staff user' });
      }
      if (creator.institution) {
        return res.status(409).json({ error: 'Staff creator is already linked to another institution' });
      }
    }

    const institution = await Institution.create({
      name,
      type,
      address,
      contactEmail,
      phone,
      status: status ? String(status).toLowerCase() : undefined,
      createdByStaff: createdByStaffId || null
    });

    if (creator) {
      creator.institution = institution._id;
      await creator.save();
    }

    res.status(201).json(institution);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/admin/institutions/:id
router.patch('/institutions/:id', verifyToken, requireAdmin, async (req, res) => {
  try {
    const payload = {};
    const allowed = ['name', 'type', 'address', 'contactEmail', 'phone', 'status'];
    for (const key of allowed) {
      if (req.body[key] !== undefined) payload[key] = req.body[key];
    }
    if (payload.status !== undefined) {
      const normalizedStatus = String(payload.status).toLowerCase();
      if (!ALLOWED_INSTITUTION_STATUS.includes(normalizedStatus)) {
        return res.status(400).json({ error: 'status must be pending, active, or suspended' });
      }
      payload.status = normalizedStatus;
    }
    if (Object.keys(payload).length === 0) {
      return res.status(400).json({ error: 'No valid fields provided for update' });
    }

    const institution = await Institution.findByIdAndUpdate(
      req.params.id,
      payload,
      { new: true }
    );

    if (!institution) return res.status(404).json({ error: 'Institution not found' });
    res.json(institution);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/v1/admin/institutions/:id
router.delete('/institutions/:id', verifyToken, requireAdmin, async (req, res) => {
  try {
    const institution = await Institution.findByIdAndDelete(req.params.id);
    if (!institution) {
      return res.status(404).json({ error: 'Institution not found' });
    }

    await User.updateMany({ institution: institution._id }, { $set: { institution: null } });
    res.json({ message: 'Institution deleted and linked users unassigned' });
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

// POST /api/v1/admin/users
router.post('/users', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { email, fullName, password, phone } = req.body;

    if (!email || !fullName || !password) {
      return res.status(400).json({ error: 'email, fullName, and password are required' });
    }

    const existing = await User.findOne({ email });
    if (existing) {
      return res.status(409).json({ error: 'A user with this email already exists' });
    }

    let firebaseUser;
    try {
      firebaseUser = await firebaseAdmin.auth().createUser({
        email,
        displayName: fullName,
        password,
        emailVerified: false,
      });
    } catch (firebaseError) {
      const code = firebaseError.code || '';
      if (code === 'auth/email-already-exists') {
        return res.status(409).json({ error: 'A Firebase account with this email already exists' });
      }
      if (code === 'auth/invalid-password') {
        return res.status(400).json({ error: 'Password must be at least 6 characters' });
      }
      return res.status(500).json({ error: firebaseError.message });
    }

    try {
      const user = await User.create({
        firebaseUid: firebaseUser.uid,
        email,
        fullName,
        role: 'owner',
        accountStatus: 'active',
        phone: phone || undefined,
        institution: null,
        suspended: false,
      });
      const populated = await User.findById(user._id).populate('institution', 'name type status');
      res.status(201).json(populated);
    } catch (dbError) {
      await firebaseAdmin.auth().deleteUser(firebaseUser.uid).catch(() => {});
      throw dbError;
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/admin/users/:id
router.patch('/users/:id', verifyToken, requireAdmin, async (req, res) => {
  try {
    const payload = {};
    const allowed = ['fullName', 'email', 'phone', 'suspended', 'role', 'institutionId'];
    for (const key of allowed) {
      if (req.body[key] !== undefined) payload[key] = req.body[key];
    }

    if (payload.role !== undefined) {
      const normalizedRole = String(payload.role).toLowerCase();
      if (!ALLOWED_ROLES.includes(normalizedRole)) {
        return res.status(400).json({ error: 'invalid role value' });
      }
      payload.role = normalizedRole;
    }
    if (payload.suspended !== undefined && typeof payload.suspended !== 'boolean') {
      return res.status(400).json({ error: 'suspended must be a boolean' });
    }
    if (payload.institutionId !== undefined) {
      if (payload.institutionId) {
        const institution = await Institution.findById(payload.institutionId);
        if (!institution) {
          return res.status(404).json({ error: 'Institution not found' });
        }
      }
      payload.institution = payload.institutionId || null;
      delete payload.institutionId;
    }
    if (Object.keys(payload).length === 0) {
      return res.status(400).json({ error: 'No valid fields provided for update' });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      payload,
      { new: true }
    ).populate('institution', 'name type status');

    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/v1/admin/users/:id
router.delete('/users/:id', verifyToken, requireAdmin, async (req, res) => {
  try {
    const user = await User.findByIdAndDelete(req.params.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ message: 'User deleted' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/admin/staff
router.get('/staff', verifyToken, requireAdmin, async (req, res) => {
  try {
    const staff = await User.find({ role: 'staff' })
      .populate('institution', 'name type status')
      .sort({ createdAt: -1 });
    res.json(staff);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/admin/staff/:id/approve
router.patch('/staff/:id/approve', verifyToken, requireAdmin, async (req, res) => {
  try {
    const staff = await User.findOneAndUpdate(
      { _id: req.params.id, role: 'staff' },
      { accountStatus: 'active' },
      { new: true }
    ).populate('institution', 'name type status');

    if (!staff) return res.status(404).json({ error: 'Staff not found' });
    res.json(staff);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/admin/staff/:id/reject
router.patch('/staff/:id/reject', verifyToken, requireAdmin, async (req, res) => {
  try {
    const staff = await User.findOneAndUpdate(
      { _id: req.params.id, role: 'staff' },
      { accountStatus: 'rejected' },
      { new: true }
    ).populate('institution', 'name type status');

    if (!staff) return res.status(404).json({ error: 'Staff not found' });
    res.json(staff);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/admin/staff/:id/assign-institution
router.patch('/staff/:id/assign-institution', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { institutionId } = req.body;
    if (!institutionId) {
      return res.status(400).json({ error: 'institutionId is required' });
    }

    const institution = await Institution.findById(institutionId);
    if (!institution) {
      return res.status(404).json({ error: 'Institution not found' });
    }

    const staff = await User.findOneAndUpdate(
      { _id: req.params.id, role: 'staff' },
      { institution: institutionId },
      { new: true }
    ).populate('institution', 'name type status');

    if (!staff) return res.status(404).json({ error: 'Staff not found' });
    res.json(staff);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/v1/admin/staff/promote
router.post('/staff/promote', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { userId, institutionId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId is required' });

    const updates = { role: 'staff' };
    if (institutionId !== undefined) {
      if (institutionId) {
        const institution = await Institution.findById(institutionId);
        if (!institution) {
          return res.status(404).json({ error: 'Institution not found' });
        }
      }
      updates.institution = institutionId || null;
    }

    const user = await User.findByIdAndUpdate(userId, updates, { new: true })
      .populate('institution', 'name type status');
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PATCH /api/v1/admin/staff/:id
router.patch('/staff/:id', verifyToken, requireAdmin, async (req, res) => {
  try {
    const payload = {};
    const allowed = ['fullName', 'email', 'phone', 'suspended', 'institutionId'];
    for (const key of allowed) {
      if (req.body[key] !== undefined) payload[key] = req.body[key];
    }
    if (payload.suspended !== undefined && typeof payload.suspended !== 'boolean') {
      return res.status(400).json({ error: 'suspended must be a boolean' });
    }
    if (payload.institutionId !== undefined) {
      if (payload.institutionId) {
        const institution = await Institution.findById(payload.institutionId);
        if (!institution) {
          return res.status(404).json({ error: 'Institution not found' });
        }
      }
      payload.institution = payload.institutionId || null;
      delete payload.institutionId;
    }

    const user = await User.findOneAndUpdate(
      { _id: req.params.id, role: 'staff' },
      payload,
      { new: true }
    ).populate('institution', 'name type status');
    if (!user) return res.status(404).json({ error: 'Staff not found' });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/v1/admin/staff/:id
router.delete('/staff/:id', verifyToken, requireAdmin, async (req, res) => {
  try {
    const staff = await User.findOneAndUpdate(
      { _id: req.params.id, role: 'staff' },
      { role: 'owner', institution: null },
      { new: true }
    ).populate('institution', 'name type status');
    if (!staff) return res.status(404).json({ error: 'Staff not found' });
    res.json({ message: 'Staff demoted to owner and unlinked from institution' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/v1/admin/staff/:id/approval
router.post('/staff/:id/approval', verifyToken, requireAdmin, async (req, res) => {
  try {
    const { action, institutionId } = req.body;
    if (!action || !['approve', 'reject'].includes(String(action).toLowerCase())) {
      return res.status(400).json({ error: 'action must be approve or reject' });
    }

    const staff = await User.findOne({ _id: req.params.id, role: 'staff' });
    if (!staff) return res.status(404).json({ error: 'Staff not found' });

    const targetInstitutionId = institutionId || staff.institution;
    if (!targetInstitutionId) {
      return res.status(400).json({ error: 'staff has no linked institution' });
    }

    const status = String(action).toLowerCase() === 'approve' ? 'active' : 'suspended';
    const institution = await Institution.findByIdAndUpdate(
      targetInstitutionId,
      { status },
      { new: true }
    );
    if (!institution) return res.status(404).json({ error: 'Institution not found' });

    res.json({ message: `Institution ${status}`, institution });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/admin/pending
router.get('/pending', verifyToken, requireAdmin, async (req, res) => {
  try {
    const [pendingStaff, pendingInstitutions] = await Promise.all([
      User.countDocuments({ role: 'staff', accountStatus: 'pending' }),
      Institution.countDocuments({ status: 'pending' })
    ]);

    res.json({ pendingStaff, pendingInstitutions });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/v1/admin/stats
router.get('/stats', verifyToken, requireAdmin, async (req, res) => {
  try {
    const [institutions, items, claims, successfulReturns, users, staff, pendingInstitutions] = await Promise.all([
      Institution.countDocuments(),
      Item.countDocuments(),
      Claim.countDocuments(),
      Claim.countDocuments({ status: 'returned' }),
      User.countDocuments(),
      User.countDocuments({ role: 'staff' }),
      Institution.countDocuments({ status: 'pending' })
    ]);

    res.json({ institutions, items, claims, successfulReturns, users, staff, pendingInstitutions });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
