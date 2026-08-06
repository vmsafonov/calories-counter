import Foundation

enum SeedData {
    /// Set to `false` to ship an empty diary — the stock product base is still installed.
    /// The demo week is written once, on first launch, and then behaves like any other data:
    /// it is editable, deletable and never reset.
    static let importDemoDiary = true

    /// The product base from the prototype. Macros per 100 g.
    static let foods: [Food] = [
        Food(name: "Овсяная каша на воде", brand: "Nordic", kcal: 88, protein: 3, fat: 1.7, carbs: 15,
             defaultGrams: 250, unit: .portion, unitWeight: 250),
        Food(name: "Куриная грудка, запечённая", brand: "Домашнее", kcal: 165, protein: 31, fat: 3.6, carbs: 0,
             defaultGrams: 150),
        Food(name: "Творог 5%", brand: "Простоквашино", kcal: 121, protein: 17, fat: 5, carbs: 3,
             defaultGrams: 180, unit: .pack, unitWeight: 180, barcode: "4600682032045"),
        Food(name: "Банан", brand: "Свежий", kcal: 89, protein: 1.1, fat: 0.3, carbs: 23,
             defaultGrams: 120, unit: .piece, unitWeight: 120),
        Food(name: "Гречка отварная", brand: "Домашнее", kcal: 110, protein: 4.2, fat: 1.1, carbs: 21,
             defaultGrams: 200),
        Food(name: "Латте на овсяном", brand: "Кофейня", kcal: 52, protein: 1.6, fat: 2, carbs: 6.6,
             defaultGrams: 300, unit: .glass, unitWeight: 300),
        Food(name: "Ролл с курицей и соусом цезарь", brand: "Фастфуд", kcal: 214, protein: 11, fat: 9, carbs: 22,
             defaultGrams: 210, unit: .piece, unitWeight: 210, barcode: "4680123456789"),
        Food(name: "Яйцо варёное", brand: "", kcal: 155, protein: 13, fat: 11, carbs: 1.1,
             defaultGrams: 110, unit: .piece, unitWeight: 55),
        Food(name: "Хлеб цельнозерновой", brand: "Рижский", kcal: 230, protein: 9, fat: 3, carbs: 41,
             defaultGrams: 60, unit: .slice, unitWeight: 30, barcode: "4607091380019"),
        Food(name: "Лосось слабосолёный", brand: "", kcal: 202, protein: 22, fat: 12, carbs: 0,
             defaultGrams: 100),
        Food(name: "Греческий йогурт 2%", brand: "Село Зелёное", kcal: 66, protein: 9, fat: 2, carbs: 3.6,
             defaultGrams: 150, unit: .jar, unitWeight: 150, barcode: "4620013532016"),
        Food(name: "Сырники творожные", brand: "Домашнее", kcal: 184, protein: 12, fat: 8, carbs: 16,
             defaultGrams: 160, unit: .piece, unitWeight: 80),
        Food(name: "Салат овощной с маслом", brand: "", kcal: 78, protein: 1.2, fat: 6, carbs: 4.5,
             defaultGrams: 180),
        Food(name: "Мамины котлетки", brand: "Своё блюдо", kcal: 212, protein: 16, fat: 14, carbs: 6,
             defaultGrams: 120, unit: .piece, unitWeight: 60, isOwn: true),
        Food(name: "Смузи банан-шпинат", brand: "Своё блюдо", kcal: 64, protein: 2, fat: 0.6, carbs: 13,
             defaultGrams: 350, unit: .glass, unitWeight: 350, isOwn: true)
    ]

    private struct Row {
        let dayOffset: Int
        let meal: MealKind
        let food: String
        let grams: Double
        let time: (Int, Int)
    }

