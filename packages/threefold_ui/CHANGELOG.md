# Changelog

## 0.1.0

First release (SOP Appendix C, Sections 5, 11 and 13).

- `DevBanner` and `devBannerBuilder`: the orange DEV ribbon for `MaterialApp.builder`, with a custom message such as "DEV: FREE".
- `DevTile`, `DevSectionHeader`, `DevBadge`, `devLabel`, `kDevOrange`: the one look for every dev control.
- `GloveButton` (filled, outlined or text, at least 60 by 60, required semantic label), `GloveIconButton` (60) and `LabeledIconButton` (48).
- `PermissionExplainer` and `PermissionExplainerScreen`: headline, reason, 60 point button, Open Settings when denied forever, optional Not Now; never calls an OS API.
- `EmptyState`, `LoadingState`, `ErrorState`, `StaleBanner`: shared async states with text and colours from the app.
