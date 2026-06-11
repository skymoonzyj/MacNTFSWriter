# Upload to GitHub

The project directory is not a git repository yet. Use these commands when you are ready to publish it.

## First upload

```bash
cd ~/Downloads/MacNTFSWriter
git init
git add .
git commit -m "Initial NTFS Writer for Mac release"
git branch -M main
git remote add origin git@github.com:YOUR_NAME/MacNTFSWriter.git
git push -u origin main
```

Replace `YOUR_NAME/MacNTFSWriter.git` with your GitHub repository URL.

## Create a release

After the first push, create a version tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

GitHub Actions will build the DMG and create the GitHub Release automatically.

## Manual fallback

If GitHub Actions is unavailable, build locally:

```bash
cd ~/Downloads/MacNTFSWriter
./scripts/prepare-github-release.sh 0.1.0
```

Then upload files from `dist/release-0.1.0/` to GitHub Release manually.

## What users download

Users should download `MacNTFSWriter-0.1.0.pkg` and install it.

Alternatively, they can download `MacNTFSWriter-0.1.0.dmg`, open it, and drag `MacNTFSWriter.app` into Applications.

If the app is not signed with Developer ID, macOS may ask users to right-click and choose Open. Once you have an Apple Developer account, follow `docs/RELEASE.md` to sign and notarize the app.