    /// Six days of history plus today, matching the prototype's `PAST` log so the week chart,
    /// «Повторить вчерашний день» and the statistics screen have something to show.
    private static let rows: [Row] = [
        // Today
        Row(dayOffset: 0, meal: .breakfast, food: "Овсяная каша на воде", grams: 250, time: (9, 10)),
        Row(dayOffset: 0, meal: .breakfast, food: "Латте на овсяном", grams: 300, time: (9, 15)),
        Row(dayOffset: 0, meal: .lunch, food: "Куриная грудка, запечённая", grams: 150, time: (13, 40)),
        Row(dayOffset: 0, meal: .lunch, food: "Гречка отварная", grams: 200, time: (13, 42)),
        Row(dayOffset: 0, meal: .snack, food: "Банан", grams: 120, time: (16, 20)),
        // −1
        Row(dayOffset: -1, meal: .breakfast, food: "Овсяная каша на воде", grams: 250, time: (9, 5)),
        Row(dayOffset: -1, meal: .breakfast, food: "Латте на овсяном", grams: 300, time: (9, 12)),
        Row(dayOffset: -1, meal: .breakfast, food: "Сырники творожные", grams: 160, time: (9, 20)),
        Row(dayOffset: -1, meal: .lunch, food: "Лосось слабосолёный", grams: 100, time: (13, 30)),
        Row(dayOffset: -1, meal: .lunch, food: "Гречка отварная", grams: 200, time: (13, 35)),
        Row(dayOffset: -1, meal: .lunch, food: "Салат овощной с маслом", grams: 180, time: (13, 38)),
        Row(dayOffset: -1, meal: .dinner, food: "Творог 5%", grams: 180, time: (19, 10)),
        Row(dayOffset: -1, meal: .dinner, food: "Хлеб цельнозерновой", grams: 60, time: (19, 15)),
        Row(dayOffset: -1, meal: .snack, food: "Банан", grams: 120, time: (16, 40)),
        // −2
        Row(dayOffset: -2, meal: .breakfast, food: "Овсяная каша на воде", grams: 250, time: (8, 55)),
        Row(dayOffset: -2, meal: .breakfast, food: "Латте на овсяном", grams: 300, time: (9, 5)),
        Row(dayOffset: -2, meal: .lunch, food: "Куриная грудка, запечённая", grams: 150, time: (13, 20)),
        Row(dayOffset: -2, meal: .lunch, food: "Гречка отварная", grams: 200, time: (13, 25)),
        Row(dayOffset: -2, meal: .lunch, food: "Хлеб цельнозерновой", grams: 60, time: (13, 30)),
        Row(dayOffset: -2, meal: .dinner, food: "Творог 5%", grams: 180, time: (19, 30)),
        Row(dayOffset: -2, meal: .dinner, food: "Салат овощной с маслом", grams: 180, time: (19, 35)),
        Row(dayOffset: -2, meal: .snack, food: "Банан", grams: 120, time: (16, 10)),
        Row(dayOffset: -2, meal: .snack, food: "Яйцо варёное", grams: 110, time: (16, 15)),
        // −3 — the day that goes over the goal
        Row(dayOffset: -3, meal: .breakfast, food: "Сырники творожные", grams: 200, time: (9, 30)),
        Row(dayOffset: -3, meal: .breakfast, food: "Латте на овсяном", grams: 300, time: (9, 35)),
        Row(dayOffset: -3, meal: .lunch, food: "Ролл с курицей и соусом цезарь", grams: 210, time: (14, 0)),
        Row(dayOffset: -3, meal: .lunch, food: "Куриная грудка, запечённая", grams: 200, time: (14, 5)),
        Row(dayOffset: -3, meal: .lunch, food: "Гречка отварная", grams: 250, time: (14, 8)),
        Row(dayOffset: -3, meal: .dinner, food: "Салат овощной с маслом", grams: 180, time: (19, 40)),
        Row(dayOffset: -3, meal: .dinner, food: "Хлеб цельнозерновой", grams: 60, time: (19, 45)),
        Row(dayOffset: -3, meal: .snack, food: "Греческий йогурт 2%", grams: 150, time: (17, 0)),
        Row(dayOffset: -3, meal: .snack, food: "Банан", grams: 120, time: (17, 5)),
        // −4
        Row(dayOffset: -4, meal: .breakfast, food: "Овсяная каша на воде", grams: 250, time: (9, 0)),
        Row(dayOffset: -4, meal: .breakfast, food: "Яйцо варёное", grams: 110, time: (9, 5)),
        Row(dayOffset: -4, meal: .breakfast, food: "Хлеб цельнозерновой", grams: 60, time: (9, 8)),
        Row(dayOffset: -4, meal: .breakfast, food: "Латте на овсяном", grams: 300, time: (9, 12)),
        Row(dayOffset: -4, meal: .lunch, food: "Гречка отварная", grams: 200, time: (13, 45)),
        Row(dayOffset: -4, meal: .lunch, food: "Куриная грудка, запечённая", grams: 150, time: (13, 50)),
        Row(dayOffset: -4, meal: .lunch, food: "Салат овощной с маслом", grams: 180, time: (13, 55)),
        Row(dayOffset: -4, meal: .dinner, food: "Творог 5%", grams: 180, time: (19, 20)),
        Row(dayOffset: -4, meal: .snack, food: "Сырники творожные", grams: 160, time: (16, 30)),
        // −5
        Row(dayOffset: -5, meal: .breakfast, food: "Овсяная каша на воде", grams: 250, time: (9, 10)),
        Row(dayOffset: -5, meal: .breakfast, food: "Греческий йогурт 2%", grams: 150, time: (9, 15)),
        Row(dayOffset: -5, meal: .breakfast, food: "Латте на овсяном", grams: 300, time: (9, 20)),
        Row(dayOffset: -5, meal: .lunch, food: "Лосось слабосолёный", grams: 100, time: (13, 30)),
        Row(dayOffset: -5, meal: .lunch, food: "Гречка отварная", grams: 200, time: (13, 35)),
        Row(dayOffset: -5, meal: .lunch, food: "Хлеб цельнозерновой", grams: 60, time: (13, 40)),
        Row(dayOffset: -5, meal: .lunch, food: "Салат овощной с маслом", grams: 180, time: (13, 45)),
        Row(dayOffset: -5, meal: .dinner, food: "Куриная грудка, запечённая", grams: 150, time: (19, 15)),
        Row(dayOffset: -5, meal: .snack, food: "Банан", grams: 120, time: (16, 0)),
        Row(dayOffset: -5, meal: .snack, food: "Яйцо варёное", grams: 110, time: (16, 5)),
        // −6
        Row(dayOffset: -6, meal: .breakfast, food: "Овсяная каша на воде", grams: 250, time: (9, 0)),
        Row(dayOffset: -6, meal: .breakfast, food: "Латте на овсяном", grams: 300, time: (9, 10)),
        Row(dayOffset: -6, meal: .lunch, food: "Куриная грудка, запечённая", grams: 150, time: (13, 30)),
        Row(dayOffset: -6, meal: .lunch, food: "Гречка отварная", grams: 200, time: (13, 35)),
        Row(dayOffset: -6, meal: .lunch, food: "Салат овощной с маслом", grams: 180, time: (13, 40)),
        Row(dayOffset: -6, meal: .dinner, food: "Творог 5%", grams: 180, time: (19, 25)),
        Row(dayOffset: -6, meal: .dinner, food: "Хлеб цельнозерновой", grams: 60, time: (19, 30)),
        Row(dayOffset: -6, meal: .snack, food: "Яйцо варёное", grams: 110, time: (16, 20)),
        Row(dayOffset: -6, meal: .snack, food: "Банан", grams: 120, time: (16, 25))
    ]

    /// Demo entries anchored to the real calendar, so «сегодня» is actually today.
    static func demoEntries(foods: [Food]) -> [Entry] {
        guard importDemoDiary else { return [] }
        var byName: [String: UUID] = [:]
        for food in foods { byName[food.name] = food.id }
        return rows.compactMap { row in
            guard let foodID = byName[row.food] else { return nil }
            let day = Cal.adding(days: row.dayOffset, to: Cal.today)
            let stamp = Cal.calendar.date(bySettingHour: row.time.0, minute: row.time.1,
                                          second: 0, of: day) ?? day
            return Entry(foodID: foodID, meal: row.meal, grams: row.grams, day: day, createdAt: stamp)
        }
    }
}
