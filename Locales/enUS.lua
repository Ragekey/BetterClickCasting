local _, ns = ...

ns.Locales = ns.Locales or {}
local enUS = {}
ns.Locales["enUS"] = enUS

local ActiveL = setmetatable({}, {
	__index = function(_, k)
		return enUS[k] or k
	end,
})

ns.L = ActiveL

-- Löst die effektive AddOn-Sprache auf ("auto" nutzt GetLocale(), Fallback ist immer "enUS")
function ns.ResolveEffectiveLocale(preferred)
	local code = preferred
	if not code or code == "auto" or code == "" then
		code = (GetLocale and GetLocale()) or "enUS"
	end
	if code == "deDE" then
		return "deDE"
	elseif code == "esES" or code == "esMX" then
		return "esES"
	end
	return "enUS"
end

-- Aktualisiert ns.L in-place mit englischem 100%-Fallback, sodass alle Module sofort die neue Sprache nutzen
function ns.ApplyLocale(preferred)
	local effective = ns.ResolveEffectiveLocale(preferred)
	if wipe then
		wipe(ActiveL)
	else
		for k in pairs(ActiveL) do
			ActiveL[k] = nil
		end
	end
	for k, v in pairs(enUS) do
		ActiveL[k] = v
	end
	local dict = ns.Locales and ns.Locales[effective]
	if dict and dict ~= enUS then
		for k, v in pairs(dict) do
			ActiveL[k] = v
		end
	end
	ns.activeLocale = effective
	return effective
end

local L = enUS

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
L["SETTINGS_BUTTON_TOOLTIP_HINT_RIGHT"] = "• Right-Click: Open / Close Free Keys Matrix"
L["MATRIX_HEADER_BTN"] = "Matrix"
L["SETTINGS_MENU_TITLE"] = "Better Click Casting"
L["SETTINGS_HEADER_CLICKCAST"] = "Click Cast Window"
L["SETTINGS_HEADER_SPELLBOOK"] = "Spellbook Integration"
L["SETTINGS_HEADER_GENERAL"] = "General & Actions"
L["SETTINGS_TAB_CLICKCAST"] = "Click Cast"
L["SETTINGS_TAB_SPELLBOOK"] = "Spellbook & UI"
L["SETTINGS_TAB_UNITHOVER"] = "Hover Overlay"
L["SETTINGS_OPEN_CLICKCAST_BTN"] = "Open Click Cast Window (/bcc)"
L["SETTINGS_RUN_DEBUG_BTN"] = "Run Taint Diagnostics (/bcc debug)"
L["SETTINGS_RUN_DEBUG_DESC"] = "Scans PetActionBar, ActionBars, EditModeManagerFrame, UnitFrames, and SpellBookFrame for potential UI taint."

L["SETTING_SHOW_RANK_IN_NAME"] = "Show Spell Rank in Name"
L["SETTING_SHOW_RANK_IN_NAME_DESC"] = "Appends the spell rank (e.g. Rank 4) to each spell row."
L["SETTING_HIGHLIGHT_DOWNRANKS"] = "Highlight [MAX] & Downranks"
L["SETTING_HIGHLIGHT_DOWNRANKS_DESC"] = "Marks highest ranks with [MAX] in green and lower ranks in orange with max-rank hints."
L["SETTING_SHOW_RANK_SWITCHER"] = "Show Inline Rank Switcher Button"
L["SETTING_SHOW_RANK_SWITCHER_DESC"] = "Shows the clickable rank dropdown button on the right side of multi-rank spell rows."
L["SETTING_ENABLE_SMART_RULES"] = "Smart Rank Rules & Upgrade Hero-Card"
L["SETTING_ENABLE_SMART_RULES_DESC"] = "Enables per-binding rules (Always MAX, MAX - 1, MAX - 2, Fixed) and displays a reminder card when newly learned spell ranks are ready to be applied."
L["SETTING_SHOW_LINE_MANA_COST"] = "Show Live Mana Costs in Binding Rows"
L["SETTING_SHOW_LINE_MANA_COST_DESC"] = "Displays each spell's mana or resource cost right-aligned in the top row of the Click Cast list."
L["SETTING_MOVE_INTERACTIONS_BOTTOM"] = "Move Target & Menu Actions to Bottom"
L["SETTING_MOVE_INTERACTIONS_BOTTOM_DESC"] = "Places the default Target Unit and Open Context Menu bindings at the bottom of the list so your custom spells start right at the top."
L["SETTING_SHOW_LINE_TOOLTIPS"] = "Show Full Spell & Macro Tooltips"
L["SETTING_SHOW_LINE_TOOLTIPS_DESC"] = "Displays rank-accurate spell tooltips and macro text when hovering rows."
L["SETTING_COMPACT_LIST_MODE"] = "Compact Binding Rows (More Visible Spells)"
L["SETTING_COMPACT_LIST_MODE_DESC"] = "Reduces row height in the Click Cast window so almost twice as many bound spells fit on screen without scrolling."

