import Foundation
import ActivityKit

// MARK: – Activity Attributes (matches FinTrackWidget's BudgetLiveActivityAttributes)

public struct BudgetActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var spent: Double
        public var total: Double
        public var currency: String
        public var lastTransaction: String

        public init(spent: Double, total: Double, currency: String, lastTransaction: String = "") {
            self.spent = spent
            self.total = total
            self.currency = currency
            self.lastTransaction = lastTransaction
        }
    }

    public var budgetName: String
    public var budgetIcon: String

    public init(budgetName: String, budgetIcon: String) {
        self.budgetName = budgetName
        self.budgetIcon = budgetIcon
    }
}

// MARK: – Live Activity Service

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}

    private var currentActivity: Activity<BudgetActivityAttributes>?

    var isRunning: Bool { currentActivity != nil }

    // MARK: – Start

    func start(budgetName: String, budgetIcon: String,
               spent: Double, total: Double, currency: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        end()

        let attributes = BudgetActivityAttributes(budgetName: budgetName, budgetIcon: budgetIcon)
        let state = BudgetActivityAttributes.ContentState(
            spent: spent, total: total, currency: currency
        )
        let content = ActivityContent(state: state, staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date()))

        do {
            currentActivity = try Activity<BudgetActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activities unavailable (simulator, low-power mode, etc.) — silently skip
        }
    }

    // MARK: – Update

    func update(spent: Double, total: Double, currency: String, lastTransaction: String = "") {
        guard let activity = currentActivity else { return }

        let state = BudgetActivityAttributes.ContentState(
            spent: spent, total: total, currency: currency, lastTransaction: lastTransaction
        )
        let content = ActivityContent(state: state, staleDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date()))

        Task {
            await activity.update(content)
        }
    }

    // MARK: – End

    func end() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }

    // MARK: – End all orphaned activities on app launch

    func endAllOrphaned() {
        Task {
            for activity in Activity<BudgetActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
