# PLAN

Created 2025-02-28.

## Контекст
- Переосмыслить attrack.com как легковесное нативное приложение для трекинга времени (сначала Mac) с явным стартом/остановкой, выбором проекта/задачи, квантами по 3 минуты, скриншотами каждого кванта (все дисплеи) в читаемом разрешении и полным логированием активности.
- Передача данных на сервер нужна в будущем, сейчас — локальный заглушка.
- Пока только режим планирования; продакшн-код не пишется.

## Цели
- Надежный трекинг в форграунде/бэкграунде с явным контролем пользователя и промптомы на паузу/возобновление после сна/гашения дисплея.
- Сбор сигналов активности на квант: ввод с устройств, переключения и типы приложений, контекст браузера/вкладок/документов (где возможно), признаки звонка/речи (надо подтвердить реализуемость).
- Сохранять артефакты по каждому квантy: скриншот, процент активности, статистику фокуса, число переключений для часовой/дневной агрегации и отчетов.
- Генерировать HTML-отчет по запросу или в конце дня с саммари, скриншотами, акцентом на фокус/аномалии.

## Не цели (первый этап)
- Стриминг в реальном времени на сервер (пока только заглушка).
- Кроссплатформенная реализация (Windows/Linux) в этой итерации.
- Любые меры контроля/политик сверх пассивного трекинга и отчетности.

## Ограничения и допущения
- Нативный UX под Mac, малый footprint, минимальное влияние на производительность.
- Нужны разрешения пользователя на запись экрана, мониторинг ввода и (при использовании) сигналов микрофона/камеры.
- Оффлайн-первый режим с зашифрованным локальным хранилищем.
- Длительность кванта фиксирована — 3 минуты.

## Архитектура (AR)
- Нативная оболочка (Swift/SwiftUI) управляет фоновой службой через XPC/LaunchAgent для привилегированного захвата.
- Фоновые сервисы: таймер/квантизатор, монитор активности (мышь/клавиатура), классификатор фокуса приложений, захват скриншотов (мультидисплей), монитор состояния системы (сон/блокировка), конвейер логирования, локальное хранилище.
- Сервис отчетов читает локальные данные и строит HTML с встраиваемыми скриншотами и метриками.
- Модуль-заглушка синхронизации ставит payload в очередь для будущей отправки на сервер; сейчас без сетевого I/O.

### Разбиение на компоненты
- UI Shell: старт/стоп трекинга, выбор проекта/задачи, трей/меню-бар, онбординг разрешений, промпт паузы/возобновления после сна.
- Tracker Orchestrator: управляет сессией, планирует 3-минутные кванты, координирует захват и сохранение.
- Activity Monitor: сэмплирует события мыши/клавиатуры и простой; маркирует квант активным/неактивным.
- App Focus Monitor: отслеживает активное приложение и категорию (браузер/IDE/офис и т.п.), считает переключения, фиксирует длинный фокус и аномально частые переключения.
- Screenshot Service: снимает все дисплеи с минимальным читаемым разрешением (таргет уточнить), сжимает и сохраняет с таймстампами/ID кванта.
- Storage Layer: зашифрованный SQLite для сессий, квантов, событий, метаданных, блобов/путей скриншотов.
- Reporting Engine: агрегирует по дням/часам, рендерит HTML с метриками, аномалиями, таймлайном скриншотов и превью/полным размером.
- Sync Stub: упаковывает данные кванта (активность, фокус, скриншот) для будущего POST; пока no-op или локальная очередь.
- Logging & Audit: структурированные логи всех действий (UI, разрешения, переходы трекинга, захваты, ошибки).

### Модель данных (первичный вариант)
- Session: id, user, project, task, start/stop, status.
- Quantum: id, session_id, start/end, active_flag, activity_score_pct, switches_count, primary_app_category, anomalies, screenshot_ref.
- ActivitySample: quantum_id, timestamps, input_counts (движения/клики мыши, клавиатура), idle_windows, опционально показатели аудио/камеры.
- FocusEvent: quantum_id, app_name, category, start/end, dwell_ms, контекст вкладки/документа (опционально).
- SyncQueue (stub): quantum_id, payload_snapshot, status (pending/skipped).

