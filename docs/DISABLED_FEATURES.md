# Disabled Features

A running, **developer-only** list of features that are currently hidden from
the app. There is intentionally **no in-app screen** for users to toggle these —
enabling/disabling is done in code only.

The single source of truth is `DisableableFeature.disabled` in
[`FinTrack/Core/Models/DisableableFeature.swift`](../FinTrack/Core/Models/DisableableFeature.swift).
**This file must be kept in sync with that set** — whenever you add or remove a
case there, update the table below in the same commit.

> Disabling a feature only hides its UI (and, where the feature actively
> transmits data, stops its background work). No code, model, or data is ever
> deleted, so any feature here can be switched back on later.

## Currently disabled

| Feature | Where it lived | Notes |
|---|---|---|
| Collaborative Planner | Settings → Premium Features | Premium row hidden. |
| Insurance Optimizer | Settings → Premium Features | Premium row hidden. |
| Remittance Tracker | Settings → Premium Features | Premium row hidden. |
| Tax Management | Settings → its own section | Whole `sectionCard` hidden. |
| Business & Freelancer | Settings → its own section | Whole `sectionCard` hidden. |
| Audit Log | Security & Privacy → Audit Log card | UI card hidden. Background audit **logging** keeps running; only the toggle + viewer are hidden. |
| Google Drive Backup | Settings → Data & Privacy | Row hidden **and** the background sync loop in `RootView` is gated off, so previously-connected accounts stop uploading. |

## How to disable a feature

1. If the feature isn't already a `DisableableFeature` case, add one (with its
   `symbol`, `tint`, and the right `category`), and make its call site check
   `feature.isEnabled` (see the existing Tax Management / Audit Log / Google
   Drive examples). For a feature that actively sends data somewhere, also gate
   its background code path, not just the UI entry point.
2. Add the case to the `disabled` set in `DisableableFeature.swift`.
3. Add a row to the table above.

## How to re-enable a feature

1. Remove the case from the `disabled` set in `DisableableFeature.swift`.
2. Delete its row from the table above.
