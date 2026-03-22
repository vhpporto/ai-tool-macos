# Aura

A minimal, keyboard-first AI launcher for macOS. Press **Option+Space** from anywhere to get instant AI assistance — no switching apps, no context lost.

## Features

- **Global hotkey** — Option+Space opens and closes the panel from any app
- **AI chat** — streaming responses powered by OpenAI (GPT-4o, GPT-4o Mini, GPT-4 Turbo)
- **Command modes** — `/translate`, `/fix`, `/explain`, `/summarize`, `/code`, `/shorter`
- **Calculator** — type `2 + 2` or `15% of 340` and get instant results
- **Currency converter** — type `100 USD to BRL` for live exchange rates
- **Clipboard history** — ⌘⇧V shows the last 50 copied items with timestamps
- **Local LLM support** — compatible with Ollama, LM Studio, or any OpenAI-compatible endpoint
- **Markdown rendering** — headings, code blocks, bullet lists, numbered lists, inline code
- **Glassmorphic UI** — native macOS vibes, adapts to light and dark mode

## Requirements

- macOS 14 (Sonoma) or later
- OpenAI API key **or** a local LLM via [Ollama](https://ollama.com)

## Installation

### Build from source

```bash
git clone https://github.com/your-username/aura.git
cd aura/Aura
./run.sh
```

`run.sh` compiles the app, signs it with a local dev certificate, and launches it automatically.

### Release build (DMG)

```bash
cd Aura
./build-dmg.sh
```

Produces `Aura-1.0.0.dmg` ready for distribution.

## Usage

| Shortcut | Action |
|---|---|
| `Option+Space` | Toggle panel |
| `Enter` | Send message |
| `Esc` | Close panel |
| `⌘K` | Clear conversation |
| `⌘⇧V` | Open clipboard history |
| `↑ / ↓` | Navigate input history |

### Command modes

Type `/` in the input to see available commands:

| Command | Description |
|---|---|
| `/translate` | Detect language and translate |
| `/fix` | Fix grammar and improve writing |
| `/explain` | Explain a concept or piece of code |
| `/summarize` | Summarize in up to 5 bullet points |
| `/code` | Write or review code |
| `/shorter` | Make text shorter and punchier |

### Local LLM (Ollama)

1. Install Ollama: `brew install ollama`
2. Pull a model: `ollama pull llama3.2`
3. Open Aura Settings (gear icon) and set the custom endpoint:
   ```
   http://localhost:11434/v1/chat/completions
   ```
4. Type the model name in the footer model picker (e.g. `llama3.2`)

No API key required when using a local endpoint.

## Configuration

All settings are accessible from the gear icon in the footer:

- **OpenAI API Key** — stored securely in `~/Library/Application Support/Aura/`
- **Custom Endpoint** — override the API base URL for local models
- **Model** — switch between GPT-4o, GPT-4o Mini, GPT-4 Turbo

## Architecture

Aura is built with pure Swift, SwiftUI, and AppKit — no third-party dependencies.

```
Sources/Aura/
├── AuraApp.swift                  # App entry point
├── AppDelegate.swift              # Lifecycle, status bar, hotkey setup
├── ContentView.swift              # Main UI container and message routing
├── InputBarView.swift             # Text input with keyboard shortcuts
├── ResponseView.swift             # Markdown rendering engine
├── SettingsView.swift             # Inline settings panel
├── ConversationStore.swift        # State management (@Observable)
├── OpenAIService.swift            # Streaming API client (OpenAI-compatible)
├── LauncherPanelController.swift  # Floating NSPanel management
├── ClipboardMonitor.swift         # Clipboard history tracking
├── HotkeyManager.swift            # Global hotkey via Carbon
├── CalculatorHandler.swift        # Math expression evaluator
├── CurrencyHandler.swift          # Live currency conversion
├── CommandMode.swift              # AI command mode definitions
└── KeychainHelper.swift           # Credential storage
```

## Contributing

Pull requests are welcome. For major changes, open an issue first to discuss what you'd like to change.

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m 'Add my feature'`
4. Push and open a Pull Request

## License

[MIT](../LICENSE)
