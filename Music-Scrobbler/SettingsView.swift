import SwiftUI

// Enum เพื่อระบุหน้าการตั้งค่าแต่ละหน้า
private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "ทั่วไป"
    case lastfm = "Last.fm"
    
    var id: String { self.rawValue }
    
    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .general:
            GeneralSettingsView()
        case .lastfm:
            LastFmSettingsView()
        }
    }
    
    var icon: String {
        switch self {
        case .general:
            return "gearshape"
        case .lastfm:
            return "music.note.list"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var viewModel: StatusViewModel
    @State private var selection: SettingsCategory? = .general

    var body: some View {
        ZStack {
            // --- Background --- 
            LinearGradient(
                gradient: Gradient(colors: viewModel.artworkGradient),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // --- Main Content --- 
            NavigationView {
                // --- Sidebar --- 
                List(selection: $selection) {
                    ForEach(SettingsCategory.allCases) { category in
                        NavigationLink(tag: category, selection: $selection) {
                            category.destinationView
                        } label: {
                            SidebarLabelView(category: category, isSelected: selection == category)
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden) // ทำให้ List โปร่งใส
                
                // --- Detail View (จะแสดง view แรกใน list โดยอัตโนมัติ) ---
                Text("เลือกหมวดหมู่จากด้านซ้าย")
                    .foregroundStyle(.white)
            }
            .background(Color.clear) // ทำให้ NavigationView โปร่งใส
        }
        .animation(.spring(), value: viewModel.artworkGradient)
        .frame(minWidth: 680, idealWidth: 680, maxWidth: .infinity, minHeight: 450, idealHeight: 450, maxHeight: .infinity)
    }

    // Helper struct to simplify the NavigationLink label
    private struct SidebarLabelView: View {
        let category: SettingsCategory
        let isSelected: Bool

        var body: some View {
            Label(category.rawValue, systemImage: category.icon)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(StatusViewModel())
    }
}