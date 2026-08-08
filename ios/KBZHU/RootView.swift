import SwiftUI

/// One screen at a time over a shared white canvas, plus the tab bar, the calendar sheet
/// and the toast — the same structure the prototype uses.
struct RootView: View {
    @StateObject private var store = AppStore()
    @StateObject private var nav = Nav()
    @Environment(\.scenePhase) private var scenePhase

    private var tabbedScreens: Set<Screen> { [.diary, .stats, .foods, .profile] }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            if !store.didOnboard || nav.screen == .onboarding {
                OnboardingScreen()
                    .transition(.opacity)
            } else {
                screen
                    .transition(.opacity)

                if tabbedScreens.contains(nav.screen) {
                    TabBar(current: nav.screen, onSelect: { nav.go($0) })
                }
            }

            if nav.calendarOpen {
                CalendarSheet()
                    .zIndex(9)
            }

            if let toast = nav.toast {
                ToastView(message: toast)
                    .padding(.bottom, tabbedScreens.contains(nav.screen) ? 110 : 40)
                    .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.22), value: nav.screen)
        .animation(.easeOut(duration: 0.2), value: nav.calendarOpen)
        .animation(.easeOut(duration: 0.25), value: nav.toast)
        .environmentObject(store)
        .environmentObject(nav)
        .task {
            // Не мешаем первому кадру: каталог подтягиваем, когда экран уже показан
            // и пользователь может скроллить.
            try? await Task.sleep(nanoseconds: 600_000_000)
            await CatalogService.refreshIfNeeded(store: store)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // A day may have passed while the app was in the background.
                if Cal.dayOffset(nav.day) > 0 { nav.day = Cal.today }
                Task { await CatalogService.refreshIfNeeded(store: store) }
            case .background, .inactive:
                store.saveNow()
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch nav.screen {
        case .diary: DiaryScreen()
        case .add: AddFoodScreen()
        case .product: ProductScreen()
        case .scan: ScanScreen()
        case .repeatDay: RepeatScreen()
        case .stats: StatsScreen()
        case .foods: FoodsScreen()
        case .profile: ProfileScreen()
        case .bodyGoal: BodyGoalScreen()
        case .norm: NormScreen()
        case .createFood: CreateFoodScreen()
        case .ingredientPicker: IngredientPickerScreen()
        case .onboarding: OnboardingScreen()
        }
    }
}
