You Are Empty (2006) — DLSS 5 Neural Rendering
Чистая установка для x86/OpenGL-версии игры
================================================

Что это
-------

Пакет подключает экспериментальную цепочку:

You Are Empty x86/OpenGL
  -> ReShade x86
  -> DLSS5-Feeder32
  -> отдельный host64/D3D12
  -> OptiScaler
  -> DLSS/DLAA + DLSS Neural Rendering

Целевой файл игры:
  YOU_ARE_EMPTY.exe

Хеш EXE намеренно не ограничивается: установщик допускает модифицированные
сборки при условии, что игра остаётся 32-битной и использует OpenGL.

Пакет рассчитан на чистую папку игры без ReShade, QindieGL, dgVoodoo и других
графических wrapper/injector-файлов. Игра и её EXE в архив не входят.


Требования
----------

- Windows 10/11 x64.
- NVIDIA GeForce RTX 50-й серии для использованной модели Neural Rendering.
- Свежий драйвер NVIDIA. Проверенная конфигурация: RTX 5090, драйвер 616.92.
- Чистая x86/OpenGL-установка You Are Empty.
- Права записи в папку игры.

Это экспериментальный мод для одиночной игры. Не используйте инъекторы такого
типа в защищённых anti-cheat сетевых играх.


Автоматическая установка — рекомендуемый способ
-----------------------------------------------

1. Распакуйте архив в отдельную папку.

2. Дважды щёлкните Setup-YAE-DLSS5.cmd.

3. Выберите папку игры, содержащую YOU_ARE_EMPTY.exe.

Если выбранная папка защищена Windows, сценарий сам запросит стандартное UAC-
подтверждение и продолжит с правами администратора.

На этом ручные действия заканчиваются. Сценарий автоматически:

- скачивает LumeniteFX из официального репозитория автора;
- скачивает nvngx_dlss.dll из официального NVIDIA/DLSS;
- скачивает закреплённый архив nvngx_dlssnr.dll 310.8.0 из RankFTW/rhi-repo,
  который используется установочным инструментом самого DLSS5-Feeder;
- проверяет SHA-256 архива и извлечённой NR DLL;
- проверяет цифровые подписи и Product Name обеих NVIDIA DLL;
- проверяет наличие игрового EXE (без ограничения по хешу);
- создаёт резервную копию всех заменяемых файлов;
- устанавливает цепочку и запускает официальный verifier.

При желании можно положить пакет непосредственно в папку игры. Если
YOU_ARE_EMPTY.exe находится рядом со сценарием, выбор папки пропускается.

Для запуска из консоли или автоматизации:

  .\Setup-YAE-DLSS5.cmd -GameDir "D:\Games\You Are Empty"

Флаг -LaunchGame дополнительно запускает игру после успешной установки.

Все URL, ожидаемые хеши и проверки находятся в открытом текстовом файле
Setup-YAE-DLSS5.ps1. NVIDIA DLL не встроены в распространяемый архив: они
загружаются непосредственно во время установки.


Ручное получение отсутствующих файлов
-------------------------------------

Этот раздел нужен только для офлайн-установки или если автоматическая загрузка
заблокирована сетью.

Архив намеренно не распространяет NVIDIA runtimes и LumeniteFX:

- nvngx_dlss.dll
- nvngx_dlssnr.dll
- LumeniteFX-mainline.zip

NVIDIA runtimes являются проприетарными. Лицензия LumeniteFX требует использовать
официальные ссылки автора вместо независимого распространения копии проекта.

Получите эти файлы самостоятельно из официальных источников и положите их без
переименования в папку THIRD-PARTY-FILES-HERE рядом с установщиком.

  THIRD-PARTY-FILES-HERE

1. LumeniteFX-mainline.zip

   Откройте официальный проект автора:
   https://github.com/umar-afzaal/LumeniteFX

   Нажмите Code -> Download ZIP и убедитесь, что скачан именно branch mainline,
   либо используйте прямую официальную ссылку:
   https://github.com/umar-afzaal/LumeniteFX/archive/refs/heads/mainline.zip

   Браузер должен сохранить файл с именем LumeniteFX-mainline.zip. Не
   распаковывайте его: установщик сам извлечёт только необходимые файлы.

   Альтернативная команда PowerShell:

   Invoke-WebRequest -Uri "https://codeload.github.com/umar-afzaal/LumeniteFX/zip/refs/heads/mainline" -OutFile ".\THIRD-PARTY-FILES-HERE\LumeniteFX-mainline.zip"

