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
                        HStack(alignment: .center, spacing: 8) {
                            stayDate("Check-in", date: person.checkIn)
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .frame(width: 18)
                            stayDate("Current check-out", date: person.checkOut)
                        }
                        .padding(.vertical, 12)
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
                        .disabled(isSubmitting)
                        Label(rangeHint, systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
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
                Text(confirmationMessage)
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

    /// The same date is allowed on purpose: resending it changes nothing and lets the
    /// host check the request against the portal without touching the stay.
    private var rangeHint: String {
        String.localizedStringWithFormat(
            String(localized: "Choose a new check-out within the stay, from the check-in day (%@) onward."),
            RegisterText.date(earliest))
    }

    /// "Removes 2 days from ANA's original check-out (Nov 24, 2026). New check-out: Nov 22, 2026."
    private var confirmationMessage: String {
        let newDate = RegisterText.date(checkOut)
        guard let current = person.checkOut else {
            return String.localizedStringWithFormat(
                String(localized: "%1$@ will leave on %2$@."), displayName, newDate)
        }
        let calendar = PortalDates.calendar
        let days =
            calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: current), to: calendar.startOfDay(for: checkOut)
            ).day ?? 0
        let original = RegisterText.date(current)
        if days == 0 {
            return String.localizedStringWithFormat(
                String(localized: "%1$@ keeps the original check-out (%2$@)."), displayName, original)
        }
        let format: String
        switch days {
        case ..<(-1): format = String(localized: "Removes %1$lld days from %2$@'s original check-out (%3$@). New check-out: %4$@.")
        case -1: format = String(localized: "Removes %1$lld day from %2$@'s original check-out (%3$@). New check-out: %4$@.")
        case 1: format = String(localized: "Adds %1$lld day to %2$@'s original check-out (%3$@). New check-out: %4$@.")
        default: format = String(localized: "Adds %1$lld days to %2$@'s original check-out (%3$@). New check-out: %4$@.")
        }
        return String.localizedStringWithFormat(format, abs(days), displayName, original, newDate)
    }

    /// Same look as the dates of a row in Guests: title above, date below.
    private func stayDate(_ title: LocalizedStringKey, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(date.map(RegisterText.date) ?? "—")
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(date == nil ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
