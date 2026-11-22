import SwiftUI

/// Localized copy of the official portal's own help, with deep links to each portal page.
/// Strings live in the `PortalHelp` table so the long prose stays out of `Localizable.strings`.
struct PortalHelpView: View {
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(portalHelp("These instructions come from the official CASERO portal help. They describe the website, not this app."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Image("PortalLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 36)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PortalHelpTopic.channels.color, in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityLabel("CASERO")
                        Text(portalHelp("The official portal shows this logo and the colored icons below. Use them to find each section on the website."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
                        ForEach(PortalHelpTopic.all) { topic in
                            Button {
                                withAnimation { proxy.scrollTo(topic.id, anchor: .top) }
                            } label: {
                                VStack(spacing: 6) {
                                    PortalHelpTile(topic: topic, size: 56)
                                    Text(portalHelp(topic.title))
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(PortalHelpTopic.all) { topic in
                        PortalHelpTopicView(topic: topic)
                            .id(topic.id)
                    }

                    Link(destination: CaseroClient.baseURL.appendingPathComponent("Principal/Ayuda")) {
                        HStack {
                            Spacer()
                            Label(portalHelp("Open help in the official portal"), systemImage: "safari")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle("Official Portal Help")
    }
}

private struct PortalHelpTopicView: View {
    let topic: PortalHelpTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PortalHelpTile(topic: topic, size: 32)
                Text(portalHelp(topic.title)).font(.headline)
                Spacer()
                Link(destination: topic.url) {
                    Label(portalHelp("Open"), systemImage: "safari")
                        .font(.subheadline)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(topic.blocks.enumerated()), id: \.offset) { index, block in
                    if index > 0 { Divider() }
                    blockView(block)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder
    private func blockView(_ block: PortalHelpTopic.Block) -> some View {
        switch block {
        case .paragraph(let text):
            Text(portalHelp(text))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        case .heading(let text):
            Text(portalHelp(text))
                .font(.subheadline.weight(.semibold))
        case .terms(let terms):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(terms, id: \.term) { item in
                    (Text(portalHelp(item.term)).fontWeight(.semibold) + Text(": ") + Text(portalHelp(item.detail)))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .steps(let steps):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(portalHelp(step.text))
                            ForEach(step.details, id: \.self) { detail in
                                Text(portalHelp(detail)).foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .notes(let notes):
            VStack(alignment: .leading, spacing: 6) {
                Label(portalHelp("Notes"), systemImage: "info.circle")
                    .font(.caption.weight(.semibold))
                ForEach(notes, id: \.self) { note in
                    Text(portalHelp(note))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct PortalHelpTile: View {
    let topic: PortalHelpTopic
    let size: CGFloat

    var body: some View {
        Group {
            if let portalImage = topic.portalImage {
                Image(portalImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: topic.symbol)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(topic.color)
            }
        }
        .frame(width: size, height: size)
        // The portal draws square tiles; a slight rounding keeps them in the app's style.
        .clipShape(RoundedRectangle(cornerRadius: size * 0.08))
        .accessibilityHidden(true)
    }
}

private func portalHelp(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: nil, table: "PortalHelp")
}

struct PortalHelpTopic: Identifiable {
    struct Step {
        let text: String
        var details: [String] = []
    }

    enum Block {
        case paragraph(String)
        case heading(String)
        case terms([(term: String, detail: String)])
        case steps([Step])
        case notes([String])
    }

    let id: String
    let title: String
    let symbol: String
    /// Tile copied from the portal's home page, shown so users recognize the section on the website.
    var portalImage: String? = nil
    /// Matches the tile colors on the portal's home page so the sections are easy to recognize.
    let color: Color
    let path: String
    let blocks: [Block]

    var url: URL { path.isEmpty ? CaseroClient.baseURL : CaseroClient.baseURL.appendingPathComponent(path) }

    static let all: [PortalHelpTopic] = [home, profile, registerGuest, activeGuests, registeredGuests, channels]

    static let home = PortalHelpTopic(
        id: "home",
        title: "Home",
        symbol: "house.fill",
        color: Color(red: 0.36, green: 0.42, blue: 0.5),
        path: "",
        blocks: [
            .paragraph(
                "This section shows every operation available in the CASERO application. They are in the top menu bar and in the work area."
            ),
            .heading("Top menu bar"),
            .terms([
                ("Home", "Shows the main screen with every operation available in the application."),
                ("Guest", "Shows a menu with the “Register guest”, “Active guests” and “Registered guests” operations."),
                ("Communication channels", "Configures the alternative communication channels."),
                ("My profile", "Shows the signed-in user's details and lets them change their password."),
                ("Help", "Shows the help."),
                ("About", "Shows information about the application."),
                ("Exit", "Closes the application."),
            ]),
            .heading("Work area"),
            .terms([
                ("Register guest", "Registers one or more guests with their companions."),
                ("Active guests", "Lists the guests who are currently registered."),
                ("Registered guests", "Keeps a history of every guest the host has registered."),
            ]),
        ]
    )

    static let profile = PortalHelpTopic(
        id: "profile",
        title: "My profile",
        symbol: "person.crop.circle.fill",
        color: Color(red: 0.42, green: 0.36, blue: 0.75),
        path: "Cuenta/Perfil",
        blocks: [
            .paragraph("This section changes the signed-in user's password. Follow these steps:"),
            .steps([
                Step(text: "In the “Clave anterior” (previous password) field, type the current password."),
                Step(
                    text:
                        "In the “Nueva clave” (new password) and “Confirmar la clave” (confirm password) fields, type the new password."
                ),
                Step(text: "Tap the “Cambiar” (change) button to change the password."),
            ]),
            .notes([
                "The password must have at least one uppercase letter, one lowercase letter, one digit, one special character and at least 8 characters."
            ]),
        ]
    )

    static let registerGuest = PortalHelpTopic(
        id: "register",
        title: "Register guest",
        symbol: "person.badge.plus",
        portalImage: "PortalRegisterGuest",
        color: Color(red: 1, green: 0.55, blue: 0.16),
        path: "Huespedes",
        blocks: [
            .paragraph("This section registers one or more guests. Follow these steps:"),
            .steps([
                Step(
                    text:
                        "From the drop-down list, select “Pasaporte” (passport), “Carné de Identidad” (identity card), “Nombre y Apellidos” (full name) or “Número de identidad” (identity number). Type the matching information in the text field and tap the “Buscar” (search) button."
                ),
                Step(
                    text:
                        "When the search finishes, the guest's information is shown so you can check that it matches the guest's identity document. Then add the guest with the “Adicionar” (add) button."
                ),
                Step(
                    text:
                        "The “Detalles del huésped” (guest details) window opens. Select the “Fecha entrada” (check-in date) and “Fecha salida” (check-out date), plus the “País de Procedencia” (country of origin) for foreigners, then tap “Adicionar” (add)."
                ),
                Step(
                    text: "To edit a guest's details, select the guest and tap the edit icon.",
                    details: [
                        "The “Detalles del huésped” (guest details) window opens for that guest. Select the check-in and check-out dates you want to change and tap “Aceptar” (accept)."
                    ]
                ),
                Step(text: "To remove a guest, tap the delete icon."),
                Step(text: "Tap the “Registrar” (register) button to finish the registration."),
            ]),
            .notes([
                "To register several guests, repeat steps 1, 2 and 3 as many times as needed, then step 6.",
                "The first guest added must be a foreigner or a Cuban living abroad.",
                "Cuban nationals added after a guest are treated as that guest's companions.",
                "The “Número de identidad” (identity number) field is for foreigners who are temporary or permanent residents in Cuba.",
            ]),
        ]
    )

    static let activeGuests = PortalHelpTopic(
        id: "active",
        title: "Active guests",
        symbol: "person.fill.checkmark",
        portalImage: "PortalActiveGuests",
        color: Color(red: 1, green: 0.34, blue: 0.16),
        path: "Huespedes/HuespedesActivos",
        blocks: [
            .paragraph(
                "This section lists the guests who are currently staying, lets you add new companions to them and edit their check-out date. Follow these steps:"
            ),
            .steps([
                Step(text: "First select a guest."),
                Step(
                    text:
                        "The guest's area turns blue and two icons appear in the top-right corner: add companions and change check-out date."
                ),
            ]),
            .paragraph("What to do for each option is described below."),
            .heading("To add companions to a guest"),
            .steps([
                Step(
                    text:
                        "Tap the add companions icon. A new window opens with two options at the top: “Listar” (list) and “Adicionar” (add)."
                ),
                Step(text: "To see the selected guest's companions, tap the “Listar” (list) button."),
                Step(text: "To add a new companion to the guest, tap the “Adicionar” (add) button."),
                Step(text: "Type the companion's identity card number in the “Carné de identidad” field and tap “Buscar” (search)."),
                Step(text: "When the companion's details are returned, tap “Adicionar” (add)."),
                Step(
                    text:
                        "The “Detalles del acompañante” (companion details) window opens. Select the “Fecha inicio estancia” (stay start date) and “Fecha fin estancia” (stay end date), then tap “Adicionar” (add)."
                ),
                Step(
                    text: "To edit a companion's details, select them and tap the edit icon.",
                    details: [
                        "The “Detalles del acompañante” (companion details) window opens. Select the check-in and check-out dates you want to change and tap “Adicionar” (add)."
                    ]
                ),
                Step(text: "To remove a companion, tap the delete icon."),
                Step(text: "Tap the “Registrar” (register) button to finish."),
            ]),
            .notes([
                "To register several companions, repeat the steps starting from step 3 for each companion you want to add.",
                "To go back to the active guests list at any point, tap the back icon.",
            ]),
            .heading("To change a guest's check-out date"),
            .steps([
                Step(text: "With the guest selected, tap the change check-out date icon in the top-right corner."),
                Step(text: "In the window that opens, select the “Fecha salida” (check-out date) and tap “Cambiar” (change)."),
            ]),
            .notes([
                "Use “Mostrar” (show) to choose how many guests appear in the results: 5, 10, 15 or 20."
            ]),
        ]
    )

    static let registeredGuests = PortalHelpTopic(
        id: "registered",
        title: "Registered guests",
        symbol: "person.fill",
        portalImage: "PortalRegisteredGuests",
        color: Color(red: 0.06, green: 0.6, blue: 0.28),
        path: "Huespedes/HuespedesRegistrados",
        blocks: [
            .paragraph("This section lists the registered guests. Follow these steps:"),
            .steps([
                Step(
                    text: "Optionally select a “Desde” (from) – “Hasta” (to) date range, only one of them, or neither.",
                    details: [
                        "From: every guest registered from that date onwards.",
                        "To: every guest registered up to that date.",
                    ]
                ),
                Step(text: "Tap the “Buscar” (search) button."),
                Step(
                    text:
                        "When the search finishes, the list of registered guests is shown. Move through it with the pagination bar at the bottom."
                ),
            ]),
            .heading("To show a guest's companions"),
            .steps([
                Step(text: "First select a guest."),
                Step(text: "The guest's area turns blue and the companions icon appears in the top-right corner."),
                Step(text: "Tap the companions icon. A new window shows the selected guest's companions."),
            ]),
            .notes([
                "To register several companions, repeat the steps starting from step 3 for each companion you want to add.",
                "To go back to the active guests list at any point, tap the back icon.",
                "Use “Mostrar” (show) to choose how many guests appear in the results: 5, 10, 15 or 20.",
            ]),
        ]
    )

    static let channels = PortalHelpTopic(
        id: "channels",
        title: "Communication channels",
        symbol: "envelope.fill",
        portalImage: "PortalChannels",
        color: Color(red: 0.24, green: 0.5, blue: 0.76),
        path: "ViasComunicacion",
        blocks: [
            .paragraph("This section configures the alternative communication channels. Follow these steps:"),
            .heading("To add new channels"),
            .steps([
                Step(
                    text:
                        "Add an email: type the email address in the “Correo” (email) field and tap “Registrar Correo” (register email)."
                ),
                Step(
                    text:
                        "Add a mobile phone: type the mobile number in the “Teléfono” (phone) field and tap “Registrar Teléfono” (register phone)."
                ),
                Step(text: "Tap the “Confirmar” (confirm) button to finish the configuration."),
            ]),
            .notes(["To add several channels, repeat steps 1 and/or 2 as many times as needed, then step 3."]),
            .heading("To remove existing channels"),
            .steps([
                Step(text: "Select the channel you want to remove."),
                Step(text: "The channel's area turns blue and the delete icon appears in the top-right corner."),
                Step(text: "Tap the delete icon and the channel is removed."),
                Step(text: "Tap the “Confirmar” (confirm) button to finish the configuration."),
            ]),
            .notes(["To remove several channels, repeat steps 1, 2 and 3 as many times as needed, then step 4."]),
        ]
    )
}
