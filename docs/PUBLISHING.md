# Публикация на GitHub

Эта папка — чистый снимок текущих исходников, подготовленный для нового репозитория. Исходная рабочая папка не изменена. Старые коммиты, локальные настройки, кэши, сборки и личные конфигурации не перенесены. Исходники приложения и сборочные файлы сохранены без изменений.

В папке уже создан Git-репозиторий с веткой main; файлы подготовлены к первому коммиту. Публикация и первый коммит ещё не выполнялись. Пустые каталоги зависимостей — сохранённые Git submodules с точными исходными коммитами, а не потерянные файлы. Загружайте проект через Git/GitHub Desktop: загрузка файлов через веб-интерфейс не сохраняет gitlinks.

## GitHub Desktop

1. File → Add Local Repository → выберите эту папку.
2. Проверьте изменения и создайте первый коммит в main.
3. Нажмите Publish repository, задайте имя scratch-cards-ios и нужную видимость.

## Через терминал

В корне этой папки:

```sh
python3 tools/check_public_repository.py
python3 build-system/Make/PostboxImportCheck.py
git diff --cached --stat
git commit -m "Publish scratch-card Telegram iOS prototype"
git remote add origin https://github.com/YOUR_GITHUB_LOGIN/scratch-cards-ios.git
git push -u origin main
```

Сначала создайте на GitHub пустой репозиторий без автоматического README и лицензии. Замените YOUR_GITHUB_LOGIN своим GitHub-логином. Telegram-ник автора не определяет его GitHub-логин.

При первом импорте сохранены исходные пробелы и переносы upstream-кода. Проверка whitespace в CI применяется к последующим изменениям; начальный снимок не переформатируется. Это сохраняет исходники приложения побайтово.

## About

Description:

```text
Scratch-to-reveal photo messages for an unofficial Telegram iOS client. Native animations, themed covers and spoiler compatibility. By @meeckhaill.
```

Website: https://t.me/meeckhaill

Topics: ios swift uikit telegram scratch-card animations prototype

## Сборка и оформление

Перед сборкой скачайте зависимости:

```sh
git submodule update --init --recursive
```

Далее следуйте [BUILDING.md](BUILDING.md), используя собственные API-данные и подпись. Публичные upstream-примеры и тестовые сертификаты сохранены; личный local_configuration.json исключён.

Для нового клонирования используйте git clone --recurse-submodules. Демонстрационные изображения можно добавить по инструкции [media/README.md](media/README.md). Авторство [@meeckhaill](https://t.me/meeckhaill), GPL и лицензии зависимостей сохранены. Готовый публичный бинарный релиз не создавался.
