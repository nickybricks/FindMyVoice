# Settings UI Redesign — SuperWhisper Style

## Plan

### Architecture
- Replace `TabView` in `SettingsView.swift` with `NavigationSplitView` (sidebar + detail)
- Split into focused sub-view files to keep each file small
- Preserve all existing config load/save logic in `SettingsView.swift`

### File Structure
```
FindMyVoiceApp/
├── SettingsView.swift          — NavigationSplitView container, config state, toolbar
├── SettingsSidebar.swift        — Sidebar list with colored icon items + footer
├── ConfigurationView.swift     — Recording window picker + Keyboard shortcuts
├── HomeView.swift              — App overview / about
├── ModesView.swift             — Placeholder for modes
├── VocabularyView.swift        — Placeholder for vocabulary
├── SoundSettingsView.swift     — Sound start/stop pickers (existing logic)
├── ModelsLibraryView.swift     — API provider + model settings (existing logic)
├── HistoryView.swift           — Placeholder for history
```

### Sidebar Items
| Item             | Icon              | Color  | Content View           |
|------------------|-------------------|--------|------------------------|
| Home             | house.fill        | orange | HomeView               |
| Modes            | square.grid.2x2   | blue   | ModesView              |
| Vocabulary       | text.book.closed  | green  | VocabularyView         |
| Configuration    | gearshape.fill    | gray   | ConfigurationView      |
| Sound            | speaker.wave.2    | pink   | SoundSettingsView      |
| Models Library   | cpu               | purple | ModelsLibraryView      |
| History          | clock             | teal   | HistoryView            |

### Key Design Details
- Sidebar icons: SF Symbol on colored rounded rect background
- Cards: white background, 12pt corner radius, subtle border
- Key badges: gray rounded rect with key text inside
- Recording window picker: 3 horizontal cards (Classic/Mini/None), selected = blue border
- Window size: ~700x500 to fit two-panel layout
- Toolbar: sidebar toggle (left), mic name (center), headphone icon (right)
- Sidebar footer: status text + app name button

## Tasks
- [x] Write plan
- [x] Create SettingsSidebar.swift
- [x] Create ConfigurationView.swift
- [x] Create HomeView, ModesView, VocabularyView, SoundSettingsView, ModelsLibraryView, HistoryView
- [x] Rewrite SettingsView.swift as NavigationSplitView container
- [x] Add files to Xcode project
- [x] Build with `make install` and verify
- [ ] Review

---

# Editable Keyboard Shortcuts

## Tasks
- [x] Add `HotkeyCombo` struct to Models.swift (key + modifiers, display helpers)
- [x] Add shortcut fields to `AppConfig` with backward-compat decoding
- [x] Add shortcut defaults + `hotkey` → `toggle_recording` migration to backend
- [x] Build interactive shortcut recorder UI (NSEvent key capture, escape cancels)
- [x] Duplicate detection across all shortcut rows (red flash on conflict)
- [x] Reset-to-default ↺ button per row
- [x] Update `registerHotkey()` to use `HotkeyCombo` with Carbon modifier mask
- [x] Extend key code mapping to support a-z, 0-9, special keys (not just F1-F12)
- [x] Update status polling to compare `toggleRecording` instead of `hotkey`
- [x] `make install` — builds and installs successfully
- [ ] Manual verification: quit + relaunch, test recording/resetting shortcuts
