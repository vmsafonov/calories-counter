import Foundation

/// Тянет общий каталог продуктов с CDN и отдаёт его в `AppStore`.
///
/// Раз в сутки при запуске: запрос с `If-None-Match`, и если файл не менялся, сервер
/// отвечает 304 и трафика почти нет. Ошибки сети молча игнорируются — на устройстве
/// остаётся последняя известная копия, приложение полностью работает офлайн.
@MainActor
enum CatalogService {

    /// Где лежит опубликованный каталог. Меняется на свой адрес, если публиковать
    /// не на GitHub Pages (Cloudflare Pages, Object Storage — что угодно, отдающее файл).
    static let url = URL(string: "https://vmsafonov.github.io/calories-counter/catalog.json")!

    /// Чаще раза в сутки ходить незачем — каталог меняется редко.
    static let checkInterval: TimeInterval = 60 * 60 * 24

    static func refreshIfNeeded(store: AppStore, force: Bool = false) async {
        if !force, let checked = store.catalogCheckedAt,
           Date().timeIntervalSince(checked) < checkInterval {
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        if let etag = store.catalogETag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            return // сети нет — попробуем в следующий запуск
        }

        store.markCatalogChecked()

        // 304 — каталог не менялся с прошлого раза.
        guard http.statusCode == 200,
              let catalog = try? JSONDecoder().decode(CatalogFile.self, from: data) else {
            return
        }

        store.applyCatalog(catalog, etag: http.value(forHTTPHeaderField: "ETag"))
    }
}
