import SwiftUI

struct RegisterGuestView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RegisterGuestViewModel

    init(client: CaseroClient) {
        _viewModel = StateObject(wrappedValue: RegisterGuestViewModel(client: client))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Look up each person, set the stay dates and add them to the registration. Tap Register people to submit them to the official portal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    Link(destination: CaseroClient.baseURL.appendingPathComponent("Huespedes")) {
                        Label("Complete in official portal", systemImage: "safari")
                    }
                    .padding(.horizontal, 4)

                    Picker("Look up by", selection: $viewModel.lookupKind) {
                        ForEach(RegisterGuestViewModel.LookupKind.allCases) { kind in
                            Text(LocalizedStringKey(kind.segmentLabel)).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    lookupInputCard
                    lookUpButton

                    if !viewModel.candidates.isEmpty {
                        matchesSection
                    }

                    if let person = viewModel.foundPerson {
                        foundSection(person)
                    }

                    if !viewModel.queue.isEmpty {
                        queueSection
                    }

                    if let results = viewModel.lastSubmission {
                        lastResultSection(results)
                    }

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
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

    private var lookupInputCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            InputCard {
                Group {
                    if viewModel.lookupKind == .foreignGuestByName {
                        TextField("First name", text: $viewModel.firstName)
                            .padding(.vertical, 12)
                        Divider()
                        TextField("First surname", text: $viewModel.lastName1)
                            .padding(.vertical, 12)
                        Divider()
                        TextField("Second surname", text: $viewModel.lastName2)
                            .padding(.vertical, 12)
                    } else {
                        TextField(
                            LocalizedStringKey(viewModel.lookupKind.fieldLabel),
                            text: $viewModel.identificador,
                        )
                        .keyboardType(viewModel.lookupKind == .cubanCompanion ? .numberPad : .default)
                        .padding(.vertical, 12)
                    }
                }
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            }
            Label(LocalizedStringKey(viewModel.lookupKind.help), systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var lookUpButton: some View {
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

    private var matchesSection: some View {
        section("Matches") {
            InputCard {
                ForEach(Array(viewModel.candidates.enumerated()), id: \.offset) { index, person in
                    if index > 0 { Divider() }
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func foundSection(_ person: PersonaValidation) -> some View {
        section("Found") {
            InputCard {
                VStack(alignment: .leading) {
                    Text(person.fullName).font(.headline)
                    if let nationality = person.nationality {
                        Text(nationality).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 12)
                Divider()
                DatePicker("Check-in", selection: $viewModel.checkIn, displayedComponents: .date)
                    .padding(.vertical, 8)
                Divider()
                DatePicker("Check-out", selection: $viewModel.checkOut, displayedComponents: .date)
                    .padding(.vertical, 8)
            }
            if let message = viewModel.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
            Button {
                viewModel.addToQueue()
            } label: {
                Text("Add to registration").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!viewModel.canAdd)
        }
    }

    private var queueSection: some View {
        section("Ready to register (\(viewModel.queue.count))") {
            InputCard {
                ForEach(Array(viewModel.queue.enumerated()), id: \.offset) { index, entry in
                    if index > 0 { Divider() }
                    HStack {
                        Text(
                            "\(entry.firstName) \(entry.lastName1) \(entry.lastName2)".trimmingCharacters(
                                in: .whitespaces))
                        Spacer()
                        Button {
                            viewModel.removeFromQueue(IndexSet(integer: index))
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSubmitting)
                        .accessibilityLabel("Remove")
                    }
                    .padding(.vertical, 12)
                }
            }
            if let message = viewModel.submitBlockedMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
            Button {
                Task { await viewModel.submit() }
            } label: {
                Group {
                    if viewModel.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Register people")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(!viewModel.canSubmit)
        }
    }

    private func lastResultSection(_ results: [Guest]) -> some View {
        section("Last result") {
            InputCard {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, guest in
                    if index > 0 { Divider() }
                    VStack(alignment: .leading) {
                        Label(
                            Self.displayName(guest.fullName),
                            systemImage: guest.response == "OK" ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundStyle(guest.response == "OK" ? .green : .red)
                        Text(guest.response ?? String(localized: "Unconfirmed")).font(.caption)
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    /// Headline + content block, matching the SMS confirmation section.
    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
    }

    /// `RegistrarHuesped` echoes the wire name (`NOMBRE**APELLIDO1*APELLIDO2`) as `Biografico`.
    private static func displayName(_ wireName: String) -> String {
        wireName.split(whereSeparator: { $0 == "*" || $0 == " " }).joined(separator: " ")
    }
}
