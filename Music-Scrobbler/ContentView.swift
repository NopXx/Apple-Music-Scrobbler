//
//  ContentView.swift
//  Music-Scrobbler
//
//  Created by NopXx on 10/10/2568 BE.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.17, blue: 0.3),
                    Color(red: 0.06, green: 0.09, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.white)
                Text("Apple Music Scrobbler")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                Text("Scrobble เพลงที่คุณชอบด้วยลุคกระจกจาก SwiftUI")
                    .font(.subheadline)
                    .glassSecondaryText()
                    .multilineTextAlignment(.center)
            }
            .glassCard(padding: 24, shadowOpacity: 0.16)
            .padding(32)
        }
    }
}

#Preview {
    ContentView()
}
