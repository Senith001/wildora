# Private conflict-report photos

A standalone Cloudflare Worker proxies private Cloudinary images after Firebase
identity and report-access checks. No Firebase billing upgrade or Firebase
Storage bucket is required. The deployed service is:

`https://wildora-conflict-photos.wildora.workers.dev`

## API

- `GET /health`: public service identification only.
- `POST /reports/{reportId}/photo`: Firebase bearer token plus raw JPEG/PNG/WebP
  body, up to 5 MB. Returns `photoUrl` (the private proxy address) and `reporterId`.
  A missing report is permitted for first submission; an existing report must
  belong to the uploader. Never put the Firebase token in a query string.
- `GET /reports/{reportId}/photo/{sha256}.{format}`: Firebase bearer token. The
  report must exist and contain that exact proxy address. Only its reporter or
  an authorized CLO may read the image. Demo CLOs are limited to demo reports.

The Worker verifies Firebase ID tokens using the Firebase Auth REST account
lookup endpoint, checks project/issuer/subject/expiry, reads reports through
Firestore using the same token and enforces the stricter private-image rule.
Client-supplied officer claims alone never authorize access.

Cloudinary assets use `authenticated` delivery and content-addressed IDs under
`wildora/{reporterId}/{reportId}/{sha256}` with overwrite disabled. Retrying the
same image/report does not create another reference. Signed Cloudinary download
URLs remain inside the Worker; only authorized image bytes are returned with
`Cache-Control: private, no-store`. API errors do not include secrets or tokens.

## Deploy

1. Authorize the Cloudflare CLI with `npx wrangler login` (or `--device`).
2. Review `wrangler.jsonc`: cloud name, Firebase project and exact browser origins.
   Native Flutter requests do not use browser CORS. For Flutter web development,
   use port 8080 or add its specific origin to `ALLOWED_ORIGINS`.
3. Run `npx wrangler deploy --config services/conflict-photos/wrangler.jsonc`.
4. Store `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` and `FIREBASE_API_KEY` using
   `npx wrangler secret put NAME --config services/conflict-photos/wrangler.jsonc`.
   Enter values interactively; do not put them in command arguments or source.
5. Deploy the scoped Firestore rules using the existing conflict-reporting
   deployment script. It preserves every other collection's existing policy.
6. Rebuild Flutter. The configured endpoint is the default; override it using
   `--dart-define=CONFLICT_PHOTO_API_URL=https://your-backend.example` if needed.
   Before changing hosts, update the photo-reference allowlist in Firestore rules.

Cloudinary account credentials are held locally in the Git-ignored,
owner-readable `.firebase/conflict-reporting/cloudinary.json` and remotely in
Cloudflare secrets. There is no unsigned upload preset or API secret in Flutter.

## Verification

Run `node --test --experimental-test-coverage services/conflict-photos/test/worker.test.mjs`.
The 22 Node tests cover token failures, role/ownership restrictions, private
reads, content validation, streaming limits, rate limits, retries and failures.
Measured Worker coverage: 100% lines, 84.95% branches, 94.44% functions.

The live regression script `scripts/conflict_reporting/verify_private_photos.cjs`
requires the existing Firebase CLI login, `FIREBASE_CLI_ROOT`, and the local
ignored credential files. It checks real uploads/downloads, unauthorized access,
legacy photo delivery and workflow protection. Clearly labelled temporary
reports, users and Cloudinary assets are removed afterward.

## Boundaries

Free-account quotas and availability apply. Uploads are capped at ten per user
per minute at each Cloudflare location; this is not a global abuse-prevention
system. Signed-in anonymous community reporting remains supported. A production
release should add appropriate abuse controls and monitor free-tier usage.
Abandoned images from interrupted submissions are content-addressed and reused
on retry, but automatic removal of unreferenced assets is not implemented.

Reporter photos remain durable locally. CLO downloads are transient and require
online access after restart. The fictional demo CLO remains restricted to demo
incidents and is not a production officer account.
