# Better Click Casting

### The Backstory (or: Why This AddOn Exists)

Back in the Beta, I dutifully reported an issue for Blizzard's built-in **Click Cast Bindings** menu. Why? Because while the native Click Casting system itself is rock-solid, its UI was clearly copy-pasted straight from Retail, a magical place where **Spell Ranks** haven't existed for fifteen years.

* **Want to know if that Flash Heal in your list is Rank 1, Rank 4, or Rank 7?** *Good luck guessing!*
* **Learned a new spell rank at your class trainer and want to upgrade your binding?** *Have fun deleting the row, hunting down the spell in your Spellbook, and binding it all over again!*
* **Want to see a tooltip in the list to check mana costs?** *Too bad!*

Sadly, the menu never got any love from Blizzard.
**Are you in the same boat as me? Then have fun with this AddOn!**

---

### Features

**Better Click Casting** upgrades Blizzard's native Click Cast window and Spellbook with full **Spell Rank support** and quality-of-life features for Classic and *WoW Forever*, without replacing Blizzard's system or requiring heavy unitframe add-ons like VuhDo, Cell, or HealBot.

* **Visible Spell Ranks & Live Mana Costs:** Shows the exact bound rank right next to every spell name, such as **Flash Heal (Rank 4)**, plus live mana costs directly in the Click Cast row.
* **Max-Rank & Downrank Detection:** Marks spells at your highest learned rank with a green **[MAX]** tag and highlights lower ranks in orange with a max-rank hint like **(Rank 2 / Max 4)**.
* **Inline Rank Switcher:** Switch between all learned ranks directly inside the Click Cast row via a compact dropdown (including mana costs and tooltips), or **Right-Click** the rank button to jump straight to **MAX** without re-binding your mouse button.
* **Smart Rank Rules & Trainer Upgrade Modes:** Assign rules per binding (**Always MAX**, **Always MAX - 1**, **Always MAX - 2**, **Always MAX - 3**, or **Fixed Rank**). When you learn a new spell rank at your class trainer, choose between the compact **Upgrade Hero-Card**, **Auto-Open & Prepare** (highlighting the Save button right after closing the trainer), or **Manual Only**.
* **1-Click Upgrade All & Copyable Binding Summary:** Upgrade all bound spells to their highest learned rank at once, or export a formatted text summary of all your bindings (**`/bcc list`**).
* **Clean Grouping, Sorting & Custom Order:** Organize custom bindings by **Modifier** (Direct, Shift, Ctrl, Alt), **Mouse Button** (LMB, RMB, MMB, MB4, MB5), **Action Type** (Spells, Pet Actions, Macros), or keep a logically sorted list, and optionally move the default **Target Unit / Open Context Menu** actions to the bottom.
* **1-Click Direct Bind & Auto Class-Tab in the Spellbook:** Automatically switches to your active class Spellbook tab when opening `/bcc`, and lets you bind any spell in a single click via **1-Click Direct Bind**.
* **Spellbook Key Badges:** Displays your assigned mouse button shorthands (**LMB**, **RMB**, **S-LMB**, **MB4**) directly on the spell icons in your Spellbook.
* **Optional Unit Frame Hover Overlay:** Optionally display a compact, 100% taint-free overlay when hovering over unit frames (**Modifier Only** or **Always**), showing your bound spells for the active modifier, their rank status (**[MAX]**, **[-1]**, **[-2]**), and live mana costs (automatically graying out spells and highlighting mana in red when out of mana). Includes customizable **Scale** (`70%` to `150%`), **Background Opacity** (`30%` to `100%`), **6 Anchor Modes** (**Cursor**, **Top**, **Bottom**, **Left**, **Right**, or **Free Movable Position**), and a global **Overlay Unlock & Placeholder Mode** (**`/bcc move`**).
* **3-Tab Settings Window, Native Options & Power-User Slash Commands:** Configure everything in a dedicated 3-tab window (**`/bcc cfg`**, Minimap Right-Click, or **`Esc -> Options -> AddOns -> Better Click Casting`** with global search support) or directly via **`/bcc help`** slash commands.
* **Localization:** Full support for **English (enUS)** and **German (deDE)** clients.

---

### License

Released under the [MIT License](./LICENSE).
