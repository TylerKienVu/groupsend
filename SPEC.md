# GroupSend — Spec & Roadmap

## Vision

A mobile app for friend groups of climbers. The core loop: check in when you climb, see your crew's consistency on a heatmap. Accountability through visibility, not gamification.

---

## Product Decisions (locked)

- **Platform:** iOS first, Android later
- **Auth:** SMS OTP via Clerk
- **Sessions are group-scoped** — no solo logging; if you're not in a group, there's nothing to log
- **Groups:** A user can belong to multiple groups
- **Gym:** Free text field set by group creator
- **Heatmap:** Hybrid — aggregate view on top (group rhythm), individual rows below (personal accountability)
- **Push notifications v1:** History-based reminders — if a user climbed on a given day last week, send a reminder at the same time this week. Tapping the notification completes the check-in. No notification sent if they didn't climb that day last week.
- **Sessions per day:** One per user per group per day
- **Web portal v1:** Lightweight — shows group info, redirects to app store

---

## Data Model

```prisma
model User {
  id          String   @id @default(cuid())
  phone       String   @unique
  name        String
  avatarColor String
  createdAt   DateTime @default(now())

  memberships GroupMember[]
  sessions    Session[]
}

model Group {
  id          String   @id @default(cuid())
  name        String
  gymName     String
  description String?
  inviteCode  String   @unique @default(cuid())
  createdAt   DateTime @default(now())
  createdBy   String

  members     GroupMember[]
  sessions    Session[]
}

model GroupMember {
  groupId  String
  userId   String
  joinedAt DateTime @default(now())

  group    Group @relation(fields: [groupId], references: [id])
  user     User  @relation(fields: [userId], references: [id])

  @@id([groupId, userId])
}

model Session {
  id         String   @id @default(cuid())
  userId     String
  groupId    String
  climbedAt  DateTime
  createdAt  DateTime @default(now())

  user       User  @relation(fields: [userId], references: [id])
  group      Group @relation(fields: [groupId], references: [id])
}
```

---

## Tech Stack

| Layer | Choice |
|---|---|
| Mobile | React Native (Expo) — iOS first |
| Language | TypeScript throughout |
| API | Node.js + Express |
| ORM | Prisma |
| Database | PostgreSQL on Neon (free tier) |
| Auth | Clerk (SMS OTP) |
| Push notifications | Expo Push Notification Service |
| API hosting | Railway |
| Web portal | Simple HTML or Next.js page (hosted on Vercel) |

---

## Phases

---

### Phase 1 — Foundation
*Goal: working API with auth, groups, and sessions. No mobile UI yet.*

- [x] Initialize repo structure (monorepo: `/api`, `/mobile`, `/web`)
- [x] Set up Neon Postgres database
- [x] Write Prisma schema, run first migration
- [x] Set up Express server with TypeScript
- [x] Integrate Clerk for SMS OTP auth
- [x] Auth middleware — protect routes with JWT verification

**API routes built in this phase:**
```
POST /auth/verify          → exchange Clerk token for session
GET  /users/me             → get current user profile
POST /users               → create profile after first login
```

---

### Phase 2 — Groups
*Goal: users can create groups, generate invite links, and join via invite code. Deploy API to Railway.*

- [x] Group CRUD routes
- [x] Invite code generation on group creation
- [x] Join group via invite code
- [x] Lightweight web portal — `/invite/:code` shows group name, gym, member count, App Store link
- [x] Deploy API to Railway

**API routes:**
```
POST /groups                    → create group
GET  /groups                    → list my groups
GET  /groups/:id                → group detail + members
POST /groups/join/:inviteCode   → join a group
GET  /invite/:inviteCode        → public — group info for web portal (no auth)
```

---

### Phase 3 — Sessions
*Goal: users can log sessions (current time or retroactive). Heatmap data is queryable.*

- [x] Session logging route
- [x] Retroactive session logging (pass a custom `climbedAt`)
- [x] Query sessions for a group (powers the heatmap)
- [x] Prevent duplicate sessions (one per user per day per group)

**API routes:**
```
POST /sessions                          → log a session (body: groupId, climbedAt)
GET  /sessions?groupId=&weeks=12        → sessions for heatmap rendering
DELETE /sessions/:id                    → delete a session (own sessions only)
```

---

### Phase 4 — Mobile App (core screens)
*Goal: the full app is usable end-to-end on iOS.*

- [x] Expo project setup, navigation (React Navigation, tab-based)
- [ ] Auth screens — phone entry, OTP verification
- [ ] Profile creation screen (name + avatar color)
- [ ] Home screen — list of groups, + button to create
- [ ] Group creation screen — name, gym, description → share invite link
- [ ] Group detail screen — member list with session counts
- [ ] Heatmap component — aggregate row + individual member rows
- [ ] Check-in screen — one-tap button, retroactive log option
- [ ] Deep link handling — `/invite/:code` opens join flow in app

---

### Phase 5 — Push Notifications
*Goal: history-based reminder notifications that complete a check-in on tap.*

- [ ] Register Expo push token on login, store on User model
- [ ] Daily cron job — for each user, check if they had a session exactly 7 days ago; if yes, send a push notification
- [ ] Notification payload includes a deep link → tapping it fires `POST /sessions` and confirms check-in
- [ ] User can disable notifications in settings

**Schema addition:**
```prisma
// Add to User model
expoPushToken  String?
```

---

### Phase 6 — Polish & TestFlight
*Goal: stable enough to share with your actual friend group.*

- [ ] Error handling and loading states throughout mobile app
- [ ] Empty states (no groups, no sessions yet)
- [ ] Retroactive log UX — date picker, clean confirmation
- [ ] Basic input validation on all forms
- [ ] App icons, splash screen
- [ ] TestFlight build + internal distribution

---

## V2 Backlog (not in scope now)

- Web portal with full check-in functionality (no app required)
- Push notifications for group activity ("Jake just checked in 💪")
- Android support
- Overlap view — highlight days when 2+ friends climbed together
- Multiple gyms per group
- Session notes/comments
- Streak tracking

---

## Open Questions

None — all decisions locked.
