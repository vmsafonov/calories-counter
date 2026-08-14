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
# точек, запятых и значков ®/™/©.
_STRIP = re.compile(r"[\s\"'" + chr(0x2018) + chr(0x2019) + chr(0x201C) + chr(0x201D)
                    + r"«»„\-–—_.,®™©]")

# Кавычки, которыми обрамляют название после юрформы.
_QUOTES = "\"'" + chr(0x2018) + chr(0x2019) + chr(0x201C) + chr(0x201D) + "«»„"

# Организационно-правовые формы: в поле «производитель» они мусор, бренд — то, что дальше.
# «ООО "Марс"» и «Марс» — один производитель, а «АО "» — вовсе не производитель.
_LEGAL = re.compile(r"^(ооо|оао|зао|пао|ао|ип|тд|пк)\b\.?\s*", re.IGNORECASE)


def normalize_key(brand: str) -> str:
    return _STRIP.sub("", brand.lower().replace("ё", "е"))


def strip_noise(brand: str) -> str:
    """Убирает юрформу, обрамляющие кавычки и значки ®/™/© — то, что не бренд.

    «ПАО "Красный Октябрь"» → «Красный Октябрь», «SNICKERS®» → «SNICKERS»,
    «АО "» → «» (пустая строка: производитель неизвестен).
    """
    text = brand.replace("®", "").replace("™", "").replace("©", "")
    text = re.sub(r"\s+", " ", text).strip()
    # Юрформ может быть несколько подряд: «ООО ПК "Айсберг-Люкс"».
    while True:
        stripped = _LEGAL.sub("", text, count=1).strip()
        if stripped == text:
            break
        text = stripped
    # Кавычки снимаем только парные снаружи: иначе «Россия» — щедрая душа! теряет
    # открывающую и остаётся с висящей закрывающей.
    # Внутренние кавычки означают, что строка закавычена криво («"Винзавод "Дионис"»);
    # такую не трогаем, иначе потеряется закрывающая.
    while (len(text) >= 2 and text[0] in _QUOTES and text[-1] in _QUOTES
           and not any(ch in _QUOTES for ch in text[1:-1])):
        text = text[1:-1].strip()
    # От «АО "» после юрформы остаются одни кавычки — это не производитель.
    if not any(ch.isalnum() for ch in text):
        return ""
    return text


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
    "storck": "Storck",
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

# Склейки из Open Food Facts: там поле brands — список через запятую, при импорте
# он слился в одну строку («Самокат Вкусвилл Ана Райз»), либо к бренду прилип вкус
# или слоган («Добрый Мультифрукт», «У Палыча Всегда Вкусно»). Ключ — исходное
# написание, значение — бренд, к которому строка относится.
#
# Сюда попадает только то, что разобрано глазами. Настоящие суб-бренды —
# «Пятёрочка Кафе», «Перекрёсток Select», «Яндекс Лавка» — остаются отдельными.
_ALIAS_SOURCES: dict[str, str] = {
    "Самокат Вкусвилл Ана Райз": "ВкусВилл",
    "Лавка Яндекс": "Яндекс Лавка",
    "Маркет Перекрёсток": "Перекрёсток",
    "EPICA персик-маракуйя": "Epica",
    "Epica Flavorite": "Epica",
    "Добрый Мультифрукт": "Добрый",
    "Snickers Криспер": "Snickers",
    "Pringles Alexa": "Pringles",
    "У Палыча Всегда Вкусно": "У Палыча",
    "August Storck": "Storck",
    "ООО \"КДВ Воронеж\" (KDV)": "КДВ Воронеж",
}

