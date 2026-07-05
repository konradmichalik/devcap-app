# Release

## Steps

1. **Bump version** in `project.yml`:
   ```yaml
   MARKETING_VERSION: "x.y.z"
   ```

2. **Regenerate Xcode project** to sync the version into `project.pbxproj`:
   ```bash
   make xcode
   ```

3. **Commit both files**:
   ```bash
   git add project.yml DevcapApp.xcodeproj/project.pbxproj
   git commit -m "release: vx.y.z"
   ```

4. **Tag the release**:
   ```bash
   git tag vx.y.z
   ```

5. **Push**:
   ```bash
   git push && git push --tags
   ```

## Code Signing & Notarization

> **Status:** not yet enabled. Releases are currently built with ad-hoc signing
> (`CODE_SIGN_IDENTITY="-"`), so users must right-click → *Open* to bypass
> Gatekeeper and no integrity guarantee is provided beyond `checksums.txt`.
> The release workflow already contains the signing/notarization steps — they
> stay inactive until the secrets below exist, then run automatically.

### Why

A Developer ID signature plus notarization lets the app launch without the
Gatekeeper warning and proves the artifact has not been tampered with.

### One-time prerequisites

1. Join the [Apple Developer Program](https://developer.apple.com/programs/).
2. Create a **Developer ID Application** certificate (Xcode → Settings →
   Accounts → Manage Certificates, or the Developer portal).
3. Export it from Keychain Access as a `.p12` (private key included) and set an
   export password.
4. Create an **app-specific password** for notarization at
   [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security.
5. Base64-encode the certificate for storage as a secret:
   ```bash
   base64 -i DeveloperID.p12 | pbcopy
   ```

### Required GitHub repository secrets

| Secret | Value |
|--------|-------|
| `MACOS_CERTIFICATE_BASE64` | base64 of the Developer ID Application `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | the `.p12` export password |
| `MACOS_SIGN_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `MACOS_NOTARY_APPLE_ID` | Apple ID email used for notarization |
| `MACOS_NOTARY_PASSWORD` | app-specific password from step 4 |
| `MACOS_NOTARY_TEAM_ID` | your 10-character Apple Team ID |

Add them under **Settings → Secrets and variables → Actions**.

### What the workflow does once the secrets are set

1. Imports the certificate into a temporary keychain.
2. Re-signs `DevcapApp.app` with the Developer ID identity and the **hardened
   runtime** (`--options runtime --timestamp`).
3. Packages the DMG, submits it with `xcrun notarytool submit --wait`, and
   staples the ticket with `xcrun stapler staple`.

Steps are guarded by `if: env.MACOS_CERTIFICATE_BASE64 != ''`, so nothing
changes for the current unsigned flow until every secret is present.

### Verifying a signed build locally

```bash
codesign -dvvv --verbose=4 DevcapApp.app     # identity + hardened runtime flag
spctl -a -vvv --type execute DevcapApp.app   # "accepted, source=Notarized Developer ID"
xcrun stapler validate devcap-arm64-apple-darwin.dmg
```

> **Note:** these steps are untested in CI (they require the secrets above).
> After adding the secrets, cut a throwaway pre-release tag to validate the
> pipeline end-to-end before relying on it.

## Versioning

Follows [Semantic Versioning](https://semver.org/):

- **Patch** (`0.6.1` → `0.6.2`) — bug fixes, UI tweaks
- **Minor** (`0.6.x` → `0.7.0`) — new features, backward-compatible
- **Major** (`0.x.y` → `1.0.0`) — breaking changes

## Notes

- `project.yml` is the source of truth for the version — `MARKETING_VERSION` maps to the user-facing version string
- `CURRENT_PROJECT_VERSION` stays at `"1"` (incremented only for App Store builds)
- Always run `make xcode` after changing `project.yml` so the generated `.xcodeproj` stays in sync
