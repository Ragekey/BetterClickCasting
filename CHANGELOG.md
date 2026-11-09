# Changelog

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
