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

    // MARK: Общий каталог

    /// Ревизия каталога, которая сейчас разложена по продуктам.
    var catalogRevision: String?
    /// ETag последнего ответа — чтобы не качать файл, который не менялся.
    var catalogETag: String?
    /// Когда последний раз ходили за каталогом (успешно или нет).
    var catalogCheckedAt: Date?

    /// A fresh install: an empty diary, no own dishes, only the stock product base.
    static var initial: AppData {
        var data = AppData()
        data.foods = SeedData.foods
        data.catalogRevision = SeedData.bundledRevision
        return data
    }

    init() {}

    /// Терпимое чтение: файл, записанный прошлой версией приложения, не должен
    /// становиться нечитаемым из-за новых полей.
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        foods = try box.decodeIfPresent([Food].self, forKey: .foods) ?? []
        entries = try box.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        goals = try box.decodeIfPresent(Goals.self, forKey: .goals) ?? Goals()
        bodyProfile = try box.decodeIfPresent(BodyProfile.self, forKey: .bodyProfile) ?? BodyProfile()
        goal = try box.decodeIfPresent(GoalKind.self, forKey: .goal) ?? .lose
        userName = try box.decodeIfPresent(String.self, forKey: .userName) ?? ""
        didOnboard = try box.decodeIfPresent(Bool.self, forKey: .didOnboard) ?? false
        showRemaining = try box.decodeIfPresent(Bool.self, forKey: .showRemaining) ?? true
        catalogRevision = try box.decodeIfPresent(String.self, forKey: .catalogRevision)
        catalogETag = try box.decodeIfPresent(String.self, forKey: .catalogETag)
        catalogCheckedAt = try box.decodeIfPresent(Date.self, forKey: .catalogCheckedAt)
    }
}
