# Better Click Casting

### The Backstory (or: Why This AddOn Exists)

Back in the Beta, I dutifully reported an issue for Blizzard's built-in **Click Cast Bindings** menu. Why? Because while the native Click Casting system itself is rock-solid, its UI was clearly copy-pasted straight from Retail, a magical place where **Spell Ranks** haven't existed for fifteen years.

* **Want to know if that Flash Heal in your list is Rank 1, Rank 4, or Rank 7?** *Good luck guessing!*
* **Learned a new spell rank at your class trainer and want to upgrade your binding?** *Have fun deleting the row, hunting down the spell in your Spellbook, and binding it all over again!*
* **Want to see a tooltip in the list to check mana costs?** *Too bad!*

Sadly, the menu never got any love from Blizzard (even Blizzard's native tooltips had to be fixed).
**So here is the missing Classic upgrade Blizzard forgot to ship:**

---

### Features

**Better Click Casting** upgrades Blizzard's native Click Cast window and Spellbook with full **Spell Rank support** and quality-of-life features for *WoW Forever*, without replacing Blizzard's system or requiring heavy unitframe add-ons like VuhDo, Cell, or HealBot.

* **Visible Spell Ranks, Live Mana Costs & Unlearned Spell Warnings:** Shows the exact bound rank right next to every spell name, such as **Flash Heal (Rank 4)**, plus live mana costs directly in the Click Cast row. Automatically flags spells that are currently unlearned (for example after a talent respec) with a desaturated icon and a red **`[NOT LEARNED]`** warning.
* **Max-Rank & Downrank Detection:** Marks spells at your highest learned rank with a green **[MAX]** tag and highlights lower ranks in orange with a max-rank hint like **(Rank 2 / Max 4)**.
* **Inline Rank Switcher:** Switch between all learned ranks directly inside the Click Cast row via a compact dropdown (including mana costs and tooltips), or **Right-Click** the rank button to jump straight to **MAX** without re-binding your mouse button.
* **Smart Rank Rules & Trainer Upgrade Modes:** Assign rules per binding (**Always MAX**, **Always MAX - 1**, **Always MAX - 2**, **Always MAX - 3**, or **Fixed Rank**). When you learn a new spell rank at your class trainer, choose between the compact **Upgrade Hero-Card**, **Auto-Open & Prepare** (highlighting the Save button right after closing the trainer), or **Manual Only**.
* **Per-Character Binding Presets / Loadouts (`/bcc preset`):** Save and switch between multiple named Click Cast setups on the same character (such as **Raid**, **Dungeon**, or **Solo / Off-Spec**) directly from the header dropdown inside `ClickBindingFrame`, in Tab 4, or via **`/bcc preset [load|save|del|list] <Name>`**.
* **Visual Free Keys Matrix (`4x5` / `8x5` Cheat-Sheet, `/bcc keys`):** Open a live visual grid showing all bound and **`[FREE]`** combinations of `Direct`, `Shift`, `Ctrl`, `Alt` (plus optional multi-modifier combinations `Shift+Ctrl`, `Shift+Alt`, `Ctrl+Alt`, `S+C+A` for 40 slots) across `LMB`, `RMB`, `MMB`, `MB4`, and `MB5`. Accessible via the **Matrix** header button in `ClickBindingFrame`, Right-Clicking the settings gear icon, **`/bcc keys [combos|auto]`**, or automatically whenever `/bcc` opens.
* **Compact Binding Rows (`/bcc compact`):** Reduces row height in `ClickBindingFrame` from `46 px` to `32 px` by default so almost twice as many bound spells fit on screen without scrolling.
* **1-Click Upgrade All & Copyable Binding Summary:** Upgrade all bound spells to their highest learned rank at once (**`/bcc max`**), or export a formatted text summary of all your bindings including free key slots (**`/bcc list`**).
* **Clean Grouping, Sorting & Custom Order:** Organize custom bindings by **Modifier** (Direct, Shift, Ctrl, Alt), **Mouse Button** (LMB, RMB, MMB, MB4, MB5), **Action Type** (Spells, Pet Actions, Macros), or keep a logically sorted list, and optionally move the default **Target Unit / Open Context Menu** actions to the bottom.
* **1-Click Direct Bind & Auto Class-Tab in the Spellbook:** Automatically switches to your active class Spellbook tab when opening `/bcc`, and lets you bind any spell in a single click via **1-Click Direct Bind**.
* **Spellbook Key Badges:** Displays your assigned mouse button shorthands (**LMB**, **RMB**, **S-LMB**, **MB4**) directly on the spell icons in your Spellbook.
* **Optional Unit Frame Hover Overlay:** Optionally display a compact, 100% taint-free overlay when hovering over unit frames (**Modifier Only** or **Always**), showing your bound spells for the active modifier, their rank status (**[MAX]**, **[-1]**, **[-2]**, **[NOT LEARNED]**), live mana costs (highlighting insufficient mana in red), and live **Out-of-Range detection (`[OOR]`, `/bcc range`)**. Includes customizable **Scale** (`70%` to `150%`), **Background Opacity** (`30%` to `100%`), **6 Anchor Modes** (**Cursor**, **Top**, **Bottom**, **Left**, **Right**, or **Free Movable Position**), automatic hiding while right-click context menus are open, and a global **Overlay Unlock & Placeholder Mode** (**`/bcc move`**).
* **Character Profiles, Direct Copy & `!BCC1:...!` String Import/Export (Tab 4):** Copy AddOn **Settings** and/or **Click Cast Keybinds** directly from any saved character on your account (supporting *WoW Forever* first and last names, automatic cross-character spell rank and Smart Rule resolution, **Merge vs. Replace** mode, and optional character-specific settings), or share compact **`!BCC1:...!`** export strings (**`/bcc export`**, **`/bcc import`**, **`/bcc copy`**).
* **4-Tab Settings Window, Native Options & Power-User Slash Commands:** Configure everything in a dedicated 4-tab window (**`/bcc cfg`**, Minimap Right-Click, or **`Esc -> Options -> AddOns -> Better Click Casting`** with global search support) or directly via **`/bcc help`** slash commands.
* **Localization & Live Language Switcher:** Full support for **English (`enUS` / `enGB`)**, **German (`deDE`)**, and **Spanish (`esES` / `esMX`)** clients with automatic client detection, 100% English fallback, and a live in-game language switcher (**`/bcc lang`**).

---

### License

Released under the [MIT License](./LICENSE).
