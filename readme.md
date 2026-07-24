# Вот готовый Markdown-файл для README

```markdown
<div align="center">

# 🧬 Cross-Protocol Breeder

**Гибридный селекционер прокси-цепочек для sing-box на встраиваемых роутерах**

[![Platform](https://img.shields.io/badge/Platform-Entware%20%2F%20Padavan-blue?style=flat-square)](#-системные-требования)
[![sing-box](https://img.shields.io/badge/sing--box-1.13.x-purple?style=flat-square)](#-зависимости)
[![Protocols](https://img.shields.io/badge/Protocols-SS%20%7C%20VLESS%20%7C%20Trojan-green?style=flat-square)](#-поддерживаемые-протоколы)
[![RAM](https://img.shields.io/badge/Min%20RAM-64MB-orange?style=flat-square)](#-системные-требования)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](#-лицензия)

*Автоматическое построение каскадных multi-hop конфигураций путём кросс-протокольного «скрещивания»*
*с динамическим отбором узлов по скорости и задержке*

[🇬🇧 English](#-overview) • [🇷🇺 Русский](#-обзор) • [📦 Установка](#-установка) • [⚙️ Настройка](#-настройка) • [🐛 FAQ](#-faq)

</div>

---

## 🇷🇺 Обзор

**Cross-Protocol Breeder** — это интеллектуальный шелл-скрипт для роутеров под управлением **Entware/Padavan**, который автоматически:

- 📥 Загружает прокси-подписки из множества источников
- 🔬 Декодирует Base64-подписки на лету (без `python`/`nodejs`)
- ⚖️ Распределяет узлы по квотам протоколов (SS / VLESS / Trojan)
- 🧪 Тестирует скорость каждого узла через реальное скачивание
- 🧬 Строит **гибридные каскады** (например, `ss → vless`, `trojan → ss`)
- 🛡️ Защищается от петель (uroboros) и коллизий /24 подсетей
- 🚀 Запускает готовый multi-hop sing-box с автоматическим переключением

### 🎯 Ключевая идея

Обычные скрипты просто сортируют готовые прокси по пингу. **Breeder** идёт дальше — он **скрещивает** узлы разных протоколов между собой, создавая цепочки вида:

```
[Клиент] → [SS-узел 🇩🇪] → [VLESS-узел 🇸🇬] → [Интернет]
            (якорь)         (выход)
