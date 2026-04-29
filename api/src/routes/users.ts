import { Router } from 'express';
import { getAuth } from '@clerk/express';
import { requireAuth } from '../middleware/requireAuth';
import prisma from '../lib/prisma';

const router = Router();

// GET /users/me
router.get('/me', requireAuth, async (req, res) => {
  const { userId: clerkId } = getAuth(req);

  const user = await prisma.user.findUnique({
    where: { clerkId: clerkId! },
  });

  if (!user) {
    res.status(404).json({ error: 'User not found' });
    return;
  }

  res.json(user);
});

// POST /users — create profile after first Clerk login
router.post('/', requireAuth, async (req, res) => {
  const { userId: clerkId } = getAuth(req);
  const { name, avatarColor } = req.body;

  if (!name || !avatarColor) {
    res.status(400).json({ error: 'name and avatarColor are required' });
    return;
  }

  const existing = await prisma.user.findUnique({ where: { clerkId: clerkId! } });
  if (existing) {
    res.status(409).json({ error: 'User already exists' });
    return;
  }

  const user = await prisma.user.create({
    data: { clerkId: clerkId!, name, avatarColor },
  });

  res.status(201).json(user);
});

// PUT /users/me/device-token — register or clear APNs token
// Body: { deviceToken: string | null }
router.put('/me/device-token', requireAuth, async (req, res) => {
  const { userId: clerkId } = getAuth(req);
  const { deviceToken } = req.body;

  if (deviceToken !== null && typeof deviceToken !== 'string') {
    res.status(400).json({ error: 'deviceToken must be a string or null' });
    return;
  }

  await prisma.user.update({
    where: { clerkId: clerkId! },
    data: { apnsDeviceToken: deviceToken ?? null },
  });

  res.status(204).send();
});

export default router;