L["SETTING_QUICK_BIND_SPELLBOOK"] = "1-Click Direct Bind in Spellbook"
L["SETTING_QUICK_BIND_SPELLBOOK_DESC"] = "When enabled while Click Cast Bindings is open, clicking any spell in the Spellbook with ANY mouse button (including Left-Click, Right-Click, Middle-Click, Mouse4+, and Shift/Ctrl/Alt modifiers) immediately binds it to that button."
L["SETTING_SHOW_SPELLBOOK_BADGES"] = "Show Bound Key Badges in Spellbook"
L["SETTING_SHOW_SPELLBOOK_BADGES_DESC"] = "Displays assigned mouse buttons (LMB, RMB, MMB, S-LMB, MB4) directly on bound spell ranks in the Spellbook."
L["SETTING_AUTO_SHOW_ALL_RANKS"] = "Auto-Enable 'Show All Spell Ranks'"
L["SETTING_AUTO_SHOW_ALL_RANKS_DESC"] = "If 'Show All Spell Ranks' is turned off in your Spellbook, temporarily enables it while the Click Cast window is open and restores it when closed."
L["SETTING_AUTO_SELECT_PRIMARY_TAB"] = "Auto-Select Primary Class Tab on Open"
L["SETTING_AUTO_SELECT_PRIMARY_TAB_DESC"] = "When opening /bcc while the Spellbook is still on the General tab, automatically switches to the class specialization tab containing most of your bound spells (or the first class tab)."

L["TRAINER_BEHAVIOR_BUTTON_FORMAT"] = "Trainer: %s"
L["TRAINER_BEHAVIOR_MENU_TITLE"] = "Smart Rules After Trainer"
L["TRAINER_BEHAVIOR_CARD"] = "Show Reminder Card (Default)"
L["TRAINER_BEHAVIOR_CARD_SHORT"] = "Reminder Card"
L["TRAINER_BEHAVIOR_CARD_DESC"] = "Displays a compact reminder card whenever newly learned spell ranks match your Smart Rules. Clicking 'Open & Upgrade' opens /bcc and prepares the new ranks."
L["TRAINER_BEHAVIOR_AUTO"] = "Auto-Open & Prepare After Trainer"
L["TRAINER_BEHAVIOR_AUTO_SHORT"] = "Auto-Open"
L["TRAINER_BEHAVIOR_AUTO_DESC"] = "Automatically opens the Click Cast window (/bcc) out of combat after closing the class trainer, applies all pending Smart Rule rank updates, and highlights the Save button."
L["TRAINER_BEHAVIOR_OFF"] = "Silent (Manual in /bcc Only)"
L["TRAINER_BEHAVIOR_OFF_SHORT"] = "Silent"
L["TRAINER_BEHAVIOR_OFF_DESC"] = "Hides the reminder card and prevents auto-opening after visiting a trainer. Your Smart Rules remain saved so you can upgrade manually inside /bcc or via '/bcc max'."
L["TRAINER_BEHAVIOR_TOOLTIP_DESC"] = "Controls how Smart Rules (Always MAX, MAX - 1, etc.) react when you learn a new spell rank at your class trainer:\n\n• |cffffd100Reminder Card:|r Compact popup with 1-click preview.\n• |cffffd100Auto-Open:|r Opens /bcc with updated ranks ready to Save.\n• |cffffd100Silent:|r No popup after visiting the trainer."

