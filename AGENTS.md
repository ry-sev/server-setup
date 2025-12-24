# AGENTS.md

## Build/Test Commands
- **Lint**: `shellcheck setup.sh deploy.sh modules/*.sh` (install: `apt install shellcheck`)
- **Dry run**: `bash -n <script.sh>` to syntax-check without executing
- **Test single module**: `sudo ./modules/<module>.sh` (requires root, runs on live system)

## Code Style Guidelines
- **Shebang**: Always `#!/bin/bash` with `set -euo pipefail` for strict mode
- **Imports**: Source utils first: `source "${SCRIPT_DIR}/utils.sh"`
- **Functions**: Use `snake_case`, define before use, document with `# comment` above
- **Variables**: UPPERCASE for exports/config (`DOMAIN`), lowercase for locals (`local username`)
- **Quoting**: Always quote variables `"$var"`, use `[[ ]]` for conditionals
- **Logging**: Use `log_info`, `log_success`, `log_warning`, `log_error`, `log_step` from utils.sh
- **Error handling**: Exit with `exit 1` on errors, use `|| true` to ignore expected failures
- **Idempotency**: Scripts should be safe to run multiple times (check before creating)
- **Backups**: Use `backup_file` before modifying system files
- **Structure**: Each module has `setup_<name>()` main function, runs if executed directly:
  ```bash
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
      setup_modulename
  fi
  ```
