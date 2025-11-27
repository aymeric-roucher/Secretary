# Jarvis - macOS AI Secretary

A native macOS secretary app integrated with the Gemini Live API (Multimodal) for real-time voice command processing and tool execution.

## Architecture

Jarvis uses a streamlined architecture powered by Google's Gemini Live API (WebSocket):

1.  **Voice Input**: Captures audio from the microphone.
2.  **Gemini Live API**: Sends audio directly to Gemini (model: `gemini-live-2.5-flash-preview`).
3.  **Direct Tool Calling**: The Gemini model processes the audio, transcribes it, and determines if a tool needs to be called (e.g., typing text, opening apps) in a single session.
4.  **Tool Execution**: The app executes the requested tool locally on macOS.

## Tools

The following tools are available to the AI:
- `type(text: String)`: Type text into the active window.
- `open_app(target: String)`: Open an application or URL.
- `switch_to(app_name: String)`: Switch focus to a running application.

## Setup

1.  Launch Jarvis.
2.  Go to **Settings**.
3.  Enter your **Gemini API Key**.
4.  Grant Microphone and Accessibility permissions.
5.  Use the global hotkey (default: `@`, i.e. Shift+2) to talk to Jarvis.

## Implementation Details

- **Core**: `JarvisApp/Sources/Core`
    - `GeminiClient.swift`: Manages the WebSocket connection to Gemini Live API.
    - `ToolManager.swift`: Handles macOS system interactions (AppleScript/Accessibility).
    - `AudioRecorder.swift`: Handles audio capture.
- **UI**: `JarvisApp/Sources/Views`
    - SwiftUI-based interface for Settings and the Spotlight overlay.

## Requirements

- macOS 13.0+
- Google Gemini API Key
