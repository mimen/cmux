---
deployment_status: partial
deployment_last_assessed: 2026-10-03
deployment_targets:
  - component: macOS desktop app
    where: none
    detail: This fork does not deploy the fleet app; installed copies use upstream manaflow-ai/cmux releases and Sparkle updates
  - component: cmux CLI
    where: none
    detail: This fork does not deploy the fleet CLI; installed copies are bundled in the upstream macOS app
---

# cmux fork deployment

This records deployment ownership for the `mimen/cmux` fork. Read it with [PROJECT.md](PROJECT.md) before treating a fork change as a running release.

The fork's macOS desktop app has no evidenced fleet deployment. Installed `/Applications/cmux.app` copies on the M5, M3, and Mini use upstream's [Sparkle appcast](https://github.com/manaflow-ai/cmux/releases/latest/download/appcast.xml), matching `SUFeedURL` in [Resources/Info.plist](Resources/Info.plist). [README.md](README.md) documents Homebrew and upstream DMG installation. These are upstream release-channel installs, not local builds from this fork.

The fork's `cmux` CLI has no evidenced fleet deployment. Each inspected upstream app bundles its CLI at `/Applications/cmux.app/Contents/Resources/bin/cmux`, as [the release workflow](.github/workflows/release.yml) specifies.

The repository contains cloud, iOS, and package-release configurations, but those do not establish deployments owned by this fork. They are omitted from the targets. The status is partial because release automation exists but no fork-owned delivery to the fleet was established.
