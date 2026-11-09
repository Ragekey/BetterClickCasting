local _, ns = ...

local L = setmetatable({}, {
	__index = function(t, k)
		return k
	end,
})

ns.L = L

-- Englischer Standard-Fallback (enUS / enGB)
L["ADDON_TITLE"] = "Better Click Casting"
L["RANK_FALLBACK_FORMAT"] = "Rank %d"
L["TAG_MAX"] = "[MAX]"
L["TAG_MAX_SHORT"] = "Max"
L["MAX_RANK_HINT_FORMAT"] = " / Max %d"

-- Smarte Rang-Regeln
L["SMART_RULE_HEADER"] = "Auto-Update Rule"
L["SMART_RULE_MAX"] = "Always MAX Rank"
L["SMART_RULE_MAX_MINUS_1"] = "Always MAX - 1"
L["SMART_RULE_MAX_MINUS_2"] = "Always MAX - 2"
L["SMART_RULE_MAX_MINUS_3"] = "Always MAX - 3"
L["SMART_RULE_FIXED"] = "Fixed Rank (No Auto-Update)"
L["SMART_RULE_TOOLTIP_DESC"] = "Automatically updates this binding when you learn a new spell rank and opens the Click Cast window ready to save."
L["TAG_RULE_M1_SHORT"] = "M-1"
L["TAG_RULE_M2_SHORT"] = "M-2"
L["TAG_RULE_M3_SHORT"] = "M-3"
L["TAG_RULE_FIX_SHORT"] = "Fix"
L["TOOLTIP_SMART_RULE_LABEL"] = "Auto-Rule:"

-- Hero-Card (Upgrade-Benachrichtigung)
L["HEROCARD_TITLE"] = "Better Click Casting: Rank Updates Ready"
L["HEROCARD_SUBTITLE"] = "Your Smart Rules found new learned ranks for your bindings:"
L["HEROCARD_MORE_FORMAT"] = "+%d more binding(s) ready to update..."
L["HEROCARD_BTN_OPEN_APPLY"] = "Open & Upgrade"
L["HEROCARD_BTN_OPEN_APPLY_DESC"] = "Opens Click Cast Bindings, applies the target ranks from your Smart Rules, and highlights the Save button."
L["HEROCARD_BTN_KEEP_CURRENT"] = "Keep Current Ranks"
L["HEROCARD_BTN_KEEP_CURRENT_DESC"] = "Sets the listed bindings to Fixed Rank (Manual) so they keep their current rank and won't trigger this reminder again."
L["HEROCARD_BTN_DISMISS_DESC"] = "Hide for now (remind me again later)"
L["SAVE_BUTTON_GLOW_HINT"] = "Smart Rules applied! Click Save to confirm."

-- Rang-Wechsler-Button und Kontextmenü
L["SELECT_RANK_TITLE_FORMAT"] = "%s: Select Rank"
L["RANK_SWITCHER_TOOLTIP_TITLE"] = "Change Spell Rank & Rule"
L["RANK_SWITCHER_CURRENT_FORMAT"] = "Current: %s (Max learned: %s)"
L["RANK_SWITCHER_RULE_FORMAT"] = "Active Rule: %s"
L["RANK_SWITCHER_HINT_LEFT"] = "• Left-Click: Choose rank or Smart Rule"
L["RANK_SWITCHER_HINT_RIGHT"] = "• Right-Click: Upgrade to highest rank (Always MAX)"

-- Gruppierung und Sortierung im ClickBindingFrame
L["GROUP_BUTTON_FORMAT"] = "Group: %s"
L["GROUP_MENU_TITLE"] = "Group & Sort Bindings"
L["GROUP_MODE_MODIFIER"] = "By Modifier (Direct / Shift / Ctrl / Alt)"
L["GROUP_MODE_MODIFIER_SHORT"] = "Modifier"
L["GROUP_MODE_BUTTON"] = "By Mouse Button (LMB / RMB / MMB / MB4+)"
L["GROUP_MODE_BUTTON_SHORT"] = "Button"
L["GROUP_MODE_TYPE"] = "By Action Type (Spells / Macros)"
L["GROUP_MODE_TYPE_SHORT"] = "Type"
L["GROUP_MODE_NONE"] = "Flat List (Logical Sort LMB / RMB / MMB / MB4+)"
L["GROUP_MODE_NONE_SHORT"] = "Off"
L["GROUP_TOOLTIP_TITLE"] = "List Grouping & Sorting"
L["GROUP_TOOLTIP_DESC"] = "Organizes your custom click bindings into clean sections and sorts mouse buttons in logical order (Left, Right, Middle, Mouse 4+)."

L["GROUP_HDR_NO_MOD"] = "Direct Click (No Modifier)"
L["GROUP_HDR_MOD_FORMAT"] = "%s + Click"
L["GROUP_HDR_SPELLS"] = "Spells"
L["GROUP_HDR_PET"] = "Pet Actions"
L["GROUP_HDR_MACROS"] = "Macros"
L["GROUP_HDR_UNBOUND"] = "Unassigned"

