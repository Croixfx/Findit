const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const connectDB = require('./config/db');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/api/v1/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    message: 'FindIt API is running',
    timestamp: new Date().toISOString()
  });
});

// Routes
app.use('/api/v1/auth', require('./routes/auth'));
app.use('/api/v1/institutions', require('./routes/institutions'));
app.use('/api/v1/items', require('./routes/items'));
// app.use('/api/v1/chat', require('./routes/chat'));

app.listen(PORT, async () => {
  await connectDB();
  console.log(`FindIt server running on port ${PORT}`);
});

module.exports = app;
