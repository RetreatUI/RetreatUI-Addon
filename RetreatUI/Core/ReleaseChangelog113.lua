local RUI = RetreatUI
if not RUI then return end

RUI.changelog = {
  version = RUI.version,
  title = "RetreatUI v1.1.3",
  summary = "Class HUD organization, improved wrapping and Ascension-focused stability updates.",
  changes = {
    "All learned offensive cooldown abilities remain on Main; defensives and combat utility remain on Utility.",
    "Main wraps after nine icons, including the custom Knight of Xoroth HUD.",
    "Corrected Eternal Bloodmage: Wicked Howl is Defensive/Utility and Eternal Resolve is Offensive/Main.",
    "Removed unsafe inspect, talent and broad learned-state API fallbacks from live addon paths.",
    "Removed retired party tracker source files and fixed the Buff Manager keybind button texture path.",
  },
}
