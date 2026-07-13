# Contributing to Hideaway

Thanks for helping make Hideaway better. Small, focused changes are easiest to review.

## Development

1. Fork and clone the repository.
2. Create a branch from `main`.
3. Run `swift build` and `swift test` before opening a pull request.
4. For UI changes, launch with `swift run Hideaway` and exercise both stash and restore.
5. Describe any macOS preference behavior you changed and how you verified restoration.

Never test against a Mac whose current Finder, Dock, widget, or menu-bar settings you cannot safely change. Restore the app before terminating a manual test whenever possible.

## Pull requests

- Keep unrelated changes out of the same pull request.
- Update `CHANGELOG.md` under **Unreleased** for user-visible behavior.
- Add or update documentation when behavior, requirements, or release steps change.
- Do not commit credentials, signing identities, notarization files, or Sparkle private keys.

## Releasing

Releases are automated by `.github/workflows/release.yml`.

1. Update `CHANGELOG.md`, commit, and ensure CI is green.
2. Confirm the repository secret `SPARKLE_PRIVATE_KEY` contains the base64 private key exported from Sparkle's `generate_keys` tool for account `com.takhoffman.hideaway`.
3. Create and push a semantic-version tag such as `v0.1.0`.
4. The workflow builds a universal app, creates a signed zip, publishes a GitHub Release, and commits the updated signed appcast to `main`.
5. Install the release archive on a clean account and verify **Check for Updates…** before announcing it.

For a production Developer ID release, set `CODE_SIGN_IDENTITY` and add the corresponding signing/notarization setup to the workflow. Sparkle's EdDSA signature still protects update archives independently.
