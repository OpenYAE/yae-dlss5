Обычному пользователю ничего скачивать сюда вручную не нужно.

Запустите Setup-YAE-DLSS5.cmd в корне пакета: он сам скачает, проверит и
разместит все три зависимости, а затем выполнит установку.

Ручной режим нужен только для офлайн-установки. В таком случае положите сюда:

1. LumeniteFX-mainline.zip

   Официальная загрузка:
   https://github.com/umar-afzaal/LumeniteFX/archive/refs/heads/mainline.zip

   Сохраните ZIP без распаковки именно под именем LumeniteFX-mainline.zip.

2. nvngx_dlss.dll

   Официальный x64 runtime из репозитория NVIDIA DLSS:
   https://github.com/NVIDIA/DLSS/tree/main/lib/Windows_x86_64/rel

   Прямая официальная загрузка:
   https://raw.githubusercontent.com/NVIDIA/DLSS/main/lib/Windows_x86_64/rel/nvngx_dlss.dll

3. nvngx_dlssnr.dll

   Автоматическая установка использует закреплённый архив RankFTW/rhi-repo,
   указанный в официальном установочном инструменте DLSS5-Feeder:
   https://github.com/RankFTW/rhi-repo/releases/download/dlssnr-310.8.0/nvngx_dlssnr_310.8.0.zip

   ZIP SHA-256:
   388C0A7912E15EC911B9C9E11A692142B11FE387DDF2B637D8C358138FFFB3AC

   Извлечённая DLL SHA-256:
   E16BCF15E16E13F527491CDF7845B2FE6521A738D8F7C9C721866A8496E1FC8E

   Альтернативный официальный источник:

   Скачайте свежий официальный Game Ready или Studio Driver:
   https://www.nvidia.com/en-us/drivers/

   Откройте driver .exe через 7-Zip (https://www.7-zip.org/), найдите внутри
   nvngx_dlssnr.dll и извлеките его в эту папку. Если файл отсутствует, проверьте
   более новый пакет драйвера.

   Правильный файл имеет Product Name «NVIDIA DLSSNR» и действительную цифровую
   подпись NVIDIA Corporation. Не переименовывайте nvngx_dlssd.dll или другую DLL.

Готовая структура:

THIRD-PARTY-FILES-HERE\
  LumeniteFX-mainline.zip
  nvngx_dlss.dll
  nvngx_dlssnr.dll

Подробная инструкция и команды PowerShell находятся в корневом README.txt.
Установщик проверяет подписи NVIDIA DLL и ожидаемые названия продуктов.
