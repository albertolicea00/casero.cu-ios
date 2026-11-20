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
                Section("Look up") {
                    Picker("Type", selection: $viewModel.lookupKind) {
                        ForEach(RegisterGuestViewModel.LookupKind.allCases) { kind in
                            Text(LocalizedStringKey(kind.rawValue)).tag(kind)
                        }
                    }
                    TextField(
                        LocalizedStringKey(
                            viewModel.lookupKind == .foreignGuest ? "Passport number" : "Carné de identidad"),
                        text: $viewModel.identificador,
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                    Button {
                        Task { await viewModel.lookUp() }
                    } label: {
                        if viewModel.isLookingUp {
                            ProgressView()
                        } else {
                            Text("Look up")
                        }
                    }
                    .disabled(!viewModel.canLookUp)
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
                                    guest.fullName,
                                    systemImage: guest.response == "OK" ? "checkmark.circle.fill" : "xmark.circle.fill"
                                )
                                .foregroundStyle(guest.response == "OK" ? .green : .red)
                                Text(guest.response ?? String(localized: "Unconfirmed")).font(.caption)
                            }
                        }
                    }
                }

                Section {
                    NavigationLink("Complete in official portal") {
                        PortalPageView(path: "Huespedes", title: "Register guest")
                    }
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
        .onChange(of: viewModel.identificador) { _ in viewModel.clearLookup() }
        .onChange(of: viewModel.isSessionExpired) { expired in
            guard expired else { return }
            Task {
                await appState.reportSessionExpired()
                viewModel.acknowledgeSessionExpired()
            }
        }
    }
}
