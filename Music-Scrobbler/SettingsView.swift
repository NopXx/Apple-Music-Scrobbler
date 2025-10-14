// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    // ใช้ @AppStorage เพื่อให้ค่าที่ตั้งไว้ถูกบันทึกและนำกลับมาใช้ใหม่ได้อัตโนมัติ
    @AppStorage("webhookURL") private var webhookURL: String = ""
    @AppStorage("showNotifications") private var showNotifications: Bool = true
    @AppStorage("scrobblePercent") private var scrobblePercent: Double = 50.0

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
                }
                .glassCard()
                
                Text("แอปจะ Scrobble เมื่อเล่นเพลงถึงเปอร์เซ็นต์ที่กำหนด หรือเล่นไปแล้ว 4 นาที (อย่างใดอย่างหนึ่งถึงก่อน)")
                    .font(.caption)
                    .glassSecondaryText()
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .frame(width: 520, height: 320)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
