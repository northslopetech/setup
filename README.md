# Northslope Machine Setup Script

# Usage

Run the following command

```
/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/northslopetech/setup/refs/heads/latest/setup.sh)"
```

## After

You can now use the command `setup` in your terminal to run the latest version of this script.

```
setup
```

# Essential Tools

If you prefer not to run the full setup script, the following tools are necessary for Northslope development:

- **`git`** - Version control
- **`node`** - JavaScript runtime (v18+ required, v24 recommended)
- **`pnpm`** - Fast, disk space efficient package manager
- **`gh`** - GitHub CLI (required for repository operations)
- **`direnv`** - Environment variable management

Install these on your own, and that will get you off the ground.
For convenience, we also recommend **`asdf`** for managing tool versions across projects,
though it's not strictly required if you prefer to install tools manually.
