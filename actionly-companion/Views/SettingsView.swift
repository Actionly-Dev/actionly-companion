//
//  SettingsView.swift
//  actionly-companion
//
//  Created by Kevin Gruber on 16/01/26.
//

import SwiftUI

struct SettingsView: View {
    let settings = SettingsManager.shared
    @State private var tempApiToken: String = ""
    @State private var showTokenSaved: Bool = false

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings, tempApiToken: $tempApiToken, showTokenSaved: $showTokenSaved)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ExecutionSettingsView(settings: settings)
                .tabItem {
                    Label("Execution", systemImage: "play.circle")
                }
        }
        .frame(width: 500, height: 380)
        .onAppear {
            tempApiToken = settings.apiToken
        }
    }
}

struct GeneralSettingsView: View {
    @Bindable var settings: SettingsManager
    @Binding var tempApiToken: String
    @Binding var showTokenSaved: Bool

    var body: some View {
        Form {
            Section {
                // AI Model Selection
                Picker("AI Model:", selection: $settings.selectedModel) {
                    ForEach(AIModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Provider:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(settings.selectedModel.provider.rawValue)
                        .foregroundColor(.primary)
                }
            } header: {
                Text("AI Configuration")
            }

            Section {
                // API Token (Secure)
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("Enter your API token", text: $tempApiToken)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Save Token") {
                            settings.apiToken = tempApiToken
                            withAnimation {
                                showTokenSaved = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showTokenSaved = false
                                }
                            }
                        }
                        .disabled(tempApiToken.isEmpty)

                        if !settings.apiToken.isEmpty {
                            Button("Clear Token") {
                                tempApiToken = ""
                                settings.apiToken = ""
                            }
                            .foregroundColor(.red)
                        }

                        Spacer()

                        if showTokenSaved {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Saved")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                            .transition(.opacity)
                        }
                    }

                    Text("Your API token is stored securely in the macOS Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("API Authentication")
            } footer: {
                Text("Get your Google AI API key from https://aistudio.google.com/app/apikey")
                    .font(.caption)
            }

            Section {
                HStack {
                    Image(systemName: settings.hasValidSettings ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(settings.hasValidSettings ? .green : .red)
                    Text(settings.hasValidSettings ? "API configured" : "API token required")
                        .font(.caption)
                }
            } header: {
                Text("Status")
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

struct ExecutionSettingsView: View {
    @Bindable var settings: SettingsManager

    var body: some View {
        Form {
            Section {
                Picker("Execution Speed:", selection: $settings.executionSpeed) {
                    ForEach(ExecutionSpeed.allCases) { speed in
                        Text(speed.displayName).tag(speed)
                    }
                }
                .pickerStyle(.menu)

                Text(settings.executionSpeed.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Action Timing")
            } footer: {
                Text("Slower speeds are more reliable for multi-application workflows. Use faster speeds only if you experience no issues.")
                    .font(.caption)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "keyboard")
                            .foregroundColor(.blue)
                        Text("Press ESC during execution to stop")
                    }

                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.orange)
                        Text("Multi-app workflows switch apps automatically")
                    }

                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.green)
                        Text("Delays between actions prevent race conditions")
                    }
                }
                .font(.caption)
            } header: {
                Text("Execution Tips")
            }

            Section {
                let execSettings = settings.executionSettings
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Action delay:")
                        Spacer()
                        Text("\(execSettings.actionDelayMs)ms")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("App switch delay:")
                        Spacer()
                        Text("\(execSettings.appSwitchDelayMs)ms")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
            } header: {
                Text("Current Timing Values")
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

#Preview {
    SettingsView()
}
