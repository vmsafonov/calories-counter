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


if __name__ == "__main__":
    unittest.main(verbosity=1)
