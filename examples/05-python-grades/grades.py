# Задача: оценки студентов.
#
# 1. average(scores) — среднее арифметическое, для пустого списка — 0.
# 2. letter(avg) — буквенная оценка: 90+ → "A", 75+ → "B", 60+ → "C", иначе "F".
# 3. report(students) — словарь {имя: буква} для словаря {имя: [баллы]}.
#
# Проверка: python3 grades.py — должно напечатать «Все проверки пройдены».


def average(scores):
    total = 0
    for s in scores:
        total += s
    return total / len(scores)


def letter(avg):
    # TODO
    pass


def report(students):
    # TODO
    pass


if __name__ == "__main__":
    assert average([80, 90, 100]) == 90
    assert average([]) == 0
    assert letter(95) == "A" and letter(75) == "B" and letter(60) == "C" and letter(10) == "F"
    assert report({"Аня": [90, 95], "Боря": [50, 70]}) == {"Аня": "A", "Боря": "C"}
    print("Все проверки пройдены")
