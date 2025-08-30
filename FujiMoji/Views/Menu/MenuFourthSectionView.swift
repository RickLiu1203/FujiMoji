//
//  MenuFourthSectionView.swift
//  FujiMoji
//
//  Created by Rick Liu on 2025-08-29.
//

import SwiftUI

struct MenuFourthSectionView: View {
    @ObservedObject var fujiMojiState: FujiMojiState
    @State private var tempStartKey: String = ""
    @State private var tempEndKey: String = ""
    @FocusState private var isEditingStart: Bool
    @FocusState private var isEditingEnd: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Start Capture Key")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("", text: $tempStartKey)
                    .textFieldStyle(.plain)
                    .frame(width: 12)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isEditingStart ? Color.black.opacity(0.15) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .onChange(of: tempStartKey) {
                        tempStartKey = filterAndLimitInput(tempStartKey)
                    }
                    .onSubmit {
                        submitStartKey()
                    }
                    .focused($isEditingStart)
                    .onTapGesture {
                        isEditingStart = true
                    }
            }
            
            HStack {
                Text("End Capture Key")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("", text: $tempEndKey)
                    .textFieldStyle(.plain)
                    .frame(width: 12)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isEditingEnd ? Color.black.opacity(0.15) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .onChange(of: tempEndKey) {
                        if tempEndKey.lowercased() != "space" {
                            tempEndKey = filterAndLimitInput(tempEndKey)
                        }
                    }
                    .onSubmit {
                        submitEndKey()
                    }
                    .focused($isEditingEnd)
                    .onTapGesture {
                        isEditingEnd = true
                    }
            }
        }
        .font(.system(size: 13, weight: .medium))
        .onAppear {
            tempStartKey = fujiMojiState.startCaptureKey
            tempEndKey = displayEndKey(fujiMojiState.endCaptureKey)
        }
    }
    
    private func displayEndKey(_ key: String) -> String {
        return key == " " ? "␣" : key
    }
    
    private func filterAndLimitInput(_ input: String) -> String {
        // Allow typing "Space" for the end key
        if input.lowercased().hasPrefix("space") && input.count <= 5 {
            return input
        }
        
        // Filter to only allow printable ASCII characters (excluding control characters)
        let filtered = input.filter { char in
            let ascii = char.asciiValue ?? 0
            return ascii >= 32 && ascii <= 126 // Printable ASCII range
        }
        
        // Limit to 1 character unless it's "Space"
        if filtered.lowercased() != "space" && filtered.count > 1 {
            return String(filtered.prefix(1))
        }
        
        return filtered
    }
    
    private func submitStartKey() {
        let trimmed = tempStartKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || !isValidCaptureKey(trimmed) {
            // Revert to previous state
            tempStartKey = fujiMojiState.startCaptureKey
        } else {
            fujiMojiState.startCaptureKey = trimmed
            fujiMojiState.updateCaptureKeys()
        }
        isEditingStart = false
    }
    
    private func submitEndKey() {
        let trimmed = tempEndKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // Revert to previous state
            tempEndKey = displayEndKey(fujiMojiState.endCaptureKey)
        } else {
            let actualKey = trimmed.lowercased() == "space" ? " " : trimmed
            if isValidCaptureKey(actualKey) {
                fujiMojiState.endCaptureKey = actualKey
                fujiMojiState.updateCaptureKeys()
            } else {
                // Revert to previous state
                tempEndKey = displayEndKey(fujiMojiState.endCaptureKey)
            }
        }
        isEditingEnd = false
    }
    
    private func isValidCaptureKey(_ key: String) -> Bool {
        // Must be exactly 1 character
        guard key.count == 1 else { return false }
        
        let char = key.first!
        let ascii = char.asciiValue ?? 0
        
        // Must be printable ASCII (space to tilde)
        return ascii >= 32 && ascii <= 126
    }
}
