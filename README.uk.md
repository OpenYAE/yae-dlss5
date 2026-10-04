# You Are Empty — DLSS 5 Neural Rendering

[English](README.md) | [Русский](README.ru.md) | **Українська**

Експериментальне встановлення DLSS Neural Rendering для оригінальної 32-бітної
OpenGL-версії **You Are Empty**.

Ланцюжок обробки:

```text
You Are Empty x86/OpenGL
  -> ReShade x86
  -> DLSS5-Feeder32
  -> host64 / D3D12
  -> OptiScaler
  -> DLSS/DLAA + DLSS Neural Rendering
```

## Приклади

На кожному зображенні ліворуч показано вихідну картинку з вимкненим DLSS 5,
а праворуч — результат з увімкненим DLSS 5 Neural Rendering.

![Порівняння DLSS 5 OFF і ON — персонажі та оточення](docs/images/example1.png)

![Порівняння DLSS 5 OFF і ON — міська сцена](docs/images/example2.png)

## Встановлення однією командою

Відкрийте PowerShell і виконайте:

```powershell
irm 'https://raw.githubusercontent.com/Blu2z/yae-dlss5/main/install.ps1' | iex
```

Відкриється вікно вибору теки гри. Виберіть теку, що містить:

```text
YOU_ARE_EMPTY.exe
```

Хеш ігрового EXE навмисно не обмежується, тому допускаються модифіковані
збірки. Гра має залишатися 32-бітною та використовувати OpenGL.

Для запуску з `cmd.exe`, вікна «Виконати» або ярлика використовуйте повний варіант:

```cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm 'https://raw.githubusercontent.com/Blu2z/yae-dlss5/main/install.ps1' | iex"
```

Команда завантажує поточну версію цього публічного репозиторію в тимчасову теку,
запускає основний інсталятор і після завершення видаляє тимчасові файли.

Перед запуском віддаленого сценарію його можна переглянути:
[install.ps1](https://github.com/Blu2z/yae-dlss5/blob/main/install.ps1).

## Вимоги

- Windows 10/11 x64.
- Оригінальна x86/OpenGL-версія гри з файлом `YOU_ARE_EMPTY.exe`.
- NVIDIA GeForce RTX 50-ї серії для використаної моделі Neural Rendering.
- Сучасний драйвер NVIDIA; перевірено на RTX 5090 з драйвером 616.92.
- Доступ до GitHub під час встановлення.
- Права запису в теку гри.

## Що робить інсталятор

- завантажує відсутні LumeniteFX та NVIDIA NGX runtime із закріплених джерел;
- перевіряє SHA-256 архіву DLSS-NR і цифрові підписи NVIDIA DLL;
- зберігає файли, що замінюються, у `_DLSS5-Backups`;
- встановлює ReShade, DLSS5-Feeder і OptiScaler;
- запускає вбудовану перевірку конфігурації.

Інсталятор не змінює драйвер, реєстр, Windows Defender, системні каталоги чи
глобальні Vulkan layers.

## Керування

- `Home` — меню ReShade.
- `Insert` — панель host64/OptiScaler.
- Клавіша ефектів ReShade за замовчуванням використовує VK 222 і може
  відображатися як апостроф або `Є`/`Э` (залежно від розкладки). Її можна змінити
  в налаштуваннях ReShade.

## Ручне та офлайн-встановлення

Завантажте репозиторій через **Code → Download ZIP**, розпакуйте та запустіть
`Setup-YAE-DLSS5.cmd`. Повну інструкцію, ручне отримання залежностей і
відновлення з резервної копії описано в [README.txt](README.txt) (російською).

## Експериментальний статус

Пакет призначений для одиночної гри. Не використовуйте подібні інжектори в
захищених anti-cheat мережевих іграх. Повідомляючи про проблему, додавайте
логи ReShade, DLSS5-Feeder і OptiScaler без персональних шляхів.

## Сторонні компоненти

Гра та її EXE не розповсюджуються. NVIDIA runtime і LumeniteFX не зберігаються в
репозиторії та завантажуються інсталятором з оригінальних джерел. Інші
включені компоненти зберігають власні ліцензії; їхні тексти знаходяться в
[`THIRD-PARTY-NOTICES`](THIRD-PARTY-NOTICES).
