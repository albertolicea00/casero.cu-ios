import SwiftUI

/// Everything the app can do, tab by tab. Strings live in the `UserManual` table.
struct AppUserManualView: View {
    var body: some View {
        HelpDocumentView(
            navigationTitle: "App User Manual",
            intro:
                "CASERO helps you report your guests to immigration from your phone: by SMS, or through the official portal casero.rem.cu with your host account. It is an unofficial app.",
            sections: AppUserManualView.sections,
            table: "UserManual"
        ) {
            EmptyView()
        }
    }

    static let sections: [HelpSection] = [
        HelpSection(
            id: "start",
            title: "Getting started",
            symbol: "flag",
            blocks: [
                .terms([
                    (
                        "SMS reports",
                        "Work without an account or internet. You need cellular service and a phone number associated with your host registration (call 18808)."
                    ),
                    (
                        "Portal features",
                        "Register, Guests and your account need your casero.rem.cu username and password. The portal is only reachable from inside Cuba."
                    ),
                ]),
                .heading("Sign in"),
                .steps([
                    HelpStep(text: "Tap the yellow “Sign in to the app session” banner, or the same button in Settings → Account."),
                    HelpStep(text: "Enter your portal username and password."),
                    HelpStep(
                        text:
                            "Keep “Remember credentials” on to save them in this device's Keychain. Each time they are used, iOS asks for Face ID, Touch ID or your passcode."
                    ),
                ]),
                .heading("Banners at the top"),
                .bullets([
                    "Yellow: you are not signed in.",
                    "Orange: the session expired; sign in again.",
                    "Red: no internet connection. Saved guests are still available.",
                ]),
            ]
        ),
        HelpSection(
            id: "sms",
            title: "SMS reports",
            symbol: "message",
            blocks: [
                .paragraph(
                    "Report a guest by SMS to 7344. Each person is a separate exchange, and only the final registration code confirms the report."
                ),
                .heading("Report a foreign guest"),
                .steps([
                    HelpStep(text: "Choose “Guest”."),
                    HelpStep(text: "Enter the passport and the stay days."),
                    HelpStep(text: "Tap “Preview SMS”. Messages opens with the prepared text; review it and tap Send."),
                ]),
                .heading("Report a Cuban companion"),
                .steps([
                    HelpStep(text: "Register the main guest first and wait for its registration code."),
                    HelpStep(
                        text:
                            "Choose “Companion”, enter the main guest's passport, the companion's 11-digit identity number and the stay days."
                    ),
                    HelpStep(text: "Turn on “The main guest's registration is confirmed” and tap “Preview SMS”."),
                ]),
                .heading("Confirm the received code"),
                .steps([
                    HelpStep(text: "The reply brings the person's name, nationality and a confirmation code. Check them."),
                    HelpStep(text: "Under “Confirm received code”, enter the code without HC and send the prepared message."),
                    HelpStep(text: "Wait for the final registration code. That is your proof of the report."),
                ]),
                .notes([
                    "Confirmation requests expire after six hours; after that, start again.",
                    "The app never sends anything by itself and does not read your messages.",
                    "The ⓘ button explains the procedure and opens the Cubatramite guide.",
                ]),
            ]
        ),
        HelpSection(
            id: "register",
            title: "Register guests",
            symbol: "person.badge.plus",
            blocks: [
                .paragraph(
                    "Registers guests and companions in the official portal. Needs sign-in. It is in beta: if something fails, finish in the portal or by SMS."
                ),
                .steps([
                    HelpStep(
                        text:
                            "Choose how to look up: Passport, ID card, Name or Temp. ID. Fill in the fields and tap “Look up”."
                    ),
                    HelpStep(
                        text:
                            "Pick the right person, set the check-in (up to 7 days back) and check-out dates, and tap “Add to registration”."
                    ),
                    HelpStep(text: "Repeat for each person. You can remove someone from the list with the trash button."),
                    HelpStep(
                        text:
                            "Tap “Register people”, review the summary and confirm. The app cannot undo a registration."
                    ),
                    HelpStep(
                        text:
                            "The result shows each person's stay ID, which you can copy. Only the stay ID proves the registration."
                    ),
                ]),
                .notes([
                    "Add the main guest (a foreigner or a Cuban living abroad) first. People found by ID card are registered as companions.",
                    "You can save a PDF before sending, after sending and when it fails. A PDF is not proof of registration.",
                    "If the connection drops after sending, the people are marked “Sent without confirmation”. Check Guests or the portal before sending again, to avoid duplicates.",
                    "If the portal refuses, it gives no reason. Try SMS or your immigration office.",
                ]),
            ]
        ),
        HelpSection(
            id: "guests",
            title: "Guests",
            symbol: "person.2",
            blocks: [
                .paragraph("Your guests from the official portal. Needs sign-in to update; saved data stays available offline. In beta."),
                .terms([
                    ("Active", "Guests currently staying, grouped by departure: leaves today, tomorrow, in N days."),
                    ("History", "Every registered guest, grouped by check-in month, with a sort order."),
                ]),
                .bullets([
                    "Search by name or passport.",
                    "Change the date range with the calendar button; the default range is set in Settings.",
                    "Reload with the arrow button.",
                    "Drag the side bar to jump between groups.",
                ]),
                .heading("Guest details"),
                .bullets([
                    "See the stay, the photo and the companions.",
                    "Add companion (active guests only): look up the companion's ID card, set the dates and confirm.",
                    "Update check-out (active guests and companions): pick the new date; the app shows how many days are added or removed before you confirm.",
                ]),
            ]
        ),
        HelpSection(
            id: "settings",
            title: "Settings",
            symbol: "gearshape",
            blocks: [
                .terms([
                    (
                        "Portal Profile Account",
                        "Your name, ID card, username and address from the portal. Change your password from here in the portal."
                    ),
                    (
                        "Communication channels",
                        "Your registered phones and emails. Add or remove them in the portal."
                    ),
                    ("Remember credentials", "Saves your password in this device's Keychain. Sign out deletes it."),
                    (
                        "Auto re-authenticate on expiry",
                        "Signs in again by itself when the app opens or the session expires, after Face ID, Touch ID or your passcode. Off by default."
                    ),
                    (
                        "Cache",
                        "How long guests are kept on the device (1 hour to 12 months, or forever), whether photos are saved, and Clear cache."
                    ),
                    (
                        "Guests",
                        "The default date range and Export guest data: pick dates and CSV / Excel or PDF (optionally with photos), then share the file."
                    ),
                ]),
                .notes([
                    "Signing out deletes the saved password, the cached guests and the photos from this device."
                ]),
            ]
        ),
        HelpSection(
            id: "help",
            title: "Help and references",
            symbol: "questionmark.circle",
            blocks: [
                .bullets([
                    "The ⓘ button on SMS, Register and Guests explains each section and links to the portal.",
                    "Official Portal Help: the portal's own instructions, with a link to each page.",
                    "Cubatramite source: an offline summary of the rules for reporting guests.",
                    "Privacy Policy & Terms: on the CASERO website.",
                ])
            ]
        ),
        HelpSection(
            id: "troubleshooting",
            title: "Troubleshooting",
            symbol: "wrench.and.screwdriver",
            blocks: [
                .terms([
                    ("The portal does not load", "It only works from inside Cuba. Use SMS reports instead."),
                    (
                        "The session keeps expiring",
                        "Sign in again, or turn on Auto re-authenticate on expiry in Settings."
                    ),
                    ("No SMS reply", "Check that you sent it from the associated number and with the exact format."),
                    (
                        "This device cannot send SMS",
                        "Use the preview on your registered phone, or type the same message there."
                    ),
                ])
            ]
        ),
    ]
}
