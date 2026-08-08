import SwiftUI

/// Search / own food / recent, with multi-select and a per-item portion field.
struct AddFoodScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    var body: some View {
        VStack(spacing: 0) {
            head
            list
        }
        .overlay(alignment: .bottom) {
            if !nav.selection.isEmpty { selectionBar }
        }
        .animation(.easeOut(duration: 0.22), value: nav.selection.count)
    }

    // MARK: - Search + tabs

    private var head: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavBar(title: "Добавить в «\(nav.targetMeal.title)»") { nav.go(.diary) }
                .padding(.bottom, 16)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink(0.35))

                TextField("Продукт или блюдо", text: $nav.query)
                    .golos(500, 15)
                    .foregroundStyle(Theme.ink)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()

                Button {
                    nav.go(.scan)
                } label: {
                    Text("Скан")
                        .golos(600, 12.5)
                        .foregroundStyle(Theme.greenDark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                ForEach(AddTab.allCases, id: \.self) { tab in
                    Chip(title: tab.title, isOn: nav.addTab == tab, height: 32) {
                        nav.addTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    // MARK: - Results

    private var hasQuery: Bool {
        !nav.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var pool: [Food] {
        switch nav.addTab {
        case .own: return store.ownFoods
        case .recent: return store.recentFoods()
        case .search: return store.baseFoods
        }
    }

    /// Пока ищут — вкладки не сужают выдачу: ищем сразу по всей еде, и по базе,
    /// и по своим блюдам. Вкладки остаются способом посмотреть списки без запроса.
    private var results: [Food] {
        guard hasQuery else { return pool }
        return store.searchAllFoods(nav.query)
    }

    private var caption: String {
        if hasQuery { return "Найдено · \(results.count)" }
        switch nav.addTab {
        case .own: return "Ваши блюда · \(store.ownFoods.count)"
        case .recent: return "Недавние"
        case .search: return "Популярное"
        }
    }

    private var emptyStateText: String {
        if hasQuery {
            return "Ничего не нашлось. Попробуйте другое название или создайте своё блюдо."
        }
        switch nav.addTab {
        case .own: return "Здесь появятся ваши блюда — создайте первое."
        case .recent: return "Здесь появится то, что вы уже добавляли в дневник."
        case .search: return "База продуктов пуста."
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if nav.addTab == .own {
                    createOwnCard
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                }

                SectionCaption(text: caption)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                if results.isEmpty {
                    Text(emptyStateText)
                        .golos(400, 13, lineHeight: 1.5)
                        .foregroundStyle(Theme.ink(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 8)
                }

                ForEach(results) { food in
                    resultRow(food)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var createOwnCard: some View {
        Button {
            nav.openOwnDishForm()
        } label: {
            HStack(spacing: 12) {
                Text("+")
                    .golos(400, 20)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Theme.green, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Создать своё блюдо")
                        .golos(600, 14)
                        .foregroundStyle(Theme.greenDark)
                    Text("Например, «мамины котлетки»")
                        .golos(400, 11.5)
                        .foregroundStyle(Theme.ink(0.45))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(Theme.greenTintSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(Theme.green.opacity(0.45))
            )
        }
        .buttonStyle(.plain)
    }

    private func resultRow(_ food: Food) -> some View {
        let isSelected = nav.isSelected(food.id)
        let grams = nav.selectedGrams(food.id) ?? food.defaultGrams

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    nav.openProduct(food, source: food.isOwn ? "Своя еда" : "Поиск", returnTo: .add)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(food.name)
                            .golos(500, 14.5)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Text(food.listSubtitle)
                            .golos(400, 12)
                            .foregroundStyle(Theme.ink(0.42))
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    nav.toggleSelection(food)
                } label: {
                    Text(isSelected ? "✓" : "+")
                        .golos(600, 16)
                        .foregroundStyle(isSelected ? Color.white : Theme.greenDark)
                        .frame(width: 32, height: 32)
                        .background(isSelected ? Theme.green : Theme.greenTint, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if isSelected {
                HStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        NumericField(
                            text: Binding(
                                get: { grams > 0 ? String(Int(grams)) : "" },
                                set: { value in
                                    let parsed = min(5000, Double(value.filter(\.isNumber)) ?? 0)
                                    nav.setSelectedGrams(food.id, grams: parsed)
                                }
                            ),
                            weight: 600, size: 15, alignment: .trailing
                        )
                        .frame(width: 52)
                        Text("г")
                            .golos(500, 13)
                            .foregroundStyle(Theme.ink(0.45))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                    if let unit = food.unit, food.gramsPerUnit > 0 {
                        let count = grams / food.gramsPerUnit
                        Text("≈ \(Ru.number(count)) \(unit.form((count * 10).rounded() / 10))")
                            .golos(400, 12)
                            .tabularNumbers()
                            .foregroundStyle(Theme.ink(0.42))
                    }

                    Spacer(minLength: 0)

                    Text("\(Int(food.nutrition(grams: grams).kcal.rounded())) ккал")
                        .golos(600, 13)
                        .tabularNumbers()
                        .foregroundStyle(Theme.greenDark)
                }
                .padding(.top, 4)
                .padding(.bottom, 10)
            }

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
    }

    // MARK: - Multi-select bar

    private var selectedTotalKcal: Int {
        Int(nav.selection.reduce(0.0) { sum, item in
            guard let food = store.food(item.foodID) else { return sum }
            return sum + food.nutrition(grams: item.grams).kcal
        }.rounded())
    }

    private var selectionBar: some View {
        HStack(spacing: 8) {
            Button {
                nav.selection = []
            } label: {
                Text("×")
                    .golos(400, 20)
                    .foregroundStyle(Theme.ink(0.55))
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.ink(0.14), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            PrimaryButton(
                title: "Добавить \(nav.selection.count) \(Ru.positions(nav.selection.count)) · \(selectedTotalKcal) ккал",
                fontSize: 15.5
            ) {
                let count = nav.selection.count
                for item in nav.selection where item.grams > 0 {
                    store.addEntry(foodID: item.foodID, meal: nav.targetMeal,
                                   grams: item.grams, day: nav.day)
                }
                nav.selection = []
                nav.go(.diary)
                nav.flash("Добавлено \(count) \(Ru.positions(count))")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 30)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .overlay { Color.white.opacity(0.6) }
                .overlay(alignment: .top) { Rectangle().fill(Theme.ink(0.08)).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
