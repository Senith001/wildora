# Data Models

Canonical schema reference for Wildora Firestore collections.

## Collections

### animals
- **animalId**: String (document ID)
- **species**: String
- **name**: String
- **collarId**: String? (nullable)
- **currentLocation**: Object? (nullable)
  - **latitude**: double
  - **longitude**: double
  - **timestamp**: Timestamp

### highRiskZones
- **zoneId**: String (document ID)
- **name**: String
- **riskLevel**: String
- **center**: GeoPoint
- **radiusMeters**: double

### alerts
- **alertId**: String (document ID)
- **type**: String
- **timestamp**: Timestamp
- **status**: String
- **responseStatus**: String ('unclaimed' | 'responding' | 'resolved')
- **respondingOfficerId**: String? (nullable)
- **respondingOfficerName**: String? (nullable)
- **respondingAt**: Timestamp? (nullable)
- **animalId**: String (reference to animals)
- **zoneId**: String (reference to highRiskZones)
- **location**: Object
  - **latitude**: double
  - **longitude**: double
- **animalName**: String (denormalized)
- **locationLabel**: String? (nullable)

### officers
- **officerId**: String (document ID)
- **name**: String
- **role**: String ('ranger' | 'clo')
- **contactNo**: String? (nullable)
- **location**: GeoPoint
- **locationUpdatedAt**: Timestamp
- **fcmTokens**: Array of Strings

### dutyRoster
- **date**: String (document ID in yyyy-MM-dd format)
- **onDutyRangerIds**: Array of Strings
- **lastUpdated**: Timestamp

### userPreferences
- **userId**: String (document ID)
- **themeMode**: String ('system' | 'light' | 'dark')
- **lastUpdated**: Timestamp

## Subcollections

### alerts/{alertId}/recipients
- **officerId**: String (document ID, reference to officers)
- **officerName**: String (denormalized)
- **role**: String ('ranger' | 'clo')
- **deliveryStatus**: String ('pending' | 'delivered' | 'read')
- **readAt**: Timestamp? (nullable)
- **notifiedChannels**: Array of Strings