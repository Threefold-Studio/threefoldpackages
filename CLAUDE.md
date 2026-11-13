# threefoldpackages: CLAUDE.md

Shared packages for every Threefold Studio app and game. This repo follows the Threefold Studio SOP (TFS-SOP-001) in Threefold-Studio/sop; read its Appendix C and the section each package implements.

## Rules for this repo
1. Every package is pure where it can be: `threefold_kit` and the rules inside `threefold_game_kit` import no Flutter plugin, so they test with `dart test` and no device.
2. Every public function has tests. Run `dart test` (or `flutter test` for Flutter packages) and `dart analyze --fatal-infos` in each changed package before every commit.
3. Breaking changes raise the major part of the tag (v1 to v2); apps pin a tag, never a branch.
4. Changing behaviour here changes every app that upgrades: say in the pull request which apps are affected.
5. No app-specific names, colours, copy or keys in any package; apps pass those in.

## Studio rules
SOP sections 0.7 to 0.11 apply (branch and pull request, Codex review, commits authored Seth A. Ward Sr. <admin@threefoldstudio.co> with no AI trailer, stage files by path). This repo ships no app builds; merges start no build.
