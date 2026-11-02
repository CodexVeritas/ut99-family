# Unreal Tournament (GOTY) for the family

Native Linux Unreal Tournament 99 with the OldUnreal 469e patch and our mod pack
(Chaos UT, Rocket Arena, StuffSwapper, Rebel Mac and other weapon/skin packs, 300+ extra maps).
Works on Ubuntu and Arch/Omarchy (64-bit PCs).

## 1. Download

```bash
git clone https://github.com/CodexVeritas/ut99-family.git
cd ut99-family
```

## 2. Set up (once)

```bash
./setup.sh
```

It installs a few system packages (asks for your password), downloads the game
(about 1.8 GB), then asks for your screen size, player name, character, team color,
and the family server's address.

## 3. Play (every time)

| Command | What it does |
|---|---|
| `./play.sh` | Opens the game. Practice Session already has Low Gravity + StuffSwapper on. |
| `./join.sh` | Checks the family server is up, asks for its password the first time, then opens the game connected to it. |
| `./server.sh` | Hosts the family server in this terminal. Close the terminal or press Ctrl+C to stop it. |
| `./update.sh` | Gets the latest shared settings, mods, and fixes. Your profile, key bindings, and server password are kept. Hosts: stop the server first, then start it again after. |

The server runs Deathmatch on DM-lol-Harbour with Low Gravity + StuffSwapper and bots.
It needs UDP ports 7777-7778 forwarded to the hosting PC. It is not listed publicly;
people join with the host's address.

### Joining from inside the game

This always works, including on a server with a password:

1. Run `./play.sh` and wait for the main menu.
2. Go to **Multiplayer > Open Location**.
3. Type the server address with its port, e.g. `203.0.113.5:7777`, and press OK.
4. Type the server password when the box asks for it.

`./join.sh` does the same in one step. It remembers the password in `.server-password` on your
PC only (never uploaded). If the password changes, it clears the saved one and asks again next time.

## Sharing your settings with everyone

Change settings in the game (mutators, game rules, map rotations, key bindings), quit it, then run:

```bash
./publish-settings.sh
```

It copies them into `config/`, shows what changed, and asks before pushing. Your name, screen size,
passwords, and server history are left out, and it refuses to publish anything that looks like an
IP address. Everyone else picks the changes up with `./update.sh`; their own profile and key
bindings stay as they are (key binding changes reach new installs only).

## Notes

- Everything lives in this folder. Delete the folder to uninstall.
- Change your look later in the game: Options > Player Setup.
- Re-run `./setup.sh` to change the saved server address or your profile.
- `./update.sh` resets in-game Options (sound, video) when shared settings changed, because those
  live in the same file as the shared game settings.
- Quit the game before editing anything in `game/System64/*.ini`; the game rewrites those files on exit.
- The base game downloads from OldUnreal's official mirror. The mod pack is a release
  download from this repo and contains only community content, not Epic's game files.