L["SETTINGS_EXPORT_BINDINGS_BTN"] = "Binding Summary (/bcc list)"
L["SETTINGS_EXPORT_BINDINGS_DESC"] = "Opens a clean, copyable text summary of all active Click Cast bindings, spell ranks, mana costs, and Smart Rules."
L["SETTINGS_FREE_KEYS_MATRIX_BTN"] = "Free Keys Matrix (/bcc keys)"
L["SETTINGS_FREE_KEYS_MATRIX_DESC"] = "Opens a 4x5 visual matrix showing all bound and free combinations of Direct / Shift / Ctrl / Alt and LMB / RMB / MMB / MB4 / MB5."
L["EXPORT_POPUP_TITLE"] = "Better Click Casting: Binding Summary (Ctrl+C to copy)"
L["EXPORT_EMPTY"] = "No custom Click Cast bindings configured yet."
L["FREE_KEYS_SUMMARY_PREFIX"] = "Free Slots (4x5 Grid)"
L["MATRIX_POPUP_TITLE"] = "Click Cast Key Matrix (4x5)"
L["MATRIX_POPUP_TITLE_EXPANDED"] = "Click Cast Key Matrix (8x5)"
L["MATRIX_STATS_FORMAT"] = "|cff99ccff%d / %d Bound|r  •  |cff40ff59%d Free Slots|r"
L["MATRIX_ROW_DIRECT"] = "Direct"
L["MATRIX_ROW_SHIFT"] = "Shift"
L["MATRIX_ROW_CTRL"] = "Ctrl"
L["MATRIX_ROW_ALT"] = "Alt"
L["MATRIX_ROW_SHIFT_CTRL"] = "Shift + Ctrl"
L["MATRIX_ROW_SHIFT_ALT"] = "Shift + Alt"
L["MATRIX_ROW_CTRL_ALT"] = "Ctrl + Alt"
L["MATRIX_ROW_SHIFT_CTRL_ALT"] = "S + C + A"
L["MATRIX_SHOW_COMBOS_CHECKBOX"] = "Show modifier combinations (8x5)"
L["MATRIX_SHOW_COMBOS_DESC"] = "Expands the matrix from 20 slots (4x5) to 40 slots (8x5) by including multi-modifier combinations (Shift+Ctrl, Shift+Alt, Ctrl+Alt)."
L["MATRIX_AUTO_OPEN_CHECKBOX"] = "Auto-open with /bcc"
L["MATRIX_AUTO_OPEN_DESC"] = "Automatically opens the Free Keys Matrix alongside the Click Cast Bindings window whenever you open /bcc."
L["MATRIX_CELL_FREE"] = "[FREE]"
L["MATRIX_CELL_FREE_TOOLTIP"] = "This mouse button combination is currently unassigned and ready to bind."
L["MATRIX_EXTRA_BINDINGS_FORMAT"] = "|cffffd100Additional Bindings:|r %s"
L["MATRIX_FOOTER_HINT"] = "Green [FREE] slots are available. Hover any bound slot to inspect its spell rank and tooltip."

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
L["SETTING_UNITHOVER_SHOW_MANA"] = "Show Mana Costs"
L["SETTING_UNITHOVER_SHOW_MANA_DESC"] = "Displays the live mana cost column on the right side of the hover overlay."
L["SETTING_UNITHOVER_SHOW_RANK_TAGS"] = "Show [MAX] & Downrank Tags"
L["SETTING_UNITHOVER_SHOW_RANK_TAGS_DESC"] = "Appends [MAX] or [-1], [-2] rank status indicators next to spell names in the hover overlay."
L["SETTING_UNITHOVER_SHOW_RANGE"] = "Highlight Out-of-Range Spells [OOR]"
L["SETTING_UNITHOVER_SHOW_RANGE_DESC"] = "Dims bound spells and highlights the mouse button in red with an [OOR] badge when the hovered unit is out of spell range."
L["SETTING_UNITHOVER_SCALE_FORMAT"] = "Overlay Scale: %d%%"
L["SETTING_UNITHOVER_ALPHA_FORMAT"] = "Background Opacity: %d%%"
L["SETTING_UNITHOVER_SHOW_INTERACTIONS"] = "Include Target & Context Menu Actions"
L["SETTING_UNITHOVER_SHOW_INTERACTIONS_DESC"] = "Also lists default Target Unit and Open Context Menu bindings in the unit frame hover overlay."
L["SETTING_UNITHOVER_UNLOCK_MOVE"] = "Unlock All Overlays (Placeholder Mode)"
L["SETTING_UNITHOVER_UNLOCK_MOVE_DESC"] = "Shows all movable Better Click Casting overlays (Trainer Upgrade Card and Unit Frame Hover Overlay) with placeholder markers so you can freely drag them or right-click to reset."
L["UNITHOVER_DRAG_HINT"] = "Left-Drag: Move  |  Right-Click: Reset Position"
L["UNITHOVER_PREVIEW_HEADER"] = "Click Cast [PLACEHOLDER]"
L["UNITHOVER_PREVIEW_ROW_1"] = "Flash Heal (Rank 4)"
L["UNITHOVER_PREVIEW_ROW_2"] = "Renew (Rank 6)"

