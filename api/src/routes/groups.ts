import { Router } from "express";
import { requireAuth } from "../middleware/requireAuth";
import { getAuth } from "@clerk/express";
import prisma from "../lib/prisma";

const router = Router();

router.post("/", requireAuth, async (req, res) => {
  const { userId: clerkId } = getAuth(req);

  const { name, gymName, description } = req.body;

  if (!name) {
    res.status(400).json({
      error: "name is required",
    });
    return;
  }

  const userCreatingTheGroup = await prisma.user.findUnique({
    where: {
      clerkId: clerkId!,
    },
  });

  if (!userCreatingTheGroup) {
    res.status(500).json({
      error: "Authenticated user has no profile",
    });
    return;
  }

  const group = await prisma.group.create({
    data: {
      name,
      gymName,
      description,
      createdBy: userCreatingTheGroup.id,
      members: {
        create: {
          userId: userCreatingTheGroup.id,
        },
      },
    },
  });

  res.status(201).json(group);
});

router.get("/", requireAuth, async (req, res) => {
  const { userId: clerkId } = getAuth(req);

  const currentUser = await prisma.user.findUnique({
    where: {
      clerkId: clerkId!,
    },
  });

  if (!currentUser) {
    res.status(500).json({
      error: "Authenticated user has no profile",
    });
    return;
  }

  const currentUserMemberships = await prisma.groupMember.findMany({
    where: {
      userId: currentUser.id,
    },
    include: {
      group: true,
    },
  });

  const groups = currentUserMemberships.map((membership) => membership.group);

  res.status(200).json({
    groups,
  });
});

router.get("/:id", requireAuth, async (req, res) => {
  const { userId: clerkId } = getAuth(req);

  const currentUser = await prisma.user.findUnique({
    where: { clerkId: clerkId! },
  });

  if (!currentUser) {
    res.status(500).json({ error: "Authenticated user has no profile" });
    return;
  }

  const group = await prisma.group.findUnique({
    where: { id: req.params.id as string },
    include: {
      members: {
        include: { user: true },
      },
    },
  });

  if (!group) {
    res.status(404).json({ error: "Group not found" });
    return;
  }

  const isMember = group.members.some((m) => m.userId === currentUser.id);
  if (!isMember) {
    res.status(403).json({ error: "You are not a member of this group" });
    return;
  }

  res.status(200).json(group);
});

router.post("/join/:inviteCode", requireAuth, async (req, res) => {
  const { userId: clerkId } = getAuth(req);

  const currentUser = await prisma.user.findUnique({
    where: { clerkId: clerkId! },
  });

  if (!currentUser) {
    res.status(500).json({ error: "Authenticated user has no profile" });
    return;
  }

  const group = await prisma.group.findUnique({
    where: { inviteCode: req.params.inviteCode as string },
  });

  if (!group) {
    res.status(404).json({ error: "Invalid invite code" });
    return;
  }

  const alreadyMember = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: group.id, userId: currentUser.id } },
  });

  if (alreadyMember) {
    res.status(409).json({ error: "You are already a member of this group" });
    return;
  }

  await prisma.groupMember.create({
    data: { groupId: group.id, userId: currentUser.id },
  });

  res.status(200).json(group);
});

router.get("/invite/:inviteCode", async (req, res) => {
  const group = await prisma.group.findUnique({
    where: { inviteCode: req.params.inviteCode as string },
    include: { members: true },
  });

  if (!group) {
    res.status(404).json({ error: "Invalid invite code" });
    return;
  }

  res.status(200).json({
    name: group.name,
    gymName: group.gymName,
    description: group.description,
    memberCount: group.members.length,
  });
});

export default router;
