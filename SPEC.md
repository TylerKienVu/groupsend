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
- **Heatmap:** **Column-stack** visualization — each column is one day (last 14 days on group detail, last 10 on home cards), each colored dot in the column is one climber who showed up. The dot color is the climber's avatar color, so you can scan and see *who* climbed, not just how many. See [Column-stack rules](#column-stack-rules).
- **Rhythm rank:** Each member's recent activity (sessions in the last 4 weeks) maps to a V-grade label, V0 ("Chalking up") through V8+ ("Pro mode"). Displayed as a ranked leaderboard on the group detail screen, sorted by rank descending. This *replaces* the previous "individual heatmap rows" idea — the column stack already shows individual identity per day, so a leaderboard adds the cumulative-rhythm dimension without doubling up on the same axis.
- **Push notifications v1:** History-based reminders — if a user climbed on a given day last week, send a reminder at the same time this week. Tapping the notification completes the check-in. No notification sent if they didn't climb that day last week.
- **Sessions per day:** One per user per group per day
- **Web portal v1:** Lightweight — shows group info, redirects to app store

---

## Design Language

### Brand
- **Dark UI**, Partiful-influenced. Black-ish bg (`#0B0B0F`), warm off-white text (`#F4F3EF`).
- **Accent:** sandstone orange `#FF7B3F` — primary CTA, glow on the "today" column, focused borders. Reads as "sunset on red rock," ties the brand to the climbing context without literal imagery.
- **Type:** Geist (sans) + Geist Mono. Mono is used for labels, timestamps, ranks, and any "data-feel" type. Sans for headlines and body. *iOS implementation uses SF Pro / SF Mono (system fonts) as stand-ins — Geist requires bundling font files and is a Phase 6 polish step.*

### Color systems (two distinct palettes — do not mix)
- **Avatar palette** (10 saturated colors) — identifies *people*. Each user picks one at signup; appears around their initials in avatars, and as the dot color in the column-stack chart. This is the only place these colors should appear.
- **V-grade palette** (V0–V10) — identifies *climbing grades*. Used for grade chips (rhythm rank labels, future route-grade UI). These are the climbing-bright Partiful colors. Do not use these as person identity.

### Column-stack rules
- **Each column = one day.** Most recent day on the right (today on group detail; "yesterday" on invite preview because the invite preview shows past activity, not current).
- **Each dot in a column = one climber who showed up that day.** Dot color = the climber's avatar color.
- **Empty slots above the dots** stay rendered as faint placeholders so the chart shape always reads at a glance — quiet days look like thin columns, busy days fill the column.
- **Capacity** = group member count (current cap is 6 on group detail, 5–6 on home cards based on space).
- **Overflow** (more climbers than capacity, e.g. members + guests):
  - **Group detail:** show `+N` dot in the topmost slot, *replacing* what would have been the capacity-th climber dot. Column height stays uniform across days.
  - **Home cards & invite preview:** clip silently. The `+N` affordance is unnecessary at small sizes and adds noise.
- **Today highlight:** orange glow (`box-shadow` matching the accent) on every dot in today's column on group detail.

### Iconography
- Hand-drawn SVG hold shapes (Jug, Crimp, Sloper, Pinch) live in the design system but are used sparingly. No emoji. No stock icon-pack icons — only the hand-rolled set in `tokens.jsx` (`Icon.*`). *iOS implementation currently uses SF Symbols as a pragmatic stand-in; porting the hold shapes to SwiftUI Paths is a Phase 6 polish step.*

---

## Data Model

```prisma
model User {
  id          String   @id @default(cuid())
  clerkId     String   @unique  // added in Phase 1 migration
  phone       String?           // populated by Clerk; optional until sync is wired
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
| Mobile | Swift / SwiftUI — iOS first (native) |
| Language | Swift (mobile), TypeScript (API) |
| API | Node.js + Express |
| ORM | Prisma |
| Database | PostgreSQL on Neon (free tier) |
| Auth | Clerk (SMS OTP) — clerk-ios Swift SDK |
| Push notifications | Apple Push Notification Service (APNs) |
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
*Goal: the full app is usable end-to-end on iOS. Native Swift/SwiftUI, xcodegen for project scaffolding. Visual reference: see HTML design mockup (10 screens).*

- [x] xcodegen project.yml, Xcode project scaffold, Clerk Swift SDK via SPM
- [x] **Onboarding** — Phone entry → OTP → profile creation (name + avatar color). *UI complete; Clerk SDK calls (`signIn.create`, `attemptFirstFactor`) are stubbed with TODOs — wiring them is the next task before auth works end-to-end.*
- [x] **Empty home** — first-run state when user has no groups; CTA to create or join
- [x] **Home** — list of group cards, each showing name, gym, member avatars, and a 10-day mini column-stack
- [x] **Group creation** — name, gym, optional description → share invite link. *Also exposes an accent color picker (from the mockup) that wasn't in the original spec text.*
- [x] **Group detail** — member count, 14-day column-stack chart, rhythm-rank leaderboard, check-in CTA
- [x] **Check-in** — one-tap "Climbed today" + retroactive logging. *Retroactive UI is a week strip (Mon–Sun of current week) rather than a full arbitrary date picker — matches the design mockup. Full date picker moved to Phase 6.*
- [x] **Invite landing** — join CTA, opened from invite link. *Column-stack preview not shown: the public `GET /invite/:code` endpoint only returns name/gym/memberCount — no session data. Showing the chart requires either making sessions public or a new endpoint. Deferred.*
- [x] **Settings** — notification toggles, sign out, profile card. *"Leave group" not yet implemented — it needs a `DELETE /groups/:id/members/me` endpoint that doesn't exist yet. "Edit profile" is a placeholder nav row. Both deferred.*
- [x] Deep link handling — `groupsend://invite/:code` opens `InviteView` as a sheet from anywhere in the app

---

### Phase 5 — Push Notifications
*Goal: history-based reminder notifications that complete a check-in on tap.*

- [x] Register APNs device token on login, store on User model
- [x] Cron job (every 5 min) — find sessions from exactly 7 days ago in the same ±2.5 min window; send a push at the same time they climbed last week. Retroactive sessions filtered out by comparing climbedAt vs createdAt.
- [x] Notification payload includes a deep link → tapping it fires `groupsend://checkin/:groupId` which opens CheckInView preselected on that group
- [x] User can disable notifications in settings (History reminders toggle calls clearDeviceToken)

**Schema addition:**
```prisma
// Add to User model
apnsDeviceToken  String?
```

---

### Phase 6 — Polish & TestFlight
*Goal: stable enough to share with your actual friend group.*

- [ ] Wire Clerk SDK calls in `PhoneEntryView` (`signIn.create`) and `OtpView` (`attemptFirstFactor`) so SMS OTP auth works end-to-end
- [ ] `DELETE /groups/:id/members/me` API endpoint + "Leave group" in Settings
- [ ] Invite landing column-stack preview — requires session data from the invite endpoint
- [ ] Full retroactive date picker (currently limited to current week)
- [ ] Edit profile screen (name + avatar color change, `PUT /users/me`)
- [ ] Hold-shape icons ported from `tokens.jsx` SVGs to SwiftUI Paths
- [ ] Bundle Geist + Geist Mono fonts
- [ ] Error handling and loading states throughout mobile app
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
- **Guests** — non-member climbers who tagged along for a session. Currently the only source of column-stack overflow; modeling them as first-class would make the `+N` overflow case real instead of mocked.

---

## Open Questions

None — all decisions locked.
