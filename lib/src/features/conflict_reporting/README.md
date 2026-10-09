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
   coordinates. The coordinate preview is illustrative, not a live map.
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

- `flutter test --no-pub --coverage`: **237 passing tests**, comprising the
  **144 existing tests** and **93 conflict reporting unit/widget tests**.
- Chrome browser storage: **3 passing tests** using
  `flutter test --no-pub --platform chrome test/browser/conflict_reporting/browser_store_checks.dart`.
- Feature/test analysis: **no issues**.
- VM line coverage: **93.9%** overall; application **96.9%**, domain **99.1%**,
  native data **94.2%**, presentation **92.1%**. Browser storage is verified
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
