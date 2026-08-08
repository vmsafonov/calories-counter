import SwiftUI

/// Статус дня по калориям. Одна и та же шкала используется в бейдже дня, в ленте недели,
/// в точках календаря и в столбцах графика — чтобы цвет везде значил одно и то же.
enum DayStatus {
    /// Записей нет.
    case empty
    /// Меньше 80% нормы.
    case under
    /// 80–100% нормы.
    case onTarget
    /// Больше нормы.
    case over

    init(kcal: Int, goal: Int) {
        guard kcal > 0 else { self = .empty; return }
        guard goal > 0 else { self = .onTarget; return }
        if kcal > goal { self = .over }
        else if Double(kcal) < Double(goal) * 0.8 { self = .under }
        else { self = .onTarget }
    }

    var title: String {
        switch self {
        case .empty: return "Нет записей"
        case .under: return "Ниже нормы"
        case .onTarget: return "В норме"
        case .over: return "Превышение"
        }
    }

    /// Цвет точки в ленте недели и в календаре, он же — цвет столбца на графике.
    var markColor: Color {
        switch self {
        case .empty: return Theme.ink(0.16)
        case .under: return Theme.proteinBar
        case .onTarget: return Theme.green
        case .over: return Theme.fatBar
        }
    }

    var badgeBackground: Color {
        switch self {
        case .empty: return Theme.ink(0.05)
        case .under: return Theme.proteinTint
        case .onTarget: return Theme.greenTint
        case .over: return Theme.fatTint
        }
    }

    var badgeForeground: Color {
        switch self {
        case .empty: return Theme.ink(0.45)
        case .under: return Theme.proteinText
        case .onTarget: return Theme.greenDark
        case .over: return Theme.fatText
        }
    }
}
