import string


def top_words(text: str, n: int) -> list[tuple[str, int]]:
    """Возвращает n самых частых слов текста в виде (слово, количество).

    Регистр и знаки препинания не учитываются. При равной частоте слова
    идут по алфавиту.
    """
    counts = {}
    for raw in text.split():
        word = raw.strip(string.punctuation).lower()
        counts[word] += 1

    ranked = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    return ranked[:n]


if __name__ == "__main__":
    print(top_words("Мама мыла раму. Раму мыла мама, а папа — нет!", 3))
