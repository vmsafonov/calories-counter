import Foundation

/// Стартовое наполнение базы. Берётся из вшитого снимка каталога
/// (`Resources/catalog.json`, собирается из `catalog/catalog.csv`), дальше каталог
/// обновляется по сети — см. `CatalogService`.
///
/// Это справочник для поиска, а не данные пользователя: дневник и «Своя еда»
/// на чистой установке пустые.
enum SeedData {
    static var foods: [Food] {
        CatalogFile.bundled()?.products.map { $0.makeFood() } ?? []
    }

    static var bundledRevision: String? {
        CatalogFile.bundled()?.revision
    }
}
