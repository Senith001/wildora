/**
 * Wildora Cloud Functions for High-Risk Animal Movement Alerts
 * 
 * REQUIREMENTS:
 * - Firebase Project must be on BLAZE plan (not Spark) to deploy Cloud Functions
 * - Deploy with: firebase deploy --only functions
 * 
 * WHAT THIS DOES:
 * - Triggers on new alert documents created in alerts/{alertId}
 * - Resolves nearby eligible officers using SAME proximity logic as Flutter client
 * - Sends FCM push notifications to nearby officers only (not broadcast to all)
 * - Graceful degradation: Flutter app works with in-app alerts if this isn't deployed
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function triggered when a new high-risk alert is created.
 * Sends FCM push notifications to nearby eligible officers only.
 */
exports.sendHighRiskAlertNotification = functions.firestore
  .document('alerts/{alertId}')
  .onCreate(async (snap, context) => {
    const alertData = snap.data();
    const alertId = context.params.alertId;
    
    console.log(`Processing alert ${alertId} for ${alertData.animalName} in ${alertData.locationLabel}`);
    
    try {
      // 1. Load the zone to get center coordinates
      const db = admin.firestore();
      const zoneDoc = await db.collection('highRiskZones').doc(alertData.zoneId).get();
      
      if (!zoneDoc.exists) {
        console.error(`Zone ${alertData.zoneId} not found`);
        return null;
      }
      
      const zoneCenter = zoneDoc.data().center;
      
      // 2. Resolve nearby recipients using SAME proximity logic as client
      const nearbyOfficerIds = await resolveNearbyRecipients(alertData, zoneCenter);
      
      if (nearbyOfficerIds.length === 0) {
        console.log('No nearby officers found for FCM notification');
        return null;
      }
      
      // 3. Gather FCM tokens from nearby recipient officers
      const tokens = await gatherFcmTokens(nearbyOfficerIds);
      
      if (tokens.length === 0) {
        console.log('No FCM tokens found for nearby recipients');
        return null;
      }
      
      // 4. Build FCM message with notification and data payload
      const message = {
        notification: {
          title: '🚨 High-Risk Movement',
          body: `${alertData.animalName} entered ${alertData.locationLabel || 'danger zone'} - immediate attention required`,
        },
        data: {
          alertId: alertId,
          animalId: alertData.animalId || '',
          zoneId: alertData.zoneId || '',
          type: 'high_risk_movement'
        }
      };
      
      // 5. Send FCM to all nearby officers' tokens
      const response = await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        ...message
      });
      
      console.log(`FCM sent successfully to ${response.successCount}/${tokens.length} devices for ${nearbyOfficerIds.length} nearby officers`);
      
      // Log any failures for debugging
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Failed to send to token ${tokens[idx]}: ${resp.error}`);
          }
        });
      }
      
      return { 
        success: true, 
        recipientCount: nearbyOfficerIds.length, 
        tokenCount: tokens.length, 
        successCount: response.successCount 
      };
      
    } catch (error) {
      console.error('Error sending FCM notification:', error);
      return { success: false, error: error.message };
    }
  });

/**
 * Resolves nearby eligible officers using the SAME proximity rules as the Flutter client:
 * - notifyRadiusMeters = 5000m (5km) 
 * - maxLocationAgeMinutes = 30 minutes
 * - Rangers: must be on dutyRoster/{today}.onDutyRangerIds AND have fresh location AND be within radius
 * - CLOs: must be within radius (no duty or freshness check)
 * - Fallback: if no nearby officers, return nearest-2 among role+duty eligible
 */
async function resolveNearbyRecipients(alertData, zoneCenter) {
  const db = admin.firestore();
  
  // Get today's date in YYYY-MM-DD format for duty roster lookup
  const today = new Date(alertData.timestamp.toDate()).toISOString().split('T')[0];
  
  // LOCKED configuration values (must match client DetectionConfig)
  const NOTIFY_RADIUS_METERS = 5000; // 5km proximity radius
  const MAX_LOCATION_AGE_MINUTES = 30; // 30-minute freshness threshold
  
  const nearbyRecipients = [];
  
  // Get all officers to check proximity
  const allOfficersSnapshot = await db.collection('officers').get();
  const allOfficers = allOfficersSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  }));
  
  // Get today's duty roster for ranger eligibility
  const dutyDoc = await db.collection('dutyRoster').doc(today).get();
  const onDutyRangerIds = dutyDoc.exists ? (dutyDoc.data().onDutyRangerIds || []) : [];
  
  console.log(`Checking ${allOfficers.length} officers for proximity to zone center (${zoneCenter.latitude}, ${zoneCenter.longitude})`);
  console.log(`On-duty rangers today (${today}): ${onDutyRangerIds.join(', ')}`);
  
  for (const officer of allOfficers) {
    // Check if officer has usable location
    if (!officer.location) {
      console.log(`Officer ${officer.officerId} has no location - skipping`);
      continue;
    }
    
    // For Rangers: check location freshness + duty status
    if (officer.role === 'ranger') {
      // Check duty status for today
      if (!onDutyRangerIds.includes(officer.officerId)) {
        console.log(`Ranger ${officer.officerId} is off-duty today - skipping`);
        continue; // Off duty
      }
      
      // Check location freshness
      const locationUpdatedAt = officer.locationUpdatedAt.toDate();
      const locationAge = Date.now() - locationUpdatedAt.getTime();
      const locationAgeMinutes = locationAge / (1000 * 60);
      
      if (locationAgeMinutes > MAX_LOCATION_AGE_MINUTES) {
        console.log(`Ranger ${officer.officerId} has stale location (${locationAgeMinutes.toFixed(1)} min old) - skipping`);
        continue; // Stale location
      }
    }
    // For CLOs: no duty status required, no freshness check (static location OK)
    
    // Check proximity using haversine distance
    const distanceMeters = haversineMeters(
      officer.location.latitude,
      officer.location.longitude,
      zoneCenter.latitude,
      zoneCenter.longitude
    );
    
    console.log(`Officer ${officer.officerId} (${officer.role}) is ${distanceMeters.toFixed(0)}m away`);
    
    if (distanceMeters <= NOTIFY_RADIUS_METERS) {
      console.log(`Including ${officer.officerId} - within ${NOTIFY_RADIUS_METERS}m radius`);
      nearbyRecipients.push(officer.officerId);
    }
  }
  
  // LOCKED fallback: if no nearby officers found, use nearest-2 approach
  if (nearbyRecipients.length === 0) {
    console.log('No officers within radius - applying nearest-2 fallback');
    
    const eligibleWithDistance = allOfficers
      .filter(officer => officer.location && isRoleEligible(officer, onDutyRangerIds))
      .map(officer => ({
        officerId: officer.officerId,
        distance: haversineMeters(
          officer.location.latitude,
          officer.location.longitude,
          zoneCenter.latitude,
          zoneCenter.longitude
        )
      }))
      .sort((a, b) => a.distance - b.distance);
    
    const nearest2 = eligibleWithDistance.slice(0, 2).map(o => o.officerId);
    console.log(`Fallback: nearest-2 eligible officers: ${nearest2.join(', ')}`);
    
    return nearest2;
  }
  
  console.log(`Found ${nearbyRecipients.length} nearby officers: ${nearbyRecipients.join(', ')}`);
  return nearbyRecipients;
}

/**
 * Checks if officer is role-eligible for alerts (for fallback logic)
 */
function isRoleEligible(officer, onDutyRangerIds) {
  if (officer.role === 'ranger') {
    // Rangers need on-duty status (still respected in fallback)
    return onDutyRangerIds.includes(officer.officerId);
  } else if (officer.role === 'clo') {
    // CLOs always eligible
    return true;
  }
  return false;
}

/**
 * Gathers FCM tokens from the specified officer IDs
 */
async function gatherFcmTokens(officerIds) {
  const db = admin.firestore();
  const tokens = [];
  
  console.log(`Gathering FCM tokens for ${officerIds.length} officers`);
  
  for (const officerId of officerIds) {
    try {
      const officerDoc = await db.collection('officers').doc(officerId).get();
      if (officerDoc.exists) {
        const fcmTokens = officerDoc.data().fcmTokens || [];
        console.log(`Officer ${officerId}: ${fcmTokens.length} FCM tokens`);
        tokens.push(...fcmTokens);
      }
    } catch (error) {
      console.error(`Error getting FCM tokens for officer ${officerId}:`, error);
    }
  }
  
  // Remove empty/invalid tokens
  const validTokens = tokens.filter(token => token && token.length > 0);
  console.log(`Total valid FCM tokens: ${validTokens.length}`);
  
  return validTokens;
}

/**
 * Calculate haversine distance between two points in meters
 * SAME implementation as client-side geo.dart
 */
function haversineMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
           Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
           Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}