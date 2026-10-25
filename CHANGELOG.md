## 0.6.1

- With **Font** set to Rusty Pixel, text now falls back to the game's font if the pixel font can't be loaded, instead of disappearing.
- After updating, restart the game rather than reloading the UI: the pixel font has moved, and the game only finds new files when it starts.

## 0.6.0

- Raid frames: Blizzard's raid frames, and raid-style party frames, with flat health and power bars and 1px borders. The empty part of the health bar is a dim shade of its color, and aggro and your target show as 1px borders.
- Nameplates: flat health bars with a 1px border and a tinted track, and flat cast bars colored by cast type, in four styles switched live: Slim, Framed, Thick and Minimal. Your target gets a second 1px outline (on Framed, the window's border) and a soft target an underline, in the colors Blizzard gives them. A **Friendly NPCs: names only** option hides the bars of friendly NPCs and pets. Friendly nameplates in dungeons and raids are closed to addons and keep Blizzard's look.
- Four new accents: Azure, Rose, Fel and Frost. The accent cards now wrap into rows of four.
- Action bars: the dividers Retail's main bar draws between buttons are gone; past the last filled slot they showed on their own.
- Character window: kit window and tabs, gear in square slots bordered in their quality color, the stats as kit headings, and the item flyout as a kit panel. On WoW Forever, the side panes and icon tabs too.
- Quest, gossip, merchant and mail windows: kit windows, buttons, tabs and edit boxes, with items in square slots bordered in their quality color. The parchment pages stay.
- Each of the new modules can be turned off in `/rui`, and the character and NPC windows have a quality borders option of their own.
- XP bar: at the level cap it now follows renown, paragon and friendship factions, and shows a maxed reputation full instead of disappearing. A new **At max level** setting can hide the bar there instead. While the bar is hidden, the action bars no longer keep room for it.

## 0.5.4

- Updated for Retail 12.1.5.
- Action bars: short keybindings (`sM4`, `cQ`, `N5`), and buttons turn red when out of range.
- Buffs and debuffs: short timers (`12m`, `45`) that turn red in their last 5 seconds.
- Tooltips: unit borders and health bars in class or reaction color.

## 0.5.2

- First public release. RustyUI is a clean, flat reskin of the default UI: near-black panels, borders one screen pixel thin, square icons and an accent color. It changes how Blizzard's own frames look, never replaces them, so frames keep their places and Edit Mode keeps working.
- It skins the action bars, the micro menu and bag bar, bags, unit frames, the minimap, tooltips, cast bars, buffs and debuffs, chat, the objective tracker, popups and the game menu, timers and the extra action button, and the talents window. It also replaces the experience bar with one of its own, which shows your watched reputation at the level cap. Each of these can be turned off on its own.
- The accent can be Gold, Rust, Teal or Violet, picked from preview cards that show the kit in each color. Borders can take the accent color instead of grey.
- `/rui` opens the settings window. It remembers its position and the page you were on, and closes on Escape. When a change needs a reload, a Reload UI button appears in its title bar.
