import SwiftUI

/// Product card: pick a portion in units or grams, see the macros, add it to the meal
/// you came from. Also used to correct the portion of an entry that is already logged.
struct ProductScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    private var context: ProductContext? { nav.product }

    var body: some View {
        if let context, let food = store.food(context.foodID) {
            content(context: context, food: food)
        } else {
            VStack {
                NavBar(title: "Продукт") { nav.go(.diary) }
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    private func content(context: ProductContext, food: Food) -> some View {
        let grams = context.grams
        let nutrition = food.nutrition(grams: grams)
        let unitWeight = max(1, food.gramsPerUnit)
        let unitCount = (grams / unitWeight * 10).rounded() / 10
        let isUnitMode = food.unit != nil && context.mode == .unit

        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NavBar(title: context.source, titleSize: 14, titleWeight: 600,
                           titleColor: Theme.ink(0.5)) {
                        nav.product = nil
                        nav.screen = context.returnTo
                    }
                    .padding(.bottom, 20)

                    Text(food.name)
                        .golos(700, 25)
                        .kerning(-0.25)
                        .foregroundStyle(Theme.ink)
                    Text("\(food.brand.isEmpty ? "Без бренда" : food.brand) · \(Ru.number(food.kcal)) ккал в 100 г")
                        .golos(400, 13)
                        .foregroundStyle(Theme.ink(0.45))
                        .padding(.top, 5)

                    // Из чего собрано блюдо — чтобы было видно, что именно добавляете.
                    if food.isComposed {
                        Text(food.partsLine)
                            .golos(400, 12, lineHeight: 1.45)
                            .foregroundStyle(Theme.ink(0.42))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }

                    portionCard(context: context, food: food,
                                isUnitMode: isUnitMode,
                                unitWeight: unitWeight,
                                unitCount: unitCount)
                        .padding(.top, 22)
                        .padding(.bottom, 16)

                    HStack(spacing: 8) {
                        MacroTile(value: "\(Int(nutrition.kcal.rounded()))", caption: "ккал",
                                  valueColor: Theme.ink, captionColor: Theme.ink(0.45),
                                  background: .white, bordered: true)
                        MacroTile(value: "\(Int(nutrition.protein.rounded())) г", caption: "белки",
                                  valueColor: Theme.proteinText, captionColor: Theme.proteinText.opacity(0.7),
                                  background: Theme.proteinTint)
                        MacroTile(value: "\(Int(nutrition.fat.rounded())) г", caption: "жиры",
                                  valueColor: Theme.fatText, captionColor: Theme.fatText.opacity(0.75),
                                  background: Theme.fatTint)
                        MacroTile(value: "\(Int(nutrition.carbs.rounded())) г", caption: "углев.",
                                  valueColor: Theme.carbText, captionColor: Theme.carbText.opacity(0.75),
                                  background: Theme.carbTint)
                    }
                    .padding(.bottom, 18)

                    HStack(spacing: 10) {
                        Circle()
                            .fill(Theme.green)
                            .frame(width: 7, height: 7)
                        Text(context.editingEntryID != nil
                             ? "В приёме «\(context.meal.title)»"
                             : "Добавится в «\(context.meal.title)»")
                            .golos(500, 13.5)
                            .foregroundStyle(Theme.ink(0.6))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Theme.ink(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 0) {
                PrimaryButton(title: context.editingEntryID != nil
                              ? "Сохранить порцию"
                              : "Добавить \(Int(nutrition.kcal.rounded())) ккал") {
                    commit(context: context, food: food)
                }
            }
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

    // MARK: - Portion

    private func portionCard(context: ProductContext, food: Food,
                             isUnitMode: Bool, unitWeight: Double, unitCount: Double) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Сколько съели")
                    .golos(500, 12.5)
                    .foregroundStyle(Theme.ink(0.5))
                Spacer(minLength: 0)
                if let unit = food.unit {
                    HStack(spacing: 6) {
                        Chip(title: unit.modeLabel, isOn: isUnitMode, height: 34,
                             horizontalPadding: 11, cornerRadius: 10, fontSize: 11.5) {
                            setMode(.unit, food: food)
                        }
                        Chip(title: "В граммах", isOn: !isUnitMode, height: 34,
                             horizontalPadding: 11, cornerRadius: 10, fontSize: 11.5) {
                            setMode(.gram, food: food)
                        }
                    }
                }
            }
            .padding(.bottom, 16)

            if isUnitMode, let unit = food.unit {
                HStack(spacing: 14) {
                    StepperButton(symbol: "−", size: 48, cornerRadius: 16, fontSize: 22) {
                        stepUnits(-1, unitWeight: unitWeight)
                    }
                    VStack(spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Ru.number(unitCount))
                                .golos(700, 32)
                                .tabularNumbers()
                                .foregroundStyle(Theme.ink)
                            Text(unit.form(unitCount))
                                .golos(500, 15)
                                .foregroundStyle(Theme.ink(0.45))
                        }
                        Text("≈ \(Int(context.grams.rounded())) г")
                            .golos(400, 12)
                            .tabularNumbers()
                            .foregroundStyle(Theme.ink(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    StepperButton(symbol: "+", size: 48, cornerRadius: 16, fontSize: 22) {
                        stepUnits(1, unitWeight: unitWeight)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    StepperButton(symbol: "−", size: 48, cornerRadius: 16, fontSize: 22) {
                        setGrams(max(10, context.grams - 10))
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        NumericField(
                            text: Binding(
                                get: { context.grams > 0 ? String(Int(context.grams)) : "" },
                                set: { setGrams(min(5000, Double($0.filter(\.isNumber)) ?? 0)) }
                            ),
                            weight: 700, size: 26, alignment: .trailing
                        )
                        .frame(width: 92)
                        Text("г")
                            .golos(500, 14)
                            .foregroundStyle(Theme.ink(0.45))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    StepperButton(symbol: "+", size: 48, cornerRadius: 16, fontSize: 22) {
                        setGrams(context.grams + 10)
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Actions

    private func setGrams(_ value: Double) {
        nav.product?.grams = value
    }

    private func setMode(_ mode: PortionMode, food: Food) {
        guard var context = nav.product else { return }
        context.mode = mode
        if mode == .unit {
            let unitWeight = max(1, food.gramsPerUnit)
            context.grams = max(unitWeight, (context.grams / unitWeight).rounded() * unitWeight)
        }
        nav.product = context
    }

    /// Half-unit steps, as in the prototype: 1 ролл, 1,5 ролла, 2 ролла…
    private func stepUnits(_ direction: Double, unitWeight: Double) {
        guard let current = nav.product?.grams else { return }
        let half = max(1, unitWeight / 2)
        let next = ((current + direction * unitWeight) / half).rounded() * half
        nav.product?.grams = max(half, next)
    }

    private func commit(context: ProductContext, food: Food) {
        guard context.grams > 0 else { return }
        if let entryID = context.editingEntryID {
            store.updateGrams(entryID: entryID, grams: context.grams)
            nav.product = nil
            nav.go(.diary)
            nav.flash("Порция обновлена")
        } else {
            store.addEntry(foodID: food.id, meal: context.meal, grams: context.grams, day: nav.day)
            nav.product = nil
            nav.go(.diary)
            nav.flash("«\(food.name)» в дневнике")
        }
    }
}
