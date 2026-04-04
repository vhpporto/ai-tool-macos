import SwiftUI

struct InlineSettingsView: View {

    @State private var apiKey = ""
    @State private var keyStatus: KeyStatus = .checking
    @State private var selectedModel: String = UserDefaults.standard.string(forKey: "aura_selected_model") ?? "gpt-4o"
    @State private var customEndpoint: String = UserDefaults.standard.string(forKey: "aura_custom_endpoint") ?? ""
    @State private var endpointSaved = false
    var onDone: () -> Void

    enum KeyStatus { case checking, configured, missing }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Header
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button(action: onDone) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close settings")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            VStack(alignment: .leading, spacing: 20) {

                // MARK: API Key
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        SecureField("sk-...", text: $apiKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.09), lineWidth: 0.8))

                    HStack {
                        statusBadge
                        Spacer()
                        saveButton
                    }
                }

                Divider()

                // MARK: Custom Endpoint
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Endpoint")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Image(systemName: "network")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        TextField("http://localhost:11434/v1/chat/completions", text: $customEndpoint)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.primary)
                            .onSubmit { saveEndpoint() }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.09), lineWidth: 0.8))

                    if let endpointError {
                        Text(endpointError)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.auraError)
                    }

                    HStack {
                        Text("Leave blank for OpenAI. Works with Ollama, LM Studio, etc.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button {
                            saveEndpoint()
                        } label: {
                            Text(endpointSaved ? "Saved" : "Save")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(endpointSaved ? Color.auraSuccess : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(endpointSaved ? Color.auraSuccess.opacity(0.15) : Color.auraAccent.opacity(0.85))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                // MARK: Model
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 4) {
                        ForEach(ConversationStore.availableModels, id: \.self) { model in
                            modelRow(model)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .onAppear {
            keyStatus = KeychainHelper.read(key: "openai_api_key") != nil ? .configured : .missing
            customEndpoint = UserDefaults.standard.string(forKey: "aura_custom_endpoint") ?? ""
        }
    }

    @State private var endpointError: String?

    private func saveEndpoint() {
        let trimmed = customEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  url.host != nil else {
                endpointError = "Invalid URL. Must start with http:// or https://"
                return
            }
        }

        endpointError = nil
        UserDefaults.standard.set(trimmed, forKey: "aura_custom_endpoint")
        withAnimation(.easeInOut(duration: 0.15)) { endpointSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.15)) { endpointSaved = false }
        }
    }

    // MARK: - Save button

    private var saveButton: some View {
        let isEmpty = apiKey.isEmpty
        return Button {
            guard !isEmpty else { return }
            if KeychainHelper.save(key: "openai_api_key", value: apiKey) {
                keyStatus = .configured
                apiKey = ""
            }
        } label: {
            Text("Save Key")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isEmpty ? Color.secondary : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(isEmpty ? Color.primary.opacity(0.06) : Color.auraAccent.opacity(0.85))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
    }

    // MARK: - Model row

    private func modelRow(_ model: String) -> some View {
        let isSelected = selectedModel == model
        return Button {
            selectedModel = model
            UserDefaults.standard.set(model, forKey: "aura_selected_model")
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.auraAccent : Color.secondary.opacity(0.4))

                VStack(alignment: .leading, spacing: 2) {
                    Text(model)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    Text(modelDescription(model))
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? Color.auraAccent.opacity(0.08) : Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.auraAccent.opacity(0.25) : Color.primary.opacity(0.07), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(model): \(modelDescription(model))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func modelDescription(_ model: String) -> String {
        switch model {
        case "gpt-4o":      return "Most capable · Best for complex tasks"
        case "gpt-4o-mini": return "Fast & cheap · Great for quick questions"
        case "gpt-4-turbo": return "Balanced · Large context window"
        default: return ""
        }
    }

    // MARK: - Status badge

    @ViewBuilder
    private var statusBadge: some View {
        switch keyStatus {
        case .checking:
            EmptyView()
        case .configured:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                Text("Key configured")
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.auraSuccess)
        case .missing:
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Not configured")
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.auraError)
        }
    }
}
