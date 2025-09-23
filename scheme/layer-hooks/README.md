# Каталог layer-hooks/ - Хуки слоев

Каталог содержит общие хуки, используемые библиотекой слоев.

## Структура каталогов

### `systemd/`
**Назначение**: Хуки для systemd
**Содержит**:
- `netgen/` - генерация сетевых конфигураций
- `ttyset/` - настройка терминала

## Назначение

Хуки используются слоями для:
- Настройки системных служб
- Генерации конфигурационных файлов
- Настройки оборудования
- Сетевой конфигурации

Переменная `LAYER_HOOKS` указывает путь:
```bash
printf 'LAYER_HOOKS="%s"\n'  "$IGTOP/layer-hooks" >> "${ctx[IGENVF]}"
```

Используются в mmdebstrap конфигурациях слоев.

## Типы хуков

### Системные хуки
- **netgen/**: Генерация сетевых конфигураций systemd-networkd
- **ttyset/**: Настройка параметров терминала и консоли

### Хуки сборки
Используются в mmdebstrap конфигурациях:
```yaml
mmdebstrap:
  setup-hooks:
    - layer-hooks/systemd/netgen/setup.sh
  customize-hooks:
    - layer-hooks/systemd/ttyset/customize.sh
```

## Создание хуков

1. **Создайте структуру каталогов**:
   ```bash
   mkdir -p layer-hooks/my-category/my-hook
   ```

2. **Создайте хуки для этапов**:
   ```bash
   touch layer-hooks/my-category/my-hook/{setup,customize,cleanup}.sh
   chmod +x layer-hooks/my-category/my-hook/*.sh
   ```

3. **Интегрируйте в слои**:
   ```yaml
   mmdebstrap:
     customize-hooks:
       - layer-hooks/my-category/my-hook/customize.sh
   ```
