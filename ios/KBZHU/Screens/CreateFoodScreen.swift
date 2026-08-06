import SwiftUI

/// Единая форма продукта. Тремя способами:
/// — «Своё блюдо» (видно только вам),
/// — «Новый продукт» в общую базу (сюда приводит ненайденный штрих-код),
/// — правка уже существующего продукта.
///
/// Значения можно вводить на 100 г либо на порцию — во втором случае указывается,
/// сколько граммов эта порция весит.
struct CreateFoodScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    private var kind: FoodFormKind { nav.foodForm }
    private var isPortionMode: Bool { nav.draft.mode == .portion }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NavBar(title: title) { goBack() }
                        .padding(.bottom, 16)

                    Text(subtitle)
                        .golos(400, 13, lineHeight: 1.5)
                        .foregroundStyle(Theme.ink(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 22)

                    fieldLabel("Название")
                    TextField(namePlaceholder, text: $nav.draft.name)
                        .golos(500, 15)
                        .foregroundStyle(Theme.ink)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.bottom, 18)

                    fieldLabel("Как считаем продукт")
                    HStack(spacing: 6) {
                        Chip(title: "Граммы", isOn: !isPortionMode, height: 44,
                             horizontalPadding: 8, cornerRadius: 13, fillsWidth: true) {
                            nav.draft.mode = .grams
                        }
                        Chip(title: portionChipTitle, isOn: isPortionMode, height: 44,
                             horizontalPadding: 8, cornerRadius: 13, fillsWidth: true) {
                            nav.draft.mode = .portion
                        }
                    }
                    .padding(.bottom, 18)

                    if isPortionMode {
                        fieldLabel(weightFieldLabel)
                        NumericField(text: $nav.draft.grams, placeholder: "120",
                                     weight: 600, size: 15, allowsDecimal: true)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.bottom, 18)
                    }

                    fieldLabel(macrosSectionLabel)
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

            PrimaryButton(title: saveTitle) { save() }
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

    // MARK: - Тексты

    private var title: String {
        switch kind {
        case .ownDish: return "Своё блюдо"
        case .baseProduct: return "Новый продукт"
        case .edit: return "Редактировать продукт"
        }
    }

    private var subtitle: String {
        switch kind {
        case .ownDish:
            return "Видно только вам — в разделе «Своя еда». В общий поиск не попадёт."
        case .baseProduct(let barcode):
            if let barcode {
                return "Штрих-код \(barcode) не нашёлся. Заполните карточку — продукт попадёт в общий список, и в следующий раз сканер его узнает."
            }
            return "Продукт попадёт в общий список — его будет видно в поиске, а не только в «Своей еде»."
        case .edit:
            return "Исправьте значения — они сохранятся и будут применяться дальше."
        }
    }

    private var namePlaceholder: String {
        if case .ownDish = kind { return "Мамины котлетки" }
        return "Например, «Творог 5%»"
    }

    /// Для продукта, который уже считается в штуках или стаканах, вторая вкладка
    /// называется по его единице, а не «Порция».
    private var portionChipTitle: String {
        switch nav.draft.unit {
        case .piece: return "Штуки"
        case .glass: return "Стаканы"
        case .pack: return "Пачки"
        case .jar: return "Баночки"
        case .slice: return "Ломтики"
        case .portion, .none: return "Порция"
        }
    }

    private var weightFieldLabel: String {
        switch nav.draft.unit {
        case .piece: return "Вес 1 шт, г"
        case .glass: return "Объём 1 стакана, г"
        case .pack: return "Вес 1 пачки, г"
        case .jar: return "Вес 1 баночки, г"
        case .slice: return "Вес 1 ломтика, г"
        case .portion, .none: return "Вес порции, г"
        }
    }

    private var macrosSectionLabel: String {
        isPortionMode ? "На всю порцию" : "На 100 г"
    }

    private var saveTitle: String {
        switch kind {
        case .ownDish: return "Сохранить блюдо"
        case .baseProduct: return "Сохранить продукт"
        case .edit: return "Сохранить изменения"
        }
    }

    private var hint: String {
        guard isPortionMode else {
            return "Значения на 100 г — как на упаковке. Сколько съели, укажете при добавлении."
        }
        if let kcal = nav.draft.kcal.ruDouble, let grams = nav.draft.grams.ruDouble, grams > 0 {
            let per100 = Int((kcal / grams * 100).rounded())
            return "Это \(per100) ккал на 100 г. Порцию можно менять при добавлении."
        }
        return "Укажите вес и калорийность порции — приложение само пересчитает на 100 г."
    }

    // MARK: - Вёрстка полей

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

    // MARK: - Действия

    private func goBack() {
        switch kind {
        case .edit: nav.screen = .foods
        // Со скана возвращаемся в поиск, а не обратно в камеру.
        case .ownDish, .baseProduct: nav.screen = .add
        }
    }

    private func values() -> AppStore.FoodValues {
        let draft = nav.draft
        return AppStore.FoodValues(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            mode: draft.mode,
            portionGrams: draft.grams.ruDouble ?? 100,
            kcal: draft.kcal.ruDouble ?? 0,
            protein: draft.protein.ruDouble ?? 0,
            fat: draft.fat.ruDouble ?? 0,
            carbs: draft.carbs.ruDouble ?? 0,
            unit: draft.unit
        )
    }

    private func save() {
        let payload = values()

        switch kind {
        case .edit(let id):
            store.updateFood(id: id, values: payload)
            nav.draft = .empty
            nav.screen = .foods
            nav.flash("«\(payload.name.isEmpty ? "Продукт" : payload.name)» обновлено")

        case .ownDish:
            let created = store.createFood(payload, isOwn: true)
            nav.draft = .empty
            nav.addTab = .own
            nav.screen = .add
            nav.flash("«\(created.name)» в вашей еде")

        case .baseProduct(let barcode):
            let created = store.createFood(payload, isOwn: false, barcode: barcode)
            nav.draft = .empty
            // Сразу открываем карточку — обычно продукт заводят, чтобы тут же его съесть.
            nav.openProduct(created,
                            source: barcode.map { "Штрих-код \($0)" } ?? "Новый продукт",
                            returnTo: .add)
            nav.flash("«\(created.name)» добавлен в базу")
        }
    }
}
