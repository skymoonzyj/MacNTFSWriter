# Release Guide

This project can produce a local unsigned DMG today, and it is ready to move to a signed/notarized release when you have an Apple Developer account.

## Local release

```bash
cd MacNTFSWriter
./scripts/prepare-github-release.sh 0.1.0
```

Upload everything in `dist/release-0.1.0/` to a GitHub Release.

## GitHub Actions release

Push a tag to let GitHub build and publish the release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The workflow runs `swift build`, `swift test`, creates a DMG, uploads it as an artifact, and creates a GitHub Release for tag builds.

## Signing

Local ad-hoc signing is automatic when packaging the DMG. It makes the app bundle structurally signed, but it does not remove Gatekeeper warnings for public users.

For public distribution, use a Developer ID Application certificate:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./scripts/package-dmg-macos.sh
```

## Notarization

Set Apple notarization credentials and enable notarization:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE=1 \
APPLE_ID="you@example.com" \
APPLE_TEAM_ID="TEAMID" \
APPLE_APP_PASSWORD="app-specific-password" \
./scripts/package-dmg-macos.sh
```

The script signs the `.app`, submits it with `notarytool`, staples the ticket, and then builds the DMG.

## Before publishing

- Test on a Mac without Homebrew to confirm the install guidance is clear.
- Test on a clean NTFS disk that was fully shut down from Windows.
- Test on a hibernated/dirty NTFS disk and confirm the app recommends read-only or Windows repair.
- Test first launch after downloading from GitHub, especially if the build is unsigned.
- Keep macFUSE approval wording visible because macOS requires user approval for that system extension.
