import Foundation
import SwiftUI

enum Screen: Hashable {
    case diary
    case add
    case product
    case scan
    case repeatDay
    case stats
    case foods
    case profile
    case bodyGoal
    case norm
    case createFood
    case mealPick
    case onboarding
}

enum AddTab: String, CaseIterable, Hashable {
    case search, own, recent

    var title: String {
        switch self {
        case .search: return "Поиск"
        case .own: return "Своя еда"
        case .recent: return "Недавние"
        }
    }
}

enum PortionMode: Hashable { case unit, gram }

/// The product card can be opened to add a new portion or to correct an existing entry.
struct ProductContext: Hashable {
    var foodID: UUID
    var grams: Double
    var mode: PortionMode
    /// «Поиск», «Своя еда», «Штрих-код 4600682…», «Запись в дневнике»
    var source: String
    var meal: MealKind
    var editingEntryID: UUID?
    /// Where ← goes back to.
    var returnTo: Screen
}

/// A row ticked in the multi-select list, with its own portion.
struct SelectedItem: Identifiable, Hashable {
    var id: UUID { foodID }
    var foodID: UUID
    var grams: Double
}

/// What the numbers in the food form are measured in.
enum FoodEntryMode: Hashable {
    /// КБЖУ вводятся на 100 г, продукт считается в граммах.
    case grams
    /// КБЖУ вводятся на порцию, у порции есть вес в граммах.
    case portion
}

/// What the food form is doing right now.
enum FoodFormKind: Hashable {
    /// «Своё блюдо» — видно только пользователю, в общий поиск не попадает.
    case ownDish
    /// Новый продукт в общую базу; штрих-код известен, если пришли со скана.
    case baseProduct(barcode: String?)
    /// Правка существующего продукта.
    case edit(UUID)
}

/// Fields of the food form. Kept as strings so the text fields behave while half-typed.
struct FoodDraft: Hashable {
    var name = ""
    /// Вес одной порции, только в режиме `.portion`.
    var grams = ""
    var kcal = ""
    var protein = ""
    var fat = ""
    var carbs = ""
    var mode: FoodEntryMode = .portion
    /// Единица уже существующего продукта — чтобы правка не превращала «шт» в «порцию».
    var unit: FoodUnit? = .portion

    static let empty = FoodDraft()

    /// Pre-fills the form with a product's values, in the mode that product uses.
    static func editing(_ food: Food) -> FoodDraft {
        guard let unit = food.unit else {
            return FoodDraft(name: food.name,
                             grams: "",
                             kcal: Ru.number(food.kcal),
                             protein: Ru.number(food.protein),
                             fat: Ru.number(food.fat),
                             carbs: Ru.number(food.carbs),
                             mode: .grams,
                             unit: nil)
        }
        let grams = food.unitWeight ?? (food.defaultGrams > 0 ? food.defaultGrams : 100)
        let m = grams / 100
        return FoodDraft(name: food.name,
                         grams: Ru.number(grams),
                         kcal: Ru.number(food.kcal * m),
                         protein: Ru.number(food.protein * m),
                         fat: Ru.number(food.fat * m),
                         carbs: Ru.number(food.carbs * m),
                         mode: .portion,
                         unit: unit)
    }
}

/// Navigation + transient screen state. Mirrors the prototype's single state machine so the
/// flows behave exactly as designed (the diary is the only "home"; everything is pushed onto it).
final class Nav: ObservableObject {
    @Published var screen: Screen = .diary
    @Published var day: Date = Cal.today

    @Published var calendarOpen = false
    @Published var calendarMonth: Int = Cal.month(Cal.today)
    @Published var calendarYear: Int = Cal.year(Cal.today)

    @Published var targetMeal: MealKind = .lunch
    @Published var addTab: AddTab = .search
    @Published var query = ""
    @Published var selection: [SelectedItem] = []

    @Published var product: ProductContext?
    @Published var foodForm: FoodFormKind = .ownDish
    @Published var draft: FoodDraft = .empty

    @Published var onboardingStep = 1

    @Published var toast: String?
    @Published var openSwipeEntryID: UUID?

    /// Invalidates the previous toast timer when a new message arrives.
    private var toastToken = 0

    func go(_ screen: Screen) {
        self.screen = screen
        openSwipeEntryID = nil
        selection = []
    }

    func openAdd(meal: MealKind) {
        targetMeal = meal
        query = ""
        addTab = .search
        selection = []
        screen = .add
    }

    func openProduct(_ food: Food, source: String, returnTo: Screen) {
        product = ProductContext(foodID: food.id,
                                 grams: food.defaultGrams,
                                 mode: food.unit == nil ? .gram : .unit,
                                 source: source,
                                 meal: targetMeal,
                                 editingEntryID: nil,
                                 returnTo: returnTo)
        screen = .product
    }

    func openEntry(_ entry: Entry, food: Food) {
        product = ProductContext(foodID: food.id,
                                 grams: entry.grams,
                                 mode: food.unit == nil ? .gram : .unit,
                                 source: "Запись в дневнике",
                                 meal: entry.meal,
                                 editingEntryID: entry.id,
                                 returnTo: .diary)
        openSwipeEntryID = nil
        screen = .product
    }

    /// «Создать своё блюдо» — по умолчанию порциями, как готовое домашнее блюдо.
    func openOwnDishForm() {
        foodForm = .ownDish
        draft = FoodDraft(mode: .portion, unit: .portion)
        screen = .createFood
    }

    /// Новый продукт в общую базу. Со скана приходит штрих-код, и значения обычно
    /// написаны на упаковке на 100 г — поэтому режим по умолчанию граммовый.
    func openNewProductForm(barcode: String?) {
        foodForm = .baseProduct(barcode: barcode)
        draft = FoodDraft(mode: .grams, unit: nil)
        screen = .createFood
    }

    func openEditForm(_ food: Food) {
        foodForm = .edit(food.id)
        draft = .editing(food)
        screen = .createFood
    }

    func flash(_ message: String) {
        toastToken += 1
        let token = toastToken
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self, self.toastToken == token else { return }
            self.toast = nil
        }
    }

    func isSelected(_ foodID: UUID) -> Bool {
        selection.contains { $0.foodID == foodID }
    }

    func selectedGrams(_ foodID: UUID) -> Double? {
        selection.first { $0.foodID == foodID }?.grams
    }

    func toggleSelection(_ food: Food) {
        if let index = selection.firstIndex(where: { $0.foodID == food.id }) {
            selection.remove(at: index)
        } else {
            selection.append(SelectedItem(foodID: food.id, grams: food.defaultGrams))
        }
    }

    func setSelectedGrams(_ foodID: UUID, grams: Double) {
        guard let index = selection.firstIndex(where: { $0.foodID == foodID }) else { return }
        selection[index].grams = grams
    }
}
