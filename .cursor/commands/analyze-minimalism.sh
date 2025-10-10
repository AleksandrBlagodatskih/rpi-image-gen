#!/bin/bash
# Анализ принципа минимализма в коде расширений rpi-image-gen
# Используется в Cursor Tasks для автоматической проверки качества кода

set -euo pipefail

echo "=== Анализ принципа минимализма ==="

# 1. Подсчет общего количества строк кода
echo "Общее количество строк кода:"
total_lines=$(find layer/ -name '*.yaml' -exec wc -l {} \; | awk '{sum += $1} END {print sum}')
echo "$total_lines строк"

# 2. Поиск дублированного кода (простая проверка apt-get install)
echo -e "\nПоиск дублированного кода:"
duplicates=$(find layer/ -name '*.yaml' -exec grep -h 'apt-get install' {} \; | sort | uniq -c | awk '$1 > 1 {print "⚠️  " $2 ": " $1 " раз"}')
if [[ -n "$duplicates" ]; then
    echo "$duplicates"
else
    echo "Дублирование не найдено"
fi

# 3. Анализ функций в bash скриптах
echo -e "\nАнализ функций в скриптах:"
if [[ -d "layer-hooks/" ]; then
    for script in layer-hooks/*.sh; do
        if [[ -f "$script" ]; then
            echo "Файл: $(basename "$script")"
            # Анализ длины функций
            awk '
            /^function / {
                func=substr($2, 1, index($2, "(")-1)
                if (func) {
                    start=NR
                    getline
                    while ($0 !~ /^}/ && NR-start < 50) {
                        getline
                    }
                    lines=NR-start
                    if (lines > 30) {
                        print "⚠️  " func ": " lines " строк"
                    }
                }
            }
            ' "$script" 2>/dev/null || true
        fi
    done
else
    echo "Директория layer-hooks/ не найдена"
fi

# 4. Проверка на сложные конструкции
echo -e "\nПроверка на потенциальные проблемы:"
complex_functions=$(find layer/ -name '*.yaml' -exec grep -l 'customize-hooks' {} \; | wc -l)
echo "Слоев с кастомными хуками: $complex_functions"

# Вывод рекомендаций
echo -e "\n💡 Рекомендации:"
echo "- Функции длиннее 30 строк рекомендуется разбить"
echo "- Избегайте дублирования команд установки пакетов"
echo "- Используйте переменные для повторяющихся значений"
echo "- Каждая функция должна выполнять только одну задачу"

exit 0
