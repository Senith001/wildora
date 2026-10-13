# Human–wildlife conflict reporting

The mobile reporting and separate CLO review workflows are connected to
`wildora-138e3` Firestore. The user chose to retain the free plan: report text
syncs to the server, while photographs are retained on the reporting device.
The form and report details disclose this photo limitation. SMS and real
responder notification/dispatch services remain deferred.

## Architecture

- `domain/`: immutable report snapshots, validation and storage/remote contracts.
  No Firebase or widget dependency.
- `application/`: the report coordinator, identity service and injectable
  location/photo services.
- `data/`: atomic native file storage, browser storage and the Firebase gateway.
- `presentation/`: individual screens, manual-location validation, direct-route
  recovery and role-protected CLO access.
- `conflict_reporting.dart`: the feature's public entry point.

`ConflictReportRepository` retains the original public name used by routes and
coordinates use cases through injected contracts. The durable outbox separates
local storage from server acceptance. Stable IDs and transactions protect
retries from duplicate records or regression of officer workflow states.
Snapshots are immutable, including attachment bytes. The feature does not
modify the high-risk movement implementation or its tests.

## Reporting and recovery

1. Choose wildlife/conflict types, enter a description and confirm GPS or
   manually entered coordinates. Photographs are optional. GPS permission
   errors and a 15-second timeout show recovery guidance without invented
   coordinates. A real OpenStreetMap preview marks the GPS coordinates. Change
   opens a map where tapping selects a point; coordinates remain editable as a
   fallback. The initial Sri Lanka viewport does not count as a selected incident.
   Cancel preserves the existing location. Map failures show recovery guidance
   and a retry action without discarding coordinates.
2. Validate required inputs, coordinate ranges, the 500-character description
   limit and JPEG/PNG/WebP photographs up to 5 MB.
3. Generate a stable client reference and persist the complete report and
   attachment locally. A failed write preserves the form and never presents
   the report as saved.
4. Send the report while the confirmation observes its current state. In the
   application's free-plan mode, the attachment stays local and the server
   receives `photoDeliveryStatus: deviceOnly`. The adapter's Cloud Storage
   upload mode can be enabled after configuring a bucket and its access rules;
   `AppRouter` currently passes `uploadPhotos: false`.
5. Show Submitted only after server acknowledgement and local status persistence.
   Failed or timed-out delivery retains the same ID and a retryable outbox entry.
   A transaction that finds an existing server report preserves later review
   or resolution instead of overwriting it.
6. Retry on a foreground Firestore transition from cached data to a server
   snapshot. Manual retry is also available. This is foreground recovery,
   not an operating-system background service.

Native reports use flushed temporary files followed by rename in the app support
folder. Writes are serialized; interrupted syncing records reload as pending.
Corrupt saved files produce a recoverable loading error rather than silent
history loss. Browser storage uses a feature-specific local-storage namespace;
quota errors propagate before saved confirmation. Clearing app/site data,
uninstalling, or private-browser storage removal can erase local reports.
Unsubmitted form drafts are not persisted.

## Identity, ownership and CLO access

Reporters use a persisted Firebase anonymous identity. New server records carry
`reporterId`; non-CLO feeds query that identity plus explicitly labelled demo
reports. Firestore enforces ownership independently of UI checks.

CLO access uses email/password sign-in and a server-issued `role: clo` claim.
The app checks that claim before opening the dashboard or review screen. The
server permits only Submitted → Under Review → Resolved transitions, with
response notes required for resolution. Guarded transactions prevent concurrent
or stale transitions. Remote review updates are saved locally; older snapshots
cannot roll back newer local workflow state.

A fictional training account, `demo-clo@wildora.example`, was provisioned through
the Firebase API. Its `isDemo: true` claim restricts cloud access and review to
demo incidents. This is not a production officer identity. Generated credentials
are stored only in the owner-readable, Git-ignored file
`.firebase/conflict-reporting/demo-clo.json`; credentials are not embedded in
source or logged by the provisioning script.

Only `conflictReports` was excluded from the project's existing public wildcard
and given ownership/CLO rules. Other collections retain their previous live
access policy. The checked-in rules add the feature block without changing
other collection rules. Backups and deployment metadata are retained in the
ignored `.firebase/conflict-reporting/` directory.

## Demo reports

Three fictional records are stored in Firestore and cached on the emulator:

| ID | Reference | Workflow state |
| --- | --- | --- |
| `demo-hwc-001` | `DEMO-HWC-001` | Submitted |
| `demo-hwc-002` | `DEMO-HWC-002` | Under Review |
| `demo-hwc-003` | `DEMO-HWC-003` | Resolved |

Descriptions and references are explicitly marked DEMO. They are excluded from
real responder notifications. Demo server records are imported into My Reports
when the authenticated feed connects; personal history otherwise remains this
device's submissions. The emulator's My Reports screen was inspected and showed
all three references and states.

Scripts under `scripts/conflict_reporting/` provide create-only demo seeding,
training-account provisioning and scoped rules deployment. They use the existing
Firebase CLI login via `FIREBASE_CLI_ROOT`; they do not print credentials, overwrite
existing sample reports or configure paid services. Provisioning preserves an
existing local credential file. Rule deployment checks that another deployment
has not changed the live release before updating it.

## Design traceability

