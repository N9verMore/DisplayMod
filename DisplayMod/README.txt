DisplayMod 1.1 — настройки экрана для BLACK SOULS II
=====================================================
(English below)

Что делает
----------
* Режим экрана:
    Оконный       — обычное окно выбранного размера.
    Безрамочный   — окно без рамки на весь монитор (рекомендуется:
                    мгновенный Alt+Tab, разрешение рабочего стола).
    Полноэкранный — то же, но с переключением разрешения монитора.
* Разрешение: размер окна (оконный) или разрешение монитора (полноэкранный).
* Масштаб:
    Авто (растянуть) — картинка на весь экран.
    Пропорционально  — без искажений, по краям чёрные полосы.
    x1, x2, ...      — целочисленное увеличение (самые чёткие пиксели).
* Штатный Alt+Enter (полноэкранный 640x480) заменён: теперь он переключает
  «оконный <-> последний полноэкранный режим».

Установка
---------
1. Распакуйте архив в папку игры, чтобы получилось:
       BLACK SOULS II\Game.exe
       BLACK SOULS II\DisplayMod\install.bat
   (папку игры в Steam: ПКМ по игре -> Управление -> Просмотреть локальные файлы)
2. Закройте игру и запустите DisplayMod\install.bat.

Python и другие программы не нужны — установщик использует встроенный
в Windows PowerShell. Мод встраивается в ВАШИ скрипты игры, остальные
скрипты не меняются, поэтому он совместим с официальным 18+ патчем,
переводами и разными версиями игры. Меню само переключается на русский,
если игра русифицирована, иначе — английский.

Важно: если вы ставите перевод или патч ПОСЛЕ мода, он может перезаписать
скрипты игры — просто запустите install.bat ещё раз. То же после проверки
целостности файлов в Steam.

Удаление: DisplayMod\uninstall.bat (убирает только мод).
Бэкап ваших скриптов до установки: DisplayMod\Scripts.rvdata2.backup.

Управление
----------
F5          — меню настроек (в любой момент), также пункт
              «Настройки экрана» на титульном экране.
Вверх/вниз  — выбор строки, влево/вправо — значение, «Применить» —
              применить и сохранить, Esc/X/F5 — закрыть.
Alt+Enter   — оконный / полноэкранный.

Настройки хранятся в DisplaySettings.ini в папке игры (удалите файл,
чтобы вернуть настройки по умолчанию). Строка language=ru / en / auto
задаёт язык меню.

Ограничения движка RPG Maker VX Ace
-----------------------------------
* Игра всегда рисует картинку 640x480 — мод её масштабирует,
  больше деталей появиться не может.
* Когда окно игры неактивно, движок полностью замирает. Поэтому в режиме
  «Полноэкранный» при Alt+Tab монитор остаётся в разрешении игры, пока вы
  не вернётесь в игру или не выйдете из неё (при выходе разрешение
  возвращается автоматически).
* Если в окне F1 включён запуск в полноэкранном режиме, при старте экран
  один раз мигнёт (движок включает свой режим 640x480, мод его выключает).
  Снимите эту галочку в F1, чтобы убрать мигание.

Отладка: создайте пустой файл DisplayMod\debug — мод начнёт писать
DisplayMod\log.txt.


=====================================================
DisplayMod 1.1 — display settings for BLACK SOULS II
=====================================================

Features
--------
* Display mode: Windowed / Borderless (recommended) / Fullscreen
  (borderless + changes the monitor resolution).
* Resolution: window size (windowed) or monitor resolution (fullscreen).
* Scaling: Auto (stretch), Keep aspect (black bars), x1/x2/... integer
  scaling (sharpest pixels).
* The built-in Alt+Enter (640x480 fullscreen) is replaced: it now toggles
  windowed <-> your fullscreen mode.

Install
-------
1. Extract the archive into the game folder so that you get
       BLACK SOULS II\DisplayMod\install.bat   (next to Game.exe)
2. Close the game and run DisplayMod\install.bat.

No Python needed (uses PowerShell built into Windows). The mod is inserted
into YOUR game scripts and leaves all other scripts untouched, so it works
with the official 18+ patch, translations and different game versions.
If you install a patch/translation after the mod, just run install.bat again.

Uninstall: DisplayMod\uninstall.bat.

Controls: F5 — settings menu (anytime, also "Display" on the title screen),
Alt+Enter — windowed / fullscreen. Settings: DisplaySettings.ini
(language=ru / en / auto).

Engine limits: the game always renders at 640x480 (the mod only scales it);
the engine freezes while the window is inactive, so in Fullscreen mode the
monitor keeps the game resolution while you Alt+Tab, until you return or
quit the game.
