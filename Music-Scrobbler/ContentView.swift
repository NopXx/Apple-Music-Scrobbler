//
//  ContentView.swift
//  Music-Scrobbler
//
//  Created by NopXx on 10/10/2568 BE.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: StatusViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: viewModel.artworkGradient),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.primary)
                Text("Apple Music Scrobbler")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text("Scrobble เพลงที่คุณชอบด้วยลุคกระจกจาก SwiftUI")
                    .font(.subheadline)
                    .glassSecondaryText()
                    .multilineTextAlignment(.center)
            }
            .glassCard(padding: 24, shadowOpacity: 0.16)
            .padding(32)
        }
        .animation(.spring(), value: viewModel.artworkGradient)
    }
}

#Preview {
    ContentView()
        .environmentObject(StatusViewModel())
}
