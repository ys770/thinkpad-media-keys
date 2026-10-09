# ThinkPad Media Keys

Turn the "productivity" keys on recent ThinkPads (Snipping Tool, Phone Link, ★) into
**Previous / Play-Pause / Next track** keys on Windows. No AutoHotkey, no background process.
The tool is a 4 KB program that sends one media key and exits. Lenovo's own hotkey software launches it.

| Key (P14s Gen 5) | Lenovo default | After |
|---|---|---|
| F10 | Snipping Tool | ⏮ Previous track |
| F11 | Phone Link (or a Microsoft Store web page if Phone Link isn't installed) | ⏯ Play / Pause |
| F12 ★ | User-defined | ⏭ Next track |

**Tested on:** ThinkPad P14s Gen 5 AMD (21ME), Windows 11 24H2, Lenovo Hotkey driver 10.17.2606.
It should work on other ThinkPads that use the same driver (`fn.inf` / `TPHKLOAD` / `shtctky.exe`),
but their key IDs may differ. `find-keys.ps1` will tell you yours. If you get it working on another model, please open
a PR or issue so it can be added to the list.

## Why PowerToys and similar remappers don't work

These keys don't send keystrokes. The keyboard firmware reports a Lenovo "hotkey event" that
Lenovo's hotkey service (`shtctky.exe`, running as SYSTEM) handles itself by launching an app or a link.
Windows never sees a key press, so PowerToys / AutoHotkey key remapping can't catch it.

## How it works

**1. The AppLaunch table (Snipping Tool key, and others).**
Before running its built-in action, `shtctky.exe` checks
`HKLM\SOFTWARE\Lenovo\ShortcutKey\AppLaunch\<key id>` for an override. That's how Fn+F2 "lock"
and the ★ key are wired up. Adding an entry for a key's ID makes Lenovo launch your program
instead. Key IDs look like `Ex_91` and aren't documented, so `find-keys.ps1` finds them by
temporarily adding a logging entry for every possible ID and recording which ones fire.

**2. The Phone Link key is special.**
Its handler ignores the override and works like this:
- If the **Phone Link app is not installed**, it opens a hardcoded `https://www.microsoft.com/store/apps/9NMPJ99VJBWV` page.
- If it **is** installed, it opens the `ms-phone:` link.

So the fix is:
1. Make sure Phone Link is installed. Some refurbished or debloated PCs *deprovision* it, which
   blocks reinstalling (`0x80073CF6`). The installer removes that block and keeps a backup.
2. Register this tool as an app that can open `ms-phone:` links, and choose it as the default.
   After that, pressing the key runs Play/Pause instantly.

(Pointing an AppLaunch entry at the Phone Link key "sort of" works, but Lenovo retries it
every ~6 s while it waits for Phone Link, so playback toggles several times. Don't do that.)

**3. The ★ key** is officially customizable in Lenovo Commercial Vantage, but only to "open an app".
The tool ships copies named `Next.exe` / `Prev.exe` / `PlayPause.exe` that act based on their
own file name, and puts Start Menu shortcuts where Vantage's app picker can see them.

## Install

Requirements: Windows 10/11, the Lenovo Hotkey driver (installed by default on ThinkPads), and admin rights.
The C# compiler that ships with Windows is used to build the program, so there's nothing else to install.

1. Download or clone this repo.
2. Open **PowerShell as administrator** (as your own user) in the repo folder.
3. *(Other models only)* find your key IDs:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\find-keys.ps1
   ```
4. Install. The defaults are for the P14s Gen 5:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   # other models / mappings, e.g.:
   # .\install.ps1 -PrevKeyId Ex_91 -NextKeyId Ex_9B -PhoneLinkKey playpause
   ```
5. Press the **Phone Link key** once. When Windows asks which app to use, pick
   **ThinkPad Media Keys** and tick **Always**.
6. **★ key:** in Lenovo Commercial Vantage, go to User-defined key → Open an app →
   Start Menu → ThinkPad Media Keys → **Media Next Track**.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```
This removes the overrides, the link handler, the shortcuts and the files. Phone Link stays installed.

## Troubleshooting

- **Phone Link opens instead of the "which app" prompt.** Windows only shows the prompt when it
  notices a new handler. Settings → Default apps → "Choose defaults by link type" doesn't list
  `MS-PHONE`. Try signing out and back in, then pressing the key again.
- **It stopped working after an update.** Lenovo driver updates may reset the AppLaunch table, so re-run `install.ps1`.
  If Phone Link got removed, the F11 key will open the Store page again. Reinstall Phone Link to fix it.
- **A key does nothing during `find-keys.ps1`.** That's expected. It means that key goes through the
  table and was captured. Everything is restored when the script finishes.

## Prior art

- [qwerty12/T470-F10-F12-MediaKeys](https://github.com/qwerty12/T470-F10-F12-MediaKeys): the same
  AppLaunch idea for the 2017 T470, using AutoHotkey.
- ThinkPad forum threads on `ShortcutKey\AppLaunch` (e.g. remapping the ThinkVantage button).
- Linux added support for the Phone Link key in 2024 (`KEY_LINK_PHONE`, hotkey event `0x1320`).

New here: the Phone Link key on 2024+ ThinkPads, automatic key-ID discovery, and no
AutoHotkey dependency.

## Disclaimer

This changes Lenovo and Windows registry settings. It's been tested on one machine. Use it at your own
risk, and run `uninstall.ps1` to revert.

## License

MIT
