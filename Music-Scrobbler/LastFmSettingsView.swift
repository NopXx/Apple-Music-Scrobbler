
import SwiftUI

struct LastFmSettingsView: View {
    @EnvironmentObject private var viewModel: StatusViewModel

    var body: some View {
        Form {
            Section(header: Text("Last.fm").foregroundStyle(Color.white.opacity(0.8))) {
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
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