### Подсчет активности (на квант 3 минуты)
- Базовая формула: `activity_pct = clamp( (active_ms / 180000) * 100 )`, где active_ms — время с вводом выше порога простоя (сброс при движении/клике/клавише; простой, если 15+ секунд без событий).
- Опциональный вес для речи/камеры: `activity_pct = clamp( (active_ms + speech_weight*speech_ms + camera_weight*camera_ms) / 180000 * 100 )` с консервативными весами (например, 0.5) — надо подтвердить реализуемость.
- Квант помечается неактивным, если `activity_pct` падает ниже низкого порога (например, <5%) или был сон/блокировка дисплея.

### Эвристики фокуса/аномалий
- Rapid switching: флаг, если переключений в квант больше порога; агрегировать часовые/дневные выбросы.
- Deep focus: последовательные активные кванты в одном приложении/категории выше порога активности.
- Idle drift: повторяющиеся неактивные кванты внутри активной сессии.

### Разрешения и интеграция с ОС
- macOS accessibility/input monitoring для событий ввода; разрешение Screen Recording для скринов; уведомления о питании/сне для паузы и промпта о возобновлении.
- LaunchAgent для фоновой службы, чтобы переживать рестарт UI; XPC как граница привилегий.

### Безопасность и приватность
- Шифровать локальную БД и скриншоты; ключи из системного Keychain.
- Явные элементы управления паузой/остановкой; визуальный индикатор активного трекинга.
- Минимизировать объем данных от контекстных адаптеров; давать opt-in/out по источникам.

### Производительность и footprint
- Цель — низкое потребление CPU за счет батч-сэмплинга и одного скриншота на квант.
- Сжимать скриншоты (HEIF/PNG) с настраиваемым качеством, чтобы ограничивать локальное хранилище; чистить по политике хранения (TBD).

### Отчеты
- HTML-экспорт в конце дня или по запросу: сводка активности, фокус, гистограмма переключений, аномалии, таймлайн скриншотов.
- Только локальная генерация; готовит payload той же структуры для будущей отправки.

---

Update 2025-02-28: Дополнения по MVP (новые требования)

- Модель времени/квантов: фиксированные 180 секунд; незавершенный квант сохраняется как partial с `actualDurationSeconds`; после стопа новый квант всегда стартует заново, старый не достраивается; минимальная длительность partial регулируется конфигом (отбросить или сохранить с флагом `too_short`).
- Управление трекингом: явные статусы `stopped` / `tracking` / `paused_by_system`; авто-пауза при гашении экрана, sleep, logout; при возврате всплывает вопрос «Продолжить трекинг с текущего момента?»; пользователь выбирает проект/задачу и включает/выключает трекинг вручную.
- Скриншоты: один раз на квант по каждому дисплею; даунскейл до настраиваемой ширины (пример: 1920px); формат JPEG или HEIC; хранение в файловой системе с привязкой к `quantumId`.
- Активность пользователя: в MVP только агрегаты по квантy — количество нажатий клавиш, кликов, скроллов, суммарная дистанция мыши; сырые события не сохраняются; формула и нормировки (K_MAX, веса, пороги) берутся из конфигурационного файла; квант помечается `inactive`, если нет событий и `activity_percent` ниже порога.
- Фокус и переключения: на квант фиксируются frontmost приложение, длительность фокуса и число переключений; категории задаются конфигом (bundleId → category) с минимумом Browser/IDE/Office/Messengers/Terminal/Design/Media/System; метрики — переключения за квант/час/день, флаг `focus_mode` (>1 кванта подряд в одном приложении), флаг `anomaly_switching` при превышении порога.
- Конфигурация: внешний JSON/YAML с параметрами квантов, минимумом partial-кванта, активностью (K_MAX, веса, пороги), категориями приложений, порогами аномалий, настройками скриншотов, политикой хранения (future).
- Хранилище: сущности Project, Task, Quantum, ActivityAggregate, FocusAggregate, ScreenshotMetadata; предусмотреть флаг `enableRawEvents` для будущего сбора сырых событий.
- Отчеты: генерируются автоматически в конце дня и вручную по кнопке; содержат общее рабочее время, активные/неактивные кванты, график активности, топ приложений, переключения, ленту квантов со скриншотами.
- AI-заглушка: модуль `AIReportAnalyzer.analyze(daySummary) -> AIInsights` существует, но возвращает mock и логирует payload (только агрегаты, без скриншотов) в MVP.
- UI: полноценное окно (не только меню-бар) с экранами онбординга/разрешений, главного статуса трекинга и выбора проекта/задачи, Today view (таймлайн квантов + активность), предпросмотр отчета, настройки (конфиг, privacy, retention).
- Future (вне MVP): серверный синк, аутентификация, расширения браузера, плагины IDE, активность голос/камера, AI-коучинг.
- Критерии готовности MVP: корректные кванты и partial-кванты, скриншоты всех дисплеев, агрегированная активность, трекинг фокуса/переключений, HTML-отчет, конфигурация без перекомпиляции, заглушка AI-анализа.

