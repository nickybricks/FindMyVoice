# FindMyVoice

## What This Is
A lightweight macOS SuperWhisper clone — global hotkey voice-to-text that pastes into any active app. Python backend + native SwiftUI frontend.

## Architecture
- **Backend**: Python 3.10+ script (`backend/findmyvoice_core.py`) handles audio recording, Whisper API transcription, clipboard paste, and exposes a local HTTP API on `localhost:7890`
- **Frontend**: Native SwiftUI macOS app with MenuBarExtra for menu bar presence and a Settings window. Communicates with backend via HTTP.
- **Config**: JSON file at `~/.findmyvoice/config.json`

## Git Push & Release Workflow

When asked to push to GitHub, follow this exact process:

### 1. Version Bump (Semantic Versioning)

Determine the version bump based on scope of changes:

| Change Type | Bump | Example |
|---|---|---|
| Bug fixes, typos, minor tweaks | **Patch** (`0.2.0` → `0.2.1`) | Fix a broken API route |
| New features, significant additions | **Minor** (`0.2.0` → `0.3.0`) | Add a new phase or feature |
| Breaking changes, major rewrites | **Major** (`0.2.0` → `1.0.0`) | Complete architecture change |

- Update `"version"` in `package.json`

### 2. Update README.md

Before pushing, ensure `README.md` reflects:
- Any new features or changes
- Updated tech stack if dependencies changed
- Updated setup instructions if env vars or steps changed

### 3. Commit & Tag

```bash
# Stage all relevant files
git add -A

# Commit with version in message
git commit -m "v{VERSION}: {Brief description of changes}"

# Create a git tag
git tag v{VERSION}
```

### 4. Push

```bash
# Push to the specified remote (ask which one if not specified)
git push {remote} main --tags
```

- Default remote is `github`
- Always push tags with `--tags`

### 5. Create GitHub Release

```bash
# Create a release on GitHub with release notes
gh release create v{VERSION} --title "v{VERSION}: {Brief description}" --notes "{Release notes in markdown}"
```

- Always create a GitHub release after pushing a new tag
- Include a `## Changes` section with bullet points summarizing what changed
- The release title should match the commit message format: `v{VERSION}: {Brief description}`


## Build & Install

After any Swift code change, the app must be rebuilt and reinstalled:

```bash
make install
```

This builds a Release binary and copies it to `/Applications/FindMyVoice.app`, replacing any existing version.

After running `make install`:
1. Quit the running app (click the menu bar icon → Quit)
2. Relaunch from `/Applications/FindMyVoice.app`

Do **not** run the app directly from the Xcode build folder — always use the installed copy in `/Applications`.

## Tech Stack
- Python: sounddevice, numpy, scipy, openai, flask
- Swift: SwiftUI, MenuBarExtra (macOS 14+)
- Build: Makefile, xcodebuild

## Project Structure
```
FindMyVoice/
├── backend/
│   ├── findmyvoice_core.py
│   ├── requirements.txt
│   └── setup.sh
├── FindMyVoiceApp/
│   ├── FindMyVoiceApp.swift
│   ├── SettingsView.swift
│   ├── APIClient.swift
│   ├── Models.swift
│   └── Assets.xcassets/
├── FindMyVoice.xcodeproj/
├── README.md
├── Makefile
├── tasks/
│   └── todo.md
└── CLAUDE.md
```

## Code Style
- Python: simple, minimal, no classes unless necessary. Use type hints.
- Swift: idiomatic SwiftUI, use Form/GroupBox/TabView. Native macOS look.
- No over-engineering. Keep files small and focused.

## Key Constraints
- macOS 14+ minimum (for MenuBarExtra)
- Config must have sensible defaults and be created automatically on first run
- Backend must handle missing API key gracefully (don't crash, show error)
- All sounds reference macOS system sounds in `/System/Library/Sounds/`
- Accessibility and microphone permissions must be handled with clear alerts
- The SwiftUI app launches the Python backend as a subprocess and kills it on quit

## Claude Code Behavior

### Planning
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan — don't keep pushing
- Write the plan before writing code
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### Verification
- Never mark a task complete without proving it works
- Backend: confirm the HTTP API responds on localhost:7890
- SwiftUI: confirm it compiles with xcodebuild
- Test the full flow: hotkey → record → transcribe → paste
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### Code Quality
- Simplicity first — make every change as simple as possible. Impact minimal code.
- For non-trivial logic, pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for obvious, simple fixes — don't over-engineer
- No temporary hacks. Find root causes. Senior developer standards.

### Subagents
- Use subagents to keep main context window clean when possible
- Offload research, exploration, and parallel analysis to subagents
- One task per subagent for focused execution

### Task Tracking
- Write plan to `tasks/todo.md` with checkable items before starting
- Check in before starting implementation
- Mark items complete as you go
- High-level summary at each step
- Add a review section to `tasks/todo.md` when done
