Purpose
-------
This repository must be installed at the root path C:\EcaAfrica on tablets. The included helper scripts help enforce and automate moving the repository to that location.

Quick usage
-----------
- Move an existing clone into place (interactive):
  - Run `scripts\ensure-install-root.ps1` from the repository root. It will move files (preserving `.git`) into `C:\EcaAfrica`.

- Install a git hook to run the check after merges/pulls:
  - Run `scripts\install-git-hooks.ps1` from the repository root. This installs a `post-merge` hook that invokes the movement script.

Notes
-----
- The movement script avoids overwriting an existing `C:\EcaAfrica` repo unless `-Force` is supplied.
- Running from inside an existing `C:\EcaAfrica` subfolder (e.g. `C:\EcaAfrica\Tablet_Setup`) will abort — it expects the repository root to be the true root path.
- Hooks are installed into `.git/hooks` (local only).
