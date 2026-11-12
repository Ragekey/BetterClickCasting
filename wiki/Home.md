# Better Click Casting Wiki

Welcome to the official documentation for **Better Click Casting** for *WoW Forever*.

**Better Click Casting** upgrades Blizzard's built-in **Click Cast Bindings** (`ClickBindingFrame`) and **Spellbook** (`PlayerSpellsFrame`) with full **Spell Rank support**, **Smart Rank Rules**, **1-Click Spellbook Binding**, a **Unit Frame Hover Overlay**, and **Character Profile Sharing**, all while staying 100% native and taint-free.

---

## 1. Quick Start

### How to Open Better Click Casting
* **Click Cast Bindings Window**:
  * Type **`/bcc`** in chat.
  * **Left-Click** the **Better Click Casting** Minimap button (or the Addon Compartment entry).
  * Or open via `Esc -> Options -> Keybindings -> Click Casting`.
* **Better Click Casting Settings Window (4 Tabs)**:
  * Type **`/bcc cfg`** in chat (or `/bcc cfg 1` through `/bcc cfg 4`).
  * **Right-Click** the **Better Click Casting** Minimap button.
  * Click the **Gear Icon** in the top-left portrait area of Blizzard's Click Cast Bindings window.
  * Or open via `Esc -> Options -> AddOns -> Better Click Casting`.

---

## 2. Spellbook Direct-Binding & Key Badges

When you open `/bcc`, **Better Click Casting** automatically opens your Spellbook alongside the Click Cast window, switches to your primary class tab, and activates **Show All Spell Ranks**.

* **1-Click Direct Bind**: Simply press your desired mouse button (or modifier + mouse button, such as `Shift + Left-Click` or `Mouse Button 4`) directly on any spell icon in your Spellbook to bind that exact spell rank immediately.
  * **Important Note (`LMB` / Left-Click)**: Be careful when clicking a spell with an unmodified **Left-Click (`LMB`)** while the Click Cast window is open, as this will immediately bind that spell to `LMB` and override your default **Target Unit** left-click action! (You can re-add *Target Unit* anytime via **Add Binding**, or toggle 1-Click Direct Bind in Tab 2 / via `/bcc qb`).
* **Spellbook Key Badges**: Bound spells display a green badge (such as `LMB`, `S-RMB`, `CS-MB4`) directly on their Spellbook icon so you can see at a glance which ranks are bound.

---

## 3. Spell Ranks, Smart Rank Rules & Trainer Upgrades

In *WoW Forever*, spells have multiple ranks with different healing/damage values and mana costs.

### Visual Rank Indicators & Inline Rank Switcher
* **Rank & Live Mana Display**: Every spell row in `ClickBindingFrame` shows its exact bound rank and current mana cost.
* **Max-Rank vs. Downrank Highlighting**:
  * Spells at your highest learned rank display a green **`[MAX]`** tag.
  * Intentional or outdated downranks are highlighted in orange with a hint showing your highest available rank, such as **`(Rank 2 / Max 4)`**.
* **Inline Rank Switcher Dropdown**:
  * **Left-Click** the compact rank button on any row to switch between all learned ranks of that spell (showing mana costs and full tooltips) without re-binding your mouse button.
  * **Right-Click** the rank button to jump straight to your highest learned rank (**`MAX`**).

### Smart Rank Rules
You can assign a **Smart Rank Rule** to each spell binding via the Inline Rank Switcher dropdown:
* **Always MAX**: Automatically tracks your highest learned rank when you visit a class trainer.
* **Always MAX - 1 / MAX - 2 / MAX - 3**: Automatically keeps the binding 1, 2, or 3 ranks below your highest learned rank for mana-efficient downranking!
* **Fixed Rank**: Locks the binding to a specific rank and never prompts for upgrades.

