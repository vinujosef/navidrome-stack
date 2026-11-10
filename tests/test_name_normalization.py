"""Artist spelling coverage and boundaries for built-in normalization."""
import importlib.util
import itertools
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    'normalize_names', Path(__file__).resolve().parents[1] / 'scripts/lib/normalize-names.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class NameNormalizationTests(unittest.TestCase):
    def test_case_spacing_and_period_variants(self):
        for letters, first, second, surname in itertools.product(
                ['AR', 'ar', 'Ar', 'aR'], ['', '.', ' ', '. ', ' . ', '..'],
                ['', '.', ' ', '. ', ' . ', '..'], ['Rahman', 'RAHMAN', 'rahman']):
            value = letters[0] + first + letters[1] + second + surname
            with self.subTest(value=value):
                self.assertEqual(module.normalize_names(value), 'A. R. Rahman')

    def test_other_names_and_multiple_artists(self):
        value = 'Sara Rahman; A. R. Rahmani'
        self.assertEqual(module.normalize_names(value), value)
        self.assertEqual(module.normalize_names('Singer / A.R.RAHMAN; arrahman'),
                         'Singer / A. R. Rahman; A. R. Rahman')

    def test_additional_artist_variants(self):
        for first, second, case in itertools.product(
                ['', '.', ' ', '. ', ' . ', '..'],
                ['', '.', ' ', '. ', ' . ', '..'],
                [str.lower, str.upper, str.title]):
            for prefix, middle, surnames, canonical in [
                ('Neha', 'S', ['Nair'], 'Neha S. Nair'),
                ('K', 'S', ['Chitra', 'Chithra'], 'K. S. Chithra'),
                ('K', 'J', ['Yesudas'], 'K. J. Yesudas'),
                ('K', 'G', ['Markose'], 'K. G. Markose'),
                ('M', 'G', ['Radhakrishnan'], 'M. G. Radhakrishnan'),
                ('K', 'S', ['Harisankar'], 'K. S. Harisankar'),
                ('G', 'V', ['Prakash', 'Prakas Kumar', 'Prakash Kumar'],
                 'G. V. Prakash Kumar'),
                ('S', 'P', ['Balasubrahmanyam', 'Balasubramanyam'],
                 'S. P. Balasubrahmanyam'),
            ]:
                for surname in surnames:
                    value = case(prefix + first + middle + second + surname)
                    with self.subTest(value=value):
                        self.assertEqual(module.normalize_names(value), canonical)
                        self.assertEqual(module.normalize_names(canonical), canonical)
        for value in ['Neha Nair', 'NEHANAIR', 'neha.nair']:
            self.assertEqual(module.normalize_names(value), 'Neha S. Nair')

    def test_multiple_new_artists_and_boundaries(self):
        self.assertEqual(
            module.normalize_names('NehaS. Nair / K.S.Chitra & K.J.Yesudas'),
            'Neha S. Nair / K. S. Chithra & K. J. Yesudas')
        value = 'Sneha Nair / Neha Nairan / K.S.Chitral / K.J.Yesudasan'
        self.assertEqual(module.normalize_names(value), value)

    def test_sid_sriram_variants(self):
        for separator, surname, case in itertools.product(
                ['', ' ', '.', '. ', '  '], ['Sriram', 'Sriam', 'Shriram'],
                [str.lower, str.upper, str.title]):
            value = case('Sid' + separator + surname)
            with self.subTest(value=value):
                self.assertEqual(module.normalize_names(value), 'Sid Sriram')

    def test_new_names_in_combinations(self):
        self.assertEqual(
            module.normalize_names('G.V. Prakash / SID SRIAM & S.P.Balasubramanyam'),
            'G. V. Prakash Kumar / Sid Sriram & S. P. Balasubrahmanyam')
        for value in ['', 'Other Artist', 'Sid Sriraman', 'S.P.Balasubramanyamson',
                      'G.V.Prakashan', 'Prakash Kumar', 'Balasubrahmanyam']:
            self.assertEqual(module.normalize_names(value), value)
        canonical = 'G. V. Prakash Kumar / Sid Sriram / S. P. Balasubrahmanyam'
        self.assertEqual(module.normalize_names(canonical), canonical)

    def test_nikhita_gandhi_and_new_name_combinations(self):
        for separator, case in itertools.product(
                ['', ' ', '.', '. ', '  '], [str.lower, str.upper, str.title]):
            self.assertEqual(module.normalize_names(case('Nikhita' + separator + 'Gandhi')),
                             'Nikhita Gandhi')
        self.assertEqual(
            module.normalize_names('K.G.Markose / M.G.Radhakrishnan; '
                                   'K.S.Harisankar & NIKHITAGANDHI'),
            'K. G. Markose / M. G. Radhakrishnan; K. S. Harisankar & Nikhita Gandhi')
        for value in ['', 'Other Artist', 'K.G.Markosean', 'M.G.Radhakrishnana',
                      'K.S.Harisankaran', 'Nikhita Gandhian']:
            self.assertEqual(module.normalize_names(value), value)
        canonical = ('K. G. Markose / M. G. Radhakrishnan / '
                     'K. S. Harisankar / Nikhita Gandhi')
        self.assertEqual(module.normalize_names(canonical), canonical)

    def test_sreekumar_and_yuvan_variants(self):
        for first, second, case in itertools.product(
                ['', '.', ' ', '. ', '  '], ['', '.', ' ', '. ', '  '],
                [str.lower, str.upper, str.title]):
            for parts, canonical in [
                (('M', 'G', 'Sreekumar'), 'M. G. Sreekumar'),
                (('Yuvan', 'Shankar', 'Raja'), 'Yuvan Shankar Raja'),
            ]:
                value = case(parts[0] + first + parts[1] + second + parts[2])
                with self.subTest(value=value):
                    self.assertEqual(module.normalize_names(value), canonical)
                    self.assertEqual(module.normalize_names(canonical), canonical)
        self.assertEqual(module.normalize_names('M.G.SREEKUMAR / YuvanShankarRaja'),
                         'M. G. Sreekumar / Yuvan Shankar Raja')
        for value in ['', 'Other Artist', 'M.G.Sreekumaran',
                      'Yuvan Shankar Rajan', 'Shankar Raja']:
            self.assertEqual(module.normalize_names(value), value)

    def test_sam_cs_variants(self):
        for first, second, ending, case in itertools.product(
                ['', '.', ' ', '. ', '  '], ['', '.', ' ', '. ', '  '],
                ['', '.'], [str.lower, str.upper, str.title]):
            value = case('Sam' + first + 'C' + second + 'S' + ending)
            with self.subTest(value=value):
                self.assertEqual(module.normalize_names(value), 'Sam C. S.')
        self.assertEqual(module.normalize_names('Sam C. S.'), 'Sam C. S.')
        self.assertEqual(module.normalize_names('SAMCS / A.R.RAHMAN'),
                         'Sam C. S. / A. R. Rahman')
        for value in ['', 'Other Artist', 'Sam C. Smith', 'Samson', 'XSamCS']:
            self.assertEqual(module.normalize_names(value), value)
