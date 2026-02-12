# Ecash App Release Process

## Release Candidates

- Create release branch (if new major/minor): `git checkout -b releases/vX.Y`
- Update versions:
  - `pubspec.yaml`: `version: X.Y.Z-rc.N+VCODE` (see Version Code Reference below)
  - `rust/ecashapp/Cargo.toml`: `version = "X.Y.Z-rc.N"`
  - `just build-linux`
  - `flutter analyze`
- Commit: `git commit -am "chore: bump version to vX.Y.Z-rc.N"`
- Push: `git push upstream releases/vX.Y`
- Tag: `git tag -a -s vX.Y.Z-rc.N`
- Push tag: `git push upstream vX.Y.Z-rc.N`
- Verify GitHub release created with APK and AppImage

## Final Release

- On release branch: `git checkout releases/vX.Y`
- Create final release branch: `git checkout -b releases/vX.Y.Z`
- Update versions:
  - `pubspec.yaml`: `version: X.Y.Z+VCODE` (see Version Code Reference below)
  - `rust/ecashapp/Cargo.toml`: `version = "X.Y.Z"`
  - `linux/appstream/org.fedimint.app.appdata.xml`: Add `<release version="X.Y.Z" date="YYYY-MM-DD" />` entry
- Commit: `git commit -am "chore: bump version to vX.Y.Z"`
- Push: `git push upstream releases/vX.Y.Z`
- Tag: `git tag -a -s vX.Y.Z`
- Push tag: `git push upstream vX.Y.Z`
- Verify GitHub release created with APK and AppImage

## Post-Release

- Add branch protection to `releases/vX.Y` (first release only)
- PR to bump master to next alpha:
  - `pubspec.yaml`: `version: X.(Y+1).0-alpha`
  - `rust/ecashapp/Cargo.toml`: `version = "X.(Y+1).0-alpha"`

## Version Code Reference

The version code (VCODE) must be included in `pubspec.yaml` after a `+` suffix for F-Droid auto-update detection.

- RC: `VCODE = major*1000000 + minor*10000 + patch*100 + rc_num`
- Final: `VCODE = major*1000000 + minor*10000 + patch*100 + 90`

Examples:
- `0.5.0` → `version: 0.5.0+50090`
- `0.5.0-rc.1` → `version: 0.5.0-rc.1+50001`
- `1.0.0` → `version: 1.0.0+1000090`