L["HEROCARD_PREVIEW_TITLE"] = "New Spell Ranks Available [PLACEHOLDER]"
L["HEROCARD_PREVIEW_SUBTITLE"] = "Left-Drag: Move Card  |  Right-Click: Reset to Default Position"
L["HEROCARD_PREVIEW_ROW_1"] = "Flash Heal |cff888888[LMB]|r: |cffffb833Rank 3|r -> |cff40ff59Rank 4 (MAX)|r"
L["HEROCARD_PREVIEW_ROW_2"] = "Renew |cff888888[RMB]|r: |cffffb833Rank 5|r -> |cff40ff59Rank 6 (MAX)|r"
L["OVERLAY_UNLOCK_BTN_UNLOCK_ALL"] = "Unlock & Move Overlays (/bcc move)"
L["OVERLAY_UNLOCK_BTN_LOCK_ALL"] = "Lock All Overlays (/bcc lock)"
L["OVERLAY_UNLOCK_BTN_RESET_POS"] = "Reset Positions"
L["OVERLAY_UNLOCK_BTN_RESET_POS_DESC"] = "Resets the Trainer Upgrade Card and Unit Frame Hover Overlay back to their default screen positions."

L["UNITHOVER_HDR_PREFIX"] = "Click Cast"
L["UNITHOVER_NO_MODIFIER"] = "No Modifier"
L["UNITHOVER_EMPTY_MODIFIER_FORMAT"] = "No spells bound for %s"
L["UNITHOVER_TAG_DOWNRANK_FORMAT"] = "[-%d]"
L["UNITHOVER_TAG_OOR"] = "[OOR]"

