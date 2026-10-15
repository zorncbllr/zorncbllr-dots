# zorncbllr-dots

An Arch Linux desktop: Hyprland (lua config) + quickshell UI, with a zsh / kitty /
starship / fastfetch terminal. Configs are installed as symlinks (GNU stow), so the
files in `~/.config` *are* the files in this repo and edits are tracked by git.

> **Status:** the linking, backup, dry-run and uninstall logic is tested. The full
> first-time path (installing `yay`, building the local packages, the system setup
> step) has not been run on a fresh machine yet. Try it in a VM first.

## Install

Arch Linux only. Run as your normal user (it uses `sudo` where needed).

```sh
git clone https://github.com/zorncbllr/zorncbllr-dots ~/zorncbllr-dots
cd ~/zorncbllr-dots
./install.sh --dry-run      # preview: links per package, existing files, files that differ
./install.sh                # packages + links + groups/services + zsh as login shell
```

Log out and back in afterwards (groups, login shell and environment).

**Keep the clone where you put it.** The symlinks point into this directory; if you
move or delete it, the desktop configs break. If you move it, run `./install.sh` again.

| Option | Effect |
|---|---|
| `--dry-run` | change nothing; show what would be linked or backed up |
| `--no-deps` | skip package installation and the python venv |
| `--no-system` | skip groups, kernel module and services (needs sudo) |
| `--no-chsh` | keep your current login shell |
| `<pkg> ...` | only link these stow packages, e.g. `./install.sh zsh kitty` |

### What it does
1. **Packages:** installs only what is *missing* (`pacman -T`, so an installed
   provider such as `quickshell-git` is not replaced) via `yay`, from
   `packages/packages.txt`; builds MicroTeX and the cursor theme from `sdata/dist-arch`;
   creates the python venv used by the quickshell scripts.
2. **Links:** existing files that would be overwritten are moved to
   `~/.dotfiles-backup-<timestamp>/`, then each stow package is linked. Links are per
   file (`stow --no-folding`), so files apps create at runtime never land in the repo.
3. **Generated files** (`hypr/hyprland/colors.lua`, `hypr/hyprlock/colors.conf`,
   `fuzzel/fuzzel_theme.ini`, `kdeglobals`) are rewritten whenever the wallpaper or theme
   changes. They are listed in each package's `.seed-files`: copied once as defaults,
   never linked and never overwritten.
4. **System setup:** adds you to `video,i2c,input`, loads `i2c-dev`, enables
   `bluetooth` and the `ydotool` user service, builds the `pkgfile` database.

### Uninstall
```sh
./uninstall.sh              # removes the symlinks only; packages and backups stay
```
Copy anything you want back from `~/.dotfiles-backup-<timestamp>/`.

## Layout
| Path | Contents |
|---|---|
| `stow/zsh` | `.zshrc`, `.zshenv`, `zshrc.d/`. Uses the Arch packages `zsh-autosuggestions`, `zsh-syntax-highlighting` and `pkgfile`; no oh-my-zsh |
| `stow/kitty`, `starship`, `fastfetch` | terminal, prompt, greeting |
| `stow/hypr`, `quickshell`, `matugen` | compositor, shell UI, colour generation |
| `stow/desktop` | fuzzel, wlogout, fonts, Qt/KDE theming, flags files |
| `stow/bin` | small scripts for `~/.local/bin` (`keepawake`) |
| `packages/packages.txt` | every package `install.sh` may install |
| `sdata/` | local PKGBUILDs (MicroTeX, cursor theme) and the python venv requirements |

## Customising
- **Machine-specific shell config:** put aliases, functions and `PATH` additions in
  `~/.zshrc.local` (untracked, sourced by `.zshrc`). See `stow/zsh/.zshrc.local.example`.
- **Hyprland:** your own binds, rules and variables go in `~/.config/hypr/custom/`.
- **Add a package:** create `stow/<name>/` mirroring `$HOME` (e.g.
  `stow/foo/.config/foo/foo.conf`) and re-run `./install.sh foo`.
- **A file the desktop regenerates:** list it in `stow/<pkg>/.seed-files` and in
  `stow/<pkg>/.stow-local-ignore` (see `stow/hypr/`).

## Troubleshooting
- **Greeting (fastfetch) output missing in kitty:** the colour-sequence file must end
  its last escape sequence with `\`; an unterminated one makes the terminal swallow
  whatever is printed next. This repo's template is fixed and `zshrc.d/dots-hyprland.zsh`
  adds the missing `\` defensively.
- **"command not found" gives no package suggestions:** run `sudo pkgfile --update` once.

## Credits and licence
Derived from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
(Illogical Impulse) and its contributors. Licensed under GPL-3.0, see `LICENSE`.
Upstream is tracked as the `upstream` remote; changes are cherry-picked, not merged blindly.
