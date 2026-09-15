# Releasing SVG Viewer

Two distribution channels, both driven by `build.sh` (locally or from `.github/workflows/build.yml`).
Team: **TEAMID** (override with `TEAM_ID=…`). Bundle ID: `com.patlaplante.SVGViewer`.

## 1. Direct download (Developer ID + notarization)

Same flow as `mdview/bundle.sh`.

```sh
# one-time: store notarization credentials (app-specific password from appleid.apple.com)
xcrun notarytool store-credentials notarize-profile --apple-id you@example.com --team-id TEAMID

./build.sh --universal --sign devid --notarize    # → build/SVGViewer-<version>.zip
```

Needs the *Developer ID Application* certificate in the keychain (create it at
developer.apple.com/account/resources/certificates and install it, or export the `.p12` mdview's CI uses).

## 2. Mac App Store

### One-time setup (developer.apple.com / App Store Connect)

1. **Certificates** → create and install two certificates:
   - *Apple Distribution* (signs the app)
   - *Mac Installer Distribution* (signs the `.pkg`)
2. **Identifiers** → register App ID `com.patlaplante.SVGViewer` (macOS, no extra capabilities).
3. **Profiles** → *Mac App Store Connect* profile for that App ID; download it to
   `Resources/SVGViewer.provisionprofile` (git-ignored).
4. **App Store Connect → Apps → +** → New macOS app, bundle ID `com.patlaplante.SVGViewer`, SKU e.g. `svgviewer`.
5. **Users and Access → Integrations → App Store Connect API** → generate a key with the *App Manager* role.
   Save `AuthKey_<KEYID>.p8` to `~/.appstoreconnect/private_keys/`; note the Key ID and Issuer ID.

### Each release

```sh
# bump CFBundleShortVersionString / CFBundleVersion in Resources/Info.plist, then:
ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=xxxxxxxx-xxxx-… \
  ./build.sh --universal --sign appstore --pkg --upload
```

This produces a sandboxed, distribution-signed `.app` with the embedded provisioning profile, wraps it in a
signed `.pkg`, validates it and uploads it. Then in App Store Connect: attach the processed build to a
version, fill in screenshots (1280×800 or larger), description, category (Graphics & Design), privacy
(no data collected), and submit for review.

What the app declares (already in `Resources/`):

- `SVGViewer.entitlements` — App Sandbox, user-selected file read/write (open + export), outgoing network
  client (required by WebKit's networking process even for local content).
- `Info.plist` — `ITSAppUsesNonExemptEncryption = NO` (skips the export-compliance question),
  `LSApplicationCategoryType`, document types for `.svg`/`.svgz`, minimum macOS 14.
- `--sign appstore` adds `com.apple.application-identifier` and `com.apple.developer.team-identifier`
  to the entitlements, matching what Xcode embeds.

The app uses only public API (no `drawsBackground` KVC etc.) and no third-party code, so the automated
binary checks should pass. `CFBundleVersion` must strictly increase between uploads for the same
`CFBundleShortVersionString`.

## GitHub Actions

Pushing a tag `v*` runs both jobs; *Run workflow* lets you run the Developer ID job alone or with the
App Store job. Repository secrets:

| Secret | Used by | Value |
| --- | --- | --- |
| `MACOS_CERTIFICATE`, `MACOS_CERTIFICATE_PWD` | developer-id | base64 `.p12` of the Developer ID Application cert (same as mdview) |
| `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` | developer-id | notarytool credentials (same as mdview) |
| `MACOS_DIST_CERTIFICATE`, `MACOS_DIST_CERTIFICATE_PWD` | app-store | base64 `.p12` containing *both* Apple Distribution and Mac Installer Distribution certs |
| `MAC_PROVISIONING_PROFILE` | app-store | base64 of the Mac App Store provisioning profile |
| `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY` | app-store | App Store Connect API key id, issuer id, base64 of the `.p8` |

```sh
base64 -i cert.p12 | pbcopy      # etc.
gh secret set MACOS_CERTIFICATE --repo patbonecrusher/svg-viewer
```

## Local testing of the sandbox

`./build.sh --sign dev --open` signs with the Apple Development certificate and the real sandbox
entitlements, which is the closest you can get to the App Store build without the distribution certs.
