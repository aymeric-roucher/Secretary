import SwiftUI
import AppKit

final class FloatingPanel<Content: View>: NSPanel {
    private let didClose: () -> Void
    
    init(view: @escaping () -> Content, contentRect: NSRect, didClose: @escaping () -> Void) {
        self.didClose = didClose
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel, .titled, .fullSizeContentView], backing: .buffered, defer: false)
        
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        animationBehavior = .utilityWindow
        setFrame(contentRect, display: false)
        contentView = NSHostingView(rootView: view())
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    override func cancelOperation(_ sender: Any?) {
        close()
    }
    
    override func resignKey() {
        super.resignKey()
        close()
    }
    
    override func close() {
        super.close()
        didClose()
    }
}

final class FloatingPanelHandler {
    private var panel: FloatingPanel<AnyView>?
    private var onClose: (() -> Void)?
    
    func configureOnClose(_ onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func toggle(appState: AppState) {
        if panel == nil {
            show(appState: appState)
        } else {
            hide()
        }
    }
    
    func show(appState: AppState) {
        if panel != nil { return }
        let panel = FloatingPanel(view: {
            AnyView(SpotlightView().environmentObject(appState))
        }, contentRect: NSRect(x: 0, y: 0, width: 740, height: 260), didClose: { [weak self] in
            self?.panel = nil
            Task { @MainActor in
                self?.onClose?()
            }
        })
        
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.orderFrontRegardless()
            panel.center()
        }
        
        self.panel = panel
        Task { @MainActor in appState.isSpotlightVisible = true }
    }
    
    func hide() {
        if let panel = panel {
            panel.orderOut(nil)
            self.panel = nil
            Task { @MainActor in self.onClose?() }
        }
    }
}