# Один бренд, записанный кириллицей и латиницей: в Open Food Facts карточки заводят
# и так, и так, а normalize_key их не сводит — это разные буквы, не разные написания.
# Для российских марок канон кириллический (он же на упаковке), для международных
# оставлен латинский — тот, что уже выбран в CANON.
_TRANSLIT_SOURCES: dict[str, str] = {
    "VkusVill": "ВкусВилл",
    "Aktibio": "АктиБио",
    "АКTИБИО": "АктиБио",          # с латинской T в середине
    "Pobeda": "Победа",
    "Yashkino": "Яшкино",
    "Sloboda": "Слобода",
    "Kommunarka": "Коммунарка",
    "Korovka": "Коровка",
    "КОРОВКА": "Коровка",
    "Iskrenne Vash": "Искренне Ваш",
    "molvest": "Молвест",
    "Santa Bremor": "Санта Бремор",
    "Ferma": "Ферма",
    "Doshirak": "Доширак",
    "svalya": "Сваля",
    "Burger King": "Бургер Кинг",
    "Макфа": "Makfa",
    "Марс": "Mars",
    "Фруттис": "Fruttis",
    "Фрутелла": "Fruittella",
    "Frutella": "Fruittella",
    "O Life": "O!LIFE",
    "O LIFE!": "O!LIFE",
}

ALIASES: dict[str, str] = {normalize_key(source): canon
                           for source, canon in {**_ALIAS_SOURCES,
                                                 **_TRANSLIT_SOURCES}.items()}

# Группы, где официальное написание — предположение (взято самое частое либо
# самое аккуратное из вариантов). Показываются в таблице с пометкой.
GUESSED: set[str] = {
    "cookchart", "creativekitchen", "epica", "fitnessshock", "gbalance",
    "goodmix", "kerlli", "letsgo", "orion", "snaqfabriq", "snickers",
    "вкусипольза", "вкустех", "зеленыйлуг", "индилайт", "московскийкартофель",
    "павапава", "первымделом", "рамонтипайз", "самиготовим", "свежеезавтра",
    "фэг", "щелковохлеб", "ясносолнышко",
}


def canonical_brand(brand: str) -> str:
    """Итоговое написание производителя: без юрформы, по словарю склеек и канонов.

    Пустая строка означает, что производителя в этой ячейке не было («АО "»).
    """
    cleaned = strip_noise(brand)
    if not cleaned:
        return ""
    alias = ALIASES.get(normalize_key(brand)) or ALIASES.get(normalize_key(cleaned))
    if alias:
        return alias
    return CANON.get(normalize_key(cleaned), cleaned)


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

    # Группируем по написанию, уже очищенному от юрформы: «ООО "Марс"» и «Марс» —
    # один производитель, и канон для них нужен один.
    spellings: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    for line in rows:
        brand = (line[brand_col] or "").strip() if len(line) > brand_col else ""
        cleaned = strip_noise(brand)
        if cleaned and normalize_key(brand) not in ALIASES:
            spellings[normalize_key(cleaned)][cleaned] += 1

    uncovered = [variants for key, variants in spellings.items()
                 if len(variants) > 1 and key not in CANON]
    if uncovered:
        print("Группы без канона в CANON — дополните словарь:", file=sys.stderr)
        for variants in uncovered:
            print("  • " + " | ".join(sorted(variants)), file=sys.stderr)
        raise SystemExit(1)

    # Таблица для вычитки собирается по фактическим заменам: что было → что стало.
    moves: dict[tuple[str, str], int] = defaultdict(int)

    new_rows: list[list[str]] = []
    for line in rows:
        line = list(line)
        brand = (line[brand_col] or "").strip() if len(line) > brand_col else ""
        canon = canonical_brand(brand) if brand else ""
        if brand and canon != brand:
            moves[(brand, canon)] += 1
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

    table: list[str] = []
    for (before, after), count in sorted(moves.items(), key=lambda item: (item[0][1].lower(),
                                                                         -item[1])):
        mark = "  (предположение)" if normalize_key(after) in GUESSED else ""
        shown = after if after else "— (производитель убран)"
        table.append(f"{before} ({count})  →  {shown}{mark}")

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