L["ACTION_UPGRADE_ALL_MAX_FORMAT"] = "Upgrade All Bound Spells to MAX (%d)"
L["ACTION_UPGRADE_ALL_MAX_NONE"] = "All Bound Spells Are at MAX Rank"
L["ACTION_UPGRADE_ALL_MAX_DESC"] = "Upgrades all currently bound downranked spells in the list to their highest learned rank."
L["CHAT_UPGRADED_COUNT_FORMAT"] = "|cff40ff40Better Click Casting:|r Upgraded %d spell binding(s) to highest learned rank (click Save to apply)."
L["CHAT_SMART_RULES_APPLIED_FORMAT"] = "|cff40ff40Better Click Casting:|r Auto-updated %d binding(s) via Smart Rules. Click |cffffd100Save|r to confirm!"
L["CHAT_SMART_RULES_LOCKED_FIXED_FORMAT"] = "|cff99ccffBetter Click Casting:|r Locked %d binding(s) to their current fixed rank (Fixed Rule)."
L["CHAT_HELP_HINT"] = "|cff99ccffBetter Click Casting:|r Use |cffffffff/bcc|r to open Click Cast Bindings, |cffffffff/bcc cfg|r for Settings, or |cffffffff/bcc help|r for all commands."
L["CHAT_STATE_ON"] = "|cff40ff59[ON]|r"
L["CHAT_STATE_OFF"] = "|cffff5555[OFF]|r"
L["CHAT_SETTING_CHANGED_FORMAT"] = "|cff99ccffBetter Click Casting:|r %s: %s"
L["CHAT_OVERLAYS_UNLOCKED"] = "|cff40ff59Better Click Casting:|r Overlays unlocked (Placeholder Mode). Drag to move, Right-Click to reset, or type |cffffffff/bcc lock|r when done."
L["CHAT_OVERLAYS_LOCKED"] = "|cff99ccffBetter Click Casting:|r All overlays locked."
L["CHAT_OVERLAYS_RESET"] = "|cff40ff59Better Click Casting:|r Reset all overlay positions to default."
L["CHAT_COMBAT_ERR"] = "|cffff5555Better Click Casting:|r Cannot perform this action during combat."
L["CHAT_HELP_HEADER"] = "|cff99ccffBetter Click Casting|r |cffffffffSlash Commands (/bcc):|r"
L["CHAT_HELP_LINE_1"] = "  |cffffd100/bcc|r (Click Cast UI)  |  |cffffd100/bcc cfg [1-4]|r (Settings Window)"
L["CHAT_HELP_LINE_2"] = "  |cffffd100/bcc preset [load|save|del|list] <Name>|r  |  |cffffd100/bcc export|r  |  |cffffd100/bcc import|r  |  |cffffd100/bcc copy <Name>|r"
L["CHAT_HELP_LINE_3"] = "  |cffffd100/bcc max|r (Upgrade All)  |  |cffffd100/bcc keys [combos|auto]|r (Matrix)  |  |cffffd100/bcc list|r (Summary)  |  |cffffd100/bcc trainer [card|auto|off]|r"
L["CHAT_HELP_LINE_4"] = "  |cffffd100/bcc group [mod|button|type|none]|r  |  |cffffd100/bcc hover [off|mod|always]|r  |  |cffffd100/bcc anchor [cursor|top|bottom|left|right|free]|r"
L["CHAT_HELP_LINE_5"] = "  |cffffd100/bcc move|r or |cffffd100lock|r (Overlays)  |  |cffffd100/bcc reset|r  |  |cffffd100/bcc scale <70-150>|r  |  |cffffd100/bcc alpha <30-100>|r"
L["CHAT_HELP_LINE_6"] = "  |cffffd100/bcc qb|r, |cffffd100mana|r, |cffffd100range|r, |cffffd100compact|r, |cffffd100bottom|r, |cffffd100autotab|r, |cffffd100rules|r, |cffffd100ranks|r, |cffffd100downrank|r, |cffffd100switcher|r, |cffffd100tooltips|r, |cffffd100badges|r, |cffffd100allranks|r, |cffffd100mm|r"
L["CHAT_HELP_LINE_7"] = "  |cffffd100/bcc charsettings|r, |cffffd100merge|r  |  |cffffd100/bcc status|r  |  |cffffd100/bcc debug|r"

