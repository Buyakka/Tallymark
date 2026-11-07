std = "lua51"
max_line_length = false
exclude_files = { ".git/" }

-- unused "self" and the shared addon name are fine
ignore = { "212/self", "211/ADDON" }

globals = {
    "TallymarkDB",
    "TallymarkCharDB",
    "SLASH_TALLY1",
    "SlashCmdList",
}

read_globals = {
    "CreateFrame",
    "UIParent",
    "DEFAULT_CHAT_FRAME",
    "STANDARD_TEXT_FONT",
    "C_AddOns",
    "C_Timer",
    "C_Spell",
    "C_Item",
    "C_Map",
    "strtrim",
    "issecretvalue",
    "GetBuildInfo",
    "GetTime",
    "UnitPosition",
    "UnitOnTaxi",
    "UnitIsDeadOrGhost",
    "IsSwimming",
    "IsMounted",
    "time",
    "wipe",
    "INVSLOT_RANGED",
    "INVSLOT_AMMO",
    "UnitAffectingCombat",
    "UnitClassBase",
    "IsInInstance",
    "GetRealZoneText",
    "GetSubZoneText",
    "GetInstanceInfo",
    "GetInventoryItemCount",
    "GetInventoryItemID",
}
