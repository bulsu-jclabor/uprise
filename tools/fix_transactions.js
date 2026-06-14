#!/usr/bin/env node
/**
 * tools/fix_transactions.js
 *
 * Scans the `transactions` collection and optionally fixes documents missing
 * a `date` field or where `date` is not a Firestore Timestamp.
 *
 * Usage:
 *   node tools/fix_transactions.js --serviceAccount /path/to/key.json [--fix] [--limit N]
 *
 * Flags:
 *  --serviceAccount  Path to a Firebase service account JSON file (required)
 *  --fix             Actually write fixes. Without this flag the script runs in dry-run mode.
 *  --limit N         Optional number of documents to process (useful for testing)
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function parseArgs() {
  const args = process.argv.slice(2);
  const out = {};
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--serviceAccount') out.serviceAccount = args[++i];
    else if (a === '--fix') out.fix = true;
    else if (a === '--limit') out.limit = parseInt(args[++i], 10);
  }
  return out;
}

async function main() {
  const opts = parseArgs();
  if (!opts.serviceAccount) {
    console.error('Missing --serviceAccount /path/to/key.json');
    process.exit(1);
  }
  const keyPath = path.resolve(opts.serviceAccount);
  if (!fs.existsSync(keyPath)) {
    console.error('Service account file not found:', keyPath);
    process.exit(1);
  }

  const serviceAccount = require(keyPath);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  console.log('Running fix_transactions. dryRun=', !opts.fix);

  let processed = 0;
  const batchSize = 500;
  let lastDoc = null;
  let remaining = opts.limit || Infinity;

  while (remaining > 0) {
    let q = db.collection('transactions').orderBy(admin.firestore.FieldPath.documentId()).limit(Math.min(batchSize, remaining));
    if (lastDoc) q = q.startAfter(lastDoc);
    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      if (remaining <= 0) break;
      remaining--;
      processed++;
      const data = doc.data();
      const problems = [];
      // Check date field
      const dt = data.date;
      if (!dt) {
        problems.push('missing_date');
      } else if (! (dt instanceof admin.firestore.Timestamp)) {
        problems.push('date_not_timestamp');
      }

      if (problems.length === 0) continue;

      console.log(`Doc ${doc.id} problems: ${problems.join(', ')}`);

      if (!opts.fix) continue;

      // Build update
      const updateData = {};
      if (problems.includes('missing_date') || problems.includes('date_not_timestamp')) {
        if (data.createdAt && data.createdAt instanceof admin.firestore.Timestamp) {
          updateData.date = data.createdAt;
        } else if (data.updatedAt && data.updatedAt instanceof admin.firestore.Timestamp) {
          updateData.date = data.updatedAt;
        } else {
          updateData.date = admin.firestore.Timestamp.now();
        }
      }

      try {
        await doc.ref.update(updateData);
        console.log(`  -> Fixed ${doc.id} (set date)`);
      } catch (e) {
        console.error(`  -> Failed to update ${doc.id}:`, e);
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < batchSize) break;
  }

  console.log('Done. Processed documents:', processed);
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
