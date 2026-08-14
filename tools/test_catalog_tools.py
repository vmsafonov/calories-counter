#!/usr/bin/env python3
"""Тесты инструментов каталога: нормализация производителей и сборщик.

Запуск: python3 tools/test_catalog_tools.py
"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_catalog
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


class StripNoiseTests(unittest.TestCase):
    def test_legal_form_removed(self):
        for raw, expected in [
            ('ООО "Марс"', "Марс"),
            ('ПАО "Красный Октябрь"', "Красный Октябрь"),
            ("ОАО Молочный мир", "Молочный мир"),
            ("ИП Емелин Владимир Павлович", "Емелин Владимир Павлович"),
            ('ООО ПК "Айсберг-Люкс"', "Айсберг-Люкс"),
        ]:
            self.assertEqual(normalize_brands.strip_noise(raw), expected)

    def test_trademark_signs_removed(self):
        self.assertEqual(normalize_brands.strip_noise("SNICKERS®"), "SNICKERS")

    def test_leftover_without_letters_is_empty(self):
        # «АО "» — не производитель, а обрывок строки.
        self.assertEqual(normalize_brands.strip_noise('АО "'), "")
        self.assertEqual(normalize_brands.strip_noise('ООО "'), "")

    def test_inner_quotes_survive(self):
        # Кавычки внутри названия снимать нельзя: потеряется закрывающая.
        self.assertEqual(normalize_brands.strip_noise("«Россия» — щедрая душа!"),
                         "«Россия» — щедрая душа!")
        self.assertEqual(normalize_brands.strip_noise("ООО Маслозавод «Дружба»"),
                         "Маслозавод «Дружба»")

    def test_plain_brand_untouched(self):
        self.assertEqual(normalize_brands.strip_noise("Lay's"), "Lay's")
        self.assertEqual(normalize_brands.strip_noise("ВкусВилл"), "ВкусВилл")


class CanonicalBrandTests(unittest.TestCase):
    def test_alias_collapses_glued_brands(self):
        # В Open Food Facts brands — список через запятую; при импорте он слипся.
        self.assertEqual(normalize_brands.canonical_brand("Самокат Вкусвилл Ана Райз"),
                         "ВкусВилл")
        self.assertEqual(normalize_brands.canonical_brand("Лавка Яндекс"), "Яндекс Лавка")
        self.assertEqual(normalize_brands.canonical_brand("Добрый Мультифрукт"), "Добрый")

    def test_legal_form_reaches_canon(self):
        self.assertEqual(normalize_brands.canonical_brand('ПАО "Красный Октябрь"'),
                         "Красный Октябрь")

    def test_real_subbrands_kept_apart(self):
        for brand in ["Пятёрочка Кафе", "Перекрёсток Select", "Яндекс Лавка"]:
            self.assertEqual(normalize_brands.canonical_brand(brand), brand)

    def test_alias_targets_are_canonical(self):
        # Псевдоним обязан указывать на итоговое написание, иначе сборка упадёт.
        for source, canon in normalize_brands._ALIAS_SOURCES.items():
            self.assertEqual(normalize_brands.canonical_brand(canon), canon,
                             f"псевдоним {source!r} ведёт на неканоничное {canon!r}")


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


if __name__ == "__main__":
    unittest.main(verbosity=1)