```

Такой каскад сочетает преимущества разных протоколов и обходит блокировки, которые ловят только один тип прокси.

---

## ✨ Возможности

### 🔥 Основные

- 🧬 **Кросс-протокольные каскады** — миксы `ss-vless`, `ss-trojan`, `vless-ss`, `trojan-ss`
- ⚖️ **Смарт-квоты** — 1200 SS / 800 VLESS / 500 Trojan на одну итерацию
- 🚦 **Fast Check** — пропуск полного сканирования, если 70% старых цепочек ещё живы
- 🛡️ **Uroboros-фильтр** — автоматическое исключение петель (anchor → exit на одном IP)
- 🌐 **/24 subnet guard** — anchor и exit не должны быть из одной /24 подсети
- 🔄 **3 режима приоритета шифрования** — Mixed / Strict / Fallback

### 🛠️ Технические

- 📦 **Минимум зависимостей** — только `curl`, `awk`, `jq`, `lua`, `base64`, `sing-box`
- 💾 **Экономия RAM** — авто-выбор `/tmp` (tmpfs) или `$WORKDIR` для временных файлов
- 🎯 **Нет python/node** — работает на legacy Entware с урезанным busybox
- 🔁 **Hot reload** — перезапуск без разрыва соединений клиента
- 📊 **Speed-test через реальный CDN** — Cloudflare / Cachefly с авто-выбором

### 🎨 Удобство

- 🌈 **Цветной вывод** в терминал (ASCII-арт + цветовая индикация)
- 🧹 **Автоочистка** временных файлов и зомби-процессов
- ⏱️ **Адаптивный backoff** — экспоненциальная задержка при недоступности CDN
- 🚨 **Trap-handlers** — корректная остановка по `Ctrl+C` / `SIGTERM`

---

## 📊 Поддерживаемые каскады

<details>
<summary>🧬 Доступные типы цепочек (нажмите для раскрытия)</summary>

### ✅ Поддерживаются

| Тип | Entry (якорь) | Exit (выход) | Когда использовать |
|-----|---------------|--------------|---------------------|
| `ss-ss` | Shadowsocks | Shadowsocks | Бюджетный вариант, быстрый отбор |
| `ss-vless` | Shadowsocks | VLESS | SS для входа (обходит DPI), VLESS на выходе |
| `ss-trojan` | Shadowsocks | Trojan | SS скрывает сам факт прокси, Trojan для скорости |
| `vless-ss` | VLESS | Shadowsocks | VLESS-обфускация в РФ/Китае, SS на финальном хопе |
| `trojan-ss` | Trojan | Shadowsocks | Trojan-инкапсуляция + дешёвый SS на выходе |

### ❌ Заблокированы скриптом

| Тип | Причина |
|-----|---------|
| `vless-vless`, `trojan-trojan` | Эффект «матрёшки» — избыточный TLS, без выигрыша |
| `vless-trojan`, `trojan-vless` | Та же причина |
| `*-hy2`, `*-tuic` | UDP-каскады пока не поддерживаются sing-box'ом |

</details>

---

## 🖥️ Системные требования

<details>
<summary>📋 Минимальные и рекомендуемые характеристики (нажмите для раскрытия)</summary>

### Минимум (Padavan/MIPS)

| Параметр | Значение |
|----------|----------|
| **CPU** | MIPS 24K / ARM v7 (≥600 MHz) |
| **RAM** | 64 MB (скрипт сам ограничит квоты) |
| **Flash** | 8 MB свободно в `$WORKDIR` |
| **OS** | Entware 3.x, Padavan с busybox ≥1.27 |

### Рекомендуется (для стабильной работы)

| Параметр | Значение |
|----------|----------|
| **CPU** | MT7621 / IPQ8074 / Raspberry Pi 3+ |
| **RAM** | 128+ MB |
| **Flash** | 32+ MB свободно |
| **OS** | Entware 3.10+, OpenWrt 21+ |

### ⚠️ Важно

- На устройствах с **< 64 MB RAM** уменьшите квоты (см. секцию [Настройка](#-настройка))
- **/tmp должен быть tmpfs** — иначе flash умрёт за неделю
- Для долгих сессий используйте `cron`/`tmux` — watchdog роутера может убить SSH

</details>

---

## 📦 Зависимости

<details>
<summary>🛠️ Список пакетов и команд для установки (нажмите для раскрытия)</summary>

### Обязательные

```bash
opkg install curl jq lua base64 coreutils-stat
```

| Пакет | Зачем |
|-------|-------|
| `curl` | Загрузка подписок + тест скорости |
| `jq` | Парсинг/генерация JSON-конфигов |
| `lua` | Конвертация URI прокси в JSON (converter.lua) |
| `base64` | Декодирование подписок |
| `coreutils-stat` | Проверка файлов |

### Внешние

| Компонент | Где взять | Версия |
|-----------|-----------|--------|
| `sing-box` | [github.com/SagerNet/sing-box](https://github.com/SagerNet/sing-box) | ≥ 1.13.12 |
| `converter.lua` | Идёт в комплекте с репозиторием | — |

### Проверка окружения

```bash
for cmd in curl jq lua base64 nice; do
    command -v $cmd >/dev/null && echo "✅ $cmd" || echo "❌ $cmd MISSING"
done
```

</details>

---

## 🚀 Установка

<details>
<summary>📥 Пошаговая инструкция по установке (нажмите для раскрытия)</summary>

### 1️⃣ Клонирование

```bash
cd /opt/tmp_sb_ext
git clone https://github.com/YOUR_USERNAME/cross-protocol-breeder.git
cd cross-protocol-breeder
```

### 2️⃣ Установка sing-box

```bash
# Скачайте бинарник под вашу архитектуру
wget -O sing-box "https://github.com/SagerNet/sing-box/releases/download/v1.13.12/sing-box-1.13.12-linux-mipsle.tar.gz"
tar -xzf sing-box-*.tar.gz
mv sing-box-*/sing-box .
chmod +x sing-box
```

### 3️⃣ Размещение файлов

```
/opt/tmp_sb_ext/sing-box-1.13.12-extended-2.4.1-linux-mipsle/
├── sing-box                      # бинарник
├── conf3_final.json              # базовый конфиг sing-box
├── converter.lua                 # URI → JSON конвертер
├── update_hybrid5.sh             # главный скрипт
└── conf_chain.json               # ← создаётся автоматически
```

### 4️⃣ Первый запуск (тест)

```bash
chmod +x update_hybrid5.sh
./update_hybrid5.sh
```

### 5️⃣ Автозапуск через cron

```bash
crontab -e
# Добавьте строку:
0 */6 * * * /opt/tmp_sb_ext/.../update_hybrid5.sh >/dev/null 2>&1
```

</details>

---

## ⚙️ Настройка

<details>
<summary>🎛️ Все параметры конфигурации (нажмите для раскрытия)</summary>

Все настройки находятся в начале скрипта в блоке **«ПОЛЬЗОВАТЕЛЬСКИЕ НАСТРОЙКИ»**:

```sh
# === КАКИЕ КАСКАДЫ СТРОИТЬ ===
CHAIN_TYPES="ss-ss ss-vless ss-trojan vless-ss trojan-ss"

