
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var viewModel: StatusViewModel
    @AppStorage("webhookURL") private var webhookURL: String = ""
    @AppStorage("showNotifications") private var showNotifications: Bool = true
    @AppStorage("scrobblePercent") private var scrobblePercent: Double = 50.0

    var body: some View {
        Form {
            Section(
                header: Text("การเชื่อมต่อ").foregroundStyle(Color.primary.opacity(0.8)),
                footer: Text("รับการแจ้งเตือน event ของเพลงไปยัง URL ที่คุณกำหนด").foregroundStyle(Color.primary.opacity(0.7))
            ) {
                LabeledContent {
                    TextField("https://example.com/webhook", text: $webhookURL)
                        .glassTextFieldBackground()
                        .disableAutocorrection(true)
                } label: {
                    Text("Webhook URL")
                        .glassSecondaryText()
                }
            }
            
            Section(header: Text("การ Scrobble").foregroundStyle(Color.primary.opacity(0.8))) {
                VStack(alignment: .leading) {
                    Text("Scrobble เมื่อเล่นถึง \(Int(scrobblePercent))%")
                        .font(.footnote)
                        .glassSecondaryText()
                    Slider(value: $scrobblePercent, in: 1...100, step: 1)
                        .tint(Color.accentColor)
                }
                
                Toggle("แสดงการแจ้งเตือนเมื่อเล่นเพลงใหม่", isOn: $showNotifications)
                    .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                    .font(.headline)
                    .foregroundStyle(Color.primary.opacity(0.92))
            }

            Section(
                header: Text("ประวัติการแก้ไขเพลง").foregroundStyle(Color.primary.opacity(0.8)),
                footer: Text("สำรองหรือกู้คืนข้อมูลการแก้ไขชื่อเพลง ศิลปิน และอัลบั้ม").foregroundStyle(Color.primary.opacity(0.7))
            ) {
                Button("ส่งออกประวัติการแก้ไข") {
                    viewModel.exportEditHistory()
                }
                .glassButton()

                Button("นำเข้าประวัติการแก้ไข") {
                    viewModel.importEditHistory()
                }
                .glassButton()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
