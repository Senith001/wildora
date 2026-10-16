import 'package:geolocator/geolocator.dart';
import 'data/incident_location_service.dart';
import 'data/incident_photo_picker.dart';
import 'data/incident_local_store.dart';
import 'data/incident_remote_store.dart';
import 'data/incident_repository.dart';

/// Composition root: concrete persistence adapters are selected in one place.
IncidentRepository createIncidentRepository() => IncidentRepository(
  local: HiveIncidentLocalStore(),
  remote: FirebaseIncidentRemoteStore(),
);

IncidentPhotoPicker createIncidentPhotoPicker() => DeviceIncidentPhotoPicker();

Future<Position> captureIncidentLocation() =>
    IncidentLocationService().capture();