### Trainer Upgrade Behavior (Tab 1)
When you learn a new spell rank that affects one of your bindings, you can choose between three behaviors:
1. **Show Upgrade Hero-Card (Default)**: Displays a movable floating notification card after learning a new rank (once out of combat). Clicking **Update** opens the Click Cast window, applies your Smart Rules, and highlights Blizzard's **Save** button.
2. **Auto-Open & Prepare**: Automatically opens the Click Cast window as soon as you close the trainer window (and are out of combat), pre-applies all rank upgrades, and highlights Blizzard's **Save** button.
3. **Manual Only**: Disables automatic notifications; you can still upgrade anytime inside `/bcc` or via `/bcc max`.

> **Why do I need to click Blizzard's "Save" button myself?**
> In the modern WoW client, Blizzard protects `C_ClickBindings.SetProfileByInfo` with `SecretArguments = "AllowedWhenUntainted"`. To keep your UI 100% free of combat taint and protected action errors, **Better Click Casting** prepares all rank changes in the list and highlights Blizzard's native **Save** button with a golden glow so your single hardware click saves the profile cleanly through Blizzard's secure code.

---

## 4. Unit Frame Hover Overlay (Tab 3)

The optional **Unit Frame Hover Overlay** shows a compact, live HUD card whenever you hover over a clickable Unit Frame (`PlayerFrame`, `TargetFrame`, `FocusFrame`, `PartyFrame`, `CompactRaidFrame`, or third-party unit frames registered in `ClickCastFrames`).

* **Activation Modes**:
  * **Off**: Disabled.
  * **When Holding a Modifier (`Shift` / `Ctrl` / `Alt`)**: Only appears while you hold a modifier key over a unit frame.
  * **Always on Unit Frame Hover**: Appears whenever your cursor rests on a unit frame and dynamically updates as you press `Shift`, `Ctrl`, or `Alt`.
* **Live Mana & Out-of-Mana Warning**: Displays live mana costs for each bound spell. If your current mana is insufficient for a spell, its name is dimmed and the mana cost turns red.
* **6 Anchor Modes**: Attach the overlay to the **Cursor**, **Top Edge**, **Bottom Edge**, **Left Edge**, **Right Edge** of the hovered unit frame, or place it at a **Free Movable Position** on your screen.
* **Global Unlock & Placeholder Mode (`/bcc move`)**: Unlocks both the **Upgrade Hero-Card** and the **Unit Frame Hover Overlay** with a green border and sample bindings so you can drag them anywhere on screen. **Right-Click** either card while unlocked to reset its position.

---

## 5. Character Profiles, Direct Copy & `!BCC1:...!` Share Strings (Tab 4)

**Better Click Casting** automatically snapshots your Settings, Click Cast Keybinds, and Smart Rules per character (including full *WoW Forever* first and last names).

* **Direct Character Copy (`/bcc copy`)**:
  * Select any of your characters in Tab 4 (`Profiles & Share`) and choose **Settings + Keybinds**, **Keybinds Only**, or **Settings Only**.
  * **Cross-Character Spell Rank Resolution**: When copying bindings to a lower-level alt or twink, **Better Click Casting** automatically matches spells by name and applies your Smart Rule (`MAX`, `MAX-1`, `MAX-2`, `MAX-3`, `FIXED`) using the highest compatible rank learned by the target character! Macros are matched automatically by name.
* **Compact `!BCC1:...!` Export & Import Strings (`/bcc export`, `/bcc import`)**:
  * Share your setup with friends or back it up as a safe, compact `!BCC1:...!` text string (no `loadstring` or executable code).
* **Merge vs. Replace & Character-Specific Settings**:
  * Enable **Merge Keybinds** (`/bcc merge`) to add imported bindings without deleting your existing non-conflicting bindings.
  * Enable **Character-Specific Settings** (`/bcc charsettings`) if you want a specific character to use its own independent AddOn settings instead of the global account profile.

---

## 6. Complete `/bcc` Slash Command Reference

Every setting and action can be controlled both in the graphical Settings window (`/bcc cfg`) and via `/bcc` slash commands:

