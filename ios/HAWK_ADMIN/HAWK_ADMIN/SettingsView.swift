import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appConfig: AppConfig
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    Toggle("Enable target alerts", isOn: Binding(
                        get: { appConfig.notificationsEnabled },
                        set: { newValue in
                            Task {
                                await appConfig.setNotificationsEnabled(newValue)
                            }
                        }
                    ))
                    Text("Permission status: \(appConfig.notificationAuthorizationStatus)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Request Permission Again") {
                        Task {
                            _ = await appConfig.requestNotificationAuthorization()
                        }
                    }
                }

                Section("Data") {
                    Text("Tracked products are synced with HAWK_ADMIN backend.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Delete All Products", role: .destructive) {
                        confirmDeleteAll = true
                    }
                }

            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete all products?", isPresented: $confirmDeleteAll) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    appConfig.clearAllItems()
                }
            } message: {
                Text("This removes all tracked products from your account.")
            }
        }
    }
}
