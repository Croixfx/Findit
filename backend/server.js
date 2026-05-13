const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const connectDB = require('./config/db');
const admin = require('./config/firebase');
const User = require('./models/User');
const Message = require('./models/Message');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/api/v1/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    message: 'FindIt API is running',
    timestamp: new Date().toISOString()
  });
});

app.use('/api/v1/auth', require('./routes/auth'));
app.use('/api/v1/institutions', require('./routes/institutions'));
app.use('/api/v1/items', require('./routes/items'));
app.use('/api/v1/claims', require('./routes/claims'));
app.use('/api/v1/notifications', require('./routes/notifications'));
app.use('/api/v1/messages', require('./routes/messages'));
app.use('/api/v1/admin', require('./routes/admin'));
app.use('/api/v1/reports', require('./routes/reports'));
app.use('/api/v1/upload', require('./routes/upload'));

// Socket.io — verify Firebase token from handshake
io.use(async (socket, next) => {
  try {
    const token = socket.handshake.auth.token;
    if (!token) return next(new Error('Authentication error: no token'));

    const decoded = await admin.auth().verifyIdToken(token);
    const user = await User.findOne({ firebaseUid: decoded.uid });
    if (!user) return next(new Error('Authentication error: user not found'));

    socket.user = user;
    next();
  } catch {
    next(new Error('Authentication error: invalid token'));
  }
});

io.on('connection', (socket) => {
  socket.on('joinClaim', (claimId) => {
    socket.join(String(claimId));
  });

  socket.on('sendMessage', async ({ claimId, content }) => {
    try {
      if (!claimId || !content) return;

      const message = await Message.create({
        claim: claimId,
        sender: socket.user._id,
        content
      });

      await message.populate('sender', 'fullName profilePictureUrl role');
      io.to(String(claimId)).emit('messageReceived', message);
    } catch (err) {
      socket.emit('error', { message: err.message });
    }
  });
});

server.listen(PORT, async () => {
  await connectDB();
  console.log(`FindIt server running on port ${PORT}`);
});

module.exports = app;
