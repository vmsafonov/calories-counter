import SwiftUI

/// «Продукт в состав» — выбор ингредиента для блюда, которое собирают из продуктов.
/// Ищет сразу по всей еде: и по общей базе, и по своим блюдам.
struct IngredientPickerScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    private var results: [Food] {
        let dishName = nav.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.searchAllFoods(nav.query)
            // Блюдо не может входить в собственный состав.
            .filter { dishName.isEmpty || $0.name.lowercased() != dishName }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                NavBar(title: "Продукт в состав") {
                    nav.query = ""
                    nav.screen = .createFood
                }
                .padding(.bottom, 14)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink(0.35))
                    TextField("Продукт или блюдо", text: $nav.query)
                        .golos(500, 15)
                        .foregroundStyle(Theme.ink)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if results.isEmpty {
                        Text("Ничего не нашлось. Продукт можно сначала завести в «Продуктах».")
                            .golos(400, 13, lineHeight: 1.5)
                            .foregroundStyle(Theme.ink(0.45))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 10)
                    }

                    ForEach(results) { food in
                        row(food)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func row(_ food: Food) -> some View {
        Button {
            nav.draftIngredients.append(DraftIngredient(foodID: food.id, grams: food.defaultGrams))
            nav.query = ""
            nav.screen = .createFood
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(food.name)
                            .golos(500, 14.5, lineHeight: 1.25)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Text(food.brand.isEmpty
                             ? "\(Int(food.kcal.rounded())) ккал / 100 г"
                             : "\(food.brand) · \(Int(food.kcal.rounded())) ккал / 100 г")
                            .golos(400, 12, lineHeight: 1.3)
                            .foregroundStyle(Theme.ink(0.42))
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Text("+")
                        .golos(600, 17)
                        .foregroundStyle(Theme.greenDark)
                        .frame(width: 32, height: 32)
                        .background(Theme.greenTint, in: Circle())
                }
                .padding(.vertical, 13)

                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
