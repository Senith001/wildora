# Wildlife incident reporting

The existing homepage (`../home/home_screen.dart`) is unchanged. Its app wrapper
adds Incident, Reports and Sync tabs. The form consists of separate screens:
type → location → details/photos → review → online or local-save result.

## Firebase data

- Firestore collection: `wildlifeIncidents`.
- Document ID: a stable random report ID, reused on every upload retry.
- Fields: reporterId, type, latitude, longitude, GeoPoint location, locationName,
  description, occurredAt, createdAt, photoUrls, status and server uploadedAt.
- Photos: Cloudinary cloud `rhi5e0gz`, unsigned preset `wildora_incidents`.
  Only HTTPS photo URLs are stored in Firestore. JPEG, PNG and WebP are accepted;
  each report allows 3 photos, each no larger than 5 MB.
- Reports streams query by reporterId and sort by createdAt locally; no composite
  Firestore index is required.

The existing application does not have an officer sign-in screen. `reporterId`
is a persisted installation/browser identity. My Reports therefore means this
installation's reports, not a signed-in officer's cross-device account. Clearing
app/browser storage removes that identity and any unsynced local reports.

## Local queue and sync

`HiveIncidentLocalStore` persists each report and its photo bytes before network
work starts. Android stores this in the app's document directory; web uses this
origin's IndexedDB. The form never claims a local save if this write fails.

`FirebaseIncidentRemoteStore` uploads photos with explicit content types using
Cloudinary, then writes their URLs and report values to Firestore. The UI
shows success only after the server write completes. Failed network attempts
stay pending; permission/configuration errors show Sync Failed with the actual
reason. Photos remain locally available until successful upload.

Sync Now retries pending and failed reports. Pending network uploads also retry
every 30 seconds while the feature is open and on app resume. No background
service is installed: keep the app open to finish synchronization. Stable report IDs
and reuse of URLs saved after failed uploads make retries safe, including if a timed-out Firestore write later
reaches the server. Sync errors do not replace reports with mock/sample entries.

## Enable the new paths in the existing Firebase project

Firebase initialization and project settings are reused. No live rules deployment
is performed by the implementation or test scripts. Incident photos do not need
a Firebase Storage bucket. Publish the Firestore rules when required:

```sh
firebase deploy --only firestore:rules --project wildora-138e3
```

`firestore.rules` adds schema validation for wildlifeIncidents. `storage.rules`
allows incident image paths and denies unmatched paths. Review any existing
remote Storage rules before replacing them. Both use the project's existing
**development-only, unauthenticated access policy expiring on 31 December 2026**.
The installation ID is not an authorization boundary. An officer authentication
and authorization policy is required before using these rules in production.

After adding native plugins, stop and restart Flutter instead of hot reload.
The Firebase configuration in this repo supports Android and web. Android
foreground location and release internet permissions are included. Web GPS needs
HTTPS or localhost and browser permission; manual coordinates work without GPS.
No iOS app/Firebase configuration exists in this repo.

## Free map preview

Capture Current Location requests a fresh high-accuracy GPS fix. Web uses the
browser geolocation API directly, converting timeout durations to numeric
milliseconds; Android keeps the native geolocator implementation. A browser
request that times out or cannot obtain a high-accuracy fix retries once with
balanced accuracy. Permission and HTTPS/localhost failures show near the map
with instructions instead of being hidden below the form. The upper map
centers on the returned latitude/longitude and anchors the pin tip at that point.
It also shows the device-reported accuracy in meters as a circle; GPS/browser
location is an estimate, not guaranteed exact physical position. Capturing again
recenters the map, and manual coordinates use the same map preview and saved
report fields. Panning the map does not silently change the report coordinates.

The preview uses `flutter_map` and OpenStreetMap standard tiles with no paid API
key. It includes contributor attribution, identifies native requests as
`com.wildora.wildora`, uses the library's tile caching, and does not bulk download
or prefetch offline map areas. Tiles require internet; failure does not prevent
saving the captured coordinates. For project/demo usage, follow the
[OpenStreetMap tile policy](https://operations.osmfoundation.org/policies/tiles/).
The map's GPS tests inject known device coordinates and in-memory tiles so they
do not request public map servers.

## Validation

```sh
flutter analyze lib/src/features/wildlife-incident lib/src/app/main_navigation_screen.dart
flutter test test/unit/wildlife_incident test/widget/wildlife_incident test/widget_test.dart
flutter build web
flutter test --platform chrome test/browser/browser_location_test.dart
firebase emulators:exec --project demo-wildora --config firebase.incident-emulators.json --only firestore,storage 'python3 test/firebase/incident_rules_smoke.py'
```

The rules script only connects to a demo project through local emulators. It
checks report writes/reads, safe repeated writes, schema rejection and Storage
image content type validation. It does not upload test data to the live project.

Implementation references: [Cloudinary uploads](https://cloudinary.com/documentation/upload_images),
[Firestore offline behavior](https://firebase.google.com/docs/firestore/manage-data/enable-offline),
[image_picker](https://pub.dev/packages/image_picker),
[geolocator](https://pub.dev/packages/geolocator).

## Cloudinary setup

The app is configured with your public cloud name and unsigned preset. In
Cloudinary, keep `wildora_incidents` Unsigned and restrict allowed formats to
JPEG/PNG/WebP with a 5 MB maximum file size. For Dynamic folders, set the preset's
Asset folder to `wildora/incidents` if you want photos grouped there; the app
leaves folder selection to the preset. No API key or API secret is needed.

Photo bytes stay in the local queue until Firestore confirms the report. Partial
upload URLs survive failures and app restarts. If the browser is closed during
an upload before its response is saved, an orphan image can remain in Cloudinary;
remove unused images through its console. Existing Base64 reports remain readable.

Restart Flutter after updating dependencies. Cloudinary's free plan has usage
limits: monitor usage in its console. Account/preset settings must be verified
in your Cloudinary console; local tests do not upload your photos.

Reference: https://cloudinary.com/documentation/upload_presets