2. nvngx_dlss.dll

   Это официальный x64 runtime DLSS Super Resolution. Откройте официальный
   репозиторий NVIDIA:
   https://github.com/NVIDIA/DLSS

   Перейдите в lib -> Windows_x86_64 -> rel -> nvngx_dlss.dll, откройте файл и
   нажмите Download raw file. Прямая официальная ссылка:
   https://raw.githubusercontent.com/NVIDIA/DLSS/main/lib/Windows_x86_64/rel/nvngx_dlss.dll

   Сохраните его как:
   THIRD-PARTY-FILES-HERE\nvngx_dlss.dll

   Альтернативная команда PowerShell:

   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/NVIDIA/DLSS/main/lib/Windows_x86_64/rel/nvngx_dlss.dll" -OutFile ".\THIRD-PARTY-FILES-HERE\nvngx_dlss.dll"

   Страница официальных релизов NVIDIA DLSS:
   https://github.com/NVIDIA/DLSS/releases

3. nvngx_dlssnr.dll

   Автоматический сценарий получает проверенную версию 310.8.0 из публичного
   release-архива RankFTW/rhi-repo, указанного в установочном инструменте
   DLSS5-Feeder:

   https://github.com/RankFTW/rhi-repo/releases/download/dlssnr-310.8.0/nvngx_dlssnr_310.8.0.zip

   Проверяемые SHA-256:

   - ZIP: 388C0A7912E15EC911B9C9E11A692142B11FE387DDF2B637D8C358138FFFB3AC
   - DLL: E16BCF15E16E13F527491CDF7845B2FE6521A738D8F7C9C721866A8496E1FC8E

   Альтернатива без community mirror — извлечение из официального драйвера:

   Эта модель Neural Rendering не опубликована отдельной официальной загрузкой.
   Возьмите её из официального пакета драйвера NVIDIA, в котором она присутствует.

   a. Скачайте подходящий свежий Game Ready или Studio Driver с официальной
      страницы NVIDIA:
      https://www.nvidia.com/en-us/drivers/

   b. Установите 7-Zip с официального сайта, если его ещё нет:
      https://www.7-zip.org/

   c. Не обязательно запускать установку драйвера. Нажмите правой кнопкой на
      загруженном NVIDIA driver .exe -> 7-Zip -> Open archive.

   d. В открытом пакете выполните поиск по имени nvngx_dlssnr.dll. Если архив
      содержит вложенные пакеты, откройте их через 7-Zip и повторите поиск.

   e. Извлеките найденный x64-файл непосредственно в:
      THIRD-PARTY-FILES-HERE\nvngx_dlssnr.dll

   f. Если в выбранном драйвере файла нет, скачайте более новый пакет. В
      проверенной конфигурации использовались драйвер 616.92 и
      nvngx_dlssnr.dll версии 310.8.0.0 размером 165840496 байт.

   В свойствах правильного файла должны быть:

   - Company Name: NVIDIA Corporation или NVIDIA;
   - Product Name: NVIDIA DLSSNR;
   - действительная цифровая подпись NVIDIA Corporation.

   Это не nvngx_dlssd.dll (Ray Reconstruction) и не файл, полученный
   переименованием другой DLL.

4. Самостоятельная проверка файлов

   Из корня распакованного пакета можно выполнить:

   Get-AuthenticodeSignature ".\THIRD-PARTY-FILES-HERE\nvngx_dlss.dll"
   Get-AuthenticodeSignature ".\THIRD-PARTY-FILES-HERE\nvngx_dlssnr.dll"
   (Get-Item ".\THIRD-PARTY-FILES-HERE\nvngx_dlss.dll").VersionInfo | Format-List CompanyName,ProductName,FileVersion
   (Get-Item ".\THIRD-PARTY-FILES-HERE\nvngx_dlssnr.dll").VersionInfo | Format-List CompanyName,ProductName,FileVersion

   Для обеих подписей Status должен быть Valid. Установщик повторяет эти проверки
   автоматически и не принимает неподписанные или переименованные NVIDIA DLL.


Ручная чистая установка
-----------------------

1. Закройте игру.

2. Распакуйте этот архив в любую отдельную папку с правами записи. Не нужно
   распаковывать его в системные каталоги.

