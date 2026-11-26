import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {runReminders} from './reminders';
import {seedDemo} from './demo';

async function main() {
  if (!/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST ?? '')) {
    throw new Error('Start the local Firestore emulator before generating demo reminders.');
  }
  initializeApp({projectId: 'demo-jewellery-manager'});
  const db = getFirestore();
  if (process.argv.includes('--sample')) await seedDemo(db);
  if (process.argv.includes('--demo')) {
    await db.doc('settings/reminders').set({digestHour: 0}, {merge: true});
  }
  await runReminders(db);
  console.log('Local reminders evaluated. Open Notifications in Flutter.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});