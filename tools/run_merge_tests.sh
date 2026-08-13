#!/bin/bash
# Прогон тестов слияния каталога (ios/Tests/CatalogMergeTests).
#
# В проекте нет тестового таргета, а заводить его — значит править project.pbxproj.
# Поэтому чистая функция CatalogMerge.merge собирается отдельным бинарём из тех же
# исходников приложения и проверяется напрямую. Тесты лежат вне папки KBZHU, поэтому
# в само приложение не попадают.
#
# Запуск: tools/run_merge_tests.sh

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="$root/ios/KBZHU"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

# -O обязателен: тест скорости отделяет индексы от линейного перебора, и на неоптимизированной
# сборке пороги не имеют смысла.
swiftc -O -o "$out/merge_tests" \
    "$app/Models/Food.swift" \
    "$app/Models/RussianText.swift" \
    "$app/Models/Catalog.swift" \
    "$app/Store/CatalogMerge.swift" \
    "$root/ios/Tests/CatalogMergeTests/main.swift"

"$out/merge_tests"
