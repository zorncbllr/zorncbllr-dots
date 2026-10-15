# zorncbllr-dots

Arch Linux + Hyprland + quickshell desktop with a zsh/kitty/starship terminal,
installed by symlinking (GNU stow) so your live configs *are* the repo files.

```sh
git clone https://github.com/zorncbllr/zorncbllr-dots && cd zorncbllr-dots
./install.sh --dry-run      # preview the links
./install.sh                # packages (yay) + links + groups/services + zsh as login shell
./uninstall.sh              # remove the symlinks again
```

Options: `--no-deps`, `--no-system`, `--no-chsh`, or name stow packages
(`./install.sh zsh kitty`). Files that already exist are moved to
`~/.dotfiles-backup-<timestamp>/` first. Links are per file (`stow --no-folding`),
so files apps generate at runtime never end up in this repo.

## Layout
| Path | Contents |
|---|---|
| `stow/zsh` | `.zshrc`, `.zshenv`, `zshrc.d/` — plain Arch plugin packages, no oh-my-zsh. Put machine-specific bits in `~/.zshrc.local` (see `.zshrc.local.example`) |
| `stow/kitty`, `starship`, `fastfetch` | terminal, prompt, greeting |
| `stow/hypr`, `quickshell`, `matugen` | compositor (lua), shell UI, colour generation |
| `stow/desktop` | fuzzel, wlogout, fonts, Qt/KDE theming, flags files |
| `packages/packages.txt` | everything `install.sh` installs |
| `sdata/` | local PKGBUILDs (MicroTeX, cursor theme) and the python venv requirements |

## Credits and licence
Derived from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
(Illogical Impulse) and its contributors. Licensed under GPL-3.0, see `LICENSE`.
Upstream is tracked as the `upstream` remote; changes are cherry-picked, not merged blindly.
