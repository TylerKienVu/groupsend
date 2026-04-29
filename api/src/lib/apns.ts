import apn from 'apn';

const provider = new apn.Provider({
  token: {
    key: process.env.APNS_PRIVATE_KEY!,
    keyId: process.env.APNS_KEY_ID!,
    teamId: process.env.APNS_TEAM_ID!,
  },
  production: process.env.APNS_ENV === 'production',
});

export async function sendCheckinReminder(
  deviceToken: string,
  groupId: string,
  gymName: string
): Promise<void> {
  const note = new apn.Notification();
  note.expiry = Math.floor(Date.now() / 1000) + 3600; // expire after 1 hour if undelivered
  note.sound = 'default';
  note.alert = {
    title: "You climbed last week 🧗",
    body: `Head to ${gymName} today?`,
  };
  note.payload = { deepLink: `groupsend://checkin/${groupId}` };
  note.topic = process.env.APNS_BUNDLE_ID!;

  const result = await provider.send(note, deviceToken);
  if (result.failed.length > 0) {
    console.error('APNs send failed:', result.failed[0].response);
  }
}
