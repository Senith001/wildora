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
- **animalId**: String (reference to animals)
- **zoneId**: String (reference to highRiskZones)
- **location**: Object
  - **latitude**: double
  - **longitude**: double
- **animalName**: String (denormalized)