3. Положите три зависимости из предыдущего раздела в
   THIRD-PARTY-FILES-HERE. Получится:

   THIRD-PARTY-FILES-HERE\
     LumeniteFX-mainline.zip
     nvngx_dlss.dll
     nvngx_dlssnr.dll

4. Откройте PowerShell в распакованной папке и выполните, заменив путь на свой:

   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-YAE-DLSS5.ps1 -GameDir "D:\Games\You Are Empty"

5. Установщик до копирования проверит:

   - наличие YOU_ARE_EMPTY.exe;
   - цифровые подписи и Product Name NVIDIA DLL;
   - структуру официального архива LumeniteFX;
   - 64-битную Windows.

6. Все заменяемые файлы автоматически сохраняются в:

   <папка игры>\_DLSS5-Backups\<дата-время>

   Там же создаются install-manifest.json и переносимая копия сценария
   восстановления.

7. Установщик не меняет реестр, драйвер, Windows Defender, системные каталоги
   или глобальные Vulkan layers.

Хеш игрового EXE не проверяется и не ограничивается. Его SHA-256 только
записывается в install-manifest.json резервной копии для диагностики.


Первый запуск
-------------

Запустите напрямую:

  YOU_ARE_EMPTY.exe

При первом старте компиляция шейдеров и создание нейронной модели могут занять
несколько секунд.

Горячие клавиши:

- Home — меню ReShade.
- Insert — host panel/меню OptiScaler.
- Клавиша эффектов ReShade использует VK 222; раскладка может отображать её как
  апостроф или «Э». При необходимости назначьте другую клавишу в Settings.

В списке ReShade должны быть включены и расположены в таком порядке:

  1. Lumenite_Kernel
  2. DLSS5_Feed

Lumenite создаёт optical-flow motion vectors, поскольку старый движок игры не
выдаёт собственные векторы движения.


Проверка результата
-------------------

После запуска в корне игры должны появиться:

- ReShade.log
- dlss5-feed.log

В host64 должны появиться:

- dlss5-feed-host.log
- ReShade.log
- OptiScaler.log

Нормальные маркеры работы:

ReShade.log:
  ReShade ... (32-bit) loaded from ...\OPENGL32.dll
  Registered add-on "DLSS 5 Feed (32-bit)"

dlss5-feed.log:
  effects: technique found
  DLSS5_MV_PROVIDER=3 (LumeniteFX Kernel)
  OpenGL: renderer="NVIDIA ..."
  host connected ... OpenGL client

host64\dlss5-feed-host.log:
  OptiScaler DLSS-NR loaded as WINMM.dll
  NGX calls are routed through OptiScaler DLSS-NR
  feature ready: ... DLAA

host64\OptiScaler.log:
  DLSS-NR reached through the game's DLSS input
  DLSS-NR running at ...
  DLSS-NR cost: ...

Именно регулярные строки DLSS-NR running/DLSS-NR cost подтверждают реальную
работу нейронной модели. Простого сообщения о загрузке DLL недостаточно.


Отключение
----------

Для временного отключения только Feeder измените в папке игры файл
dlss5-feed.cfg:

  enabled=0

После изменения перезапустите игру. Для включения верните enabled=1.

Для временного отключения всей цепочки переименуйте в папке игры:

  opengl32.dll -> opengl32.dll.off


Полное восстановление
---------------------

Закройте игру и выполните:

  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Restore-YAE-DLSS5.ps1 -GameDir "D:\Games\You Are Empty" -ConfirmRestore

Без -BackupDir сценарий выбирает самую новую резервную копию. Если установленный
файл был изменён после установки, он сначала переносится в pre-restore-changes,
а не удаляется безвозвратно.


Состав и версии
---------------

Точный проверенный набор указан в VERSIONS.txt. Публичный архив содержит
лицензионные тексты и notices в THIRD-PARTY-NOTICES.

Основные проекты:

- ReShade: https://reshade.me
- DLSS5-Feeder: https://github.com/jlrouzies-fr/DLSS5-Feeder/releases
- OptiScaler DLSS-NR: https://github.com/Dagherbou/OptiScaler_DLSSNR/releases
- LumeniteFX: https://github.com/umar-afzaal/LumeniteFX
- NVIDIA DLSS: https://github.com/NVIDIA/DLSS

Пакет не является официальным продуктом NVIDIA, разработчиков You Are Empty,
ReShade, DLSS5-Feeder, OptiScaler или LumeniteFX и не означает их одобрение.
