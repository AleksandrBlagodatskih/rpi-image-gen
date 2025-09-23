# ============================================================================
# ШАБЛОН DOCKERFILE ДЛЯ RPI-IMAGE-GEN
# ============================================================================

# [DOCKERFILE_DESCRIPTION]

# Общее описание:
# - [ОПИСАНИЕ 1]
# - [ОПИСАНИЕ 2]
# - [ОПИСАНИЕ 3]

# Функции:
# - [ФУНКЦИЯ 1]
# - [ФУНКЦИЯ 2]

# Использование:
# docker build -t [IMAGE_NAME] .
# docker run -d -p [PORT]:[PORT] [IMAGE_NAME]

# ============================================================================
# БАЗОВЫЙ ОБРАЗ
# ============================================================================

# Используйте официальные базовые образы
FROM [BASE_IMAGE]:[TAG]

# Пример для Python приложения
FROM python:[PYTHON_VERSION]-slim

# Пример для Node.js приложения
FROM node:[NODE_VERSION]-slim

# Пример для Raspberry Pi (многоархитектурный)
FROM balenalib/raspberry-pi-debian:[DEBIAN_VERSION]

# ============================================================================
# МЕТАДАННЫЕ
# ============================================================================

# Метаданные образа
LABEL maintainer="[MAINTAINER_EMAIL]"
LABEL version="[VERSION]"
LABEL description="[DESCRIPTION]"
LABEL org.opencontainers.image.source="[SOURCE_URL]"
LABEL org.opencontainers.image.licenses="[LICENSE]"

# ============================================================================
# АРГУМЕНТЫ СБОРКИ
# ============================================================================

# Аргументы для кастомизации сборки
ARG [ARG_NAME_1]=[DEFAULT_VALUE_1]
ARG [ARG_NAME_2]=[DEFAULT_VALUE_2]

# Примеры аргументов
ARG NODE_ENV=production
ARG PYTHON_VERSION=3.9
ARG DEBIAN_FRONTEND=noninteractive

# ============================================================================
# ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ
# ============================================================================

# Установка переменных окружения
ENV [ENV_VAR_1]=[VALUE_1]
ENV [ENV_VAR_2]=[VALUE_2]

# Примеры переменных
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV NODE_ENV=production
ENV PATH=/usr/local/bin:$PATH

# ============================================================================
# РАБОЧИЙ КАТАЛОГ
# ============================================================================

# Установка рабочего каталога
WORKDIR [WORK_DIR]

# Пример
WORKDIR /app

