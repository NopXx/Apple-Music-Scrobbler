// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    // ใช้ @AppStorage เพื่อให้ค่าที่ตั้งไว้ถูกบันทึกและนำกลับมาใช้ใหม่ได้อัตโนมัติ
    @AppStorage("webhookURL") private var webhookURL: String = ""
    @AppStorage("showNotifications") private var showNotifications: Bool = true
    @AppStorage("scrobblePercent") private var scrobblePercent: Double = 50.0
    @EnvironmentObject private var viewModel: StatusViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.16, blue: 0.26),
                    Color(red: 0.07, green: 0.09, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("การตั้งค่า Scrobbler")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.white)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Webhook URL")
                            .font(.footnote)
                            .glassSecondaryText()
                        TextField("https://example.com/webhook", text: $webhookURL)
                            .glassTextFieldBackground()
                            .disableAutocorrection(true)
                        
                        Text("Scrobble เมื่อเล่นถึง \(Int(scrobblePercent))%")
                            .font(.footnote)
                            .glassSecondaryText()
                        
                        Slider(value: $scrobblePercent, in: 1...100, step: 1)
                            .tint(Color.white.opacity(0.85))
                    }
                    
                    Toggle("แสดงการแจ้งเตือน", isOn: $showNotifications)
                        .toggleStyle(SwitchToggleStyle(tint: Color.white.opacity(0.85)))
                        .font(.headline)
                        .foregroundStyle(Color.white.opacity(0.92))

                    Divider()
                        .overlay(Color.white.opacity(0.2))

                    Toggle("เชื่อมต่อ Last.fm", isOn: Binding(
                        get: { viewModel.lastFmToggleState },
                        set: { viewModel.setLastFmEnabled($0) }
                    ))
                        .toggleStyle(SwitchToggleStyle(tint: Color.white.opacity(0.85)))
                        .font(.headline)
                        .foregroundStyle(Color.white.opacity(0.92))

                    if viewModel.lastFmToggleState {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: viewModel.isLastFmAuthorized ? "checkmark.seal.fill" : "exclamationmark.triangle")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(viewModel.isLastFmAuthorized ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                                Text(viewModel.lastFmStatusText)
                                    .font(.footnote)
                                    .glassSecondaryText()
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Last.fm API Key")
                                    .font(.footnote)
                                    .glassSecondaryText()
                                TextField(
                                    "Enter API key",
                                    text: Binding(
                                        get: { viewModel.lastFmApiKeyInput },
                                        set: { viewModel.updateLastFmApiKey($0) }
                                    )
                                )
                                .glassTextFieldBackground()
                                .disableAutocorrection(true)

                                Text("Shared Secret")
                                    .font(.footnote)
                                    .glassSecondaryText()
                                TextField(
                                    "Enter shared secret",
                                    text: Binding(
                                        get: { viewModel.lastFmSharedSecretInput },
                                        set: { viewModel.updateLastFmSharedSecret($0) }
                                    )
                                )
                                .glassTextFieldBackground()
                                .disableAutocorrection(true)
                            }

                            if viewModel.isLastFmAuthInProgress {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }

                            HStack(spacing: 12) {
                                Button("Sign in with Last.fm") {
                                    viewModel.beginLastFmAuthorization()
                                }
                                .glassButton()
                                .disabled(!viewModel.canStartLastFmAuthorization || viewModel.isLastFmAuthInProgress)

                                Button("Complete Sign In") {
                                    viewModel.completeLastFmAuthorization()
                                }
                                .glassButton()
                                .disabled(!viewModel.canCompleteLastFmAuthorization || viewModel.isLastFmAuthInProgress)

                                if viewModel.isLastFmAuthorized {
                                    Button("Sign Out") {
                                        viewModel.disconnectLastFm()
                                    }
                                    .glassButton()
                                }
                            }

                            Text("Sign in ด้วยเบราว์เซอร์ Last.fm แล้วกด Complete Sign In เพื่อดึง session key อัตโนมัติ")
                                .font(.caption2)
                                .glassSecondaryText()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .glassCard()
                
                Text("แอปจะ Scrobble เมื่อเล่นเพลงถึงเปอร์เซ็นต์ที่กำหนด หรือเล่นไปแล้ว 4 นาที (อย่างใดอย่างหนึ่งถึงก่อน)")
                    .font(.caption)
                    .glassSecondaryText()
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .frame(width: 520, height: 600)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(StatusViewModel())
    }
}