-- Native Blizzard Options (Esc -> Options -> AddOns)
L["BLIZZ_SETTINGS_OPEN_BTN"] = "Open Settings"
L["BLIZZ_SETTINGS_ROW_CLICKCAST"] = "Click Cast & Spell Ranks (/bcc cfg 1)"
L["BLIZZ_SETTINGS_ROW_SPELLBOOK"] = "Spellbook & General (/bcc cfg 2)"
L["BLIZZ_SETTINGS_ROW_UNITHOVER"] = "Unit Frame Hover Overlay (/bcc cfg 3)"
L["BLIZZ_SETTINGS_ROW_PROFILES"] = "Profiles, Character Copy & Import/Export (/bcc cfg 4)"
L["BLIZZ_SETTINGS_ROW_WINDOW"] = "Click Cast Bindings Window (/bcc)"
L["BLIZZ_SETTINGS_ROW_MOVE"] = "Unlock / Lock All Overlays (/bcc move)"

-- Tab 4: Profiles, Character Copy & Import/Export
L["SETTINGS_TAB_PROFILES"] = "Profiles & Share"
L["SETTINGS_HEADER_PROFILES"] = "Character Profiles & Direct Copy"
L["SETTINGS_HEADER_SHARE"] = "String Export & Import"
L["SETTING_USE_CHAR_SETTINGS"] = "Use Character-Specific Settings for This Character"
L["SETTING_USE_CHAR_SETTINGS_DESC"] = "When enabled, changes to Better Click Casting settings on this character only apply to this character instead of account-wide."
L["SETTING_IMPORT_MERGE_BINDINGS"] = "Merge Keybinds Instead of Replacing on Copy / Import"
L["SETTING_IMPORT_MERGE_BINDINGS_DESC"] = "When enabled, copying or importing keybinds keeps your existing bindings and only adds or overwrites the imported mouse button combinations."
L["PROFILE_SOURCE_MENU_TITLE"] = "Select Saved Character Profile"
L["PROFILE_SOURCE_CHAR_FORMAT"] = "Source Character: %s"
L["PROFILE_SOURCE_CHAR_DESC"] = "Select any character on your account that has logged in with Better Click Casting to copy its Settings and/or Click Cast Keybinds (including full first and last name)."
L["PROFILE_NO_CHAR_SAVED"] = "No Saved Characters Found"
L["PROFILE_CURRENT_TAG"] = "[Active]"
L["PROFILE_DELETE_SNAPSHOT"] = "Remove Saved Character Snapshot"
L["PROFILE_BTN_COPY_ALL"] = "Copy All"
L["PROFILE_BTN_COPY_ALL_DESC"] = "Copies both AddOn Settings and compatible Click Cast Keybinds (with automatic rank and Smart Rule matching) from the selected character."
L["PROFILE_BTN_COPY_BINDINGS"] = "Keybinds Only"
L["PROFILE_BTN_COPY_BINDINGS_DESC"] = "Copies only Click Cast Keybinds and Smart Rules from the selected character into the Click Cast window (click Save in /bcc to confirm)."
L["PROFILE_BTN_COPY_SETTINGS"] = "Settings Only"
L["PROFILE_BTN_COPY_SETTINGS_DESC"] = "Copies only the Better Click Casting AddOn settings and overlay positions from the selected character."

L["SHARE_SCOPE_MENU_TITLE"] = "Select Export / Import Scope"
L["SHARE_SCOPE_BUTTON_FORMAT"] = "Scope: %s"
L["SHARE_SCOPE_TOOLTIP_DESC"] = "Choose whether to export or import both Settings and Keybinds together, only Keybinds, or only AddOn Settings."
L["SHARE_SCOPE_ALL"] = "Settings + Keybinds (Complete)"
L["SHARE_SCOPE_ALL_SHORT"] = "Settings + Keybinds"
L["SHARE_SCOPE_BINDINGS"] = "Keybinds & Smart Rules Only"
L["SHARE_SCOPE_BINDINGS_SHORT"] = "Keybinds Only"
L["SHARE_SCOPE_SETTINGS"] = "AddOn Settings Only"
L["SHARE_SCOPE_SETTINGS_SHORT"] = "Settings Only"
L["SHARE_BTN_EXPORT_STRING"] = "Generate Export String"
L["SHARE_BTN_EXPORT_STRING_DESC"] = "Creates a compact, shareable !BCC1!...! string for the selected scope that you can copy with Ctrl+C."
L["SHARE_BTN_IMPORT_STRING"] = "Import from String"
L["SHARE_BTN_IMPORT_STRING_DESC"] = "Opens a dialog where you can paste a !BCC1!...! string to import Settings and/or Keybinds."

