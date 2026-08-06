import SwiftUI

/// «Своё блюдо» when creating, «Редактировать продукт» when correcting an existing one.
/// Values are entered per portion; the app converts them to per 100 g.
struct CreateFoodScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    private var isEditing: Bool { nav.editingFoodID != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NavBar(title: isEditing ? "Редактировать продукт" : "Своё блюдо") {
                        nav.screen = isEditing ? .foods : .add
                        nav.editingFoodID = nil
                    }
                    .padding(.bottom, 16)

                    Text(isEditing
                         ? "Исправьте вес порции и КБЖУ — значения сохранятся и будут применяться дальше."
                         : "Видно только вам — в разделе «Своя еда». В общий поиск не попадёт.")
                        .golos(400, 13, lineHeight: 1.5)
                        .foregroundStyle(Theme.ink(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 22)

                    fieldLabel("Название")
                    TextField("Мамины котлетки", text: $nav.draft.name)
                        .golos(500, 15)
                        .foregroundStyle(Theme.ink)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.bottom, 18)

                    fieldLabel("Вес порции, г")
                    NumericField(text: $nav.draft.grams, placeholder: "120",
                                 weight: 600, size: 15, allowsDecimal: true)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.bottom, 18)

                    fieldLabel("На всю порцию")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        macroField(caption: "Калории", placeholder: "254", text: $nav.draft.kcal,
                                   background: Theme.softCard, captionColor: Theme.ink(0.45),
                                   valueColor: Theme.ink)
                        macroField(caption: "Белки, г", placeholder: "19", text: $nav.draft.protein,
                                   background: Theme.proteinTint, captionColor: Theme.proteinText.opacity(0.75),
                                   valueColor: Theme.proteinText)
                        macroField(caption: "Жиры, г", placeholder: "17", text: $nav.draft.fat,
                                   background: Theme.fatTint, captionColor: Theme.fatText.opacity(0.8),
                                   valueColor: Theme.fatText)
                        macroField(caption: "Углеводы, г", placeholder: "7", text: $nav.draft.carbs,
                                   background: Theme.carbTint, captionColor: Theme.carbText.opacity(0.8),
                                   valueColor: Theme.carbText)
                    }
                    .padding(.bottom, 16)

                    Text(hint)
                        .golos(400, 12.5, lineHeight: 1.5)
                        .foregroundStyle(Theme.ink(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.ink(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            PrimaryButton(title: isEditing ? "Сохранить изменения" : "Сохранить блюдо") { save() }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
                .background(
                    Color.white
                        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                        .ignoresSafeArea(edges: .bottom)
                )
        }
    }

    private var hint: String {
        if let kcal = nav.draft.kcal.ruDouble, let grams = nav.draft.grams.ruDouble, grams > 0 {
            let per100 = Int((kcal / grams * 100).rounded())
            return "Это \(per100) ккал на 100 г. Порцию можно менять при добавлении."
        }
        return "Укажите вес и калорийность порции — приложение само пересчитает на 100 г."
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .golos(500, 12)
            .foregroundStyle(Theme.ink(0.5))
            .padding(.bottom, 8)
    }

    private func macroField(caption: String, placeholder: String, text: Binding<String>,
                            background: Color, captionColor: Color, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption)
                .golos(400, 11)
                .foregroundStyle(captionColor)
            NumericField(text: text, placeholder: placeholder,
                         weight: 700, size: 19, color: valueColor, allowsDecimal: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func save() {
        let draft = nav.draft
        let grams = max(1, draft.grams.ruDouble ?? 100)
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let kcal = draft.kcal.ruDouble ?? 0
        let protein = draft.protein.ruDouble ?? 0
        let fat = draft.fat.ruDouble ?? 0
        let carbs = draft.carbs.ruDouble ?? 0

        if let id = nav.editingFoodID {
            store.updateFood(id: id, name: name, portionGrams: grams,
                             kcal: kcal, protein: protein, fat: fat, carbs: carbs)
            nav.editingFoodID = nil
            nav.draft = .empty
            nav.screen = .foods
            nav.flash("«\(name.isEmpty ? "Продукт" : name)» обновлено")
        } else {
            let created = store.createOwnFood(name: name, portionGrams: grams,
                                              kcal: kcal, protein: protein, fat: fat, carbs: carbs)
            nav.draft = .empty
            nav.addTab = .own
            nav.screen = .add
            nav.flash("«\(created.name)» в вашей еде")
        }
    }
}
