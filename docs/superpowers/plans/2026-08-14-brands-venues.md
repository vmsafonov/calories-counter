# Производители: дедупликация, вкладка, заведения — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Спека:** `docs/superpowers/specs/2026-08-14-brands-venues-design.md`

**Goal:** Свести дубли написаний производителей в `catalog.csv` к канону без смены `id` товаров, добавить признак заведения (колонка `тип`), сделать четвёртую вкладку «Производители» на экране добавления еды и удалить workflow `ios.yml`.

**Architecture:** Чистка — в данных: скрипт `tools/normalize_brands.py` с явным словарём канонов переписывает `catalog.csv`, `build_catalog.py` получает защиту от возврата дублей. Признак `тип=ресторан` едет по цепочке CSV → JSON (`kind`) → `CatalogProduct` → `Food.isVenue`. Логика вкладки — чистые функции в `BrandList` рядом с `CatalogMerge`, проверяются тем же харнессом `tools/run_merge_tests.sh`.

**Tech Stack:** Python 3 (stdlib: csv, unittest), Swift/SwiftUI, swiftc-харнесс без тестового таргета.

## Global Constraints

- Коммиты: краткая первая строка на русском, без Co-Authored-By (стиль репозитория).
- Работа в ветке `feat/brands-venues` от `main`.
- `catalog.csv` — источник правды; группировок написаний в приложении нет.
- `id` ни одного существующего товара не меняется: где канон меняет slug — прежний `id` прописывается в колонку `id`.
- Публикация каталога не трогается: `catalog.yml`, `CatalogService`, сетевое обновление остаются как есть.
- Допустимые значения колонки `тип`: `ресторан` либо пусто; незнакомое значение роняет сборку.
- Проект Xcode использует file-system-synchronized groups: новые Swift-файлы подхватываются без правки `project.pbxproj`.
- Python-тесты: `python3 tools/test_catalog_tools.py`. Swift-тесты: `tools/run_merge_tests.sh`. Сборка приложения: `xcodebuild -project ios/KBZHU.xcodeproj -scheme KBZHU -sdk iphonesimulator -configuration Debug build`.

---

### Task 0: Ветка и хвост спеки

**Files:**
- Modify: `docs/superpowers/specs/2026-08-14-brands-venues-design.md` (правка уже в рабочей копии, не закоммичена)

- [ ] **Step 1: Создать ветку и закоммитить правку спеки**

```bash
cd /Users/user/Documents/calories-counter
git checkout -b feat/brands-venues
git add docs/superpowers/specs/2026-08-14-brands-venues-design.md
git commit -m "Спека: канон Fruittella вместо Fruit-tella"
```

---

### Task 1: Скрипт нормализации производителей

**Files:**
- Create: `tools/normalize_brands.py`
- Create: `tools/test_catalog_tools.py`

**Interfaces:**
- Produces: `normalize_key(brand: str) -> str` — ключ группировки; `CANON: dict[str, str]` — ключ → каноническое написание; `GUESSED: set[str]` — ключи, где канон угадан; `apply_canon(header: list[str], rows: list[list[str]]) -> tuple[list[list[str]], list[str]]` — чистая функция: возвращает переписанные строки и таблицу замен для вычитки, кидает `SystemExit` на группе без канона. Task 3 импортирует `normalize_key` в `build_catalog.py`.

- [ ] **Step 1: Написать падающие тесты**

Создать `tools/test_catalog_tools.py`:

