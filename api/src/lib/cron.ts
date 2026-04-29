import cron from 'node-cron';
import prisma from './prisma';
import { sendCheckinReminder } from './apns';

// Runs every 5 minutes. For each tick, we look for sessions that happened
// exactly 7 days ago within this 5-minute window. If the user has an APNs
// token, we send them a reminder push.
export function startCronJobs(): void {
  cron.schedule('*/5 * * * *', async () => {
    const now = new Date();
    const windowStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000 - 2.5 * 60 * 1000);
    const windowEnd   = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000 + 2.5 * 60 * 1000);

    // Only match sessions logged within 30 min of their climbedAt — this
    // filters out retroactive sessions, which would fire at midnight.
    const sessions = await prisma.session.findMany({
      where: {
        climbedAt: { gte: windowStart, lte: windowEnd },
        createdAt: {
          gte: new Date(windowStart.getTime() - 30 * 60 * 1000),
          lte: new Date(windowEnd.getTime()   + 30 * 60 * 1000),
        },
      },
      include: {
        user: { select: { apnsDeviceToken: true } },
        group: { select: { gymName: true } },
      },
    });

    for (const session of sessions) {
      const token = session.user.apnsDeviceToken;
      if (!token) continue;
      await sendCheckinReminder(token, session.groupId, session.group.gymName);
    }

    if (sessions.length > 0) {
      console.log(`[cron] Sent ${sessions.length} check-in reminder(s)`);
    }
  });

  console.log('[cron] Check-in reminder job scheduled (every 5 min)');
}
