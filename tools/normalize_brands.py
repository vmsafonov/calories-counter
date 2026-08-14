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
_STRIP = re.compile(r"[\s\"'" + chr(0x2018) + chr(0x2019) + chr(0x201C) + chr(0x201D) + r"«»„\-–—_.,]")


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

    had_bom = CSV_PATH.read_bytes().startswith(b"\xef\xbb\xbf")

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

    # Сохраняем BOM, если он был в исходнике: без него Excel не распознаёт кириллицу.
    write_encoding = "utf-8-sig" if had_bom else "utf-8"
    with CSV_PATH.open("w", encoding=write_encoding, newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(new_rows)
    print(f"\nПереписан {CSV_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
