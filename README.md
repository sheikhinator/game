# Lycho

A realistic, GTA-style life simulator for Android, built with Godot 4.7.

## Get the APK

Every push to `main` builds a debug APK with GitHub Actions.

1. Open the **Actions** tab and pick the latest green **Build APK** run.
2. Download the **Lycho-apk** artifact (a zip containing `Lycho.apk`).
3. Unzip it on your phone and install `Lycho.apk` (allow installs from unknown sources).

## Milestone 1 (current)

- Title screen with a live flyover of downtown Port Calder, Continue / New Game / Load / Settings
- Third-person character with touch joystick, camera drag, run and jump
- Downtown city blocks with photo-scanned asphalt, street lamps and hydrants
- Real-time day–night cycle with street lights at night
- GTA-style HUD: rotating minimap, health and stamina bars, clock and cash
- Pause menu: Map, Brief, Stats, Settings, Game (15 save slots)

## Project layout

| Folder | Contents |
| --- | --- |
| `scripts/` | Game code (GDScript) |
| `scripts/ui/` | Menus, HUD, touch controls |
| `shaders/` | Clothing shader for characters |
| `assets/` | Third-party CC0 art (see credits) |
| `.github/workflows/` | APK build |

## Credits

All third-party assets are CC0 (public domain):

- Characters, hairstyles, animations and the downtown city kit by [Quaternius](https://quaternius.com)
- Asphalt, pavement, fabric textures and street props from [Poly Haven](https://polyhaven.com)
