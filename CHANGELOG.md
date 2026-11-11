# Changelog

## [0.7.2] (2026-11-11)
### Fixed
- **Hover Overlay vs. Character Panel Stat Rows (`PaperDollFrame`):** Fixed the Unit Frame Hover Overlay appearing when hovering over Movement Speed or Weapon Damage stat rows in the Character / Pet / Inspect panel (where Blizzard sets `statFrame.unit = "player"` on the text row). `FindHoveredUnitFrame` now strictly verifies that a hovered frame is an actual clickable Unit Button (`SecureButton_GetUnit`, `ClickCastFrames`, or HUD UnitFrame) and ignores Character, Inspect, and Spellbook panels.
- **Full-Width Save Button Glow:** Replaced the square tutorial slot atlas on `ClickBindingFrame.SaveButton` with Blizzard's 3-slice `newplayertutorial-yellowGlow-redbutton-left/middle/right` button glow pattern so the golden highlight spans the full width of the Save button cleanly at any resolution.

## [0.7.1] (2026-11-11)
### Fixed
- **Hover Overlay Position Reset (`UnitHoverTooltip.ResetPosition`):** Fixed a Lua function declaration order issue when resetting the unlocked Unit Frame Hover Overlay position via Right-Click or `/bcc resetpos`.

## [0.7.0] (2026-11-11)
### Added
- **Character Profiles, Direct Copy & `!BCC1:...!` String Import/Export (Tab 4: `Profiles & Share`):**
  - **Direct Character Copy (`/bcc copy`):** Automatically snapshots your Settings, Click Cast Keybinds, and Smart Rules per character (including full *WoW Forever* first and last names). Copy **Settings + Keybinds**, **Keybinds Only**, or **Settings Only** from any character on your account with 1 click.
  - **Intelligent Cross-Character Spell Rank & Macro Resolution:** Imported or copied spell bindings automatically resolve to the highest compatible learned rank or Smart Rule (`MAX`, `MAX-1`, `MAX-2`, `MAX-3`, `FIXED`) on the target character and match macros by name, preparing all bindings directly in `ClickBindingFrame` with the native **Save** button highlighted.
  - **Compact `!BCC1:...!` Export & Import Strings (`/bcc export`, `/bcc import`):** Share or back up **Settings + Keybinds** (`all`), **Keybinds Only** (`bindings`), or **Settings Only** (`settings`) via safe, URL-escaped strings without `loadstring`.
  - **Character-Specific Settings (`/bcc charsettings`) & Merge Mode (`/bcc merge`):** Optionally isolate settings for individual characters instead of account-wide, and choose whether importing/copying keybinds replaces or merges with your current bindings.
- **Full Spanish Localization (`esES` / `esMX`) & Live Language Switcher (`/bcc lang`):**
  - Added complete Spanish (`esES` and `esMX`) localization alongside English (`enUS` / `enGB`) and German (`deDE`), always backed by a 100% English fallback.
  - Added a live **AddOn Language** selector in Tab 2 (`Auto (Client)`, `English`, `Deutsch`, `Español`) and `/bcc lang [auto|en|de|es]` that switches all UI text on the fly without `/reload`.

