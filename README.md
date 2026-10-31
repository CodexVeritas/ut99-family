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
| `./join.sh` | Opens the game and connects straight to the family server. |
| `./server.sh` | Hosts the family server in this terminal. Close the terminal or press Ctrl+C to stop it. |

The server runs Deathmatch on DM-lol-Harbour with Low Gravity + StuffSwapper and bots.
It needs UDP ports 7777-7778 forwarded to the hosting PC. It is not listed publicly;
people join with the host's address.

## Notes

- Everything lives in this folder. Delete the folder to uninstall.
- Change your look later in the game: Options > Player Setup.
- Re-run `./setup.sh` to change the saved server address or your profile.
- Quit the game before editing anything in `game/System64/*.ini`; the game rewrites those files on exit.
- The base game downloads from OldUnreal's official mirror. The mod pack is a release
  download from this repo and contains only community content, not Epic's game files.
