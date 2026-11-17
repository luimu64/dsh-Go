# This fork

`luimu64/dsh-Go` is a personal build fork of [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go).
All credit for the app belongs upstream; this fork only adds the English localization pass and
publishes builds of it.

## What `main` carries

`main` is upstream `main` plus the English work, always. It is not a mirrors-only fork, and it is
not a place to park experiments: anything that is not part of the English pass or the release
pipeline belongs on a branch.

Upstream does not accept external pull requests (see its `CONTRIBUTING.md` and
`.github/workflows/pr-gate.yml`), so this fork is where the work lives instead of a PR against
upstream.

## How upstream is tracked

- `git fetch upstream && git merge upstream/main` on `main`, conflict resolved by hand. The
  helper `/opt/data/scripts/dsh-go-sync` on the maintainer's machine does this weekly, in a
  throwaway worktree, and refuses to push a conflicted merge.
- `.github/workflows/release.yml` additionally follows upstream releases: when `ccch1mneyyy/dsh-Go`
  tags `vX.Y.Z`, it syncs that tag into `main` through a PR and, once merged, builds and publishes
  the English arm64 APK as `DSH Go X.Y.Z English`.

Keep the diff against upstream small. Every edited upstream file is a file that has to be merged by
hand on the next sync, so new docs go in fork-only files like this one rather than rewriting
upstream pages.

## Building

```bash
tooling/build-apk.sh -f arm64 -- --dart-define=DSH_UPDATE_REPO=luimu64/dsh-Go
```

`DSH_UPDATE_REPO` makes the in-app updater check this fork's releases instead of upstream's.
Without it the build updates from upstream, which is a valid way to run it.
