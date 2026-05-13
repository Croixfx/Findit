const express = require('express');
const multer = require('multer');
const crypto = require('crypto');
const admin = require('../config/firebase');
const verifyToken = require('../middleware/auth');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

router.post('/', verifyToken, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'No file uploaded' });

    const folder = (req.body.folder || 'uploads').replace(/[^a-zA-Z0-9_-]/g, '');
    const ext = (req.file.originalname.split('.').pop() || 'jpg').toLowerCase();
    const filename = `${folder}/${Date.now()}.${ext}`;

    const downloadToken = crypto.randomUUID();
    const bucketName = process.env.FIREBASE_STORAGE_BUCKET || 'findit-d6af0.firebasestorage.app';
    console.log('[upload] using bucket:', bucketName);
    const bucket = admin.storage().bucket(bucketName);
    const fileRef = bucket.file(filename);

    await fileRef.save(req.file.buffer, {
      metadata: {
        contentType: req.file.mimetype,
        metadata: { firebaseStorageDownloadTokens: downloadToken },
      },
    });

    const encodedName = encodeURIComponent(filename);
    const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedName}?alt=media&token=${downloadToken}`;

    res.json({ url });
  } catch (err) {
    console.error('Upload error:', err);
    res.status(500).json({ message: err.message || 'Upload failed' });
  }
});

module.exports = router;
