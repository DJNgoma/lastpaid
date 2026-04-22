import SwiftUI

struct SettingsView: View {
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var didReset = false

    private var settingsURL: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Currency", value: "ZAR")
            }

            Section {
                Button {
                    if let url = settingsURL {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                }
            } footer: {
                Text("Manage camera and location permissions for Last Paid in iOS Settings.")
            }

            Section {
                Button {
                    Haptics.medium()
                    didCompleteOnboarding = false
                    withAnimation { didReset = true }
                } label: {
                    Label("Show Welcome Walkthrough Again", systemImage: "arrow.counterclockwise.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            } header: {
                Text("Help")
            } footer: {
                if didReset {
                    Text("The welcome walkthrough will appear the next time you return to the home screen.")
                        .foregroundStyle(.green)
                } else {
                    Text("Use this if you want to revisit how scanning, saving places, and quick price recall work.")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