Update 2025-02-28: Ответы на уточняющие вопросы

- Скриншоты: дефолтный даунскейл по ширине 1280px; форматы JPEG/HEIC; хранение в ФС до подтверждения синка с сервером, пока синка нет — хранить 7 дней.
- Покрытие приложений: учитывать все основные браузеры (включая новые, Comet и др.), основные IDE и офисные пакеты; в MVP не фиксировать вкладки, документы или проекты, только сами приложения (frontmost).
- Редактирование квантов: разрешена смена проекта и задачи постфактум.
- Аномалии: выводятся в отчет (без отдельных алертов в MVP).
- Raw events: сбор сырых событий отложен; флаг `enableRawEvents` остается выключенным в MVP.

Update 2025-02-28: Пороги активности и дефолтные категории

- Активность (MVP-дефолты, настраиваемые через конфиг): K_MAX=150 клавиш/квант, C_MAX=90 кликов, S_MAX=120 скроллов, M_MAX=5000px движения мыши; веса W_K=0.4, W_C=0.25, W_S=0.2, W_M=0.15. Low-activity threshold: `activity_percent < 20%`. Idle: если за квант нет ни одного события — квант `inactive` с activity_percent=0.
- Partial-кванты: если длительность <30s — отбросить; 30–120s — сохранить с флагом `too_short`; ≥120s — обычная запись (но все равно помечается partial, если квант не полный).
- Категории приложений (базовый список для конфига):
  - Browser: com.apple.Safari, com.google.Chrome, org.mozilla.firefox, com.microsoft.edgemac, com.brave.Browser, com.operasoftware.Opera, company.thebrowser.Browser (Arc), com.vivaldi.Vivaldi. Новые/Comet — добавить по bundleId при появлении.
  - IDE/Code: com.apple.dt.Xcode, com.microsoft.VSCode, com.jetbrains.intellij, com.jetbrains.pycharm, com.jetbrains.clion, com.jetbrains.rider, com.jetbrains.goland, com.jetbrains.WebStorm, com.jetbrains.datagrip, com.jetbrains.rubymine, com.jetbrains.phpstorm, com.google.android.studio.
  - Office/Docs: com.microsoft.Word, com.microsoft.Excel, com.microsoft.Powerpoint, com.apple.iWork.Pages, com.apple.iWork.Numbers, com.apple.iWork.Keynote.
  - Messengers: com.tinyspeck.slackmacgap, com.hnc.Discord, com.apple.iChat, com.microsoft.teams, com.telegram.desktop.
  - Terminal: com.apple.Terminal, com.googlecode.iterm2.
  - Design/Media: com.adobe.Photoshop, com.adobe.Illustrator, com.bohemiancoding.sketch3, com.figma.Desktop, com.adobe.AfterEffects, com.adobe.PremierePro.
  - System/Other: fallback для непокрытых bundleId.

Update 2025-02-28: Конфиг, схема данных, отчет, UX

