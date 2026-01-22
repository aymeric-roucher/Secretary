# Secretary - macOS AI Secretary

A native macOS voice assistant that listens to your commands and executes actions like typing text, opening apps, and more.

## How It Works

```
Voice Input → OpenAI Whisper → Cerebras LLM → Tool Execution
```

1. **Voice Capture**: Press and hold the global hotkey to record your voice
2. **Transcription**: Audio is sent to OpenAI Whisper for speech-to-text
3. **Command Routing**: Transcript is processed by Cerebras (Qwen model) to determine the action
4. **Execution**: The appropriate tool is executed locally on your Mac

## Tools

| Tool            | Description                       | Example                            |
| --------------- | --------------------------------- | ---------------------------------- |
| `type`          | Types text into the active window | "Type hello world"                 |
| `open_app`      | Opens an application or URL       | "Open Safari" or "Open github.com" |
| `switch_to`     | Switches focus to a running app   | "Switch to Slack"                  |
| `deep_research` | Opens a Google search             | "Research Swift concurrency"       |

## Setup

1. Build and launch the app
2. Complete onboarding:
   - Enter your **OpenAI API Key** (for Whisper transcription)
   - Enter your **Hugging Face Token** (for Cerebras routing)
   - Grant **Microphone** permission
   - Grant **Accessibility** permission (for typing)
3. Configure your preferred hotkey (default: Shift+Space)
4. Press "Finish" when all checks pass

## Usage

1. Press and hold your hotkey
2. Speak your command
3. Release the hotkey → transcribes and types your speech
4. Hold **fn + hotkey** → enables agentic mode (LLM command routing)

Configure agentic mode behavior in Settings (fn key, always on, or disabled).

## Project Structure

```
SecretaryApp/
├── Sources/
│   ├── SecretaryApp.swift          # Entry point, AppState, hotkey handling
│   ├── Core/
│   │   ├── AudioRecorder.swift     # Microphone capture with level monitoring
│   │   ├── TranscriptionClient.swift # OpenAI Whisper API integration
│   │   ├── ThinkingClient.swift    # HuggingFace/Cerebras command routing
│   │   └── ToolManager.swift       # macOS tool execution (type, open, switch)
│   ├── Views/
│   │   ├── Theme.swift             # Theming system, fonts, colors, icons
│   │   ├── SettingsView.swift      # Main dashboard with tabs (Home, Dictionary, Style, Settings)
│   │   ├── MenuPopup.swift         # Floating overlay during recording
│   │   ├── OnboardingView.swift    # First-launch setup wizard
│   │   ├── ConfigSections.swift    # API keys, permissions, language selection UI
│   │   ├── ShortcutRecorder.swift  # Hotkey configuration
│   │   ├── WaveformView.swift      # Real-time audio visualization
│   │   └── LogsView.swift          # Log file viewer
│   └── Utils/
│       ├── Logger.swift            # File-based logging
│       ├── DictionaryStore.swift   # Custom word/correction storage
│       ├── LanguageStore.swift     # Language selection for transcription
│       ├── StyleStore.swift        # Writing style examples storage
│       ├── SoundPlayer.swift       # Audio feedback
│       └── CrashLogger.swift       # Exception handling
```

## Requirements

- macOS 14.0+ (Sonoma)
- OpenAI API Key
- Hugging Face Token

## Building

```bash
./build_app.sh
```

Then launch the app:
```bash
open Secretary.app
```

## Configuration Storage

Settings are stored in UserDefaults:
- `openaiApiKey` - OpenAI API key
- `hfApiKey` - Hugging Face token
- `SecretaryShortcutModifier` - Hotkey modifier
- `SecretaryShortcutKey` - Hotkey key code
- `hasCompletedOnboarding` - Setup completion flag
- `agenticModifier` - Agentic mode trigger: "fn" (default), "always", or "disabled"

Audio recordings are saved to `~/Documents/Secretary/recording.m4a`

Logs are written to `Secretary_Log.txt` in the app directory

### Making an installer package

https://www.itech4mac.net/2025/04/how-to-create-a-dmg-installer-for-you-applications-on-macos/


### License

Apache 2.0. You can just credit Aymeric Roucher for the app, and Raphaël Doan for the visual theme!