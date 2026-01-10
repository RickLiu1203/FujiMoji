//
//  MenuFourthSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-29.
//

import SwiftUI
import Carbon.HIToolbox

struct KeyCaptureView: NSViewRepresentable {
    @Binding var keyCombo: KeyCombo
    @Binding var isCapturing: Bool
    var onCapture: () -> Void
    
    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyCombo = { combo in
            DispatchQueue.main.async {
                self.keyCombo = combo
                self.isCapturing = false
                self.onCapture()
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        if isCapturing {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class KeyCaptureNSView: NSView {
    var onKeyCombo: ((KeyCombo) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return }
        
        let flags = event.modifierFlags
        let combo = KeyCombo(
            key: chars,
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift)
        )
        onKeyCombo?(combo)
    }
}

struct MenuFourthSectionView: View {
    @ObservedObject var fujiMojiState: FujiMojiState
    @State private var isCapturingKey: Bool = false
    @State private var tempCombo: KeyCombo = KeyCombo()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Trigger Key
            HStack {
                Text("Trigger Key(s)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: {
                    tempCombo = fujiMojiState.triggerCombo
                    isCapturingKey = true
                }) {
                    Text(isCapturingKey ? "Press Key(s)" : fujiMojiState.triggerCombo.displayString)
                        .frame(minWidth: 44)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isCapturingKey ? Color.blue.opacity(0.3) : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isCapturingKey ? Color.blue.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if isCapturingKey {
                            KeyCaptureView(keyCombo: $tempCombo, isCapturing: $isCapturingKey) {
                                fujiMojiState.setTriggerCombo(tempCombo)
                            }
                            .frame(width: 1, height: 1)
                            .opacity(0)
                        }
                    }
                )
            }
            
            // Enter ends capture toggle
            Toggle(isOn: $fujiMojiState.enterEndsCapture) {
                HStack(spacing: 6) {
                    Text("Enter to Submit")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .toggleStyle(FrostedToggleStyle())
            .frame(maxWidth: .infinity)
            .onChange(of: fujiMojiState.enterEndsCapture) {
                fujiMojiState.updateEnterEndsCapture()
            }
            
            // Tab ends capture toggle
            Toggle(isOn: $fujiMojiState.tabEndsCapture) {
                HStack(spacing: 6) {
                    Text("Tab to Submit")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .toggleStyle(FrostedToggleStyle())
            .frame(maxWidth: .infinity)
            .onChange(of: fujiMojiState.tabEndsCapture) {
                fujiMojiState.updateTabEndsCapture()
            }
        }
        .padding(.horizontal, 16)
        .font(.system(size: 13, weight: .medium))
    }
}
