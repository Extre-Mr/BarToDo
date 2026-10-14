import SwiftUI

struct SettingsView: View {
    @AppStorage("alwaysOnTop") private var alwaysOnTop = false

    var body: some View {
        Form {
            Toggle("Always on Top", isOn: $alwaysOnTop)
                .accessibilityHint("Keeps the Compact Flow window above other windows")
        }
        .padding(24)
        .frame(width: 320)
    }
}
