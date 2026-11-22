import SwiftUI

/// Offline summary of the third-party Cubatramite guide on reporting guests to MININT.
/// Written in our own words from the guide dated October 29, 2026; the full article stays one tap away.
/// Strings live in the `CubatramiteGuide` table.
struct CubatramiteGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(guide("Offline summary of the Cubatramite guide “Reporte de turistas y residentes en el exterior hospedados en viviendas en Cuba”, updated October 29, 2026."))
                        .font(.subheadline)
                    Text(guide("Cubatramite is an independent site and this is not legal advice. Rules can change; check the full guide or MININT before acting."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                Link(destination: USSDSMSReporter.instructionsURL) {
                    HStack {
                        Spacer()
                        Label(guide("Open the full guide"), systemImage: "safari")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)

                ForEach(CubatramiteGuideSection.all) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(guide(section.title), systemImage: section.symbol)
                            .font(.headline)
                        HelpBlocksView(blocks: section.blocks, table: "CubatramiteGuide")
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle("Cubatramite source")
    }
}

private func guide(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: nil, table: "CubatramiteGuide")
}

struct CubatramiteGuideSection: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let blocks: [HelpBlock]

    static let all: [CubatramiteGuideSection] = [
        whoMustReport, howToReport, sms, costsAndTiming, faq, penalties, contact,
    ]

    static let whoMustReport = CubatramiteGuideSection(
        id: "who",
        title: "Who must report",
        symbol: "person.2",
        blocks: [
            .paragraph(
                "Non-state economic actors authorized to rent out homes, rooms or spaces must report to the Ministry of the Interior (MININT) the identity details of every guest who lives abroad, and of their companions."
            ),
            .bullets([
                "Private companies and MSMEs (mipymes).",
                "Non-agricultural cooperatives.",
                "Self-employed workers (trabajadores por cuenta propia).",
            ]),
            .paragraph(
                "It covers foreign tourists and also Cubans who live abroad. Decree 160 of 2026 sets this obligation explicitly since August 4, 2026."
            ),
            .notes([
                "Self-employed hosts must also keep a register of tenants and their companions (name, surnames, citizenship and identity or passport number) and keep it for 5 years, even if their license is cancelled (article 27 of Decree-Law 90 of 2024, amended by Decree-Law 133 of 2026).",
                "Under Decree 137 of 2025, accommodations covered by its article 38 cannot host foreigners in an irregular migration status without the Immigration Authority's consent.",
            ]),
        ]
    )

    static let howToReport = CubatramiteGuideSection(
        id: "how",
        title: "How to report",
        symbol: "list.number",
        blocks: [
            .heading("Step 1: Record the guest's details"),
            .bullets([
                "Name, surnames, citizenship and identity or passport number of the tenant.",
                "The same details for each companion, if any.",
                "Check-in and check-out dates.",
            ]),
            .paragraph("Self-employed hosts record this in the Register Book of Tenants and Guests."),
            .heading("Step 2: Report to MININT"),
            .paragraph("There are two remote channels:"),
            .terms([
                (
                    "Portal Caseros",
                    "Sign in at https://casero.rem.cu/ with your host account and report the guest and, when applicable, their companions."
                ),
                ("SMS", "Send the report to 7344 from the mobile number associated with your host account."),
            ]),
            .heading("Step 3: Report the departure"),
            .paragraph(
                "Article 69 of Law 173 of 2024 (Immigration) requires reporting both check-ins and check-outs to MININT, even when the stay ends within 24 hours. Ask your MININT office how to report departures."
            ),
        ]
    )

    static let sms = CubatramiteGuideSection(
        id: "sms",
        title: "Reporting by SMS",
        symbol: "message",
        blocks: [
            .heading("Before the first report"),
            .steps([
                HelpStep(text: "Call 18808 from your mobile to ask for the number to be associated with your host registration."),
                HelpStep(text: "Wait for the confirmation. The association is not complete until you receive it."),
                HelpStep(text: "Once enabled, use that number for SMS reports."),
            ]),
            .heading("Foreign guest"),
            .steps([
                HelpStep(text: "Send HC + passport number + stay days to 7344."),
                HelpStep(text: "The reply contains the name, citizenship and a confirmation code."),
                HelpStep(text: "Send the code back preceded by HC."),
                HelpStep(text: "The system then sends a registration code, which proves the report was made."),
            ]),
            .example("HCJ1459863 5\nHC2568"),
            .heading("Companion living in Cuba"),
            .steps([
                HelpStep(text: "Confirm the main guest's registration first."),
                HelpStep(text: "Send HC + guest passport + companion identity card number + stay days to 7344."),
                HelpStep(text: "Send the confirmation code back preceded by HC."),
                HelpStep(text: "Wait for the registration code."),
            ]),
            .example("HCJ1459863 89092120806 5"),
            .notes([
                "Each person is a separate report, sent one at a time.",
                "Register the main guest before their companions.",
                "HC always goes before the data.",
                "Confirmation requests expire after six hours; after that, start again.",
                "If the SMS does not follow the format, there may be no reply.",
                "The SMS procedure was designed for foreign guests with a passport. The guide found no official SMS format for Cubans living abroad.",
            ]),
        ]
    )

    static let costsAndTiming = CubatramiteGuideSection(
        id: "costs",
        title: "Cost, hours and deadlines",
        symbol: "clock",
        blocks: [
            .terms([
                (
                    "Cost",
                    "There is no administrative fee. The portal needs internet access; SMS may incur ETECSA messaging charges."
                ),
                (
                    "Hours",
                    "Report at any time of day through the portal or SMS. Availability depends on the platforms and telecom services."
                ),
                (
                    "Deadline",
                    "Article 38.1.c of Decree 137 of 2025 requires reporting foreign guests' check-ins and check-outs within 24 hours of the rental."
                ),
                (
                    "Confirmation",
                    "The portal registers the report immediately. The SMS reply should arrive right away if the format is correct; if it does not, check that you sent it from the registered number and with the right format."
                ),
            ])
        ]
    )

    static let faq = CubatramiteGuideSection(
        id: "faq",
        title: "Frequently asked questions",
        symbol: "questionmark.circle",
        blocks: [
            .heading("Must Cubans living abroad be reported?"),
            .paragraph("Yes. The rule covers anyone who lives abroad, plus their companions."),
            .heading("Does reporting a guest authorize their stay?"),
            .paragraph("No. The report communicates their presence; it does not replace the property's authorization."),
            .heading("Can a tourist stay at a friend's home?"),
            .paragraph(
                "Not if the home is not authorized for it. Tourists must stay in hotels, other authorized lodging or homes authorized for rental. Foreign relatives need the A-2 family visa to stay with Cuban relatives."
            ),
            .heading("Must a stay shorter than one day be reported?"),
            .paragraph("Yes. Both the check-in and the check-out must be reported."),
            .heading("Can I host foreigners coming for religious activities?"),
            .paragraph(
                "A tourist visa does not allow religious activities. The church in Cuba arranges the invitation and visa, and you must check that your home may host these visitors."
            ),
            .heading("What other obligations do self-employed hosts have?"),
            .paragraph(
                "Be responsible for what happens in the property, keep the tenant register for five years, report guests who live abroad to MININT and, before leaving the country, formally appoint a representative for the rental."
            ),
        ]
    )

    static let penalties = CubatramiteGuideSection(
        id: "penalties",
        title: "Penalties",
        symbol: "exclamationmark.triangle",
        blocks: [
            .paragraph("Decree-Law 91 of 2024 sets three levels of contravention, fined in units (cuotas):"),
            .heading("Less serious"),
            .paragraph("Not providing required information, or not keeping the register book or keeping it out of date."),
            .bullets([
                "Self-employed: 20 to 40 units.",
                "MSMEs and cooperatives: 40 to 60 units.",
                "Each unit: 100 to 300 CUP.",
            ]),
            .heading("Serious"),
            .paragraph("Working without the required licenses, using unauthorized premises or obstructing inspections."),
            .bullets([
                "Self-employed: 40 to 60 units.",
                "MSMEs and cooperatives: 60 to 100 units.",
                "Each unit: 400 to 600 CUP.",
            ]),
            .heading("Very serious"),
            .paragraph("Renting to people who live abroad without reporting them to MININT."),
            .bullets([
                "Self-employed: 60 to 100 units.",
                "MSMEs and cooperatives: 100 to 200 units.",
                "Each unit: 700 to 1,000 CUP.",
            ]),
            .notes(["The fine depends on the circumstances of each case (article 4 of Decree-Law 91 of 2024)."]),
        ]
    )

    static let contact = CubatramiteGuideSection(
        id: "contact",
        title: "Contact and legal basis",
        symbol: "phone",
        blocks: [
            .paragraph("For questions about DIMEC (MININT) services:"),
            .terms([
                ("Phone", "18808"),
                ("Email", "diieminintcuba@rem.cu"),
            ]),
            .heading("Legal basis"),
            .bullets([
                "Decree-Law 171 of 1997: rental of homes, rooms or spaces.",
                "Decree-Law 90 of 2024: self-employment; article 27 sets the hosts' obligations.",
                "Decree-Law 91 of 2024: contraventions and fines.",
                "Decree 160 of 2026: reporting obligation for non-state actors, in force since August 4, 2026.",
                "Decree-Law 133 of 2026: amends article 27 of Decree-Law 90 of 2024.",
            ]),
        ]
    )
}
