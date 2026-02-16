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

                Section("Event Log") {
                    if appConfig.eventLogs.isEmpty {
                        Text("No events yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appConfig.eventLogs) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.message)
                                    .font(.subheadline)
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Button("Clear Event Log", role: .destructive) {
                        appConfig.clearEventLogs()
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
