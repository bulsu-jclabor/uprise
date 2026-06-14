Fix Transactions Script

Purpose

This script scans the `transactions` collection and optionally fixes documents that are missing the `date` field or where `date` is not a Firestore `Timestamp`. Missing dates are set to `createdAt` (if available), `updatedAt` (if available), or `Timestamp.now()`.

Usage

1. Install Node and dependencies (if not already installed):

```bash
cd tools
npm init -y
npm install firebase-admin
```

2. Place a Firebase service account JSON file somewhere safe.

3. Dry run to see which documents would be changed:

```bash
node tools/fix_transactions.js --serviceAccount /path/to/serviceAccount.json --limit 100
```

4. Apply fixes (actually updates documents):

```bash
node tools/fix_transactions.js --serviceAccount /path/to/serviceAccount.json --fix
```

Notes

- Always run with `--limit` and without `--fix` first to verify results on a small sample.
- The script requires a service account with Firestore write permissions.
- This script is destructive when `--fix` is provided; review changes and backups before running on production.
