import SwiftUI

/// Единая форма продукта в трёх режимах:
/// — «Своё блюдо» (видно только вам),
/// — «Новый продукт» в общую базу (сюда приводит ненайденный штрих-код),
/// — правка уже существующего продукта.
///
/// Данные вводятся либо на порцию (тогда указывается, как порция называется и сколько весит),
/// либо на 100 г.
struct CreateFoodScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    /// Единицы, предлагаемые в форме.
    private static let unitOptions: [FoodUnit] = [.portion, .piece, .glass, .pack, .slice]

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

                    if showsManufacturer {
                        fieldLabel("Производитель")
                        TextField("Например, Простоквашино", text: $nav.draft.manufacturer)
                            .golos(500, 15)
                            .foregroundStyle(Theme.ink)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.bottom, 18)
                    }

                    fieldLabel("Как вводите данные")
                    HStack(spacing: 6) {
                        Chip(title: "На порцию", isOn: isPortionMode, height: 44,
                             horizontalPadding: 8, cornerRadius: 13, fontSize: 13, fillsWidth: true) {
                            nav.draft.mode = .portion
                        }
                        Chip(title: "На 100 г", isOn: !isPortionMode, height: 44,
                             horizontalPadding: 8, cornerRadius: 13, fontSize: 13, fillsWidth: true) {
                            nav.draft.mode = .grams
                        }
                    }
                    .padding(.bottom, 18)

                    if isPortionMode { portionCard.padding(.bottom, 18) }

                    fieldLabel(valuesCaption)
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

    // MARK: - Порция

    private var portionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel("Порция называется")
                .padding(.bottom, 2)

            // Перенос по строкам, как flex-wrap в макете.
            FlowRow(spacing: 6) {
                ForEach(Self.unitOptions, id: \.self) { unit in
                    Chip(title: unit.rawValue, isOn: nav.draft.unit == unit,
                         height: 38, horizontalPadding: 13, cornerRadius: 11, fontSize: 12.5) {
                        nav.draft.unit = unit
                    }
                }
            }
            .padding(.bottom, 16)

            fieldLabel("Сколько весит одна порция, г")

            NumericField(text: $nav.draft.grams, placeholder: "120",
                         weight: 600, size: 15, allowsDecimal: true)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            if let barcode, !barcode.isEmpty {
                return "Штрих-код \(barcode) не нашёлся. Заполните карточку — продукт попадёт в общий список."
            }
            return "Продукт попадёт в общий список поиска."
        case .edit:
            return "Исправьте порцию и КБЖУ — значения сохранятся и будут применяться дальше."
        }
    }

    /// У своего блюда производителя нет — там это «мамины котлетки».
    private var showsManufacturer: Bool {
        switch kind {
        case .ownDish: return false
        case .baseProduct: return true
        case .edit(let id): return !(store.food(id)?.isOwn ?? true)
        }
    }

    private var namePlaceholder: String {
        switch kind {
        case .ownDish: return "Мамины котлетки"
        case .baseProduct: return "Например, творожный сырок"
        case .edit(let id): return (store.food(id)?.isOwn ?? true)
            ? "Мамины котлетки"
            : "Например, творожный сырок"
        }
    }

    private var valuesCaption: String {
        isPortionMode ? "КБЖУ на одну порцию" : "КБЖУ на 100 г"
    }

    private var saveTitle: String {
        switch kind {
        case .ownDish: return "Сохранить блюдо"
        case .baseProduct: return "Добавить в базу"
        case .edit: return "Сохранить изменения"
        }
    }

    private var hint: String {
        guard isPortionMode else {
            return "Значения на 100 г. Порцию можно будет указать при добавлении в дневник."
        }
        if let kcal = nav.draft.kcal.ruDouble, let grams = nav.draft.grams.ruDouble, grams > 0 {
            let per100 = Int((kcal / grams * 100).rounded())
            return "Это \(per100) ккал на 100 г. Порцию можно менять при добавлении."
        }
        return "Укажите вес порции и её КБЖУ — приложение само пересчитает на 100 г."
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
        case .ownDish: nav.screen = .add
        // Пришли со скана — туда же и возвращаемся.
        case .baseProduct: nav.screen = .scan
        }
    }

    private func values() -> AppStore.FoodValues {
        let draft = nav.draft
        return AppStore.FoodValues(
            name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
            manufacturer: draft.manufacturer,
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
            nav.query = ""
            nav.addTab = .own
            nav.screen = .add
            nav.flash("«\(created.name)» в вашей еде")

        case .baseProduct(let barcode):
            let created = store.createFood(payload, isOwn: false, barcode: barcode)
            nav.draft = .empty
            nav.query = ""
            nav.addTab = .search
            // Сразу открываем карточку — продукт заводят, чтобы тут же его съесть.
            nav.openProduct(created, source: "Новый продукт", returnTo: .add)
            nav.flash("«\(created.name)» добавлен в базу")
        }
    }
}

/// Ряд с переносом по строкам — `flex-wrap` из макета.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var total = CGSize(width: 0, height: 0)

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                total.width = max(total.width, rowWidth)
                total.height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        total.width = max(total.width, rowWidth)
        total.height += rowHeight
        return total
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
