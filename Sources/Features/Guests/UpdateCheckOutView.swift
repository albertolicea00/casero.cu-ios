import SwiftUI

/// Changes the check-out date of an active guest or companion, as the portal's
/// active-guests page does (`ActualizarFechaSalidaHuesped` /
/// `ActualizarFechaSalidaAcompannante`). The new date can't be before the
/// person's own check-in.
struct UpdateCheckOutView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let person: Guest
    let client: CaseroClient
    /// `nil` for the main guest; the companion's `Id` otherwise.
    var companionId: String? = nil
    let onUpdated: (Date) -> Void

    @State private var checkOut = Date()
    @State private var isConfirming = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "%@ · Stay ID %@"), displayName, person.stayId)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                    InputCard {
                        row("Check-in", value: person.checkIn.map(RegisterText.date) ?? "—")
                        Divider()
                        row("Current check-out", value: person.checkOut.map(RegisterText.date) ?? "—")
                        Divider()
                        HStack {
                            Text("New check-out")
                            Spacer(minLength: 8)
                            DatePicker("New check-out", selection: $checkOut, in: earliest..., displayedComponents: .date)
                                .labelsHidden()
                                .fixedSize()
                        }
                        .padding(.vertical, 8)
                        .disabled(successMessage != nil)
                        if let checkIn = person.checkIn {
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
                    }
                    Label("Check-out can't be before the check-in date.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    if let successMessage {
                        Label(successMessage, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            isConfirming = true
                        } label: {
                            Group {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Update check-out")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(isSubmitting || isUnchanged)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Update check-out")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(successMessage == nil ? "Cancel" : "Done") { dismiss() }
                        .disabled(isSubmitting)
                }
            }
            .alert("Update check-out?", isPresented: $isConfirming) {
                Button("Cancel", role: .cancel) {}
                Button("Update") { Task { await submit() } }
            } message: {
                Text(verbatim: "\(displayName)\n\(RegisterText.date(checkOut))")
            }
        }
        .interactiveDismissDisabled(isSubmitting)
        .onAppear { checkOut = max(person.checkOut ?? earliest, earliest) }
    }

    private var displayName: String {
        person.fullName.split(whereSeparator: { $0 == "*" || $0.isWhitespace }).joined(separator: " ")
    }

    /// Portal rule: the new check-out can be as early as the person's check-in day.
    private var earliest: Date {
        PortalDates.calendar.startOfDay(for: person.checkIn ?? .now)
    }

    private var isUnchanged: Bool {
        guard let current = person.checkOut else { return false }
        return PortalDates.calendar.isDate(current, inSameDayAs: checkOut)
    }

    private func row(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Text(value).foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let message = try await client.updateCheckOut(
                stayId: person.stayId, companionId: companionId, to: checkOut)
            successMessage = message.isEmpty ? String(localized: "Check-out updated.") : message
            onUpdated(checkOut)
        } catch PortalError.sessionExpired {
            await appState.reportSessionExpired()
        } catch {
            errorMessage = (error as? PortalError)?.errorDescription ?? error.localizedDescription
        }
    }
}
