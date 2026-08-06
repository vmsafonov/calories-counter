import Foundation

/// Everything the app persists. One JSON document on disk.
struct AppData: Codable {
    var foods: [Food] = []
    var entries: [Entry] = []
    var goals = Goals()
    var bodyProfile = BodyProfile()
    var goal: GoalKind = .lose
    var userName: String = ""
    /// Onboarding is shown until the user finishes it once.
    var didOnboard: Bool = false
    /// «Осталось» vs «Съедено» for the big number on the diary.
    var showRemaining: Bool = true

    /// A fresh install: an empty diary, no own dishes, only the stock product base.
    static var initial: AppData {
        var data = AppData()
        data.foods = SeedData.foods
        return data
    }
}