-- Zeilen-Tooltips im ClickBindingFrame
L["TOOLTIP_CLICK_BINDING_LABEL"] = "Click Binding:"
L["TOOLTIP_RANK_STATUS_LABEL"] = "Rank Status:"
L["TOOLTIP_STATUS_MAX_RANK_FORMAT"] = "Highest learned rank (%s)"
L["TOOLTIP_STATUS_DOWNRANK_FORMAT"] = "Downrank (%s / Max: %s)"
L["TOOLTIP_SWITCH_RANK_HINT"] = "Tip: Click the rank button on the right to switch ranks or set an Auto-Update Rule."

-- Zauberbuch-Tooltips und Checkbox
L["SPELLBOOK_ALREADY_BOUND_LABEL"] = "Click-bound to:"
L["SPELLBOOK_QUICK_BIND_CHECKBOX"] = "1-Click Direct Bind"
L["SPELLBOOK_QUICK_BIND_HINT"] = "Direct Bind active: Click this spell with any mouse button (or Shift/Ctrl/Alt + Click) to bind it immediately!"

-- Minimap-Button
L["MINIMAP_TOOLTIP_SUBTITLE"] = "Native Click Cast Enhancements"
L["MINIMAP_HINT_LEFT"] = "• Left-Click: Open / Close Click Cast Bindings"
L["MINIMAP_HINT_RIGHT"] = "• Right-Click: Better Click Casting Settings"
L["MINIMAP_HINT_DRAG"] = "• Drag: Move Minimap Button"

-- Settings-Button und Menü
L["SETTINGS_BUTTON_TOOLTIP_TITLE"] = "Better Click Casting: Settings"
L["SETTINGS_BUTTON_TOOLTIP_DESC"] = "Configure spell rank display, Smart Rules, grouping, inline rank switcher, spellbook helpers, and minimap icon."
L["SETTINGS_MENU_TITLE"] = "Better Click Casting"
L["SETTINGS_HEADER_CLICKCAST"] = "Click Cast Window"
L["SETTINGS_HEADER_SPELLBOOK"] = "Spellbook Integration"
L["SETTINGS_HEADER_GENERAL"] = "General & Actions"

L["SETTING_SHOW_RANK_IN_NAME"] = "Show Spell Rank in Name"
L["SETTING_SHOW_RANK_IN_NAME_DESC"] = "Appends the spell rank (e.g. Rank 4) to each spell row."
L["SETTING_HIGHLIGHT_DOWNRANKS"] = "Highlight [MAX] & Downranks"
L["SETTING_HIGHLIGHT_DOWNRANKS_DESC"] = "Marks highest ranks with [MAX] in green and lower ranks in orange with max-rank hints."
L["SETTING_SHOW_RANK_SWITCHER"] = "Show Inline Rank Switcher Button"
L["SETTING_SHOW_RANK_SWITCHER_DESC"] = "Shows the clickable rank dropdown button on the right side of multi-rank spell rows."
L["SETTING_ENABLE_SMART_RULES"] = "Smart Rank Rules & Upgrade Hero-Card"
L["SETTING_ENABLE_SMART_RULES_DESC"] = "Enables per-binding rules (Always MAX, MAX - 1, MAX - 2, Fixed) and displays a reminder card when newly learned spell ranks are ready to be applied."
L["SETTING_SHOW_LINE_TOOLTIPS"] = "Show Full Spell & Macro Tooltips"
L["SETTING_SHOW_LINE_TOOLTIPS_DESC"] = "Displays rank-accurate spell tooltips and macro text when hovering rows."

L["SETTING_QUICK_BIND_SPELLBOOK"] = "1-Click Direct Bind in Spellbook"
L["SETTING_QUICK_BIND_SPELLBOOK_DESC"] = "When enabled while Click Cast Bindings is open, clicking any spell in the Spellbook with ANY mouse button (including Left-Click, Right-Click, Middle-Click, Mouse4+, and Shift/Ctrl/Alt modifiers) immediately binds it to that button."
L["SETTING_SHOW_SPELLBOOK_BADGES"] = "Show Bound Key Badges in Spellbook"
L["SETTING_SHOW_SPELLBOOK_BADGES_DESC"] = "Displays assigned mouse buttons (LMB, RMB, MMB, S-LMB, MB4) directly on bound spell ranks in the Spellbook."
L["SETTING_AUTO_SHOW_ALL_RANKS"] = "Auto-Enable 'Show All Spell Ranks'"
L["SETTING_AUTO_SHOW_ALL_RANKS_DESC"] = "If 'Show All Spell Ranks' is turned off in your Spellbook, temporarily enables it while the Click Cast window is open and restores it when closed."

L["SETTING_SHOW_MINIMAP_BUTTON"] = "Show Minimap Button"
L["SETTING_SHOW_MINIMAP_BUTTON_DESC"] = "Displays the Better Click Casting button on the Minimap (use /bcc to toggle anytime)."

