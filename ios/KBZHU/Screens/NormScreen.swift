import SwiftUI

/// Manual daily norm: type the numbers yourself, or recalculate them from body parameters.
struct NormScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav

    @State private var kcal = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var carbs = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    NavBar(title: "Дневная норма") { nav.go(.profile) }
                        .padding(.bottom, 16)

                    Text("Задайте значения вручную — или пересчитайте по параметрам тела.")
                        .golos(400, 13, lineHeight: 1.5)
                        .foregroundStyle(Theme.ink(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 22)

                    label("Калории в день")
                    NumericField(text: $kcal, weight: 700, size: 20)
                        .padding(.horizontal, 16)
                        .frame(height: 56)
                        .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.bottom, 18)

                    label("Нутриенты, г в день")
                    HStack(spacing: 10) {
                        macroField(caption: "Белки", text: $protein,
                                   background: Theme.proteinTint,
                                   captionColor: Theme.proteinText.opacity(0.75),
                                   valueColor: Theme.proteinText)
                        macroField(caption: "Жиры", text: $fat,
                                   background: Theme.fatTint,
                                   captionColor: Theme.fatText.opacity(0.8),
                                   valueColor: Theme.fatText)
                        macroField(caption: "Углеводы", text: $carbs,
                                   background: Theme.carbTint,
                                   captionColor: Theme.carbText.opacity(0.8),
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
                        .padding(.bottom, 12)

                    Button {
                        nav.onboardingStep = 1
                        nav.go(.onboarding)
                    } label: {
                        Text("Пересчитать по параметрам")
                            .golos(500, 14)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Theme.ink(0.14), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            PrimaryButton(title: "Сохранить норму") { save() }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
                .background(
                    Color.white
                        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                        .ignoresSafeArea(edges: .bottom)
                )
        }
        .onAppear {
            let goals = store.goals
            kcal = String(goals.kcal)
            protein = String(goals.protein)
            fat = String(goals.fat)
            carbs = String(goals.carbs)
        }
    }

    private var hint: String {
        let k = max(1, Int(kcal) ?? 1)
        let p = Int(protein) ?? 0
        return "Сейчас в норме \(Int((Double(p * 4) / Double(k) * 100).rounded()))% калорий приходится на белок."
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .golos(500, 12)
            .foregroundStyle(Theme.ink(0.5))
            .padding(.bottom, 8)
    }

    private func macroField(caption: String, text: Binding<String>, background: Color,
                            captionColor: Color, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption)
                .golos(400, 11)
                .foregroundStyle(captionColor)
            NumericField(text: text, weight: 700, size: 19, color: valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func save() {
        let current = store.goals
        func value(_ text: String, _ fallback: Int) -> Int {
            guard let parsed = Int(text.filter(\.isNumber)), parsed > 0 else { return fallback }
            return parsed
        }
        store.setGoals(Goals(kcal: value(kcal, current.kcal),
                             protein: value(protein, current.protein),
                             fat: value(fat, current.fat),
                             carbs: value(carbs, current.carbs)))
        nav.go(.profile)
        nav.flash("Дневная норма обновлена")
    }
}
