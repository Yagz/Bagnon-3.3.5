# Bagnon for WoW 3.3.5

A backport of [Bagnon](https://www.curseforge.com/wow/addons/bagnon), Tuller's single-window bag addon, for the **World of Warcraft 3.3.5a (Wrath of the Lich King)** client (`Interface: 30300`).

Bagnon merges all your bags into one window, and does the same for your bank, keyring and guild bank. It also lets you browse the inventory of your other characters and search through your items.

## Addons

The repository holds several addons. Each folder is a separate addon:

| Folder | Role |
| --- | --- |
| `Bagnon` | Core addon: inventory, bank and keyring windows. Required. |
| `Bagnon_Config` | Options panels under *Interface > AddOns*. Loaded on demand. |
| `Bagnon_GuildBank` | Guild bank window. Loaded on demand, **disabled by default**. |
| `Bagnon_Forever` | Remembers the items of all your characters so you can view them offline. |
| `Bagnon_Tooltips` | Adds to item tooltips how many of the item each character owns. Requires `Bagnon_Forever`. |

## Installation

Copy (or symlink) **each** `Bagnon*` folder directly into `World of Warcraft/Interface/AddOns/`. Don't copy the repository folder itself: WoW only loads addons that sit directly in `AddOns/`.

```
Interface/AddOns/
├── Bagnon/
├── Bagnon_Config/
├── Bagnon_Forever/
├── Bagnon_GuildBank/
└── Bagnon_Tooltips/
```

To get the guild bank window, enable *Bagnon Guild Bank* in the addon list on the character selection screen.

### Development setup

Symlink the folders instead of copying them, so your changes show up in game after a `/reload`:

```sh
for d in /path/to/Bagnon-3.3.5/Bagnon*/; do
    ln -sfn "${d%/}" "/path/to/World of Warcraft/Interface/AddOns/"
done
```

Restart the client fully after adding a new Lua file or `.toc` entry, since `/reload` may not pick up new files.

## Usage

- **Slash commands**: `/bagnon` or `/bgn`, followed by `bags`, `bank`, `keys`, `config`, `version` or `help`.
- **Key bindings**: *Key Bindings > Bagnon* to toggle the inventory, bank and keyring.
- **LibDataBroker launcher**: left-click for the inventory, Shift-click for the bank, Alt-click for the keyring, right-click for options.
- **Window title**: Alt-drag to move the window, right-click to configure it, double-click to search.
- **Clean button**: sorts the items in the window.

### Guild bank

With `Bagnon_GuildBank` enabled, the guild bank window supports:

- sorting the current tab (clean button), one move at a time;
- item and money logs;
- buying the next tab by clicking it (guild leader only), with a warning if you can't afford it;
- renaming a tab and changing its icon by right-clicking it (guild leader only).

## Changes from upstream

This port started from an older Bagnon release and adjusts it to the 3.3.5 API. Features from later expansions, such as Void Storage, were removed. On top of that it fixes guild bank sorting, adds guild bank tab buying and editing, adds guild bank logs, and fixes item tooltips that went stale or kept growing after a withdrawal.

## Credits

- Original addon: **Tuller**.
- 3.3.5 backport: Richard Steininger, 5Buttons and Yagz.
