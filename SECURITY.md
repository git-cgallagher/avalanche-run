# Security policy

## Reporting a vulnerability

Please report security issues **privately** through GitHub:
[Report a vulnerability](https://github.com/git-cgallagher/avalanche-run/security/advisories/new)
(the **Security** tab, then **Report a vulnerability**). Don't open a public issue for a security problem.

You can expect an acknowledgement within a week. This is a one-person project, so fixes are best effort.

## Supported versions

Only the latest release gets fixes.

## Scope

Avalanche Run is an offline macOS game. It makes no network connections, has no accounts and
stores only its settings and local high-score table in the app's UserDefaults. Release builds
are ad-hoc signed, not notarized; see the README for what that means when you install it.