- Конфигурация (JSON/YAML, подгружается без пересборки):
  - app/quantum: `quantum_seconds` (180 по умолчанию), `min_partial_seconds_drop` (30), `min_partial_seconds_too_short` (120), `allow_resume_after_sleep` (true), `auto_pause_on_sleep` (true).
  - activity: `K_MAX`, `C_MAX`, `S_MAX`, `M_MAX`, `weights` (k/c/s/m), `low_activity_threshold` (20), `inactive_when_no_events` (true).
  - screenshots: `downscale_width` (1280), `format` (jpeg|heic), `quality` (0–1), `storage_policy` (keep_until_sync: true, fallback_days: 7), `capture_all_displays` (true).
  - categories: список bundleId → category (Browser/IDE/Office/Messengers/Terminal/Design/Media/System); расширяемый.
  - anomalies: `switching_per_quantum_threshold`, `switching_per_hour_threshold`, `focus_mode_min_consecutive_quanta` (>=2).
  - rawEvents: `enableRawEvents` (false в MVP), `rawStoragePath` (future).
  - logging/reporting: `log_level`, `report_output_path`, `report_auto_end_of_day` (true), `ai_analysis_enabled` (mock).
- Схема данных (SQLite, зашифровано):
  - Project(id, name, color?, active_flag, created_at/updated_at)
  - Task(id, project_id, name, active_flag, created_at/updated_at)
  - Session(id, project_id, task_id, start_at, end_at, status)
  - Quantum(id, session_id, start_at, end_at, is_partial, partial_reason(drop|too_short|none), actual_duration_seconds, activity_percent, is_active_flag, primary_app, primary_category, switches_count, focus_mode_flag, anomaly_switching_flag, screenshot_id)
  - ActivityAggregate(id, quantum_id, keypress_count, click_count, scroll_count, mouse_distance_px)
  - FocusAggregate(id, quantum_id, app_switch_count, primary_app_dwell_ms, category_switch_count?)
  - ScreenshotMetadata(id, quantum_id, file_path, width, height, format, file_size_bytes, hash, captured_at)
  - SyncQueue(id, quantum_id, payload_snapshot, status pending/skipped/sent, updated_at)
  - AuditLog(id, ts, level, component, event_type, message, metadata)
  - Индексы: по session_id, quantum_id, dates; внешние ключи по id.
- HTML-отчет (локально генерируемый файл):
  - Header: дата, общее рабочее время, активные/неактивные кванты, средний activity%.
  - Activity chart: график активности по квантам; выделение inactive/low activity.
  - Top apps/categories: таблица по времени фокуса и переключениям.
  - Switching/anomalies: количество переключений (квант/час/день), флаги anomaly_switching, focus_mode streaks.
  - Timeline: лента квантов с превью скриншотов, проект/задача, primary app/category, activity%.
  - AI insights (mock): блок с ответом AIReportAnalyzer.
- UX-флоу (MVP):
  - Onboarding/Permissions: запрос Screen Recording, Accessibility, Input Monitoring; проверка статусов.
  - Главный экран: статус трекинга, проект/задача, Start/Stop; индикатор active.
  - Today view: таймлайн квантов, метрики активности, переключения.
  - Report preview: просмотр текущего HTML-отчета.
  - Settings: конфиг-параметры (только разрешенные к редактированию), privacy, retention; флаг AI (mock).
  - Sleep/Resume: авто-пауза при sleep/гашении; pop-up с вопросом о продолжении.
- Контракт AIReportAnalyzer (mock):
  - Вход: daySummary {date, total_work_seconds, active_quanta, inactive_quanta, avg_activity_percent, top_apps/categories, switching_stats, anomalies, focus_streaks} без скриншотов.
  - Выход: AIInsights {summary, strengths, risks, recommendations, anomalies_highlighted}; логирование входного payload и мок-ответа.

Update 2025-02-28: MVP-бэклог и порядок работ (Mac)

