import { Router } from "express";
import { requireAuth } from "../middleware/requireAuth";
import { getAuth } from "@clerk/express";
import prisma from "../lib/prisma";

const router = Router();

// POST /sessions — log a session
router.post("/", requireAuth, async (req, res) => {
  const { userId: clerkId } = getAuth(req);

  const currentUser = await prisma.user.findUnique({
    where: { clerkId: clerkId! },
  });

  if (!currentUser) {
    res.status(500).json({ error: "Authenticated user has no profile" });
    return;
  }

  const { groupId, climbedAt: climbedAtRaw } = req.body;

  if (!groupId) {
    res.status(400).json({ error: "groupId is required" });
    return;
  }

  const membership = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId, userId: currentUser.id } },
  });

  if (!membership) {
    res.status(403).json({ error: "You are not a member of this group" });
    return;
  }

  const climbedAt = climbedAtRaw ? new Date(climbedAtRaw) : new Date();

  // Build start/end of the UTC calendar day to check for duplicates
  const dayStart = new Date(climbedAt);
  dayStart.setUTCHours(0, 0, 0, 0);
  const dayEnd = new Date(climbedAt);
  dayEnd.setUTCHours(23, 59, 59, 999);

  const existing = await prisma.session.findFirst({
    where: {
      userId: currentUser.id,
      groupId,
      climbedAt: { gte: dayStart, lte: dayEnd },
    },
  });

  if (existing) {
    res.status(409).json({ error: "You already logged a session for this group today" });
    return;
  }

  const session = await prisma.session.create({
    data: { userId: currentUser.id, groupId, climbedAt },
  });

  res.status(201).json(session);
});

// GET /sessions?groupId=&weeks=12 — sessions for heatmap
router.get("/", requireAuth, async (req, res) => {
  const { userId: clerkId } = getAuth(req);

  const currentUser = await prisma.user.findUnique({
    where: { clerkId: clerkId! },
  });

  if (!currentUser) {
    res.status(500).json({ error: "Authenticated user has no profile" });
    return;
  }

  const { groupId, weeks } = req.query;

  if (!groupId) {
    res.status(400).json({ error: "groupId is required" });
    return;
  }

  const membership = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: groupId as string, userId: currentUser.id } },
  });

  if (!membership) {
    res.status(403).json({ error: "You are not a member of this group" });
    return;
  }

  const weeksBack = parseInt(((weeks as string) ?? "12"), 10);
  const since = new Date();
  since.setUTCDate(since.getUTCDate() - weeksBack * 7);
  since.setUTCHours(0, 0, 0, 0);

  const sessions = await prisma.session.findMany({
    where: {
      groupId: groupId as string,
      climbedAt: { gte: since },
    },
    include: { user: { select: { id: true, name: true, avatarColor: true } } },
    orderBy: { climbedAt: "asc" },
  });

  res.status(200).json({ sessions });
});

// DELETE /sessions/:id — delete own session only
router.delete("/:id", requireAuth, async (req, res) => {
  const { userId: clerkId } = getAuth(req);

  const currentUser = await prisma.user.findUnique({
    where: { clerkId: clerkId! },
  });

  if (!currentUser) {
    res.status(500).json({ error: "Authenticated user has no profile" });
    return;
  }

  const session = await prisma.session.findUnique({
    where: { id: req.params.id as string },
  });

  if (!session) {
    res.status(404).json({ error: "Session not found" });
    return;
  }

  // 403 instead of 404 — we want the user to know the session exists but isn't theirs
  if (session.userId !== currentUser.id) {
    res.status(403).json({ error: "You can only delete your own sessions" });
    return;
  }

  await prisma.session.delete({ where: { id: session.id } });

  res.status(204).send();
});

export default router;
