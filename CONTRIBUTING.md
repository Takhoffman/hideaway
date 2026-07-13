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

Releases are published from the maintainer's Mac so the Sparkle private key never leaves the local Keychain.

1. Update `CHANGELOG.md`, commit, and ensure CI is green.
2. Confirm Sparkle's signing key for account `com.takhoffman.hideaway` is available in the local Keychain.
3. Run `Scripts/release.sh 0.1.0` with the intended semantic version.
4. The script builds a universal app, creates a signed zip, publishes a GitHub Release, and commits the updated signed appcast to `main`.
5. Install the release archive on a clean account and verify **Check for Updates…** before announcing it.

For a production Developer ID release, set `CODE_SIGN_IDENTITY` and add the corresponding signing/notarization setup to the workflow. Sparkle's EdDSA signature still protects update archives independently.
