import Foundation

enum SeedData {
    /// The stock product base, installed once when the app has no data file yet.
    /// This is a reference catalogue, not user data: the diary and «Своя еда» start empty.
    /// Macros are per 100 g.
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
             defaultGrams: 180)
    ]
}