L["EXPORT_STRING_TITLE_ALL"] = "Export String: Settings + Keybinds (Ctrl+C to Copy)"
L["EXPORT_STRING_TITLE_BINDINGS"] = "Export String: Keybinds Only (Ctrl+C to Copy)"
L["EXPORT_STRING_TITLE_SETTINGS"] = "Export String: Settings Only (Ctrl+C to Copy)"
L["IMPORT_POPUP_TITLE"] = "Import Better Click Casting Data"
L["IMPORT_POPUP_HINT"] = "Paste a !BCC1:...!-Export String below (Ctrl+V) and click Import:"
L["IMPORT_BTN_CONFIRM"] = "Import Now"

L["CHAT_PROFILE_COPIED_SETTINGS_FORMAT"] = "|cff40ff59Better Click Casting:|r Applied %d setting(s) from |cffffd100%s|r."
L["CHAT_PROFILE_COPIED_BINDINGS_FORMAT"] = "|cff40ff59Better Click Casting:|r Loaded %d keybind(s) from |cffffd100%s|r (%d unknown skipped). Click |cffffd100Save|r in the Click Cast window to confirm!"
L["CHAT_PROFILE_COPIED_ALL_FORMAT"] = "|cff40ff59Better Click Casting:|r Applied %d setting(s) and %d keybind(s) from |cffffd100%s|r (%d unknown skipped). Click |cffffd100Save|r to confirm keybinds!"
L["CHAT_PROFILE_NOT_FOUND_FORMAT"] = "|cffff5555Better Click Casting:|r Character profile '%s' not found."
L["CHAT_IMPORT_ERR_INVALID"] = "|cffff5555Better Click Casting:|r Invalid or corrupted !BCC1!...! import string."
L["CHAT_IMPORT_NOTHING_APPLIED_FORMAT"] = "|cffffb833Better Click Casting:|r No compatible settings or spells found in import string (%d unknown spell/macro entries skipped)."

-- Sprachauswahl (Locale Override)
L["LOCALE_MENU_TITLE"] = "AddOn Language"
L["LOCALE_BUTTON_FORMAT"] = "Language: %s"
L["LOCALE_TOOLTIP_DESC"] = "Choose the display language for Better Click Casting. 'Automatic (Client)' detects your WoW client language and always uses English as fallback."
L["LOCALE_OPT_AUTO"] = "Automatic (Client)"
L["LOCALE_OPT_AUTO_SHORT"] = "Auto (Client)"
L["LOCALE_OPT_ENUS"] = "English (enUS / enGB)"
L["LOCALE_OPT_ENUS_SHORT"] = "English"
L["LOCALE_OPT_DEDE"] = "Deutsch (deDE)"
L["LOCALE_OPT_DEDE_SHORT"] = "Deutsch"
L["LOCALE_OPT_ESES"] = "Español (esES / esMX)"
L["LOCALE_OPT_ESES_SHORT"] = "Español"
L["CHAT_LOCALE_CHANGED_FORMAT"] = "|cff40ff59Better Click Casting:|r Language set to |cffffd100%s|r."
L["SLASH_HELP_LANG"] = "  |cffffd100/bcc lang [auto|en|de|es]|r : Set AddOn display language"
L["STATUS_LOCALE_LABEL"] = "Language"