```python
#!/usr/bin/env python3
"""Тесты инструментов каталога: нормализация производителей и сборщик.

Запуск: python3 tools/test_catalog_tools.py
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import normalize_brands
from normalize_brands import CANON, apply_canon, normalize_key

HEADER = ["название", "производитель", "ккал_100г", "белки_100г", "жиры_100г",
          "углеводы_100г", "единица", "вес_единицы_г", "порция_по_умолчанию_г",
          "штрихкод", "id"]


def row(name, brand, product_id=""):
    return [name, brand, "100", "1", "2", "3", "", "", "", "", product_id]


class NormalizeKeyTests(unittest.TestCase):
    def test_variants_collapse_to_one_key(self):
        self.assertEqual(normalize_key("Lay's"), normalize_key("Lays"))
        self.assertEqual(normalize_key("Lay's"), normalize_key("Lay’s"))
        self.assertEqual(normalize_key("Зелёная линия"), normalize_key("Зеленая Линия"))
        self.assertEqual(normalize_key("Sen Soy"), normalize_key("SenSoy"))
        self.assertEqual(normalize_key("Агро-Альянс"), normalize_key("агро альянс"))

    def test_different_brands_stay_apart(self):
        self.assertNotEqual(normalize_key("Danone"), normalize_key("Добрый"))


class CanonTests(unittest.TestCase):
    def test_canon_is_official_not_most_frequent(self):
        # «Вкусвилл» встречается 55 раз против 23 у «ВкусВилл», но канон — официальное.
        self.assertEqual(CANON[normalize_key("Вкусвилл")], "ВкусВилл")

    def test_canon_keys_are_normalized(self):
        for key in CANON:
            self.assertEqual(key, normalize_key(key), f"ключ не нормализован: {key!r}")


class ApplyCanonTests(unittest.TestCase):
    def test_variant_replaced_with_canon(self):
        rows = [row("Творог", "Вкусвилл"), row("Кефир", "ВкусВилл")]
        new_rows, _ = apply_canon(HEADER, rows)
        self.assertEqual(new_rows[0][1], "ВкусВилл")
        self.assertEqual(new_rows[1][1], "ВкусВилл")

    def test_id_pinned_when_slug_changes(self):
        rows = [row("Чипсы", "Lays")]
        new_rows, _ = apply_canon(HEADER, rows)
        self.assertEqual(new_rows[0][1], "Lay's")
        self.assertEqual(new_rows[0][10], "chipsy-lays")  # прежний id сохранён

    def test_id_untouched_when_slug_same(self):
        rows = [row("Творог", "Вкусвилл")]
        new_rows, _ = apply_canon(HEADER, rows)
        self.assertEqual(new_rows[0][10], "")  # slugify и так давал одинаковый id

    def test_explicit_id_never_overwritten(self):
        rows = [row("Чипсы", "Lays", product_id="моё-имя")]
        new_rows, _ = apply_canon(HEADER, rows)
        self.assertEqual(new_rows[0][10], "моё-имя")

    def test_unknown_group_fails(self):
        rows = [row("Батончик", "Xbrand"), row("Печенье", "XBrand")]
        with self.assertRaises(SystemExit):
            apply_canon(HEADER, rows)

    def test_single_spelling_not_in_canon_passes_through(self):
        rows = [row("Хлеб", "Коломенское")]
        new_rows, _ = apply_canon(HEADER, rows)
        self.assertEqual(new_rows[0][1], "Коломенское")


if __name__ == "__main__":
    unittest.main(verbosity=1)
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `python3 tools/test_catalog_tools.py`
Expected: FAIL — `ModuleNotFoundError: No module named 'normalize_brands'`

- [ ] **Step 3: Написать `tools/normalize_brands.py`**

```python
#!/usr/bin/env python3
"""Приводит написания производителей в catalog.csv к канону.

Данные из Open Food Facts народные, поэтому один бренд записан по-разному
(«Вкусвилл» и «ВкусВилл»). Скрипт сводит такие написания к каноническому по
явному словарю CANON и следит, чтобы id товара не менялся: если смена написания
меняет slug, прежний id прописывается в колонку id.

Запуск:
  python3 tools/normalize_brands.py          # показать таблицу замен, ничего не писать
  python3 tools/normalize_brands.py --apply  # переписать catalog.csv
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "catalog" / "catalog.csv"

# Написания считаются одним производителем, если совпадают после нижнего регистра,
# замены ё на е и удаления пробелов, кавычек, апострофов, дефисов, подчёркиваний,
# точек и запятых.
_STRIP = re.compile(r"[\s\"'’«»„“\-–—_.,]")


def normalize_key(brand: str) -> str:
    return _STRIP.sub("", brand.lower().replace("ё", "е"))


# Канон — официальное написание бренда, а не самое частое: «Вкусвилл» встречается
# чаще, но официальное — «ВкусВилл». Где официальное написание достоверно
# неизвестно, взято самое частое из таблицы; такие ключи собраны в GUESSED.
CANON: dict[str, str] = {
    "ahmadtea": "Ahmad Tea",
    "alpro": "Alpro",
    "belvita": "belVita",
    "bioбаланс": "Bio Баланс",
    "cheetos": "Cheetos",
    "cookchart": "Cook Chart",
    "creativekitchen": "Creative Kitchen",
    "danone": "Danone",
    "epica": "Epica",
    "exponenta": "Exponenta",
    "fitnessshock": "Fitness Shock",
    "fruittella": "Fruittella",
    "gbalance": "G-Balance",
    "goodmix": "Goodmix",
    "heinz": "Heinz",
    "kclassic": "K-Classic",
    "kerlli": "Kerlli",
    "lays": "Lay's",
    "letsgo": "Let's Go",
    "m&ms": "M&M'S",
    "makfa": "Makfa",
    "mixbar": "Mix Bar",
    "orion": "Orion",
    "ozonfresh": "Ozon fresh",
    "planto": "Planto",
    "president": "President",
    "sensoy": "Sen Soy",
    "snaqfabriq": "Snaq Fabriq",
    "snickers": "Snickers",
    "spar": "SPAR",
    "vkusvill": "VkusVill",
    "агроальянс": "Агро-Альянс",
    "актибио": "АктиБио",
    "бабаевский": "Бабаевский",
    "вдохновение": "Вдохновение",
    "вкусвилл": "ВкусВилл",
    "вкусипольза": "Вкус и польза",
    "вкустех": "Вкустех",
    "горячаяштучка": "Горячая Штучка",
    "добрый": "Добрый",
    "домиквдеревне": "Домик в деревне",
    "зеленаялиния": "Зелёная линия",
    "зеленыйлуг": "Зелёный луг",
    "индилайт": "Индилайт",
    "кириешки": "Кириешки",
    "краснаяцена": "Красная цена",
    "красныйоктябрь": "Красный Октябрь",
    "московскийкартофель": "Московский картофель",
    "павапава": "Пава-Пава",
    "папаможет": "Папа может",
    "первымделом": "Первым делом",
    "перекресток": "Перекрёсток",
    "перекрестокselect": "Перекрёсток Select",
    "пятерочка": "Пятёрочка",
    "пятерочкакафе": "Пятёрочка Кафе",
    "рамонтипайз": "Рамонти Пайз",
    "русскоеморе": "Русское море",
    "садыпридонья": "Сады Придонья",
    "самиготовим": "Сами Готовим",
    "самокат": "Самокат",
    "свежеезавтра": "Свежее Завтра",
    "светаево": "Светаево",
    "селозеленое": "Село Зелёное",
    "фэг": "ФЭГ",
    "хлебныйдом": "Хлебный Дом",
    "черемушки": "Черёмушки",
    "щелковохлеб": "Щёлково хлеб",
    "экомилк": "Экомилк",
    "яндекславка": "Яндекс Лавка",
    "ясносолнышко": "Ясно солнышко",
    "яшкино": "Яшкино",
}

# Группы, где официальное написание — предположение (взято самое частое либо
# самое аккуратное из вариантов). Показываются в таблице с пометкой.
GUESSED: set[str] = {
    "cookchart", "creativekitchen", "epica", "fitnessshock", "gbalance",
    "goodmix", "kerlli", "letsgo", "orion", "snaqfabriq", "snickers",
    "вкусипольза", "вкустех", "зеленыйлуг", "индилайт", "московскийкартофель",
    "павапава", "первымделом", "рамонтипайз", "самиготовим", "свежеезавтра",
    "фэг", "щелковохлеб", "ясносолнышко",
}


def _column(header: list[str], name: str) -> int:
    for index, cell in enumerate(header):
        if (cell or "").strip().lower().lstrip("﻿") == name:
            return index
    sys.exit(f"в заголовке нет колонки «{name}»")


def apply_canon(header: list[str], rows: list[list[str]]) -> tuple[list[list[str]], list[str]]:
    """Возвращает (переписанные строки, таблица замен для вычитки).

    Падает (SystemExit), если нашлась группа из нескольких написаний, для которой
    в CANON нет канона: молча выбирать нельзя.
    """
    from build_catalog import slugify  # импорт здесь, чтобы не зациклить модули

    name_col = _column(header, "название")
    brand_col = _column(header, "производитель")
    id_col = _column(header, "id")

    spellings: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    for line in rows:
        brand = (line[brand_col] or "").strip() if len(line) > brand_col else ""
        if brand:
            spellings[normalize_key(brand)][brand] += 1

    uncovered = [variants for key, variants in spellings.items()
                 if len(variants) > 1 and key not in CANON]
    if uncovered:
        print("Группы без канона в CANON — дополните словарь:", file=sys.stderr)
        for variants in uncovered:
            print("  • " + " | ".join(sorted(variants)), file=sys.stderr)
        raise SystemExit(1)

    table: list[str] = []
    for key, variants in sorted(spellings.items()):
        canon = CANON.get(key)
        if canon is None or set(variants) == {canon}:
            continue
        mark = "  (предположение)" if key in GUESSED else ""
        listed = " | ".join(f"{spelling} ({count})" for spelling, count
                            in sorted(variants.items(), key=lambda item: -item[1]))
        table.append(f"{listed}  →  {canon}{mark}")

    new_rows: list[list[str]] = []
    for line in rows:
        line = list(line)
        brand = (line[brand_col] or "").strip() if len(line) > brand_col else ""
        canon = CANON.get(normalize_key(brand)) if brand else None
        if canon and brand != canon:
            name = (line[name_col] or "").strip()
            current_id = (line[id_col] or "").strip() if len(line) > id_col else ""
            old_slug = current_id or slugify(f"{name}-{brand}")
            new_slug = slugify(f"{name}-{canon}")
            if not current_id and old_slug != new_slug:
                while len(line) <= id_col:
                    line.append("")
                line[id_col] = old_slug  # прежний id, чтобы товар не «переехал»
            line[brand_col] = canon
        new_rows.append(line)

    return new_rows, table


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="переписать catalog.csv")
    args = parser.parse_args()

    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle)
        header = next(reader)
        rows = list(reader)

    new_rows, table = apply_canon(header, rows)

    if not table:
        print("Дублей написаний нет — таблица чистая")
        return

    print(f"Замен: {len(table)}\n")
    for line in table:
        print("  " + line)

    if not args.apply:
        print("\nЭто прогон без записи. Применить: python3 tools/normalize_brands.py --apply")
        return

    with CSV_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(new_rows)
    print(f"\nПереписан {CSV_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Прогнать тесты**

Run: `python3 tools/test_catalog_tools.py`
Expected: PASS (все тесты зелёные)

- [ ] **Step 5: Commit**

```bash
git add tools/normalize_brands.py tools/test_catalog_tools.py
git commit -m "Скрипт нормализации производителей со словарём канонов"
```

---

### Task 2: Вычитка и применение к данным ⛔ КОНТРОЛЬНАЯ ТОЧКА

**Files:**
- Modify: `catalog/catalog.csv`
- Modify: `ios/KBZHU/Resources/catalog.json` (перегенерация)

- [ ] **Step 1: Прогон без записи**

Run: `python3 tools/normalize_brands.py`
Expected: таблица ~71 замены, включая `Вкусвилл (55) | ВкусВилл (23) → ВкусВилл` и `Lays → Lay's`. Если скрипт упал с «группы без канона» — дополнить CANON и вернуться к Task 1 Step 4.

- [ ] **Step 2: ⛔ ОСТАНОВИТЬСЯ — показать таблицу пользователю**

Показать полную таблицу замен (особенно строки с пометкой «предположение») и ждать подтверждения. По спеке вычитка перед применением обязательна. Не продолжать без явного «ок».

- [ ] **Step 3: Применить и пересобрать каталог**

```bash
python3 tools/normalize_brands.py --apply
python3 tools/build_catalog.py
```

Expected: catalog.csv переписан; build_catalog печатает `1562 продуктов, ревизия <новая>` без ошибок.

- [ ] **Step 4: Проверить сохранность id**

```bash
python3 - <<'EOF'
import json
new = {p["id"] for p in json.load(open("ios/KBZHU/Resources/catalog.json"))["products"]}
import subprocess
old_raw = subprocess.run(["git", "show", "HEAD:ios/KBZHU/Resources/catalog.json"],
                         capture_output=True, text=True, check=True).stdout
old = {p["id"] for p in json.loads(old_raw)["products"]}
print("пропавших id:", sorted(old - new) or "нет")
print("новых id:", sorted(new - old) or "нет")
EOF
```

Expected: `пропавших id: нет` и `новых id: нет` — миграция нулевая. Если что-то пропало — стоп, разбираться, к пользователю с находкой.

- [ ] **Step 5: Commit**

```bash
git add catalog/catalog.csv ios/KBZHU/Resources/catalog.json
git commit -m "Написания производителей сведены к канону"
```

---

### Task 3: Защита от возврата дублей в сборщике

**Files:**
- Modify: `tools/build_catalog.py` (функция `build()`, после цикла по строкам)
- Modify: `tools/test_catalog_tools.py`
- Modify: `catalog/README.md`

**Interfaces:**
- Consumes: `normalize_key` из `tools/normalize_brands.py` (Task 1).

- [ ] **Step 1: Написать падающий тест**

Добавить в `tools/test_catalog_tools.py`:

```python
import tempfile

import build_catalog


def run_build_on(csv_text: str):
    """Прогоняет build() на временной таблице; возвращает результат build()."""
    tmp = Path(tempfile.mkdtemp())
    (tmp / "catalog.csv").write_text(csv_text, encoding="utf-8")
    old_csv, old_xlsx = build_catalog.CSV_PATH, build_catalog.XLSX_PATH
    build_catalog.CSV_PATH = tmp / "catalog.csv"
    build_catalog.XLSX_PATH = tmp / "нет-такого.xlsx"
    try:
        return build_catalog.build()
    finally:
        build_catalog.CSV_PATH, build_catalog.XLSX_PATH = old_csv, old_xlsx


CSV_HEAD = "название,производитель,ккал_100г,белки_100г,жиры_100г,углеводы_100г,единица,вес_единицы_г,порция_по_умолчанию_г,штрихкод,id\n"


class DuplicateSpellingGuardTests(unittest.TestCase):
    def test_two_spellings_of_one_brand_fail_build(self):
        csv_text = CSV_HEAD + (
            "Творог,Вкусвилл,100,1,2,3,,,,,\n"
            "Кефир,ВкусВилл,50,3,2,4,,,,,\n"
        )
        with self.assertRaises(SystemExit):
            run_build_on(csv_text)

    def test_single_spelling_passes(self):
        csv_text = CSV_HEAD + (
            "Творог,ВкусВилл,100,1,2,3,,,,,\n"
            "Кефир,ВкусВилл,50,3,2,4,,,,,\n"
        )
        catalog = run_build_on(csv_text)
        self.assertEqual(len(catalog["products"]), 2)
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `python3 tools/test_catalog_tools.py`
Expected: FAIL — `test_two_spellings_of_one_brand_fail_build` (сборка проходит, SystemExit не поднят)

- [ ] **Step 3: Добавить проверку в `build()`**

В `tools/build_catalog.py` — вверху файла, после существующих импортов:

```python
from normalize_brands import normalize_key
```

В `build()`, в цикле сразу после вычисления `manufacturer` — копить написания, а после цикла (перед `if errors:`) — проверять:

```python
    # ...внутри цикла, рядом с manufacturer:
        if manufacturer:
            brand_spellings.setdefault(normalize_key(manufacturer), set()).add(manufacturer)
```

Инициализация рядом с `seen_ids`:

```python
    brand_spellings: dict[str, set[str]] = {}
```

После цикла, перед `if errors:`:

```python
    # Один производитель — одно написание. Иначе варианты наползут снова
    # при следующем импорте из Open Food Facts.
    for spellings in brand_spellings.values():
        if len(spellings) > 1:
            listed = "», «".join(sorted(spellings))
            errors.append(
                f"производитель записан по-разному: «{listed}». "
                "Сведите к одному написанию: tools/normalize_brands.py"
            )
```

- [ ] **Step 4: Прогнать тесты и реальную сборку**

Run: `python3 tools/test_catalog_tools.py && python3 tools/build_catalog.py --check`
Expected: тесты PASS; `Каталог актуален` (данные уже очищены в Task 2, защита не срабатывает)

- [ ] **Step 5: Задокументировать правило в `catalog/README.md`**

В раздел «Правила, о которых стоит помнить» добавить абзац:

```markdown
**Один производитель — одно написание.** Сборка упадёт, если один бренд записан
по-разному («Вкусвилл» и «ВкусВилл»). Канон ведётся словарём в
`tools/normalize_brands.py`: дополните словарь и запустите
`python3 tools/normalize_brands.py --apply`.
```

- [ ] **Step 6: Commit**

```bash
git add tools/build_catalog.py tools/test_catalog_tools.py catalog/README.md
git commit -m "Сборка падает при двух написаниях одного производителя"
```

---

### Task 4: Колонка «тип» в таблице и сборщике

**Files:**
- Modify: `tools/build_catalog.py` (COLUMNS, `build()`)
- Modify: `tools/test_catalog_tools.py`
- Modify: `catalog/catalog.csv` (заголовок + 5 строк заведений)
- Modify: `ios/KBZHU/Resources/catalog.json` (перегенерация)
- Modify: `catalog/README.md`

**Interfaces:**
- Produces: в JSON продукта появляется необязательное поле `"kind": "ресторан"`. Task 5 декодирует его в `CatalogProduct.kind`.

- [ ] **Step 1: Написать падающие тесты**

Добавить в `tools/test_catalog_tools.py`:

```python
CSV_HEAD_KIND = (
    "название,производитель,ккал_100г,белки_100г,жиры_100г,углеводы_100г,единица,"
    "вес_единицы_г,порция_по_умолчанию_г,штрихкод,id,тип\n"
)


class KindColumnTests(unittest.TestCase):
    def test_restaurant_kind_lands_in_json(self):
        csv_text = CSV_HEAD_KIND + "Шефбургер,Rostic’s,211,12.9,6.6,25.1,,,,,,ресторан\n"
        catalog = run_build_on(csv_text)
        self.assertEqual(catalog["products"][0]["kind"], "ресторан")

    def test_empty_kind_absent_from_json(self):
        csv_text = CSV_HEAD_KIND + "Творог,ВкусВилл,100,1,2,3,,,,,,\n"
        catalog = run_build_on(csv_text)
        self.assertNotIn("kind", catalog["products"][0])

    def test_unknown_kind_fails_build(self):
        csv_text = CSV_HEAD_KIND + "Шаурма,Ларёк,250,10,15,20,,,,,,кафе\n"
        with self.assertRaises(SystemExit):
            run_build_on(csv_text)

    def test_table_without_kind_column_still_builds(self):
        csv_text = CSV_HEAD + "Творог,ВкусВилл,100,1,2,3,,,,,\n"
        catalog = run_build_on(csv_text)
        self.assertEqual(len(catalog["products"]), 1)
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `python3 tools/test_catalog_tools.py`
Expected: FAIL — `KeyError: 'kind'` в `test_restaurant_kind_lands_in_json`; `test_unknown_kind_fails_build` тоже красный

- [ ] **Step 3: Реализовать в `build_catalog.py`**

В `COLUMNS` добавить строку:

```python
    "kind": {"тип", "kind", "type"},
```

Рядом с `UNITS` завести допустимые значения:

```python
# Типы позиций. Пусто — обычная упаковка; «ресторан» — блюдо сети питания.
KINDS = {"ресторан"}
```

В `build()`, после блока с `unit` (валидация тем же стилем):

```python
        kind = (row.get("kind") or "").strip().lower()
        if kind and kind not in KINDS:
            errors.append(f"строка {line}: тип «{kind}» неизвестен, допустимы: {', '.join(sorted(KINDS))}")
            continue
```

И в сборке словаря продукта, рядом с `if barcode:`:

```python
        if kind:
            product["kind"] = kind
```

- [ ] **Step 4: Прогнать тесты**

Run: `python3 tools/test_catalog_tools.py`
Expected: PASS

- [ ] **Step 5: Пометить заведения в таблице**

В `catalog/catalog.csv`:
1. К заголовку дописать `,тип`.
2. Пять строк заведений (после Task 2 «Пятерочка Кафе» уже переписана как «Пятёрочка Кафе») получают `,,ресторан` в конце — пустой `id` плюс тип. Найти их: `grep -n "Бургер Кинг\|Пятёрочка Кафе\|Rostic" catalog/catalog.csv`. Ожидаемые строки: «Сырные Медальоны Замороженные» (Бургер Кинг), «Жаркое из свинины», «Сэндвич С Тунцом», «Панини С Курицей» (Пятёрочка Кафе), «Шефбургер Сальса» (Rostic’s).

Пример итоговой строки:

```
Сырные Медальоны Замороженные,Бургер Кинг,287.8,7.5,13.0,35.2,,,,4606993000742,,ресторан
```

(У строк без типа хвост можно не дописывать: короткая строка в CSV читается как пустые значения.)

- [ ] **Step 6: Пересобрать каталог и проверить**

```bash
python3 tools/build_catalog.py
python3 -c "
import json
products = json.load(open('ios/KBZHU/Resources/catalog.json'))['products']
venues = [p['name'] for p in products if p.get('kind') == 'ресторан']
print(len(venues), venues)"
```

Expected: `5` позиций-заведений, ошибок сборки нет.

- [ ] **Step 7: Задокументировать колонку в `catalog/README.md`**

В таблицу колонок добавить строку:

```markdown
| `тип` | нет | `ресторан` — блюдо сети питания, показывается с пометкой «Заведение». Пусто — обычная упаковка |
```

И абзац после таблицы (рядом с правилом про 100 г):

```markdown
У блюд заведений меню обычно публикует КБЖУ на порцию, а таблица хранит строго
на 100 г: заполните `единица=порция` и `вес_единицы_г`, а КБЖУ пересчитайте.
```

- [ ] **Step 8: Commit**

```bash
git add tools/build_catalog.py tools/test_catalog_tools.py catalog/catalog.csv ios/KBZHU/Resources/catalog.json catalog/README.md
git commit -m "Колонка «тип»: признак заведения едет из таблицы в JSON"
```

---

### Task 5: Признак заведения в приложении

**Files:**
- Modify: `ios/KBZHU/Models/Catalog.swift`
- Modify: `ios/KBZHU/Models/Food.swift`
- Test: `ios/Tests/CatalogMergeTests/main.swift`

**Interfaces:**
- Consumes: JSON-поле `"kind": "ресторан"` (Task 4).
- Produces: `CatalogProduct.kind: String?`, `CatalogProduct.isVenue: Bool`, `Food.isVenue: Bool` (default `false`, толерантный декодинг). Task 6 и Task 7 читают `Food.isVenue`.

- [ ] **Step 1: Написать падающие тесты**

В `ios/Tests/CatalogMergeTests/main.swift` расширить хелпер `product(...)` параметром `kind`:

```swift
func product(id: String, name: String, brand: String = "", kcal: Double = 100,
             protein: Double = 1, fat: Double = 2, carbs: Double = 3,
             barcode: String? = nil, kind: String? = nil) -> CatalogProduct {
    let json = """
    {"id":"\(id)","name":"\(name)","manufacturer":"\(brand)","kcal":\(kcal),
     "protein":\(protein),"fat":\(fat),"carbs":\(carbs)\
    \(barcode.map { ",\"barcode\":\"\($0)\"" } ?? "")\
    \(kind.map { ",\"kind\":\"\($0)\"" } ?? "")}
    """
    // остальное тело хелпера без изменений
```

И добавить сьют (перед финальным выводом результата):

```swift
suite("Признак заведения") {
    let venue = product(id: "shefburger", name: "Шефбургер", brand: "Rostic’s", kind: "ресторан")
    let merged = CatalogMerge.merge(foods: [], catalog: [venue])
    check(merged[0].isVenue, "новый продукт заведения получает isVenue")

    let again = CatalogMerge.merge(foods: merged, catalog: [venue])
    check(again[0].isVenue, "признак переживает повторное слияние")

    let becamePackaged = product(id: "shefburger", name: "Шефбургер", brand: "Rostic’s")
    let updated = CatalogMerge.merge(foods: merged, catalog: [becamePackaged])
    check(!updated[0].isVenue, "обновление без kind снимает признак")

    let plain = product(id: "tvorog", name: "Творог")
    let notVenue = CatalogMerge.merge(foods: [], catalog: [plain])
    check(!notVenue[0].isVenue, "обычный продукт — не заведение")
}
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `tools/run_merge_tests.sh`
Expected: ошибка компиляции — у `CatalogProduct`/`Food` нет `kind`/`isVenue`

- [ ] **Step 3: Реализовать**

`ios/KBZHU/Models/Catalog.swift`, в `CatalogProduct`:

```swift
    /// «ресторан» — блюдо сети питания. Пусто — обычная упаковка.
    var kind: String?

    var isVenue: Bool { kind == "ресторан" }
```

В `makeFood()` добавить аргумент `isVenue: isVenue` (после `isRetired: false`), в `applied(to:)` — строку `updated.isVenue = isVenue` (рядом с `updated.isRetired = false`).

`ios/KBZHU/Models/Food.swift`, в `Food`:
- свойство после `isRetired`:

```swift
    /// Блюдо сети питания — на вкладке производителей помечается «Заведение».
    var isVenue: Bool = false
```

- в `init(from:)` после строки с `isRetired`:

```swift
        isVenue = try box.decodeIfPresent(Bool.self, forKey: .isVenue) ?? false
```

- в основном `init` — параметр `isVenue: Bool = false` (после `isRetired: Bool = false`) и присваивание `self.isVenue = isVenue`.

- [ ] **Step 4: Прогнать тесты**

Run: `tools/run_merge_tests.sh`
Expected: PASS, включая старые сьюты (толерантный декодинг не сломан)

- [ ] **Step 5: Commit**

```bash
git add ios/KBZHU/Models/Catalog.swift ios/KBZHU/Models/Food.swift ios/Tests/CatalogMergeTests/main.swift
git commit -m "Признак заведения проезжает каталог до Food"
```

---

### Task 6: Чистая логика списка производителей

**Files:**
- Create: `ios/KBZHU/Store/BrandList.swift`
- Modify: `tools/run_merge_tests.sh` (добавить файл в swiftc)
- Test: `ios/Tests/CatalogMergeTests/main.swift`

**Interfaces:**
- Consumes: `Food.brand`, `Food.isVenue` (Task 5).
- Produces: `struct BrandRow { var name: String; var count: Int; var isVenue: Bool }`; `BrandList.rows(foods: [Food]) -> [BrandRow]`; `BrandList.filter(_ rows: [BrandRow], query: String) -> [BrandRow]`; `BrandList.foods(of brand: String, in foods: [Food]) -> [Food]`. Task 7 строит на них вкладку.

- [ ] **Step 1: Добавить файл в харнесс**

В `tools/run_merge_tests.sh` в вызов swiftc добавить строку (после `CatalogMerge.swift`):

```bash
    "$app/Store/BrandList.swift" \
```

- [ ] **Step 2: Написать падающие тесты**

В `ios/Tests/CatalogMergeTests/main.swift` добавить сьют:

```swift
suite("Список производителей") {
    let base = CatalogMerge.merge(foods: [], catalog: [
        product(id: "t1", name: "Творог", brand: "ВкусВилл"),
        product(id: "t2", name: "Кефир", brand: "ВкусВилл"),
        product(id: "t3", name: "Сырники", brand: "ВкусВилл"),
        product(id: "s1", name: "Молоко", brand: "Самокат"),
        product(id: "s2", name: "Хлеб", brand: "Самокат"),
        product(id: "a1", name: "Каша", brand: "Аврора"),
        product(id: "r1", name: "Шефбургер", brand: "Rostic’s", kind: "ресторан"),
        product(id: "n1", name: "Домашний суп"),
    ])

    let rows = BrandList.rows(foods: base)
    check(rows.count == 4, "продукты без производителя не дают строки")
    check(rows[0].name == "Rostic’s" && rows[0].isVenue, "заведение поднято наверх")
    check(rows[1].name == "ВкусВилл" && rows[1].count == 3, "дальше — по числу товаров")
    check(rows[2].name == "Самокат" && rows[2].count == 2, "сортировка по убыванию количества")
    check(rows[3].name == "Аврора", "при одном товаре — по алфавиту")

    let found = BrandList.filter(rows, query: "вкусвилл")
    check(found.map(\.name) == ["ВкусВилл"], "поиск без учёта регистра")
    check(BrandList.filter(rows, query: "  ").map(\.name) == rows.map(\.name),
          "пустой запрос не фильтрует")

    let goods = BrandList.foods(of: "Самокат", in: base)
    check(goods.count == 2 && goods.allSatisfy { $0.brand == "Самокат" },
          "фильтр отдаёт только товары производителя")
}

suite("Алфавит и ё в списке производителей") {
    let base = CatalogMerge.merge(foods: [], catalog: [
        product(id: "b1", name: "Хлеб", brand: "Бабаевский"),
        product(id: "v1", name: "Творог", brand: "Вдохновение"),
        product(id: "z1", name: "Молоко", brand: "Зелёный луг"),
    ])
    let rows = BrandList.rows(foods: base)
    check(rows.map(\.name) == ["Бабаевский", "Вдохновение", "Зелёный луг"],
          "при равном количестве — русский алфавит")
    check(BrandList.filter(rows, query: "зеленый").map(\.name) == ["Зелёный луг"],
          "поиск не различает е и ё")
}
```

- [ ] **Step 3: Убедиться, что тесты падают**

Run: `tools/run_merge_tests.sh`
Expected: ошибка компиляции — нет файла `BrandList.swift` (swiftc не найдёт путь). Создать пустой файл нельзя — сразу к реализации.

- [ ] **Step 4: Реализовать `ios/KBZHU/Store/BrandList.swift`**

```swift
import Foundation

/// Строка вкладки «Производители»: название, число товаров, признак заведения.
struct BrandRow: Hashable {
    var name: String
    var count: Int
    var isVenue: Bool
}

/// Логика вкладки «Производители». Как и `CatalogMerge` — чистые функции без
/// состояния и диска, поэтому проверяются напрямую тем же харнессом.
enum BrandList {

    /// Список производителей по переданной базе. На вход подаётся уже отфильтрованный
    /// список (`store.baseFoods`): своя еда и пропавшие позиции сюда не попадают.
    /// Заведения первыми, дальше по числу товаров, при равенстве — по алфавиту.
    static func rows(foods: [Food]) -> [BrandRow] {
        var counts: [String: (count: Int, isVenue: Bool)] = [:]
        for food in foods {
            let name = food.brand.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let entry = counts[name] ?? (0, false)
            counts[name] = (entry.count + 1, entry.isVenue || food.isVenue)
        }
        return counts
            .map { BrandRow(name: $0.key, count: $0.value.count, isVenue: $0.value.isVenue) }
            .sorted { a, b in
                if a.isVenue != b.isVenue { return a.isVenue }
                if a.count != b.count { return a.count > b.count }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }

    /// Фильтр по подстроке названия — без учёта регистра и разницы е/ё.
    static func filter(_ rows: [BrandRow], query: String) -> [BrandRow] {
        let needle = fold(query)
        guard !needle.isEmpty else { return rows }
        return rows.filter { fold($0.name).contains(needle) }
    }

    /// Товары одного производителя, в том порядке, в котором они лежат в базе.
    static func foods(of brand: String, in foods: [Food]) -> [Food] {
        foods.filter { $0.brand.trimmingCharacters(in: .whitespaces) == brand }
    }

    private static func fold(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespaces)
    }
}
```

- [ ] **Step 5: Прогнать тесты**

Run: `tools/run_merge_tests.sh`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add ios/KBZHU/Store/BrandList.swift ios/Tests/CatalogMergeTests/main.swift tools/run_merge_tests.sh
git commit -m "Чистая логика списка производителей"
```

---

### Task 7: Вкладка «Производители» на экране добавления

**Files:**
- Modify: `ios/KBZHU/Navigation/Nav.swift` (enum `AddTab`, класс `Nav`)
- Modify: `ios/KBZHU/Screens/AddFoodScreen.swift`

**Interfaces:**
- Consumes: `BrandList.rows/filter/foods` (Task 6), `Food.isVenue` (Task 5), существующие `Chip`, `SectionCaption`, `Ru.plural`, `resultRow(_:)`.
- Produces: `Nav.selectedBrand: String?`, `Nav.brandQuery: String` — сбрасываются в `openAdd`.

- [ ] **Step 1: Расширить `AddTab` и `Nav`**

В `ios/KBZHU/Navigation/Nav.swift`, enum `AddTab`:

```swift
enum AddTab: String, CaseIterable, Hashable {
    case search, own, recent, brands

    var title: String {
        switch self {
        case .search: return "Поиск"
        case .own: return "Своя еда"
        case .recent: return "Недавние"
        case .brands: return "Производители"
        }
    }
}
```

В классе `Nav`, рядом с `addTab`:

```swift
    /// Открытый производитель на вкладке «Производители». nil — показывается список.
    @Published var selectedBrand: String?
    @Published var brandQuery = ""
```

В `openAdd(meal:)` после `addTab = .search`:

```swift
        selectedBrand = nil
        brandQuery = ""
```

- [ ] **Step 2: Ветка вкладки в `AddFoodScreen`**

В `ios/KBZHU/Screens/AddFoodScreen.swift`:

1. В `pool` добавить случай (значение не используется, пока нет запроса, но switch обязан быть полным):

```swift
        case .brands: return store.baseFoods
```

2. В `caption` добавить случай:

```swift
        case .brands: return "Производители"
```

3. В `emptyStateText` добавить случай:

```swift
        case .brands: return "База продуктов пуста."
```

4. В `list`, внутри `LazyVStack`, обернуть существующее содержимое веткой. Было: `createOwnCard`-блок, `SectionCaption`, пустое состояние, `ForEach`. Стало:

```swift
            LazyVStack(alignment: .leading, spacing: 0) {
                if nav.addTab == .brands && !hasQuery {
                    brandsSection
                } else {
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
            }
```

(Пока пользователь ищет в верхнем поле — работает прежний глобальный поиск по всей еде; вкладка не сужает выдачу, как и остальные.)

5. Добавить секцию производителей (после `createOwnCard` в файле):

```swift
    // MARK: - Вкладка «Производители»

    private var brandRows: [BrandRow] {
        BrandList.filter(BrandList.rows(foods: store.baseFoods), query: nav.brandQuery)
    }

    @ViewBuilder
    private var brandsSection: some View {
        if let brand = nav.selectedBrand {
            brandFoods(brand)
        } else {
            brandListSection
        }
    }

    private var brandListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Свой поиск: производителей 910, у большинства — один товар.
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink(0.35))
                TextField("Название производителя", text: $nav.brandQuery)
                    .golos(500, 14)
                    .foregroundStyle(Theme.ink)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Theme.softCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 10)
            .padding(.bottom, 4)

            SectionCaption(text: "Производители · \(brandRows.count)")
                .padding(.top, 14)
                .padding(.bottom, 12)

            if brandRows.isEmpty {
                Text("Никого не нашлось. Попробуйте другое название.")
                    .golos(400, 13, lineHeight: 1.5)
                    .foregroundStyle(Theme.ink(0.45))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            }

            ForEach(brandRows, id: \.self) { row in
                brandRow(row)
            }
        }
    }

    private func brandRow(_ row: BrandRow) -> some View {
        Button {
            nav.selectedBrand = row.name
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.name)
                            .golos(500, 14.5)
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Text("\(row.count) \(Ru.plural(row.count, ["товар", "товара", "товаров"]))")
                            .golos(400, 12)
                            .foregroundStyle(Theme.ink(0.42))
                    }
                    Spacer(minLength: 0)
                    if row.isVenue {
                        Text("Заведение")
                            .golos(600, 10.5)
                            .foregroundStyle(Theme.greenDark)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Theme.greenTint,
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink(0.25))
                }
                .padding(.vertical, 13)

                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func brandFoods(_ brand: String) -> some View {
        let items = BrandList.foods(of: brand, in: store.baseFoods)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                nav.selectedBrand = nil
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Производители")
                        .golos(600, 13)
                }
                .foregroundStyle(Theme.greenDark)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            SectionCaption(text: "\(brand) · \(items.count)")
                .padding(.top, 8)
                .padding(.bottom, 12)

            ForEach(items) { food in
                resultRow(food)
            }
        }
    }
```

- [ ] **Step 3: Собрать приложение**

Run: `xcodebuild -project ios/KBZHU.xcodeproj -scheme KBZHU -sdk iphonesimulator -configuration Debug build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Прогнать Swift-тесты (регрессия)**

Run: `tools/run_merge_tests.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add ios/KBZHU/Navigation/Nav.swift ios/KBZHU/Screens/AddFoodScreen.swift
git commit -m "Вкладка «Производители» на экране добавления"
```

---

### Task 8: Убрать workflow ios.yml

**Files:**
- Delete: `.github/workflows/ios.yml`

- [ ] **Step 1: Удалить и закоммитить**

```bash
git rm .github/workflows/ios.yml
git commit -m "Удалён workflow сборки в симуляторе"
```

(`catalog.yml` не трогать — публикация каталога остаётся. Причина смерти ios.yml — захардкоженный `com.example.kbzhu` при сменённом bundle id; чинить не стали, спека велит удалить.)

---

### Task 9: Финальная проверка

- [ ] **Step 1: Все тесты разом**

```bash
python3 tools/test_catalog_tools.py && tools/run_merge_tests.sh && python3 tools/build_catalog.py --check
```

Expected: всё зелёное, `Каталог актуален`.

- [ ] **Step 2: Сверка со спекой**

Пройтись по спеке: дедупликация в данных (Task 1–2), защита сборки (Task 3), колонка тип (Task 4–5), вкладка с поиском и заведениями наверху (Task 6–7), CI (Task 8). Публикация не тронута: `catalog.yml`, `CatalogService`, `AppData` — без изменений (`git diff main --stat` не должен их показывать).

- [ ] **Step 3: Завершение ветки**

REQUIRED SUB-SKILL: `superpowers:finishing-a-development-branch` — пуш `feat/brands-venues`, PR в `main`.