| Command | Description |
| :--- | :--- |
| `/bcc` | Toggle Blizzard's Click Cast Bindings window + Spellbook |
| `/bcc cfg [1\|2\|3\|4]` | Open the Better Click Casting Settings window (optionally directly on Tab 1 to 4) |
| `/bcc profile` | Open Tab 4 (`Profiles & Share`) |
| `/bcc export [all\|bindings\|settings]` | Open the `!BCC1:...!` export popup |
| `/bcc import [all\|bindings\|settings]` | Open the `!BCC1:...!` import popup |
| `/bcc copy [all\|bindings\|settings] <Name>` | Copy Settings and/or Keybinds from a saved character (supports first + last name) |
| `/bcc charsettings` | Toggle character-specific settings for the current character |
| `/bcc merge` | Toggle Merge vs. Replace mode when importing/copying keybinds |
| `/bcc max` | Prepare all bound spells in `ClickBindingFrame` at their highest learned rank |
| `/bcc list` | Open a copyable text summary of all current Click Cast bindings |
| `/bcc move` (or `/bcc unlock`) | Toggle the Global Overlay Unlock & Placeholder mode |
| `/bcc reset` | Reset all movable overlay positions to default |
| `/bcc group [mod\|button\|type\|none]` | Set Click Cast list grouping mode |
| `/bcc trainer [card\|auto\|off]` | Set Trainer Upgrade behavior |
| `/bcc hover [off\|mod\|always]` | Set Unit Frame Hover Overlay activation mode |
| `/bcc anchor [cursor\|top\|bottom\|left\|right\|free]` | Set Unit Frame Hover Overlay anchor mode |
| `/bcc scale <70-150>` | Set Unit Frame Hover Overlay scale (`70%` to `150%`) |
| `/bcc alpha <30-100>` | Set Unit Frame Hover Overlay background opacity (`30%` to `100%`) |
| `/bcc lang [auto\|en\|de\|es]` | Switch AddOn language live in-game without `/reload` |
| `/bcc qb` / `/bcc badges` / `/bcc allranks` / `/bcc autotab` | Toggle Spellbook Quick-Bind, Badges, Auto-Show All Ranks, or Auto Class-Tab |
| `/bcc ranks` / `/bcc downrank` / `/bcc switcher` / `/bcc mana` | Toggle Rank in Name, Downrank Highlight, Inline Rank Switcher, or Mana Costs |
| `/bcc rules` / `/bcc bottom` / `/bcc tooltips` / `/bcc minimap` | Toggle Smart Rank Rules, Move Interactions to Bottom, Tooltips, or Minimap Button |
| `/bcc status` | Print current active settings in chat |
| `/bcc debug [copy]` | Run live `issecurevariable` taint diagnostics |
| `/bcc help` | List all available slash commands in chat |

---

## 7. Frequently Asked Questions (FAQ)

**Q: Does Better Click Casting cause action bar or pet bar taint in combat?**
**A:** No. Better Click Casting uses non-destructive `hooksecurefunc` hooks, shields spellbook slots when switching tabs, suppresses restricted cooldown secret-values on tainted spellbook items, reads unit frames passively without attaching scripts to protected frames, and leaves final profile saving to a hardware click on Blizzard's native `SaveButton`. You can verify this anytime in-game with `/bcc debug`.

**Q: Does the Unit Frame Hover Overlay work with third-party unit frames (like ElvUI, Cell, Grid2, ShadowedUnitFrames)?**
**A:** Yes! Any unit frame that uses Blizzard's `SecureUnitButtonTemplate` (`unit` attribute) or registers in the standard global `ClickCastFrames` table is detected automatically.

**Q: Which languages are supported?**
**A:** English (`enUS` / `enGB`), German (`deDE`), and Spanish (`esES` / `esMX`), with a 100% English fallback and a live in-game switcher (`/bcc lang`).
