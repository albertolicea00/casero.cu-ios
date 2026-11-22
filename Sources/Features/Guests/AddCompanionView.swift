import SwiftUI

/// Adds a Cuban companion (found by CI) to an active stay, as the portal's
/// active-guests page does: CI lookup, stay dates, confirmation, then
/// `RegistrarAcompannantes` with the guest's stay ID.
struct AddCompanionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let guest: Guest
    let client: CaseroClient
    /// CIs already in this stay, to avoid adding someone twice.
    let existingIDs: Set<String>
    let onAdded: () -> Void

    @State private var carne = ""
    @State private var person: PersonaValidation?
    @State private var photo: UIImage?
    @State private var checkIn = Date()
    @State private var checkOut = Date()
    @State private var isLookingUp = false
    @State private var isSubmitting = false
    @State private var lookupError: String?
    @State private var submitError: String?
    @State private var isConfirming = false
    @State private var result: [Guest]?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "Companion of %@ · Stay ID %@"),
                            guest.fullName, guest.stayId)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                    if let result {
                        resultSection(result)
                    } else {
                        lookupSection
                        if let person { personSection(person) }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add companion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(result == nil ? "Cancel" : "Done") { dismiss() }
                        .disabled(isSubmitting)
                }
            }
            .alert("Add companion?", isPresented: $isConfirming, presenting: person) { person in
                Button("Cancel", role: .cancel) {}
                Button("Add") { Task { await submit(person) } }
            } message: { person in
                Text(
                    verbatim:
                        "\(person.fullName)\n\(person.identificador) · \(RegisterText.stay(from: checkIn, to: checkOut))"
                )
            }
        }
        .interactiveDismissDisabled(isSubmitting)
        .onAppear {
            // Default stay: from today (never before the guest's check-in) to the guest's check-out.
            checkIn = max(PortalDates.calendar.startOfDay(for: .now), earliestCheckIn)
            checkOut = max(guest.checkOut ?? checkIn, checkIn)
        }
    }

    // MARK: - Lookup

    private var lookupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InputCard {
                TextField("Carné de identidad", text: $carne)
                    .keyboardType(.numberPad)
                    .padding(.vertical, 12)
            }
            Label("This search option is only valid for Cuban nationals.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            Button {
                Task { await lookUp() }
            } label: {
                Group {
                    if isLookingUp {
                        ProgressView().tint(.white)
                    } else {
                        Text("Look up")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(trimmedCarne.isEmpty || isLookingUp || isSubmitting)
            if let lookupError {
                Label(lookupError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: carne) { _ in
            person = nil
            photo = nil
            lookupError = nil
            submitError = nil
        }
    }

    private var trimmedCarne: String { carne.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func lookUp() async {
        let query = trimmedCarne
        isLookingUp = true
        lookupError = nil
        person = nil
        photo = nil
        defer { isLookingUp = false }
        do {
            let people = try await client.validateCompanionForStay(identificador: query)
            guard query == trimmedCarne else { return }
            guard let found = people.first else {
                lookupError = String(localized: "Person not found.")
                return
            }
            person = found
            if let data = try? await client.fetchCompanionPhoto(carne: found.identificador) {
                photo = UIImage(data: data)
            }
        } catch PortalError.sessionExpired {
            await appState.reportSessionExpired()
        } catch {
            lookupError = (error as? PortalError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Person and stay

    /// Check-in can go back at most 7 days and never before the guest's own check-in.
    private var earliestCheckIn: Date {
        let limit = RegisterGuestViewModel.earliestCheckIn()
        guard let guestCheckIn = guest.checkIn else { return limit }
        return max(limit, PortalDates.calendar.startOfDay(for: guestCheckIn))
    }

    private var validationMessage: String? {
        guard let person else { return nil }
        if let response = person.response, !response.isEmpty, response != "OK" { return response }
        let fields = [person.fullName, person.identificador, person.nationalityCode ?? "", person.sex ?? ""]
        if fields.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            || person.birthDate == nil
        {
            return String(
                localized:
                    "The portal returned incomplete personal data. Use the official portal to complete this registration."
            )
        }
        if fields.contains(where: { $0.contains(where: { ",|\n\r".contains($0) }) }) {
            return String(localized: "Personal data contains unsupported characters. Use the official portal.")
        }
        if existingIDs.contains(person.identificador.uppercased()) {
            return String(localized: "This person is already a companion in this stay.")
        }
        if checkOut < checkIn { return String(localized: "Check-out must be on or after check-in.") }
        if PortalDates.calendar.startOfDay(for: checkIn) < earliestCheckIn {
            return String(localized: "Check-in can be at most 7 days ago.")
        }
        return nil
    }

    private func personSection(_ person: PersonaValidation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            InputCard {
                PersonDetails(
                    name: person.fullName,
                    identificador: person.identificador,
                    nationality: person.nationality,
                    birthDate: person.birthDate,
                    photo: photo
                )
            }
            Text("Stay details")
                .font(.headline)
                .padding(.top, 4)
            InputCard {
                datePicker("Check-in", selection: $checkIn, in: earliestCheckIn...)
                Divider()
                datePicker("Check-out", selection: $checkOut, in: checkIn...)
                Divider()
                Label(
                    String.localizedStringWithFormat(
                        String(localized: "Stay: %@"), GuestStayText.nights(from: checkIn, to: checkOut)),
                    systemImage: "moon.stars"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
            }
            if let message = validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
            Button {
                isConfirming = true
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Add companion")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(validationMessage != nil || isSubmitting)
            if let submitError {
                Label(submitError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func datePicker(_ title: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeFrom<Date>)
        -> some View
    {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            DatePicker(title, selection: selection, in: range, displayedComponents: .date)
                .labelsHidden()
                .fixedSize()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Submit and result

    private func submit(_ person: PersonaValidation) async {
        guard validationMessage == nil, let birthDate = person.birthDate else { return }
        isSubmitting = true
        submitError = nil
        defer { isSubmitting = false }
        let entry = CompanionRegistration(
            fullName: person.fullName, identificador: person.identificador,
            nationalityCode: person.nationalityCode ?? "", sex: person.sex ?? "",
            birthDate: birthDate, checkIn: checkIn, checkOut: checkOut)
        do {
            let answer = try await client.addCompanions([entry], toStay: guest.stayId)
            result = answer
            if answer.contains(where: { $0.response == "OK" }) { onAdded() }
        } catch PortalError.sessionExpired {
            await appState.reportSessionExpired()
        } catch {
            submitError = (error as? PortalError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func resultSection(_ answer: [Guest]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(answer.enumerated()), id: \.offset) { _, item in
                let accepted = item.response == "OK"
                InputCard {
                    Label(
                        accepted ? String(localized: "Registered") : (item.response ?? String(localized: "Unconfirmed")),
                        systemImage: accepted ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accepted ? .green : .red)
                    .padding(.top, 12)
                    PersonDetails(
                        name: item.fullName, identificador: item.identificador,
                        nationality: person?.nationality, birthDate: item.birthDate, photo: photo)
                    Divider()
                    HStack {
                        fact("Stay ID", value: item.stayId)
                        Spacer(minLength: 8)
                        if let id = item.companionId { fact("ID", value: id) }
                    }
                    .font(.subheadline)
                    .padding(.vertical, 10)
                    if let checkIn = item.checkIn, let checkOut = item.checkOut {
                        Divider()
                        Label(RegisterText.stay(from: checkIn, to: checkOut), systemImage: "moon.stars")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private func fact(_ title: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 3) {
            Text(title).foregroundStyle(.secondary)
            Text(":").foregroundStyle(.secondary)
            Text(value).fontWeight(.bold).textSelection(.enabled)
        }
    }
}