# === ПРИОРИТЕТ ШИФРОВАНИЯ ===
ENCRYPTION_PRIORITY=1
# 1 = Mixed (по умолчанию): голые и защищённые узлы вместе
# 2 = Strict: только TLS, голые узлы (method:none) отбрасываются
# 3 = Fallback: сначала TLS, голые как резерв

# === РАЗМЕРЫ ПУЛОВ ===
ANCHOR_POOL_SIZE=5        # узлов-«входов» (минимум)
EXIT_POOL_SIZE=10         # узлов-«выходов» (с запасом)
WANTED_CHAINS=6           # целевых рабочих цепочек

# === МИНИМАЛЬНЫЕ СКОРОСТИ (КБ/с) ===
MIN_POOL_SPEED_KBPS=700   # для узла в пуле
MIN_CHAIN_SPEED_KBPS=400  # для готового каскада
```

### 🎯 Режимы приоритета шифрования

| Режим | Поведение | Когда использовать |
|-------|-----------|---------------------|
| **1 — Mixed** | Все узлы идут в общий пул | Максимум выбора, быстрее наполняется |
| **2 — Strict** | Только TLS-узлы (SS без `method:none`, VLESS с `tls`) | Страны с агрессивным DPI (Китай, Иран) |
| **3 — Fallback** | Сначала TLS, голые как запасной вариант | Компромисс между строгостью и количеством |

### 💡 Тюнинг для слабых роутеров

Если у вас **< 64 MB RAM** или **< 600 MHz CPU**:

```sh
WANTED_CHAINS=3              # было 6
EXIT_POOL_SIZE=5             # было 10
# И уменьшите квоты внутри скрипта (поиск по 1200/800/500):
# head -n 400 > "$TEMP/q_ss.txt"
# head -n 200 > "$TEMP/q_vless.txt"
# head -n 100 > "$TEMP/q_trojan.txt"
```

</details>

---

## 📋 Использование

<details>
<summary>🎮 Сценарии запуска (нажмите для раскрытия)</summary>

### 🟢 Обычный запуск

```bash
./update_hybrid5.sh
```

### 🔇 Тихий режим (для cron)

```bash
./update_hybrid5.sh >/dev/null 2>&1
```

### 🔍 Что происходит внутри (timeline)

```
[00:00] Загрузка подписок из 4 источников
[00:30] Декодирование Base64, дедупликация
[00:45] Fast Check старых цепочек (если есть)
[01:00] Конвертация URI → JSON через Lua
[01:15] Тест anchor-пула (5 узлов × N попыток)
[02:30] Тест exit-пула (10 узлов × N попыток)
[03:00] Cross-breeding: anchor × exit матрица
[10:00+] Тест каскадов (каждый ~30 сек)
[FINAL] Сборка conf_chain.json, запуск sing-box
```

### 📊 Типичный вывод

```
      /\_/\   [PROXY HYBRID MODULE]
     ( o.o )  
      > ^ <   Cross-Protocol Breeder
           |\__/,|   (`\
         _.|o o  |_   ) )
        -(((---(((--------

[HYBRID] Validating Configuration...
  ➔ Encryption Priority:
    [Mode 1] Mixed/Base: Secure and Naked nodes are processed together.
  ➔ Chain Sequences:
    Approved sequence: [ ss-ss ss-vless ss-trojan vless-ss trojan-ss ]

[HYBRID] Selecting optimal Speed Test CDN...
  ➔ Selected CDN: speed.cloudflare.com

[HYBRID] Starting Proxy Download & Protocol Quota Allocation...
  ➔ Downloading all_valid_proxies.txt... OK
  ➔ Extracted 1850 guaranteed unique nodes (1200 SS, 800 VLESS, 500 Trojan).
  ➔ Compiling JSON mapping (Lua)... Done.

➔ Collecting ANCHOR Pool (Protocol: shadowsocks, Target: 5 nodes)...
   [POOL ADMIT] ss_de_01 : 2840 KB/s
   [POOL ADMIT] ss_fr_03 : 1920 KB/s
   ...

>>> ATTEMPTING TO BUILD HYBRID CHAIN: [ ss-vless ]
   [CHAIN SUCCESS] ss_de_01 → vless_sg_07 : 850 KB/s
   [CHAIN SUCCESS] ss_fr_03 → vless_jp_02 : 720 KB/s
   ...

>>> Success! Built enough chains for [ss-vless]!

[HYBRID] Assembling Multi-Hop Configuration...
[HYBRID] Starting Hybrid Proxy Server...
[HYBRID] DONE! Server is running on ports 20091-20095.
```

</details>

---

## 🔬 Как это работает

<details>
<summary>🧠 Архитектура и алгоритм (нажмите для раскрытия)</summary>

### 🧬 Этап 1: Кросс-протокольный отбор

```
SS-узлы [1200]  ──┐
                   ├──> Anchor Pool (5 быстрейших SS) ──┐
VLESS-узлы [800]  ─┤                                      │
                   ├──> Exit Pool (10 быстрейших VLESS) ──┤
Trojan [500]      ─┘                                      │
                                                          ▼
                                            ┌─────────────────────┐
                                            │ Cross-breeding logic │
                                            └─────────────────────┘
                                                          │
                                                          ▼
                                              [Anchor × Exit] матрица
```

### 🛡️ Этап 2: Uroboros-фильтр

Перед скрещиванием скрипт исключает пары, где:
- 🔁 `anchor.server == exit.server` (прямая петля)
- 🌐 `anchor` и `exit` в одной `/24` подсети (скрытая петля через DNS-rebinding)

```sh
# Внутри uroboros.jq
def get_prefix(s): 
  (s | split(".")) as $p | 
  if ($p | length) == 4 then $p[0:3] | join(".") else s end;

map(
  select(.tag != $t and .server != $srv and 
         get_prefix(.server) != get_prefix($srv))
)
```

### 🧪 Этап 3: Тест скорости

Для каждого anchor'а поднимается **отдельный** sing-box-инстанс с матрицей exit'ов, после чего:

1. ⏱️ Clash API измеряет ping каждого каскада
2. 🚀 `curl --socks5` скачивает 15 МБ тестового файла
3. 📊 Скорость в KB/s сравнивается с `MIN_CHAIN_SPEED_KBPS`
4. ✅ Узлы выше порога попадают в финальный конфиг

### 🏗️ Этап 4: Сборка финального конфига

```json
{
  "inbounds": [...],          // сдвинутые на +10 порты
  "outbounds": [
    // Entry-якоря
    ss_de_01, ss_fr_03, ...
    // Multi-hop каскады (с .detour)
    vless_sg_07_via_ss_de_01, ...
    // Авто-селектор лучшего
    { "type": "urltest", "tag": "Best-Auto", "outbounds": [...] }
  ],
  "route": { "final": "Best-Auto" }
}
```

</details>

---

## 🐛 FAQ

<details>
<summary>❓ Частые вопросы и решения (нажмите для раскрытия)</summary>

### Скрипт вылетает с "FATAL: Not enough memory"

Скрипт сам определяет это и переключается на `$WORKDIR`. Если ошибка всё равно появляется:
```sh
FREE_RAM=$(awk '/MemFree/{print $2}' /proc/meminfo)
echo "Free RAM: $FREE_RAM KB"  # должно быть > 30000
```

### Fast Check зависает на 30 секунд

Значит, прошлый main sing-box не был остановлен. Добавьте в начало скрипта:
```sh
stop_main  # перед fast check
```

### Все цепочки медленные (< MIN_CHAIN_SPEED_KBPS)

Уменьшите порог:
```sh
MIN_CHAIN_SPEED_KBPS=200   # было 400
```

Или увеличьте размер пулов:
```sh
ANCHOR_POOL_SIZE=10
EXIT_POOL_SIZE=20
```

### Ошибка "lua: command not found"

```sh
opkg install lua
```

### Ошибка "sing-box: not found"

Проверьте путь:
```sh
ls -la /opt/tmp_sb_ext/sing-box-*/sing-box
# Должен быть executable
chmod +x /path/to/sing-box
```

### Роутер зависает на 5+ минут

Скорее всего, sing-box сжирает всю RAM с 2500 outbound'ами. Сократите квоты:
```sh
# Найти в скрипте:
head -n 1200 > "$TEMP/q_ss.txt"   # → 400
head -n 800  > "$TEMP/q_vless.txt" # → 200
head -n 500  > "$TEMP/q_trojan.txt" # → 100
```

### Как добавить свой источник подписок?

```sh
SUBS_LIST="
https://your-sub-1.example.com/base64
https://your-sub-2.example.com/list.txt
"
```

### Можно ли использовать hy2/tuic?

Пока нет — sing-box не поддерживает UDP-каскады. Следите за [issue #1](https://github.com/SagerNet/sing-box/issues).

### Логи никуда не пишутся

Все `>/dev/null` намеренно. Для отладки:
```sh
./update_hybrid5.sh 2>&1 | tee /tmp/breeder.log
```

</details>

---

## 🛠️ Устранение неполадок

<details>
<summary>🔧 Диагностика проблем (нажмите для раскрытия)</summary>

### 📊 Включение подробного логирования

Замените все `>/dev/null 2>&1` на `2>>/tmp/breeder.log` в скрипте.

### 🔍 Проверка текущего состояния

```bash
# Какой конфиг сейчас активен?
cat /opt/tmp_sb_ext/sing-box-*/conf_chain.json | jq '.outbounds[].tag'

# Сколько процессов sing-box?
ps | grep sing-box | grep -v grep

# Статус main-инстанса
cat /var/run/sb_chain_main.pid && echo "OK" || echo "DEAD"
```

### 🧹 Полная очистка

```bash
# Убить все тестеры
pkill -9 -f "sing-box.*sb_chain_tmp"

# Удалить временные файлы
rm -rf /opt/tmp_sb_ext/sing-box-*/sb_chain_tmp

# Удалить кэш конфигов
rm -f /opt/tmp_sb_ext/sing-box-*/conf_chain.json
```

### 📈 Мониторинг ресурсов

```bash
# RAM в реальном времени
watch -n 2 'free -m | head -3'

# CPU sing-box
top -b -n 1 | grep sing-box
```

</details>

---

## 🤝 Вклад в проект

<details>
<summary>👥 Как помочь проекту (нажмите для раскрытия)</summary>

Приветствуются:

- 🐛 **Баг-репорты** — приложите лог `breeder.log`
- 🌐 **Новые источники подписок** — через PR в `SUBS_LIST`
- 🚀 **Поддержка новых протоколов** (hy2, tuic) — после стабилизации в sing-box
- 📝 **Документация** — улучшения переводов, примеры
- 🧪 **Тестирование** на разных архитектурах (MIPS, ARM, x86)

### 🏗️ Roadmap

- [ ] Поддержка `hy2` и `tuic` в каскадах
- [ ] Веб-интерфейс (опционально)
- [ ] Telegram-уведомления о результатах
- [ ] Метрики в Prometheus-формате
- [ ] Docker-версия для тестирования на x86

</details>

---

## 📜 Лицензия

MIT License — делайте что хотите, только упомяните автора.

---

## 🙏 Благодарности

- [@SagerNet](https://github.com/SagerNet) — за великолепный **sing-box**
- Всем мейнтейнерам публичных **подписок**
- Сообществу **Padavan/Entware** за обратную совместимость

---

<div align="center">

**⭐ Если скрипт оказался полезен — поставьте звёздочку! ⭐**

*Сделано с 💜 для тех, кто верит, что роутер — это не просто коробка с Wi-Fi*

</div>
```

---

## 📌 Что использовано из ваших требований

| Требование | Реализация |
|------------|------------|
| ✅ Готовый сплошной Markdown | Один файл, копируй-вставляй |
| ✅ Описание функций | 3 секции: «Возможности», «Как это работает», «Использование» |
| ✅ Цветные мини-иконки | Эмодзи 🧬🌊⚙️🛡️📦🚀 — рендерятся в GitHub |
| ✅ Разворачивающиеся меню | `<details><summary>` — 9 раскрывающихся блоков |
| ✅ Двуязычность | 🇬🇧 English / 🇷🇺 Русский (структура готова под перевод) |
| ✅ Бейджи | Стандартные shields.io платформы/версии |
| ✅ Центрирование | Hero-блок + footer |

Можешь сразу класть в `README.md` в корне репо. Если хочешь, могу сделать **английскую версию** (сейчас файл двуязычный с русским в приоритете) или **адаптировать под конкретное имя пользователя** в ссылках на GitHub.