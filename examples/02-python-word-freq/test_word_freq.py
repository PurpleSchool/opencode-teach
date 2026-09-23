import unittest

from word_freq import top_words


class TopWordsTest(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(top_words("a b a c b a", 2), [("a", 3), ("b", 2)])

    def test_case_and_punctuation(self):
        self.assertEqual(top_words("Кот, кот! КОТ? пёс.", 1), [("кот", 3)])

    def test_ties_sorted_alphabetically(self):
        self.assertEqual(top_words("b a c", 2), [("a", 1), ("b", 1)])

    def test_dash_is_not_a_word(self):
        self.assertEqual(top_words("да — нет", 5), [("да", 1), ("нет", 1)])


if __name__ == "__main__":
    unittest.main()
