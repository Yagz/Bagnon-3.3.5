# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A backport of the Bagnon bag addon suite (by Tuller) to the World of Warcraft **3.3.5 (WotLK) client**, `## Interface: 30300`. The tree was ported from a newer/older Bagnon release; commit `27a08f8 "Reverts for 3.3.5"` shows the kind of API adjustments needed (e.g. `InterfaceOptionsFrame_OpenToCategory`, `UIDropDownMenu_SetWidth(frame, width)`, no `this` global, `SetNormalFontObject` instead of `SetTextFontObject`). Anything added must only use APIs that exist in the 3.3.5 client (Lua 5.1). Features from later expansions (e.g. Void Storage) are removed, not ported.

There is no build system, test suite, or linter. Each top-level directory is a separate addon that gets copied/symlinked into `World of Warcraft/Interface/AddOns/`; testing is done in-game (`/reload`). A quick syntax check is possible with `luac -p <file>` (note the system Lua may be newer than 5.1, so it won't catch 5.1-only incompatibilities).

## Addons in this repo

- **Bagnon** — core: inventory, bank and keyring frames. `SavedVariables: BagnonGlobalSettings`, per-character `BagnonFrameSettings`.
- **Bagnon_Config** — LoadOnDemand Interface Options panels; loaded when `InterfaceOptionsFrame` is shown or via `Bagnon:ShowOptions()`.
- **Bagnon_GuildBank** — LoadOnDemand, disabled by default; core replaces `GuildBankFrame_LoadUI` to load it. Registers as an AceAddon module of Bagnon and adds the `guildbank` frame (tabs, item/money log).
- **Bagnon_Forever** — standalone; provides the global `BagnonDB` (cached inventory/bank of other characters). Core treats it as optional (`if BagnonDB then ...`).
- **Bagnon_Tooltips** — requires Bagnon_Forever; adds "who has this item" counts to tooltips.

## Load order

Files are loaded in the order listed in each `.toc`, then via the `.xml` include files (`embeds.xml`, `localization.xml`, `utility.xml`, `components.xml`, …). **A new Lua file must be added to the appropriate `.xml`/`.toc` or it will never load.** XML paths use backslashes (`components\foo.lua`). Order matters: `Bagnon/main.lua` creates the AceAddon object, then `utility.xml` loads `ears.lua` → `classy.lua` → `callbacks.lua` before anything that depends on them.

## Core architecture (Bagnon/)

- **Namespace**: every file starts with `local Bagnon = LibStub('AceAddon-3.0'):GetAddon('Bagnon')` and attaches its object to it (`Bagnon.Frame`, `Bagnon.ItemSlot`, `Bagnon.Settings`, …). Extension addons reach core classes the same way.
- **Classes** (`utility/classy.lua`): `Bagnon.Classy:New(frameType, parentClass)` creates a widget "class" (a real hidden frame used as metatable). Instances are created with `Class:Bind(CreateFrame(...))`. Subclassing is used by extensions, e.g. `Bagnon_GuildBank` does `Classy:New('Frame', Bagnon.Frame)` and overrides methods, calling the parent explicitly (`Bagnon.Frame.UpdateEvents(self)`).
- **Internal message bus** (`utility/ears.lua`, `utility/callbacks.lua`): `Bagnon.Callbacks` is a simple pub/sub separate from WoW events. Class instances use `self:RegisterMessage(msg)` / `self:SendMessage(msg, ...)`, and the handler method has the same name as the message. Most UI updates flow through these messages rather than direct calls.
- **Frame IDs**: each window is identified by a string — `'inventory'`, `'bank'`, `'keys'`, `'guildbank'`. Almost every component is constructed with a `frameID` and ignores messages whose first argument is a different frameID.
- **Settings layers**:
  - `FrameSettings:Get(frameID)` — runtime, per-frame state object; its setters persist to the DB and broadcast messages with the frameID as first arg (`FRAME_SHOW`, `FRAME_HIDE`, `PLAYER_UPDATE`, `ITEM_FRAME_COLUMNS_UPDATE`, `BAG_SLOT_SHOW`, …). Show/Hide is reference-counted so auto-opened frames (bank, vendor, AH…) don't close manually-opened ones.
  - `SavedFrameSettings` / `SavedSettings` — wrappers around the SavedVariables with default tables (defaults are stripped on logout via `removeDefaults`).
  - `Settings` — global (account-wide) settings.
- **Item/bag state**: `utility/itemEvents.lua` (`Bagnon.BagEvents`) translates WoW bag events into slot-level messages (`ITEM_SLOT_ADD/REMOVE/UPDATE`, `BAG_UPDATE_TYPE`, `BANK_OPENED/CLOSED`). `BagSlotInfo` / `ItemSlotInfo` / `PlayerInfo` abstract over "live" vs "cached" data: when viewing another character or the bank while away, data comes from `BagnonDB` (Bagnon_Forever) instead of the container API.
- **Blizzard integration** (`main.lua`): the stock bag functions (`ToggleBag`, `OpenAllBags`, `ToggleKeyRing`, …) are replaced/hooked so Bagnon frames open instead; if a frame is disabled or doesn't control that bag, the original function is called. `BankFrame`'s open/close events are unregistered and replayed manually when the Bagnon bank is disabled.

## Localization

Strings come from AceLocale (`L = LibStub('AceLocale-3.0'):GetLocale('Bagnon')`, `'Bagnon-Config'`, etc.). When adding a user-facing string, add it to the base `localization.lua` (enUS) of the relevant addon; other locales fall back to it. Bagnon_Forever (`BAGNON_FOREVER_LOCALS`) and Bagnon_Tooltips (plain `BAGNON_*` globals) don't use AceLocale.