-- Unit-Frame Hover-Info (Spickzettel-Overlay)
L["SETTINGS_HEADER_UNITHOVER"] = "Unit Frame Hover Overlay"
L["UNITHOVER_MODE_BUTTON_FORMAT"] = "Hover Overlay: %s"
L["UNITHOVER_MODE_MENU_TITLE"] = "Display Bound Spells on Unit Hover"
L["UNITHOVER_MODE_OFF"] = "Off (Disabled)"
L["UNITHOVER_MODE_OFF_SHORT"] = "Off"
L["UNITHOVER_MODE_MODIFIER"] = "Only While Holding Modifier (Shift / Ctrl / Alt)"
L["UNITHOVER_MODE_MODIFIER_SHORT"] = "Modifier Only"
L["UNITHOVER_MODE_ALWAYS"] = "Always When Hovering Unit Frames"
L["UNITHOVER_MODE_ALWAYS_SHORT"] = "Always"
L["UNITHOVER_MODE_TOOLTIP_DESC"] = "Displays a compact, taint-free overlay with your bound spells, ranks, and live mana costs for the currently held modifier when hovering over unit frames."

L["UNITHOVER_ANCHOR_BUTTON_FORMAT"] = "Overlay Position: %s"
L["UNITHOVER_ANCHOR_MENU_TITLE"] = "Hover Overlay Anchor"
L["UNITHOVER_ANCHOR_CURSOR"] = "Follow Mouse Cursor"
L["UNITHOVER_ANCHOR_CURSOR_SHORT"] = "Cursor"
L["UNITHOVER_ANCHOR_TOP"] = "Unit Frame: Top"
L["UNITHOVER_ANCHOR_TOP_SHORT"] = "Top"
L["UNITHOVER_ANCHOR_BOTTOM"] = "Unit Frame: Bottom"
L["UNITHOVER_ANCHOR_BOTTOM_SHORT"] = "Bottom"
L["UNITHOVER_ANCHOR_LEFT"] = "Unit Frame: Left"
L["UNITHOVER_ANCHOR_LEFT_SHORT"] = "Left"
L["UNITHOVER_ANCHOR_RIGHT"] = "Unit Frame: Right"
L["UNITHOVER_ANCHOR_RIGHT_SHORT"] = "Right"
L["UNITHOVER_ANCHOR_FREE"] = "Free Position (Saved & Movable)"
L["UNITHOVER_ANCHOR_FREE_SHORT"] = "Free Position"
L["UNITHOVER_ANCHOR_TOOLTIP_DESC"] = "Choose whether the overlay follows your mouse cursor, attaches to an edge of the hovered unit frame, or stays at a fixed screen position."

L["SETTING_UNITHOVER_SHOW_IN_COMBAT"] = "Show in Combat"
L["SETTING_UNITHOVER_SHOW_IN_COMBAT_DESC"] = "When enabled, the hover overlay also appears during combat. By default it is hidden in combat."
L["SETTING_UNITHOVER_SHOW_INTERACTIONS"] = "Include Target & Context Menu Actions"
L["SETTING_UNITHOVER_SHOW_INTERACTIONS_DESC"] = "Also lists default Target Unit and Open Context Menu bindings in the unit frame hover overlay."
L["SETTING_UNITHOVER_UNLOCK_MOVE"] = "Unlock & Move Free Overlay Position"
L["SETTING_UNITHOVER_UNLOCK_MOVE_DESC"] = "Shows the overlay and lets you drag it to your preferred screen position (also movable anytime while Click Cast Bindings is open)."
L["UNITHOVER_DRAG_HINT"] = "Drag to move (click Lock in menu or close /bcc when done)"

L["UNITHOVER_HDR_PREFIX"] = "Click Cast"
L["UNITHOVER_NO_MODIFIER"] = "No Modifier"
L["UNITHOVER_EMPTY_MODIFIER_FORMAT"] = "No spells bound for %s"
L["UNITHOVER_TAG_DOWNRANK_FORMAT"] = "[-%d]"

L["ACTION_UPGRADE_ALL_MAX_FORMAT"] = "Upgrade All Bound Spells to MAX (%d)"
L["ACTION_UPGRADE_ALL_MAX_NONE"] = "All Bound Spells Are at MAX Rank"
L["ACTION_UPGRADE_ALL_MAX_DESC"] = "Upgrades all currently bound downranked spells in the list to their highest learned rank."
L["CHAT_UPGRADED_COUNT_FORMAT"] = "|cff40ff40Better Click Casting:|r Upgraded %d spell binding(s) to highest learned rank (click Save to apply)."
L["CHAT_SMART_RULES_APPLIED_FORMAT"] = "|cff40ff40Better Click Casting:|r Auto-updated %d binding(s) via Smart Rules. Click |cffffd100Save|r to confirm!"
L["CHAT_SMART_RULES_LOCKED_FIXED_FORMAT"] = "|cff99ccffBetter Click Casting:|r Locked %d binding(s) to their current fixed rank (Fixed Rule)."
L["CHAT_HELP_HINT"] = "|cff99ccffBetter Click Casting:|r Use |cffffffff/bcc|r to open Click Cast Bindings or |cffffffff/bcc minimap|r to toggle the minimap icon."
