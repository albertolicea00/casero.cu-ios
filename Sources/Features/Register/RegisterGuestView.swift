import SwiftUI

struct RegisterGuestView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RegisterGuestViewModel
    @State private var isInfoPresented = false
    /// Photos seen in the result sheet, reused on the queue cards.
    @State private var queuePhotos: [String: UIImage] = [:]
    /// Queue entry waiting for the remove confirmation.
    @State private var pendingRemoval: GuestRegistration?
    @State private var isConfirmingSubmit = false
    @State private var pdfFile: SavedPDF?
    private let client: CaseroClient

    init(client: CaseroClient) {
        self.client = client
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
                        if !viewModel.queue.isEmpty {
                            failureHelp(reason: message)
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Register guest")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isInfoPresented = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("Register guest information")
                }
            }
            .sheet(isPresented: $isInfoPresented) {
                SectionInfoSheet(
                    title: "Register guest",
                    summary:
                        "Look up guests and companions in the official registry, set their stay dates and submit them to the portal in one go.",
                    links: [.init(title: "Register guests in the portal", path: "Huespedes")]
                )
            }
            .sheet(item: $pdfFile) { file in
                ShareSheet(items: [file.url])
            }
            .sheet(isPresented: isShowingResult) {
                LookupResultSheet(
                    viewModel: viewModel,
                    loadPhoto: { await photo(for: $0) },
                    onAdded: { id, photo in queuePhotos[id] = photo }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
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
                        TextField("First name (only the first one)", text: $viewModel.firstName)
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
            if viewModel.lookupKind == .foreignGuestByName {
                // The portal matches on the first given name only; a second name finds nobody.
                Label(
                    "Try without the second given name. Example: JUAN · PEREZ · GOMEZ finds JUAN CARLOS PEREZ GOMEZ.",
                    systemImage: "lightbulb"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
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

            if let message = viewModel.lookupErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !viewModel.canLookUp && !viewModel.isLookingUp {
                Label("Fill in the fields above to look up.", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Lookup results open in a sheet; swiping it down cancels.
    private var isShowingResult: Binding<Bool> {
        Binding(
            get: { viewModel.isShowingResult },
            set: { if !$0 { viewModel.dismissResult() } }
        )
    }

    /// Same photo endpoints as Guests: Cuban nationals (CI lookup) by carné, everyone
    /// else through the foreign registry. A missing photo just keeps the initials.
    private func photo(for person: PersonaValidation) async -> UIImage? {
        let data: Data?
        if viewModel.lookupKind == .cubanCompanion {
            data = try? await client.fetchCompanionPhoto(carne: person.identificador)
        } else {
            data = try? await client.fetchForeignGuestPhoto(
                passport: person.identificador, name: person.fullName,
                nationalityCode: person.nationalityCode ?? "", sex: person.sex ?? "")
        }
        return data.flatMap(UIImage.init(data:))
    }

    private var queueSection: some View {
        section("Ready to register (\(viewModel.queue.count))") {
            ForEach(Array(viewModel.queue.enumerated()), id: \.offset) { _, entry in
                queueCard(entry)
            }
            if let message = viewModel.companionWarning {
                // Warning only, sending stays enabled: same yellow as the sign-in banner.
                Label {
                    Text(message).foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                .font(.caption.weight(.medium))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            }
            Button {
                isConfirmingSubmit = true
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
        .sheet(isPresented: $isConfirmingSubmit) {
            SubmitSummarySheet(
                entries: viewModel.queue,
                photos: queuePhotos,
                uncertainIDs: viewModel.uncertainIDs,
                onCancel: { isConfirmingSubmit = false },
                onConfirm: {
                    isConfirmingSubmit = false
                    Task {
                        if await viewModel.submit() { appState.guestsDidChange() }
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "Remove from registration?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            presenting: pendingRemoval
        ) { entry in
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { remove(entry) }
        } message: { entry in
            Text(
                [RegisterText.fullName(entry), NationalityFlag.emoji(for: entry.nationalityName)]
                    .compactMap { $0 }.joined(separator: " "))
        }
    }

    /// Same card as the result sheet plus the stay range; the trash asks first.
    private func queueCard(_ entry: GuestRegistration) -> some View {
        RegistrationCard(
            entry: entry,
            photo: queuePhotos[entry.identificador],
            isUncertain: viewModel.isUncertain(entry),
            onRemove: viewModel.isSubmitting ? nil : { pendingRemoval = entry }
        )
    }

    private func remove(_ entry: GuestRegistration) {
        guard let index = viewModel.queue.firstIndex(where: { $0.identificador == entry.identificador }) else { return }
        queuePhotos[entry.identificador] = nil
        viewModel.removeFromQueue(IndexSet(integer: index))
    }

    private func lastResultSection(_ results: [Guest]) -> some View {
        section("Last result") {
            ForEach(Array(results.enumerated()), id: \.offset) { _, guest in
                RegistrationResultCard(
                    guest: guest,
                    name: Self.displayName(guest.fullName),
                    photo: queuePhotos[guest.identificador]
                )
            }
            saveRecordButton {
                ExportService.registrationPDF(.submitted(results), photos: queuePhotos)
            }
        }
    }

    /// Shown when sending fails while people remain queued: what to do next and a
    /// PDF of the pending people with the error, to finish the report elsewhere.
    private func failureHelp(reason: String) -> some View {
        let uncertain = !viewModel.uncertainIDs.isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            Label(
                "If it keeps failing, report these people by SMS from the SMS tab, or save this PDF and take it to the nearest immigration office.",
                systemImage: "building.columns"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            saveRecordButton {
                ExportService.registrationPDF(
                    .failed(viewModel.queue, reason: reason, uncertain: uncertain), photos: queuePhotos)
            }
        }
    }

    private func saveRecordButton(_ makePDF: @escaping () -> Data) -> some View {
        Button {
            pdfFile = ExportService.writeRegistrationPDF(makePDF()).map(SavedPDF.init(url:))
        } label: {
            Label("Save PDF", systemImage: "arrow.down.doc")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
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

/// Guest-details style person block: photo, one-line name (tap it for the full
/// name when cut), document, then origin and birth date. Callers wrap it in an
/// `InputCard`; used in the result sheet and on the queue cards.
struct PersonDetails: View {
    let name: String
    let identificador: String
    let nationality: String?
    let birthDate: Date?
    let photo: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                GuestAvatar(name: name, photo: photo, size: 58)
                VStack(alignment: .leading, spacing: 7) {
                    GuestNameTooltip(name: name)
                        .font(.title3.weight(.semibold))
                        .zIndex(1)
                    Text("Passport/ID: \(identificador)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .zIndex(1)
            Divider()
            HStack {
                if let nationality {
                    fact("From (country)", value: [NationalityFlag.emoji(for: nationality), nationality]
                        .compactMap { $0 }.joined(separator: " "))
                }
                Spacer(minLength: 8)
                if let birthDate {
                    fact("Born", value: RegisterText.date(birthDate))
                }
            }
            .font(.caption)
            .padding(.vertical, 10)
        }
    }

    private func fact(_ title: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 3) {
            Text(title).foregroundStyle(.secondary)
            Text(":").foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.bold)
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }
}

/// A queued person: the same card as the result sheet plus the stay range. Shown
/// in Ready to register (with the trash) and in the review sheet (without it).
private struct RegistrationCard: View {
    let entry: GuestRegistration
    let photo: UIImage?
    /// Sent once without an answer: may already be registered.
    var isUncertain = false
    let onRemove: (() -> Void)?

    var body: some View {
        InputCard {
            if isUncertain {
                Label("Sent without confirmation. Check Guests before retrying.", systemImage: "questionmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.top, 12)
            }
            PersonDetails(
                name: RegisterText.fullName(entry),
                identificador: entry.identificador,
                nationality: entry.nationalityName,
                birthDate: entry.birthDate,
                photo: photo
            )
            .zIndex(1)
            Divider()
            HStack(spacing: 8) {
                Label(RegisterText.stay(from: entry.checkIn, to: entry.checkOut), systemImage: "moon.stars")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove")
                }
            }
            .padding(.vertical, 10)
        }
    }
}

/// One person of a `RegistrarHuesped` answer: status, the person card and the
/// stay ID the portal assigned (companions get `<guest stay>.1`, `.2`, …), which
/// can be copied.
private struct RegistrationResultCard: View {
    let guest: Guest
    let name: String
    let photo: UIImage?
    @State private var copied = false

    private var accepted: Bool { guest.response == "OK" }

    var body: some View {
        InputCard {
            Label(
                accepted ? String(localized: "Registered") : (guest.response ?? String(localized: "Unconfirmed")),
                systemImage: accepted ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(accepted ? .green : .red)
            .padding(.top, 12)
            PersonDetails(
                name: name,
                identificador: guest.identificador,
                nationality: guest.nationality,
                birthDate: guest.birthDate,
                photo: photo
            )
            .zIndex(1)
            if !guest.stayId.isEmpty {
                Divider()
                HStack(spacing: 3) {
                    Text("Stay ID").foregroundStyle(.secondary)
                    Text(":").foregroundStyle(.secondary)
                    Text(guest.stayId)
                        .font(.body.monospacedDigit().weight(.bold))
                        .textSelection(.enabled)
                    Spacer(minLength: 8)
                    Button {
                        UIPasteboard.general.string = guest.stayId
                        withAnimation { copied = true }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityLabel(copied ? "Copied" : "Copy stay ID")
                }
                .font(.subheadline)
                .padding(.vertical, 10)
                .task(id: copied) {
                    guard copied else { return }
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation { copied = false }
                }
            }
            if let checkIn = guest.checkIn, let checkOut = guest.checkOut {
                Divider()
                Label(RegisterText.stay(from: checkIn, to: checkOut), systemImage: "moon.stars")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
        }
    }
}

/// Display formatting shared by the Register cards and the submit summary.
enum RegisterText {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = PortalDates.timeZone
        return formatter
    }()

    static func date(_ date: Date) -> String { dateFormatter.string(from: date) }

    /// "Nov 21, 2026 → Nov 22, 2026 · 1 night"
    static func stay(from checkIn: Date, to checkOut: Date) -> String {
        "\(date(checkIn)) → \(date(checkOut)) · \(GuestStayText.nights(from: checkIn, to: checkOut))"
    }

    static func fullName(_ entry: GuestRegistration) -> String {
        "\(entry.firstName) \(entry.middleName) \(entry.lastName1) \(entry.lastName2)"
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

private struct SavedPDF: Identifiable {
    let url: URL
    var id: URL { url }
}

/// Last check before reporting: every person with document, origin and stay,
/// so the host reviews exactly what is about to reach the portal.
private struct SubmitSummarySheet: View {
    let entries: [GuestRegistration]
    let photos: [String: UIImage]
    var uncertainIDs: Set<String> = []
    @State private var pdfFile: SavedPDF?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(header)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        RegistrationCard(
                            entry: entry, photo: photos[entry.identificador], isUncertain: isUncertain(entry),
                            onRemove: nil)
                    }
                    Label(
                        "Check names, documents and dates. This app cannot undo a registration once the portal accepts it.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(action: onConfirm) {
                        Text(registerTitle).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    Button(action: savePDF) {
                        Label("Save PDF", systemImage: "arrow.down.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding()
                .background(.bar)
            }
            .sheet(item: $pdfFile) { file in
                ShareSheet(items: [file.url])
            }
            .navigationTitle("Review registration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    /// Writes the review as a PDF (file protection on, temp folder) and opens the
    /// share sheet so the host can keep it in Files, mail it, print it, etc.
    private func savePDF() {
        let data = ExportService.registrationPDF(.prepared(entries), photos: photos)
        pdfFile = ExportService.writeRegistrationPDF(data).map(SavedPDF.init(url:))
    }

    private func isUncertain(_ entry: GuestRegistration) -> Bool {
        uncertainIDs.contains(entry.identificador.uppercased())
    }

    private var header: String {
        entries.count == 1
            ? String(localized: "1 person will be reported to the official portal.")
            : String(localized: "\(entries.count) people will be reported to the official portal.")
    }

    private var registerTitle: String {
        entries.count == 1
            ? String(localized: "Register 1 person")
            : String(localized: "Register \(entries.count) people")
    }
}

/// Lookup results: the people on top (a single match is already active, several
/// are tapped to pick one) and, apart below, the stay dates and Add to registration.
private struct LookupResultSheet: View {
    @ObservedObject var viewModel: RegisterGuestViewModel
    let loadPhoto: (PersonaValidation) async -> UIImage?
    let onAdded: (String, UIImage?) -> Void
    @State private var photos: [String: UIImage] = [:]

    private var hasSeveral: Bool { viewModel.candidates.count > 1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if hasSeveral {
                        Text(String(localized: "\(viewModel.candidates.count) people match this search."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    ForEach(Array(viewModel.candidates.enumerated()), id: \.offset) { _, person in
                        personCard(person)
                    }
                    staySection
                }
                .padding()
            }
            .navigationTitle(hasSeveral ? "Choose person" : "Confirm person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.dismissResult() }
                }
            }
        }
    }

    private func isActive(_ person: PersonaValidation) -> Bool {
        guard let found = viewModel.foundPerson else { return false }
        return found.identificador == person.identificador && found.fullName == person.fullName
    }

    /// Tap anywhere on the card to make it the active person. The photo and the
    /// name keep their own taps (enlarge, full-name tooltip).
    private func personCard(_ person: PersonaValidation) -> some View {
        let active = isActive(person)
        return InputCard {
            PersonDetails(
                name: person.fullName,
                identificador: person.identificador,
                nationality: person.nationality,
                birthDate: person.birthDate,
                photo: photos[person.identificador]
            )
        }
        .task(id: person.identificador) {
            guard photos[person.identificador] == nil else { return }
            photos[person.identificador] = await loadPhoto(person)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.accentColor, lineWidth: active && hasSeveral ? 2 : 0)
        }
        .overlay(alignment: .topTrailing) {
            if hasSeveral {
                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(active ? Color.accentColor : Color.secondary)
                    .padding(10)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { viewModel.select(person) }
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    private var staySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stay details")
                .font(.headline)
                .padding(.top, 8)
            InputCard {
                stayDatePicker(
                    "Check-in", selection: $viewModel.checkIn,
                    in: RegisterGuestViewModel.earliestCheckIn()...)
                Divider()
                stayDatePicker("Check-out", selection: $viewModel.checkOut, in: viewModel.checkIn...)
                Divider()
                Label(
                    String.localizedStringWithFormat(
                        String(localized: "Stay: %@"),
                        GuestStayText.nights(from: viewModel.checkIn, to: viewModel.checkOut)),
                    systemImage: "moon.stars"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
            }
            if let message = viewModel.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 4)
            }
            VStack(spacing: 8) {
                Button {
                    guard let person = viewModel.foundPerson else { return }
                    let photo = photos[person.identificador]
                    viewModel.addToQueue()
                    onAdded(person.identificador, photo)
                } label: {
                    Text("Add to registration").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!viewModel.canAdd)
                if viewModel.foundPerson == nil {
                    Label("Select a person above to add them.", systemImage: "hand.tap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Label and compact picker on one row. `fixedSize` keeps the picker at its ideal
    /// width so it never falls back to the short numeric format ("11/22/26").
    private func stayDatePicker(
        _ title: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeFrom<Date>
    ) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            DatePicker(title, selection: selection, in: range, displayedComponents: .date)
                .labelsHidden()
                .fixedSize()
        }
        .padding(.vertical, 8)
    }
}
