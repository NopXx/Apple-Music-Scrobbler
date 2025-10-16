//
//  GlassHelpers.swift
//  Music-Scrobbler
//
//  Convenience modifiers that rely solely on SwiftUI materials.
//

import SwiftUI

extension View {
    func glassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 20, shadowOpacity: Double = 0.2) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        
        return self
            .padding(padding)
            .background(.ultraThinMaterial, in: shape)
            .overlay(
            shape
                .stroke(Color.primary.opacity(0.18), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(shadowOpacity), radius: 18, x: 0, y: 12)
    }
    
    func glassSecondaryText() -> some View {
        foregroundStyle(Color.primary.opacity(0.72))
    }

    func glassControl(cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let textColor = Color.primary.opacity(0.92)
        let strokeColor = Color.primary.opacity(0.22)

        return self
            .font(.headline)
            .foregroundStyle(textColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: shape)
            .overlay(
            shape
                .stroke(strokeColor, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
    }
}

extension View {
    func glassButton(cornerRadius: CGFloat = 16) -> some View {
        self
            .buttonStyle(.plain)
            .glassControl(cornerRadius: cornerRadius)
    }

    /// Provides a material-based glass background with a configurable tint for
    /// platforms that do not support the native `.glassEffect` modifier yet.
    func tintedGlassBackground(tint: Color, tintOpacity: Double = 0.35, cornerRadius: CGFloat = 16, shadowOpacity: Double = 0.15) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return self
            .background(.ultraThinMaterial, in: shape)
            .overlay(
                shape
                    .fill(tint)
                    .opacity(tintOpacity)
            )
            .overlay(
                shape
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: max(12, cornerRadius / 2), x: 0, y: 8)
    }

    /// Uses the system `glassEffect` when available, otherwise falls back to the
    /// custom tinted glass background for older macOS versions.
    @ViewBuilder
    func adaptiveGlassEffect(tint: Color, tintOpacity: Double = 0.35, cornerRadius: CGFloat = 16, shadowOpacity: Double = 0.15) -> some View {
        if #available(macOS 15, *) {
            self
                .glassEffect(
                    .regular
                        .tint(tint.opacity(tintOpacity))
                        .interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            self
                .tintedGlassBackground(
                    tint: tint,
                    tintOpacity: tintOpacity,
                    cornerRadius: cornerRadius,
                    shadowOpacity: shadowOpacity
                )
        }
    }
}

extension TextField {
    func glassTextFieldBackground(cornerRadius: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return self
            .textFieldStyle(.plain)
            .foregroundStyle(Color.primary.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: shape)
            .overlay(
            shape
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 5)
    }
}
