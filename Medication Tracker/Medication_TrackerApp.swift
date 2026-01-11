import SwiftUI
import SwiftData
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

@main
struct Medication_TrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    private let syncActor: MedicationSyncActor
    private let viewModel: MedicationViewModel

    private let username: String = AppConfig.username

    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate

        let schema = Schema([Medication.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try! ModelContainer(for: schema, configurations: [config])

        self.modelContainer = container

        let api = LiveMedicationAPIClient()
        self.syncActor = MedicationSyncActor(modelContainer: container)

        let store = SwiftDataMedicationStore(container: container)
        let repository = DefaultMedicationRepository(api: api, store: store)

        self.viewModel = MedicationViewModel(repository: repository, syncActor: syncActor)
    }

    var body: some Scene {
        WindowGroup {
            MedicationListView(
                username: username,
                vm: viewModel
            )
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }

            Task {
                await viewModel.syncAll(username: username)

                let reminders: [MedicationNotificationScheduler.MedicationReminderInfo] = (try? modelContainer.mainContext.fetch(
                    FetchDescriptor<Medication>()
                ))?.map {
                    MedicationNotificationScheduler.MedicationReminderInfo(
                        id: $0.id,
                        username: $0.username,
                        name: $0.name,
                        dosage: $0.dosage,
                        frequency: $0.frequency,
                        isActive: ($0.status == .active),
                        reminderAlert: $0.reminderAlert,
                        reminderTime1: $0.reminderTime1,
                        reminderTime2: $0.reminderTime2
                    )
                } ?? []

                await MedicationNotificationScheduler.shared.rescheduleAll(
                    username: username,
                    reminders: reminders
                )
            }
        }
    }
}
