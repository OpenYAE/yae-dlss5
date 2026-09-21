# You Are Empty — DLSS 5 Neural Rendering

Экспериментальная установка DLSS Neural Rendering для оригинальной 32-битной
OpenGL-версии **You Are Empty**.

Цепочка обработки:

```text
You Are Empty x86/OpenGL
  -> ReShade x86
  -> DLSS5-Feeder32
  -> host64 / D3D12
  -> OptiScaler
  -> DLSS/DLAA + DLSS Neural Rendering
```

## Установка одной командой

Откройте PowerShell и выполните:

```powershell
irm 'https://raw.githubusercontent.com/Blu2z/yae-dlss5/main/install.ps1' | iex
```

Откроется окно выбора папки игры. Выберите папку, содержащую:

```text
YOU_ARE_EMPTY.exe
```

Хеш игрового EXE намеренно не ограничивается, поэтому допускаются
модифицированные сборки. Игра должна оставаться 32-битной и использовать OpenGL.

Для запуска из `cmd.exe`, окна «Выполнить» или ярлыка используйте полный вариант:

```cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/Blu2z/yae-dlss5/main/install.ps1' | iex"
```

Команда загружает текущую версию этого публичного репозитория во временную папку,
запускает основной установщик и после завершения удаляет временные файлы.

Перед запуском удалённого сценария его можно просмотреть:
[install.ps1](https://github.com/Blu2z/yae-dlss5/blob/main/install.ps1).

## Требования

- Windows 10/11 x64.
- Оригинальная x86/OpenGL-версия игры с файлом `YOU_ARE_EMPTY.exe`.
- NVIDIA GeForce RTX 50-й серии для использованной модели Neural Rendering.
- Современный драйвер NVIDIA; проверено на RTX 5090 с драйвером 616.92.
- Доступ к GitHub во время установки.
- Права записи в папку игры.

## Что делает установщик

- загружает недостающие LumeniteFX и NVIDIA NGX runtime из закреплённых источников;
- проверяет SHA-256 архива DLSS-NR и цифровые подписи NVIDIA DLL;
- сохраняет заменяемые файлы в `_DLSS5-Backups`;
- устанавливает ReShade, DLSS5-Feeder и OptiScaler;
- запускает встроенную проверку конфигурации.

Установщик не меняет драйвер, реестр, Windows Defender, системные каталоги или
глобальные Vulkan layers.

## Управление

- `Home` — меню ReShade.
- `Insert` — панель host64/OptiScaler.
- Клавиша эффектов ReShade по умолчанию использует VK 222 и может отображаться
  как апостроф или `Э`. Её можно изменить в настройках ReShade.

## Ручная и офлайн-установка

Скачайте репозиторий через **Code → Download ZIP**, распакуйте и запустите
`Setup-YAE-DLSS5.cmd`. Полная инструкция, ручное получение зависимостей и
восстановление из резервной копии описаны в [README.txt](README.txt).

## Экспериментальный статус

Пакет предназначен для одиночной игры. Не используйте подобные инъекторы в
защищённых anti-cheat сетевых играх. Перед публикацией проблемы прикладывайте
логи ReShade, DLSS5-Feeder и OptiScaler без персональных путей.

## Сторонние компоненты

Игра и её EXE не распространяются. NVIDIA runtime и LumeniteFX не хранятся в
репозитории и загружаются установщиком из исходных источников. Остальные
включённые компоненты сохраняют собственные лицензии; их тексты находятся в
[`THIRD-PARTY-NOTICES`](THIRD-PARTY-NOTICES).