# ============================================================================
# ЗАВИСИМОСТИ СИСТЕМЫ
# ============================================================================

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    [SYSTEM_PACKAGE_1] \
    [SYSTEM_PACKAGE_2] \
    [SYSTEM_PACKAGE_3] \
    && rm -rf /var/lib/apt/lists/*

# Пример для Python
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Пример для Node.js
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# КОПИРОВАНИЕ ФАЙЛОВ
# ============================================================================

# Копирование файлов зависимостей (для кеширования)
COPY [SOURCE_PATH_1] [DEST_PATH_1]
COPY [SOURCE_PATH_2] [DEST_PATH_2]

# Пример для Python
COPY requirements.txt .
COPY setup.py .
COPY setup.cfg .

# Пример для Node.js
COPY package.json .
COPY package-lock.json .
COPY yarn.lock .

# ============================================================================
# УСТАНОВКА ЗАВИСИМОСТЕЙ ПРИЛОЖЕНИЯ
# ============================================================================

# Установка зависимостей Python
RUN pip install --no-cache-dir -r requirements.txt

# Установка зависимостей Node.js
RUN npm ci --only=production

# Установка зависимостей из setup.py
RUN pip install -e .

# ============================================================================
# КОПИРОВАНИЕ ИСХОДНОГО КОДА
# ============================================================================

# Копирование остального кода приложения
COPY [SOURCE_PATH] [DEST_PATH]

# Пример
COPY src/ ./src/
COPY app/ ./app/
COPY config/ ./config/

# ============================================================================
# МНОГОЭТАПНАЯ СБОРКА (MULTI-STAGE BUILD)
# ============================================================================

# Этап 1: Сборка
FROM [BUILD_BASE_IMAGE] AS builder

# Установка инструментов сборки
RUN apt-get update && apt-get install -y \
    build-essential \
    [BUILD_TOOLS]

# Копирование и сборка
COPY [SOURCE_FILES] .
RUN [BUILD_COMMAND]

# Этап 2: Финальный образ
FROM [FINAL_BASE_IMAGE]

# Копирование артефактов сборки
COPY --from=builder [BUILD_ARTIFACTS] [DEST_PATH]

# ============================================================================
# ПОЛЬЗОВАТЕЛЬ И ПРАВА
# ============================================================================

# Создание пользователя приложения
RUN useradd --create-home --shell /bin/bash [APP_USER]

# Переключение на пользователя
USER [APP_USER]

# Альтернатива - установка прав на каталог
RUN chown -R [APP_USER]:[APP_GROUP] [APP_DIR]

# ============================================================================
# ПОРТЫ И ЭКСПОЗИЦИЯ
# ============================================================================

# Экспозиция портов
EXPOSE [PORT_1]
EXPOSE [PORT_2]/tcp
EXPOSE [PORT_3]/udp

# Пример
EXPOSE 8000
EXPOSE 5432

# ============================================================================
# ТОМЫ
# ============================================================================

# Определение томов для персистентных данных
VOLUME [VOLUME_PATH_1]
VOLUME [VOLUME_PATH_2]

# Пример
VOLUME ["/app/data", "/app/logs"]

# ============================================================================
# ЗДОРОВЬЕ ПРОВЕРКА
# ============================================================================

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD [HEALTH_CHECK_COMMAND]

# Пример для веб-сервиса
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Пример для базы данных
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD pg_isready -U postgres || exit 1

# ============================================================================
# КОМАНДА ЗАПУСКА
# ============================================================================

# Команда по умолчанию
CMD ["[COMMAND]", "[ARG1]", "[ARG2]"]

# Пример для Python
CMD ["python", "app.py"]

# Пример для Node.js
CMD ["node", "server.js"]

# Пример с аргументами
CMD ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]

# ============================================================================
# ПРИМЕРЫ DOCKERFILE
# ============================================================================

# Пример 1: Простое Python приложение
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .
CMD ["python", "app.py"]

# Пример 2: Node.js приложение
FROM node:16-slim

WORKDIR /app
COPY package.json .
RUN npm install

COPY . .
CMD ["node", "server.js"]

# Пример 3: Многоэтапная сборка для Go
FROM golang:1.19 AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
CMD ["./main"]

# ============================================================================
# ПРИМЕРЫ ДЛЯ RASPBERRY PI
# ============================================================================

# Базовый образ для Raspberry Pi 4
FROM balenalib/raspberrypi4-64-debian:bullseye

# Оптимизированная сборка для Raspberry Pi
FROM balenalib/raspberry-pi-debian:bullseye

# Установка зависимостей для Raspberry Pi
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# ============================================================================
# ОПТИМИЗАЦИИ
# ============================================================================

# Очистка кеша apt
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Комбинирование команд RUN
RUN apt-get update && \
    apt-get install -y [PACKAGES] && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Копирование только необходимых файлов
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY src/ .

# ============================================================================
# БЕЗОПАСНОСТЬ
# ============================================================================

# Запуск от непривилегированного пользователя
RUN useradd --create-home --shell /bin/bash app
USER app

# Установка правильных прав
RUN chown -R app:app /app

# Ограничение ресурсов
# Это делается в docker run, не в Dockerfile

# ============================================================================
# ПРИМЕЧАНИЯ РАЗРАБОТЧИКА
# ============================================================================

# 1. Используйте официальные базовые образы
# 2. Минимизируйте количество слоев
# 3. Используйте многоэтапную сборку для оптимизации
# 4. Устанавливайте только необходимые зависимости
# 5. Используйте .dockerignore для исключения файлов
# 6. Добавляйте health checks для мониторинга
# 7. Документируйте все этапы сборки
# 8. Тестируйте образ после сборки
# 9. Используйте метки для организации
# 10. Следуйте принципам безопасности

# ============================================================================
# ФАЙЛ .DOCKERIGNORE
# ============================================================================

# .dockerignore
.git
.gitignore
README.md
docs/
tests/
__pycache__/
*.pyc
*.pyo
*.pyd
.pytest_cache/
.coverage
.env
.venv/
venv/
node_modules/
npm-debug.log
Dockerfile
.dockerignore

# ============================================================================
# СБОРКА И ЗАПУСК
# ============================================================================

# Сборка образа
docker build -t [IMAGE_NAME]:[TAG] .

# Запуск контейнера
docker run -d \
  --name [CONTAINER_NAME] \
  -p [HOST_PORT]:[CONTAINER_PORT] \
  -v [HOST_PATH]:[CONTAINER_PATH] \
  --restart unless-stopped \
  [IMAGE_NAME]:[TAG]

# Мониторинг
docker logs -f [CONTAINER_NAME]
docker stats [CONTAINER_NAME]

# Отладка
docker exec -it [CONTAINER_NAME] /bin/bash
