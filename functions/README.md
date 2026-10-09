# Wildora Cloud Functions

This directory contains Firebase Cloud Functions for the Wildora wildlife conservation system.

## Prerequisites

### Firebase Project Upgrade Required

**IMPORTANT**: Cloud Functions require your Firebase project to be upgraded from the **SPARK (free)** plan to the **BLAZE (pay-as-you-go)** plan.

- Current project `wildora-138e3` is on SPARK plan
- BLAZE plan has generous free tiers for functions and FCM
- Billing account must be attached to enable Cloud Functions

### Firebase CLI Setup

```bash
npm install -g firebase-tools
firebase login
firebase use wildora-138e3  # or your project ID
```

## What This Does

The Cloud Functions provide real-time push notifications for high-risk animal movement alerts:

1. **Trigger**: Automatically invoked when a new document is created in `alerts/{alertId}`
2. **Proximity Resolution**: Implements the SAME logic as the Flutter client:
   - 5km radius from zone center
   - Rangers: must be on-duty + have fresh location (< 30 min)
   - CLOs: only need to be within radius
   - Fallback: nearest-2 officers if no one is nearby
3. **FCM Push**: Sends push notifications to computed nearby officers' devices
4. **Graceful Degradation**: Flutter app works fully without this (in-app alerts still function)

## Deployment

### Deploy to Firebase

```bash
cd functions/
firebase deploy --only functions
```

### Local Testing (Optional)

```bash
cd functions/
npm install  # only if you want to test locally
firebase emulators:start --only functions
```

## App Integration

The Flutter app works in two modes:

1. **With Cloud Functions (Blaze plan)**: Real FCM push notifications to nearby officers
2. **Without Cloud Functions (Spark plan)**: In-app realtime alerts via Firestore listeners

Both modes use the same proximity-based targeting - only the delivery mechanism differs.

## Intentionally NOT Deployed

This task creates the Cloud Function code but does **NOT** deploy it. The deployment requires:

1. Firebase project upgrade to BLAZE plan
2. Explicit deployment command: `firebase deploy --only functions`
3. User approval for billing plan change

The Flutter app continues to work with in-app notifications while this remains undeployed.