-- Binding Presets / Loadouts
L["SETTINGS_HEADER_PRESETS"] = "Binding Presets (Spec & Content Loadouts)"
L["PRESET_MENU_TITLE"] = "Binding Presets (Loadouts)"
L["PRESET_BUTTON_FORMAT"] = "Preset: %s"
L["PRESET_SELECTED_FORMAT"] = "Selected Preset: %s"
L["PRESET_NONE_SELECTED"] = "None"
L["PRESET_NO_PRESETS_SAVED"] = "No Presets Saved Yet"
L["PRESET_ENTRY_FORMAT"] = "%s |cff888888(%d)|r"
L["PRESET_TOOLTIP_TITLE"] = "Binding Presets (Loadouts)"
L["PRESET_TOOLTIP_DESC"] = "Save and switch between multiple Click Cast binding setups on this character (for example Raid Downranks, 5-Man Dungeon, or Solo / Off-Spec)."
L["PRESET_ACT_SAVE_NEW"] = "+ Save Current Bindings as New Preset..."
L["PRESET_ACT_UPDATE_FORMAT"] = "Overwrite '%s' with Current Bindings"
L["PRESET_ACT_DELETE_FORMAT"] = "Delete Preset '%s'"
L["PRESET_ACT_OPEN_MANAGER"] = "Manage Presets in Settings (Tab 4)..."
L["PRESET_BTN_LOAD"] = "Load"
L["PRESET_BTN_LOAD_DESC"] = "Loads the selected preset into the Click Cast Bindings window (replaces current list and highlights Save)."
L["PRESET_BTN_NEW"] = "New Preset..."
L["PRESET_BTN_NEW_DESC"] = "Saves your current Click Cast bindings and Smart Rules under a new preset name."
L["PRESET_BTN_OVERWRITE"] = "Overwrite"
L["PRESET_BTN_OVERWRITE_DESC"] = "Updates the currently selected preset with your active Click Cast bindings and Smart Rules."
L["PRESET_BTN_DELETE"] = "Delete"
L["PRESET_BTN_DELETE_DESC"] = "Removes the currently selected preset from this character."
L["PRESET_POPUP_NEW_TITLE"] = "Save New Binding Preset"
L["PRESET_POPUP_NEW_HINT"] = "Enter a name for this loadout (for example Raid, Dungeon, or Solo):"
L["PRESET_POPUP_BTN_SAVE"] = "Save Preset"
L["CHAT_PRESET_SAVED_FORMAT"] = "|cff40ff59Better Click Casting:|r Saved preset |cffffd100%s|r (%d binding(s))."
L["CHAT_PRESET_LOADED_FORMAT"] = "|cff40ff59Better Click Casting:|r Loaded preset |cffffd100%s|r (%d binding(s), %d unlearned skipped). Click |cffffd100Save|r in the Click Cast window to apply!"
L["CHAT_PRESET_DELETED_FORMAT"] = "|cff99ccffBetter Click Casting:|r Deleted preset |cffffd100%s|r."
L["CHAT_PRESET_NOT_FOUND_FORMAT"] = "|cffff5555Better Click Casting:|r Preset '%s' not found."
L["CHAT_PRESET_ERR_EMPTY_NAME"] = "|cffff5555Better Click Casting:|r Please enter a valid preset name."
L["CHAT_PRESET_LIST_HEADER_FORMAT"] = "|cff99ccffBetter Click Casting:|r Saved Presets for |cffffd100%s|r (%d):"
L["CHAT_PRESET_LIST_EMPTY"] = "|cff99ccffBetter Click Casting:|r No presets saved for this character yet. Use |cffffd100/bcc preset save <Name>|r to create one."

-- Nicht gelernte Zauber (z. B. nach Talent-Respec)
L["TAG_NOT_LEARNED"] = "[NOT LEARNED]"
L["TOOLTIP_STATUS_NOT_LEARNED"] = "Not Learned (Inactive)"
L["TOOLTIP_NOT_LEARNED_HINT"] = "This spell is currently not in your spellbook (for example after a talent respec) and will not trigger until learned again or replaced."

ns.ApplyLocale("auto")