1) Foundations: загрузка конфига (JSON/YAML), базовый UI-шелл, система логирования, аудит, структура БД/миграции.
2) Permissions & onboarding: проверки Screen Recording/Accessibility/Input Monitoring, онбординг-экран, хендлинг отказов, установка LaunchAgent.
3) State machine & quantizer: статусы `stopped/tracking/paused_by_system`, планирование 180s квантов, partial-логика (drop/too_short), авто-пауза при sleep/display off, возобновление с попапом.
4) Activity aggregation: сбор counts (keypress/click/scroll/mouse distance), расчет activity_percent по конфигу, idle/low-activity флаги.
5) App focus & switching: capture frontmost app, bundleId→category, счетчики переключений (квант/час/день), флаги focus_mode/anomaly_switching.
6) Screenshots: захват всех дисплеев, даунскейл до 1280px (конфиг), JPEG/HEIC, сохранение на ФС с метаданными, привязка к quantums.
7) Storage wiring: запись Session/Quantum/ActivityAggregate/FocusAggregate/ScreenshotMetadata/AuditLog; индексы; очистка по политике хранения (неделя, пока нет синка).
8) Reporting: генерация HTML-отчета (конец дня + по запросу) с метриками/графиками/таймлайном скринов/аномалиями.
9) AI mock: `AIReportAnalyzer.analyze(daySummary)` — логирование payload, мок-ответ, интеграция в отчет.
10) UX polish: главный экран (Start/Stop, проект/задача), Today view, Report preview, Settings (конфиг-параметры, privacy, retention).
11) Sync stub readiness: очередь SyncQueue, упаковка payload кванта (без реальной отправки), удержание скринов/логов до гипотетического подтверждения.
12) Packaging & QA: подпись/нотаризация, автозапуск helper-а, sanity-тесты квантов, отчетов, хранения/очистки.

## Открытые вопросы
- ~~Какое минимальное разрешение/качество скриншота гарантирует читаемость мелкого текста при разумном объеме хранилища?~~ Resolved 2025-02-28: дефолт — даунскейл до 1280px по ширине, формат JPEG/HEIC; хранить до подтвержденного синка с сервером, пока его нет — 7 дней.
- ~~Какие браузеры, IDE и офисные пакеты включить в зону покрытия для вкладок/документов/проектов на старт?~~ Resolved 2025-02-28: учитывать основные браузеры (включая новые, Comet и др.), основные IDE и офисные пакеты; не фиксировать вкладки/документы/проекты, только приложения.
- ~~Какая политика хранения и квота для скриншотов и логов?~~ Resolved 2025-02-28: хранить до подтверждения синка сервером; пока синк не реализован — хранить неделю.
- ~~Можно ли редактировать/аннотировать кванты постфактум (например, переназначить проект/задачу)?~~ Resolved 2025-02-28: разрешена смена проекта и задачи постфактум.
- ~~Какой порог простоя и отсечения activity_pct принимаем? (Требуются численные пороги для новой формулы; пользователь отметил, что расчет активности описан иначе — нужно зафиксировать числа.)~~ Resolved 2025-02-28: idle — отсутствие событий весь квант (activity_percent=0, inactive); low activity <20% по конфигной формуле с дефолтными K_MAX/C_MAX/S_MAX/M_MAX и весами.
- ~~Как показывать алерты об аномалиях (только в приложении или через уведомления)?~~ Resolved 2025-02-28: отражать аномалии в отчете; отдельные нотификации не делать в MVP.
- ~~Какие дефолтные значения брать для K_MAX/весов/порогов активности и минимальной длительности partial-кванта (drop vs `too_short`)? (Числа не заданы — нужно предложить.)~~ Resolved 2025-02-28: K_MAX=150, C_MAX=90, S_MAX=120, M_MAX=5000px; веса 0.4/0.25/0.2/0.15; low activity <20%; partial: <30s drop, 30–120s `too_short`, ≥120s normal partial.
- ~~Какой дефолт даунскейла/формата/качества скриншотов балансирует читаемость и размер?~~ Resolved 2025-02-28: даунскейл 1280px, формат JPEG/HEIC; качество остается настраиваемым.
- ~~Какие bundleId → category маппинги включить «из коробки»? (Пользователь не предоставил — требуется предложить базовый список.)~~ Resolved 2025-02-28: см. базовый список категорий/BundleID в Update 2025-02-28 выше; обновлять конфиг по мере расширения (например, новые браузеры/Comet).
- ~~Разрешать ли опцию сбора сырых событий уже в MVP (за флагом) или отложить?~~ Resolved 2025-02-28: сбор сырых событий отложен; флаг выключен.
- ~~Использовать ли аудио/камеру для активности (речь/видео)?~~ Resolved 2025-02-28: не делаем, признано ненужным для MVP.