| Supplied critique requirement | Implementation/evidence |
| --- | --- |
| Precise validation and error recovery | Model/form validation; invalid-input and failed-save tests |
| GPS unavailable / manual fallback | Permission and timeout handling, validated coordinates; service/widget tests |
| Optional photograph | Actual picker, format/size checks and local persistence; photo/gateway tests |
| Saved locally versus server received | Durable outbox and reactive confirmation; persistence/acknowledgement tests |
| Offline storage and later synchronization | Restart recovery, foreground reconnect and manual retry tests |
| Duplicate prevention | Stable ID, concurrent-send guard and create-if-absent transaction tests |
| Dashboard visibility | Authenticated Firestore feed, demo import and dashboard tests |
| Separate CLO follow-up | Role gate, guarded transactions and response-note tests |
| Honest responder status | No claim of notification or dispatch; demo records explicitly labelled |
| SMS alternative | Deferred external channel; no gateway or provider account created |

## Verification

- `flutter test --no-pub --coverage`: **243 passing tests**, comprising the
  **144 existing tests** and **99 conflict reporting unit/widget tests**.
- Chrome browser storage: **3 passing tests** using
  `flutter test --no-pub --platform chrome test/browser/conflict_reporting/browser_store_checks.dart`.
- Feature/test analysis: **no issues**.
- VM line coverage: **93.9%** overall; application **96.9%**, domain **99.1%**,
  native data **94.2%**, presentation **92.2%**. Browser storage is verified
  separately and is excluded from the VM coverage denominator.
- Live Firebase API checks verified CLO sign-in and role claims, denied public
  report access, reporter-owned creation, member denial of officer transitions,
  demo-CLO denial of non-demo incidents, and successful demo review/resolution.
  Temporary verification documents and anonymous test users were removed.
  Another collection's existing access was also checked after rule deployment.

Tests cover real temporary-file persistence, attachment immutability, validation,
permission/timeout paths, picker cancellation, failed upload/database operations,
lost acknowledgements, retries, concurrent sends, stale snapshots, response-note
persistence, direct-route recovery, navigation, enlarged text, anonymous identity
reuse, fresh role claims, failed login, training-role limits and free-plan media
handling. SDK unit tests use scoped test doubles; live API checks separately
exercise actual Firebase access and transactions.

The project retains `main`'s Dart `^3.13.5` requirement. This workstation has Dart
3.13.1, so local verification uses already-resolved dependencies with `--no-pub`.
Normal dependency resolution requires a compatible SDK; the shared requirement
has not been lowered.

## Deferred integrations

The project currently has billing disabled and no Storage bucket. As requested,
no billing upgrade, SMS provider account or paid service was created. Cloud photo
transfer, SMS, real push notifications, responder selection/availability and
manual dispatch assignment are not activated. A production CLO identity must
replace the fictional training account before real officer operations.

Reference APIs: [Firebase account creation](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v1/accounts/signUp),
[Cloud Storage upload](https://firebase.google.com/docs/storage/flutter/upload-files),
and [Firestore offline behavior](https://firebase.google.com/docs/firestore/manage-data/enable-offline).

## Map provider

The conflict-reporting map uses `flutter_map` 8.3 with OpenStreetMap standard
tiles, visible linked attribution and the `com.wildora.wildora` application
identifier. Native tiles use flutter_map's default HTTP-aware disk cache; web
tiles use browser caching. Only visible tiles are requested (`panBuffer: 0`);
there is no bulk downloading or offline-map feature. Public tiles require no
API key or billing setup but have best-effort availability and must follow the
[OpenStreetMap tile policy](https://operations.osmfoundation.org/policies/tiles/).
Report saving still works without map tiles; GPS or valid manually entered
coordinates can be used.

A different compatible tile endpoint can be configured with
`--dart-define=CONFLICT_MAP_TILE_URL=https://.../{z}/{x}/{y}.png`. Before
switching providers, also review its attribution, authentication and usage
requirements; the current attribution credits OpenStreetMap contributors.

Map widget tests use injected in-memory tiles, so they never call the public
map service. They cover actual tap gestures, coordinate confirmation and cancel,
GPS pin accuracy, unchanged read-only previews, and failed-tile retry recovery.

## Submission rules regression

Idempotent submission reads a document before creating it. A signed-in user
may look up an unused conflict-report ID; this returns a missing document.
Existing documents still require reporter ownership, demo visibility or CLO
authorization. Without this narrow `get` allowance, first-time transactions
fail with permission denied even when internet access is working.

`scripts/conflict_reporting/verify_submission_access.cjs` verifies the unused-ID
lookup, subsequent creation, owner access, and denied public/other-member
access against the live rules. It requires the existing Firebase CLI login and
`FIREBASE_CLI_ROOT`, creates explicitly labelled temporary data and removes it
in `finally`. The Android SDK retry was also verified end to end: the original
saved report changed from Sync Failed to Submitted / Synced with its original
report reference.

## Verified emulator offline flow

An Android emulator run on 2026-10-10 verified the following with airplane
mode enabled and both Wi-Fi and mobile data disabled. A network probe returned
`Network is unreachable`. The description was clearly labelled
`DEMO OFFLINE TEST - fictional incident for testing only`.

- Submission immediately returned Report Saved / Pending Sync with a stable
  reference; the failed send remained Saved Offline / Sync Failed.
- Offline Retry Sync retained the local report and did not claim acceptance.
  A direct Firebase check confirmed the report did not exist on the server.
- Force-stopping and relaunching the app offline preserved the report in
  My Reports and its durable device file.
- Restoring connectivity automatically submitted the pending report without
  pressing Retry again. Both My Reports and the server confirmed Submitted /
  Synced under the original ID, with one additional history entry.
- Airplane mode, Wi-Fi and mobile data were restored to their original states.
  The labelled test report remains in My Reports as demonstration evidence.

Offline map tiles may be unavailable; selected coordinates remain usable for
report saving. This is expected and is separate from the report outbox.
