# threefoldpackages

Shared Dart and Flutter packages for Threefold Studio apps and games (SOP Appendix C).

| Package | Holds | Used by |
|---|---|---|
| `packages/threefold_kit` | App clock and dev time travel, day keys, dates, money in cents, phone formatting, copy checks | Every Flutter app and game |
| `packages/threefold_ui` | Dev ribbon and Dev controls, glove-size buttons, permission explainer, empty, loading and error states | Every Flutter app |
| `packages/threefold_game_kit` | Save store with backup, lives, daily rewards and streaks, season pass, sky clock, sync client | Every game |

Releases are tagged automatically: after a merge to `main`, `.github/workflows/release-tag.yml` publishes `v<RELEASE_VERSION>` if that tag does not exist yet. To release, raise `RELEASE_VERSION` and every package's `pubspec.yaml` version together in one pull request (the checks refuse a mismatch). A published tag never moves.

An app depends on a package by git, pinned to a tag:

```yaml
dependencies:
  threefold_kit:
    git:
      url: https://github.com/Threefold-Studio/threefoldpackages.git
      path: packages/threefold_kit
      ref: v0.1.0
```
