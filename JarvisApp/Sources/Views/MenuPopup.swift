import SwiftUI
import AppKit

struct MenuPopupView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18))
                    .foregroundColor(appState.isRecording ? .red : .secondary)
                WaveformView(recorder: appState.audioRecorder, isRecording: appState.isRecording)
                    .frame(height: 30)
                    .opacity(appState.isRecording ? 1 : 0.3)
            }
            
            if appState.isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

final class MenuPopupManager {
    private var panel: NSPanel?
    private weak var appState: AppState?
    private let panelWidth: CGFloat = 200
    private let panelHeight: CGFloat = 80
    
    func show(appState: AppState) {
        self.appState = appState
        
        let contentView = MenuPopupView().environmentObject(appState)
        let hosting = NSHostingController(rootView: contentView)
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.nonactivatingPanel, .hudWindow, .fullSizeContentView]
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.setFrame(NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight), display: false)
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
            let origin = NSPoint(x: screen.visibleFrame.maxX - panelWidth - 12,
                                 y: screen.visibleFrame.minY + 20)
            panel.setFrameOrigin(origin)
        }
    }
}
