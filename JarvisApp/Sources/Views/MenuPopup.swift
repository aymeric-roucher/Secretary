import SwiftUI
import AppKit

private let popupWidth: CGFloat = 340

// MARK: - Popup Message Row (reusable component)
struct PopupMessageRow: View {
    let icon: String
    let content: String
    var isSecondary: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isSecondary ? Theme.secondaryText : Theme.textColor)
                .frame(width: 16)

            Text(content)
                .font(Theme.smallFont)
                .foregroundColor(isSecondary ? Theme.secondaryText : Theme.textColor)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Main Popup View
struct MenuPopupView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status indicator row
            HStack(spacing: 12) {
                statusIndicator
                    .frame(width: 24, height: 24)

                if appState.isRecording {
                    WaveformView(recorder: appState.audioRecorder, isRecording: true)
                        .frame(height: 24)
                } else if appState.isProcessing && appState.popupTranscript == nil {
                    Text("Processing...")
                        .font(Theme.smallFont)
                        .foregroundColor(Theme.secondaryText)
                } else if let transcript = appState.popupTranscript {
                    PopupMessageRow(icon: "waveform", content: transcript)
                }
            }

            // Tool output row (if available)
            if let toolMsg = appState.popupToolMessage {
                HStack(spacing: 12) {
                    Text("↳")
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.secondaryText)
                        .frame(width: 24)

                    PopupMessageRow(
                        icon: Theme.iconForTool(name: toolMsg.toolPayload?.name, arguments: toolMsg.toolPayload?.arguments),
                        content: toolMsg.content,
                        isSecondary: true
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: popupWidth, alignment: .leading)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if appState.isCompleted {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
                .transition(.scale.combined(with: .opacity))
        } else if appState.isProcessing {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.7)
                .colorInvert()
                .colorMultiply(Theme.textColor)
        } else {
            // Recording state (default when popup is open)
            Circle()
                .fill(Theme.textColor)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Theme.textColor.opacity(0.3), lineWidth: 4))
        }
    }
}

// MARK: - Panel Manager
final class MenuPopupManager {
    private var panel: NSPanel?
    private weak var appState: AppState?

    func show(appState: AppState) {
        // Hide any existing panel first to prevent orphans
        hide()

        self.appState = appState

        let contentView = MenuPopupView().environmentObject(appState)
        let hosting = NSHostingController(rootView: contentView)

        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.nonactivatingPanel, .borderless, .fullSizeContentView]
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = false  // Use SwiftUI shadow instead for rounded corners
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        // Make the hosting view and content view fully transparent
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
        }
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor

        hosting.view.layoutSubtreeIfNeeded()
        let fitHeight = hosting.view.fittingSize.height
        let panelHeight = max(fitHeight, 50)
        panel.setFrame(NSRect(x: 0, y: 0, width: popupWidth, height: panelHeight), display: false)
        positionPanel(panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func positionPanel(_ panel: NSPanel) {
        if let screen = NSScreen.main {
            let origin = NSPoint(x: screen.visibleFrame.maxX - panel.frame.width - 16,
                                 y: screen.visibleFrame.minY + 40)
            panel.setFrameOrigin(origin)
        }
    }
}
