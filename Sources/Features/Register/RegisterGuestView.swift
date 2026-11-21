import SwiftUI

struct RegisterGuestView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RegisterGuestViewModel

    init(client: CaseroClient) {
        _viewModel = StateObject(wrappedValue: RegisterGuestViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Look up by", selection: $viewModel.lookupKind) {
                        ForEach(RegisterGuestViewModel.LookupKind.allCases) { kind in
                            Text(LocalizedStringKey(kind.segmentLabel)).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    Group {
                        if viewModel.lookupKind == .foreignGuestByName {
                            TextField("First name", text: $viewModel.firstName)
                            TextField("First surname", text: $viewModel.lastName1)
                            TextField("Second surname", text: $viewModel.lastName2)
                        } else {
                            TextField(
                                LocalizedStringKey(viewModel.lookupKind.fieldLabel),
                                text: $viewModel.identificador,
                            )
                            .keyboardType(viewModel.lookupKind == .cubanCompanion ? .numberPad : .default)
                        }
                    }
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                } footer: {
                    // Lives in the footer so the Form row clipping doesn't reshape its corners.
                    VStack(alignment: .leading, spacing: 16) {
                        Text(LocalizedStringKey(viewModel.lookupKind.help))

                        VStack(spacing: 8) {
                            Button {
                                Task { await viewModel.lookUp() }
                            } label: {
                                Group {
                                    if viewModel.isLookingUp {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Look up")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryActionButtonStyle())
                            .disabled(!viewModel.canLookUp)

                            if !viewModel.canLookUp && !viewModel.isLookingUp {
                                Label("Fill in the fields above to look up.", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !viewModel.candidates.isEmpty {
                    Section("Matches") {
                        ForEach(Array(viewModel.candidates.enumerated()), id: \.offset) { _, person in
                            Button { viewModel.select(person) } label: {
                                VStack(alignment: .leading) {
                                    Text(person.fullName).font(.headline)
                                    Text(
                                        [person.identificador, person.nationality ?? ""].filter { !$0.isEmpty }
                                            .joined(separator: " · ")
                                    )
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let person = viewModel.foundPerson {
                    Section("Found") {
                        Text(person.fullName).font(.headline)
                        if let nationality = person.nationality {
                            Text(nationality).font(.subheadline).foregroundStyle(.secondary)
                        }
                        DatePicker("Check-in", selection: $viewModel.checkIn, displayedComponents: .date)
                        DatePicker("Check-out", selection: $viewModel.checkOut, displayedComponents: .date)
                        if let message = viewModel.validationMessage {
                            Text(message).foregroundStyle(.red)
                        }
                        Button("Add to registration") { viewModel.addToQueue() }
                            .disabled(!viewModel.canAdd)
                    }
                }

                if !viewModel.queue.isEmpty {
                    Section("Ready to register (\(viewModel.queue.count))") {
                        ForEach(Array(viewModel.queue.enumerated()), id: \.offset) { _, entry in
                            Text(
                                "\(entry.firstName) \(entry.lastName1) \(entry.lastName2)".trimmingCharacters(
                                    in: .whitespaces))
                        }
                        .onDelete { viewModel.removeFromQueue($0) }

                        if let message = viewModel.submitBlockedMessage {
                            Text(message).foregroundStyle(.red)
                        }

                        Button {
                            Task { await viewModel.submit() }
                        } label: {
                            if viewModel.isSubmitting {
                                ProgressView()
                            } else {
                                Text("Register people")
                            }
                        }
                        .disabled(!viewModel.canSubmit)
                    }
                }

                if let results = viewModel.lastSubmission {
                    Section("Last result") {
                        ForEach(results) { guest in
                            VStack(alignment: .leading) {
                                Label(
                                    Self.displayName(guest.fullName),
                                    systemImage: guest.response == "OK" ? "checkmark.circle.fill" : "xmark.circle.fill"
                                )
                                .foregroundStyle(guest.response == "OK" ? .green : .red)
                                Text(guest.response ?? String(localized: "Unconfirmed")).font(.caption)
                            }
                        }
                    }
                }

                Section {
                    Link("Complete in official portal", destination: CaseroClient.baseURL.appendingPathComponent("Huespedes"))
                        .listRowBackground(Color.clear)
                }
                if let message = viewModel.errorMessage {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Register guest")
        }
        .onChange(of: viewModel.lookupKind) { _ in viewModel.clearLookup() }
        .onChange(of: viewModel.lookupQuery) { _ in viewModel.clearLookup() }
        .onChange(of: viewModel.isSessionExpired) { expired in
            guard expired else { return }
            Task {
                await appState.reportSessionExpired()
                viewModel.acknowledgeSessionExpired()
            }
        }
    }

    /// `RegistrarHuesped` echoes the wire name (`NOMBRE**APELLIDO1*APELLIDO2`) as `Biografico`.
    private static func displayName(_ wireName: String) -> String {
        wireName.split(whereSeparator: { $0 == "*" || $0 == " " }).joined(separator: " ")
    }
}
