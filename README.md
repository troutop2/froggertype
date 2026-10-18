# FroggerType 🐸 | More Than a Monkeytype Clone

A fast, minimalist typing speed test meets the legendary **Frogger Arcade** — built with [LÖVE](https://love2d.org/) (Love2D / Lua).

Toggle instantly between **Arcade Mode** (cross roads and rivers by typing!) and **Classic Mode** (full Monkeytype speed test with graphs and smooth caret).

---

## 🕹️ Game Modes

### 1. 🐸 Frogger Arcade Crossing Mode (`F1` to toggle)
- **Typing is Your Movement**: Words hover over upcoming lanes, crosswalks, drifting logs, and swimming lily pads.
- **Type to Leap**: Finish a word to launch the frog into the air in a parabolic jump onto that target!
- **Dodge Traffic**: Highway lanes feature speeding sedans, racecars, and heavy trucks. Type words to navigate safe crosswalk intervals.
- **Cross Rushing River Currents**: Logs and turtles drift with the water current. Land on them before you drift off the screen, and jump before you sink!
- **Catch Bonus Flies 🪰**: Floating fireflies appear with quick prompt words (e.g. `fly`). Type them to snatch the fly with your tongue for +300 bonus score!
- **Rescue 5 Frogs into Haven Bays**: Reach the lily pad havens at the top of the board to rescue frogs. Filling all 5 havens completes the level and unlocks the next stage with faster currents and new words!
- **Arcade Sound FX**: Procedurally synthesized jump boings, water splashes, vehicle squishes, fly catches, and victory fanfares!

---

### 2. ⌨️ Classic Monkeytype Mode (`F1` to toggle)
- **Pure Typing Flow**: 3-line viewing window with buttery smooth scrolling and animated caret interpolation.
- **Modes & Modifiers**:
  - **Time**: 15s, 30s, 60s
  - **Words**: 10, 25, 50, 100 words (instant finish on last word)
  - **Modifiers**: Punctuation (`@ punct`) and Numbers (`# num`)
- **Detailed Results Screen**:
  - Big WPM & Accuracy %
  - Raw WPM & Consistency %
  - Detailed keystroke breakdown (`correct / incorrect / extra / missed`)
  - **Signature WPM & Raw Timeline Curve** with error markers and glowing area under the curve!
- **Lily Pad Leap Progress Track**: Animated frog hops from lily pad to lily pad as you progress through the test!

---

## 🎨 Themes

Cycle themes anytime using `F2` or click the theme pill:
- 🐸 **Frogger** (Deep swamp emerald & vibrant mint green)
- 🟡 **Serika Dark** (Classic Monkeytype charcoal & amber yellow)
- 🟢 **Matrix** (Hacker terminal green)
- 🟣 **Dracula** (Vibrant purple & cyan)
- 🟠 **Carbon** (Dark slate & punchy orange)
- ❄️ **Nord** (Arctic slate & frost blue)

---

## ⌨️ Controls & Shortcuts

| Key / Action | Function |
| :--- | :--- |
| `F1` | **Switch between Arcade Mode & Classic Mode** |
| `Typing` | Type words to leap in Arcade / type text in Classic |
| `Backspace` | Erase typos in current word buffer |
| `Ctrl + Backspace` | Delete entire current word (Classic) |
| `Space` | Advance word in Classic / Restart on Arcade Game Over |
| `Tab` or `Esc` | Restart current test or level |
| `Shift + Tab` | Repeat identical test words (Classic) |
| `F2` | Cycle color theme |
| `Ctrl + M` | Toggle mechanical switch sound feedback |
| `Mouse Click` | Interactive pills for mode, timer, word count, theme, and sound |

---

## 🚀 How to Run

```powershell
& "C:\Program Files\LOVE\love.exe" .
```
Or if `love` is in your system PATH:
```bash
love .
```

---

Built for keyboard enthusiasts, speed typists, and arcade lovers! 🐸⌨️🕹️