### Fixed
- **Hover Overlay vs. Right-Click Context Menus:** Lowered the Unit Frame Hover Overlay from the `TOOLTIP` layer to the `DIALOG` layer (above all unit frames, but strictly below Blizzard's `FULLSCREEN_DIALOG` context menus, dropdowns, and `GameTooltip`) and added automatic hiding while any right-click context menu (`Menu.GetManager():IsAnyMenuOpen()`) is open.
- **Unified English Output for `/bcc debug`:** Standardized all live taint diagnostic messages and copyable reports in `/bcc debug` to English for easier international bug reporting.

## [0.6.0] (2026-11-10)
### Added
- **Dedicated 3-Tab Settings Window (`BetterClickCastingSettingsFrame` & `/bcc cfg`):**
  - Replaced the right-click context menu with a movable, Blizzard-styled settings window organized into three clean tabs: **Click Cast**, **Spellbook & General**, and **Hover Overlay**.
  - Accessible via the gear button inside `ClickBindingFrame`, Right-Clicking the Minimap button, `Esc -> Options -> AddOns -> Better Click Casting` (fully indexed in Blizzard's global Options search bar), or `/bcc cfg`.
- **Hover Overlay Fine-Tuning & Global Unlock Mode (`/bcc move`):**
  - Added sliders for **Overlay Scale** (`70%` to `150%`) and **Background Opacity** (`30%` to `100%`), plus toggles for **Show Mana Costs** and **Show Rank Status Tags** (`[MAX]`, `[-1]`, `[-2]`).
  - **Global Overlay Unlock & Placeholder Mode (`/bcc move` / `/bcc unlock`):** Simultaneously unlocks both the Rank Update Hero-Card and the Unit Frame Hover Overlay with green borders and sample rows so you can position both cards anytime (Right-Click either card to reset to default position).
- **Click Cast & Spellbook Quality-of-Life Enhancements:**
  - **Live Mana Costs in Binding Rows (`/bcc mana`):** Displays each bound spell rank's mana or resource cost right-aligned in the top row of the Click Cast list.
  - **Move Default Interactions to Bottom (`/bcc bottom`):** Places the default `Target Unit` and `Open Context Menu` rows at the bottom of the list so custom spell bindings start right at the top.
  - **Configurable Trainer Upgrade Behavior (`/bcc trainer [card|auto|off]`):** Choose whether learning new spell ranks at a class trainer shows the **Upgrade Hero-Card** (`card`), **Auto-Opens & Prepares** `/bcc` with the Save button highlighted (`auto`), or stays **Manual Only** (`off`).
  - **Auto-Select Active Class/Spec Spellbook Tab (`/bcc autotab`):** Automatically switches the Spellbook from the General tab (`Tab 1`) to your primary class tab (`Tab 2`) when opening Click Cast Bindings.
  - **Copyable Binding Summary (`/bcc list`):** Generates a clean, formatted text summary of all bound spells, ranks, mana costs, and Smart Rules for easy copying (`Ctrl+C`), sharing, or backup.
- **Complete Power-User `/bcc` Slash Command Set:**
  - Every setting and action can now be controlled directly via `/bcc` commands (`/bcc help`, `/bcc cfg`, `/bcc upgrade`, `/bcc list`, `/bcc move`, `/bcc resetpos`, `/bcc group`, `/bcc hover`, `/bcc anchor`, `/bcc trainer`, `/bcc mana`, `/bcc bottom`, `/bcc autotab`, `/bcc combat`, `/bcc status`).

### Fixed
- **Spellbook Portrait Button Tooltip:** Fixed Blizzard's Spellbook portrait button inside `ClickBindingFrame` showing *"Talents"* (`PLAYERSPELLS_BUTTON`) instead of *"Spellbook"* (`SPELLBOOK`).
- **Spellbook Cooldown Secret-Value Protection:** Unregistered `SPELL_UPDATE_COOLDOWN` on tainted `SpellBookItemFrame` instances so `SetCooldown()` never receives restricted `<secret number>` cooldown values during combat or active GCD.

## [0.5.0] (2026-11-09)
### Added
- **Unit Frame Hover Overlay (Optional, Default: Off):**
  - Displays a compact, 100% taint-free overlay when hovering over unit frames (`Only While Holding Modifier` or `Always When Hovering Unit Frames`).
  - Shows the currently active modifier (`No Modifier`, `SHIFT`, `CTRL`, `ALT`, etc.) and a clean 3-column table of bound spells for that modifier: mouse button (`LMB`, `RMB`, `MMB`, `MB4+`), spell icon + name + rank with `[MAX]` / `[-1]` / `[-2]` status tags, and live mana costs.
  - **Live Out-of-Mana Detection:** Automatically grays out spell rows and highlights mana costs in red when your current mana is insufficient for that rank.
  - **6 Anchor Options:** Follow Mouse Cursor, attach to the hovered Unit Frame (`Top`, `Bottom`, `Left`, `Right`), or use a `Free Position (Saved & Movable)` that can be dragged anytime while `/bcc` is open or via the menu unlock toggle.
  - **Combat & Interaction Toggles:** Hidden in combat by default with an optional `Show in Combat` setting, plus an optional toggle to include `Target Unit` and `Open Context Menu` actions.

## [0.4.3] (2026-11-06)
### Fixed
- **Complete Spellbook Hover Taint Protection (`_G.PET_ACTION_HIGHLIGHT_MARKS` & `PetActionBar:SetShownBase()`):**
  - Extended `BCCQuickBindButton` so it shields all valid `SpellBookItem` slots (including passive spells, unlearned spells, and when 1-Click Direct Bind is disabled) while `ClickBindingFrame` is open, as well as any `SpellBookItem` slots whose `elementData` was initialized while opening `ClickBindingFrame` via `/bcc` or the Minimap button.
  - Outside of Click Binding mode, clicks on shielded `SpellBookItem` slots cleanly forward to `OnModifiedIconClick` and `OnIconClick` while keeping `_G.PET_ACTION_HIGHLIGHT_MARKS` and `_G.ON_BAR_HIGHLIGHT_MARKS` 100% untainted during combat target changes (`TargetNearestEnemy`).
  - Moved the automatic *"Show All Spell Ranks"* CVar sync (`ShowAllSpellRanks = 1`) to login/addon load instead of calling `UpdateDisplayedSpells(true, false)` during `ClickBindingFrame:OnShow`.
- **Enhanced `/bcc debug` Diagnostics:**
  - Added a copyable `Ctrl+C` dialog popup (`/bcc debug` on findings or `/bcc debug copy`), `SpellBookFrame` element taint inspection, and status reporting for overlay-shielded Spellbook items.

## [0.4.2] (2026-11-06)
### Fixed
- **Rank 1 -> Rank 2 Smart Rule Initialization:** Bound spells that currently only have `Rank 1` learned in the Spellbook are now automatically initialized with the **Always MAX** rule in the background. When learning `Rank 2` at a class trainer later, the Upgrade Hero-Card reliably appears so you can upgrade immediately or switch to **Fixed Rank** via *"Keep Current Ranks"*.

## [0.4.1] (2026-11-06)
### Fixed
- **Combat `PetActionBar:SetShownBase()` Taint Fix:** Decoupled the Spellbook 1-Click Quick-Bind overlay (`BCCQuickBindButton`) hover and drag handlers from `SpellBookItemMixin:OnIconEnter`, `OnIconLeave`, and `OnIconDragStart` so hovering spells in the Spellbook while Click Cast Bindings is open never calls `PetActionBar:ClearPetActionHighlightMarks()` or `PetActionBar:Update()` from AddOn context.
- **Diagnostics (`/bcc debug`):** Added an in-game taint scanner command (`/bcc debug` and `/bcc debug taintlog`) that inspects `PetActionBar`, action bars, `EditModeManagerFrame`, and highlight globals via `issecurevariable`.

## [0.4.0] (2026-11-06)
### Added
- **Smart Rank Rules (Per Binding):**
  - Assign automatic rank rules per binding in the inline rank dropdown: **Always MAX**, **Always MAX - 1**, **Always MAX - 2**, **Always MAX - 3**, or **Fixed Rank (No Auto-Update)**.
  - Existing max-rank bindings automatically start with **Always MAX**, while intentional downranks start as **Fixed Rank**.
- **Rank Update Hero-Card:**
  - When learning new spell ranks at your class trainer (or on login/reload with pending Smart Rule updates), a movable Blizzard-styled notification card displays all affected bindings and their rank transitions.
  - **Open & Upgrade:** Opens Click Cast Bindings, applies the new ranks from your Smart Rules, and highlights the **Save** button in gold.
  - **Keep Current Ranks:** Locks the listed bindings to their current fixed rank (**Fixed Rule**) so the reminder won't appear again for them.
  - Remembers its screen position when dragged.

## [0.3.1] (2026-11-06)
### Fixed
- **Spellbook vs. Talent Tree Tab Fix:** Opening Click Cast Bindings after viewing the Talent Tree (`N`) now automatically switches `PlayerSpellsFrame` back to the **SpellBook** tab instead of opening the Talent Tree in the center of the screen and closing `ClickBindingFrame`.

## [0.3.0] (2026-11-05)
### Added
- **List Grouping & Logical Sorting:**
  - Switchable grouping inside `ClickBindingFrame` via the header selector pill (`Group: Modifier`) or the Settings menu: group by **Modifier** (`Direct Click`, `Shift + Click`, `Ctrl + Click`, `Alt + Click`), **Mouse Button** (`LMB`, `RMB`, `MMB`, `MB4+`), **Action Type** (`Spells`, `Pet Actions`, `Macros`), or **Off** (flat list with logical mouse-button and modifier sorting).
- **1-Click Direct Bind in Spellbook:**
  - Added a `"1-Click Direct Bind"` pill checkbox at the bottom-left of `SpellBookFrame` while `ClickBindingFrame` is open, allowing any mouse button (including `LMB`, `RMB`, `MMB`, `MB4+`, and `Shift/Ctrl/Alt` modifiers) to bind spells in a single click.
- **Persistent Spellbook Key Badges:**
  - Bound key badges (`LMB`, `RMB`, `MMB`, `S-LMB`, `MB4`, `MB5`) and tooltip lines now remain visible in the Spellbook at all times (even when `ClickBindingFrame` is closed) using `C_ClickBindings.GetProfileInfo()`.
- **Modernized Integrated Buttons:**
  - Upgraded the inline rank switcher (`92x22`), the permanently visible row delete button, the `"Group: ..."` header selector, the Spellbook `"1-Click Direct Bind"` bar, and Spellbook key badges with Blizzard's dark/gold rounded pill atlases (`common-dropdown-c-button`, `common-dropdown-a-button`).
  - Added a native gear badge (`questlog-icon-setting`) to the circular settings portrait button inside `ClickBindingFrame`.
- **Minimap Button & Addon Compartment:**
  - Uses Blizzard's native `clickcast-icon-mouse` atlas for crisp, mipmapped in-game rendering.
  - Left-Click to directly open/close Blizzard's native Click Cast Bindings window (`ClickBindingFrame`).
  - Right-Click to open the Better Click Casting Settings menu.
  - Freely draggable around the Minimap (`BetterClickCastingDB.minimapAngle`) plus `/bcc` and `/bcc minimap` slash commands.
- **Native Settings Button inside `ClickBindingFrame`:**
  - Added a circular settings portrait button right next to the Macro and Spellbook buttons at the top right of `ClickBindingFrame`.
  - Live toggles for: Rank in Name, `[MAX]` & Downrank Highlighting, Inline Rank Switcher, Full Tooltips, 1-Click Spellbook Quick-Binding, Spellbook Key Badges, Auto-Enable *"Show All Spell Ranks"* while Click Binding is open, and Minimap Button visibility.
  - **1-Click Action:** *"Upgrade All Bound Spells to MAX Rank"* directly from the settings menu.

## [0.2.0] (2026-11-05)
### Added
- **Inline Rank Switcher:** Switch between all learned ranks of a bound spell directly inside the Click Cast Bindings list via Left-Click dropdown (with mana costs and tooltips), Right-Click (instant upgrade to MAX rank), or Mouse Wheel scrolling without re-binding the mouse button.
- **Max-Rank & Downrank Detection:** Clearly distinguishes between your highest learned rank (`[MAX]`) and lower ranks (`Rank X / Max Y`).
- **Full Row Tooltips:** Hovering any spell, pet action, or macro in `ClickBindingFrame` displays the full rank-accurate spell tooltip or macro body.
- **Spellbook Quick-Binding:** Clicking a spell in the Spellbook while in Click Binding mode always adds/fills a slot automatically without having to click *"Add Binding"* first.
- **Spellbook Key Badges:** Displays the bound mouse button shorthand (`M1`, `S-M2`, etc.) directly on bound spell ranks in the Spellbook.
- **Localization & Modular Architecture:** Full `enUS` (default fallback) and `deDE` localization with modular `Core/`, `Locales/`, and `Modules/` structure.

## [0.1.0] (2026-11-05)
### Added
- Initial release displaying spell ranks (`C_Spell.GetSpellSubtext`) in `ClickBindingFrame` rows, icon rank badges (`R1`, `R2`, ...), and unbound warning messages.
