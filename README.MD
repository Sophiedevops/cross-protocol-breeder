Вот готовый код для вашего файла `readme.md`, в котором русская часть была визуально улучшена для публикации на GitHub (добавлены цитаты, структурированные списки, выделение кода и иконки), а все остальные языковые разделы приведены в точное структурное и стилистическое соответствие с ней. 

Сохраните следующий текст в файл с именем `readme.md`:

```markdown
### 🧬 cross-protocol-breeder

**🖥️ Архитектуры, которые определяет и обрабатывает `install.sh` / Architectures auto-detected by `install.sh`**

| Семейство / Family | Варианты / Variants |
| :--- | :--- |
| 🦾 **ARM** | `armv6` · `armv7` · `aarch64` |
| 🧩 **MIPS** | `mips` (BE) · `mipsel` (LE) · `mips64` · `mips64el` |
| 🚀 **RISC-V** | `riscv64` |
| 🐉 **LoongArch** | `loongarch64` |
| 🖥️ **IBM Z** | `s390x` |
| 📚 **libc** | `musl` · `glibc` · `uClibc` — определяется автоматически |
| 🏠 **Прошивка / Firmware** | OpenWrt · Padavan · Merlin (Asuswrt) · Keenetic · Entware |

`install.sh` сам определяет архитектуру процессора, порядок байт (endianness) и тип libc, скачивает подходящий бинарник `sing-box` и проверяет его флагом `version` — если endianness для mips определить не удалось, установка **безопасно останавливается до скачивания** любых файлов (см. `FORCE_ENDIAN` в самом скрипте).

---

##### 🌐 Доступные языки / Available languages

* [🇷🇺 Русский](#-русский)
* [🇬🇧 English](#-english)
* [🇮🇷 فارسی](#-فارسی)
* [🇨🇳 中文](#-中文)
* [🇸🇦 العربية](#-العربية)

---

#### 🇷🇺 Русский

> 🌟 *Автоматическое построение каскадных multi-hop конфигураций путём кросс-протокольного «скрещивания» — теперь на любом поддерживаемом роутере: MIPS, ARM, RISC-V и не только.*

##### 🧩 Что это такое?
**Cross-Protocol Breeder** 🧬 — это интеллектуальный шелл-скрипт, который автоматически загружает подписки, тестирует скорость узлов и строит **гибридные каскады** (например, `ss → vless`, `trojan → ss`).

Скрипт решает задачу создания устойчивых к блокировкам цепочек на слабых встраиваемых роутерах — от классических **MIPS/MIPSLE** (Padavan, Entware) до **ARM** (Merlin, Keenetic) и **RISC-V/LoongArch/s390x** систем. «Умный установщик» (`install.sh`) сам определяет архитектуру процессора, порядок байт (endianness) и тип libc, подбирает нужный бинарник и проверяет его флагом `version` — а движок (`update_hybrid.sh`) полностью избегает «эффекта матрёшки» (избыточного вложенного TLS).

> 🙏 **Благодарности**: под капотом используется расширенное ядро **[sing-box-extended](https://github.com/shtorm-7/sing-box-extended)** авторства **shtorm-7** — отдельное спасибо за эту сборку, без неё проект был бы невозможен.

##### 📂 Структура проекта
| Файл | 🎯 Назначение |
| :--- | :--- |
| 🛠️ `install.sh` | Установщик «в одну команду»: ставит зависимости, ядро, скрипты и крон |
| 🧬 `update_hybrid.sh` | Основной движок: квотирование → тест пулов → кросс-скрещивание → горячий перезапуск |
| 🌙 `converter.lua` | Lua-парсер: превращает прокси-ссылки в JSON на лету без внешних утилит |
| 🗂️ `conf3_final.json` | Базовый шаблон (инбаунды, сдвиг портов) |

##### ⚙️ Движок: Скрещивание протоколов (Cross-Breeding)
Обычные скрипты просто сортируют готовые прокси по пингу. **Breeder** идёт дальше: он объединяет преимущества разных протоколов.

**Пример итоговой цепочки:**
`[Клиент] 💻 → [SS-узел / Якорь] 🟢 → [VLESS-узел / Выход] 🔵 → [Интернет] 🌐`

Такой подход позволяет использовать Shadowsocks для маскировки первого прыжка (обход простого DPI), а современный VLESS — для пробития файрволов на выходе.

---

#### 📊 Поддерживаемые каскады

##### ✅ Поддерживаются
| Тип | Entry (якорь) | Exit (выход) | 💡 Когда использовать |
| :--- | :--- | :--- | :--- |
| `ss-ss` | Shadowsocks | Shadowsocks | Бюджетный вариант, быстрый отбор |
| `ss-vless` | Shadowsocks | VLESS | SS для входа (обходит DPI), VLESS на выходе |
| `ss-trojan` | Shadowsocks | Trojan | SS скрывает сам факт прокси, Trojan для скорости |
| `vless-ss` | VLESS | Shadowsocks | VLESS-обфускация в РФ/Китае, SS на финальном хопе |
| `trojan-ss` | Trojan | Shadowsocks | Trojan-инкапсуляция + дешёвый SS на выходе |

##### ❌ Заблокированы скриптом
| Тип | 🛑 Причина |
| :--- | :--- |
| `vless-vless`, `trojan-trojan` | Эффект «матрёшки» — избыточный TLS, без выигрыша |
| `vless-trojan`, `trojan-vless` | Та же причина |
| `*-hy2`, `*-tuic` | UDP-каскады пока не поддерживаются sing-box'ом |

**❓ Можно ли использовать hy2/tuic?** Пока нет — `sing-box` не поддерживает UDP-каскады.

---

##### 📥 Источники прокси (подписки)
Цепочки строятся из узлов, скачиваемых из **публичных списков прокси-подписок** (Shadowsocks/VLESS/Trojan). Список задан в переменной `SUBS_LIST` в начале `update_hybrid.sh` — вы можете свободно добавлять, удалять или заменять ссылки на свои собственные источники.

* ⚠️ **Важно**: ссылка должна вести на **raw-текст** (например, `raw.githubusercontent.com/.../file.txt`). Обычная ссылка на HTML-страницу (например, страница просмотра файла в браузере GitHub) не сработает — скрипт скачает HTML-разметку вместо списка узлов, и парсинг завершится ошибкой (0 нод).
* 🔍 Ссылки, отдающие подписку в формате **Base64** (одна длинная закодированная строка вместо построчного формата), определяются и раскодируются автоматически — отдельный Lua-декодер (`dec.lua`) подключается сам.

---

##### ⚙️ Настройка
Все настройки находятся в начале скрипта в блоке **«ПОЛЬЗОВАТЕЛЬСКИЕ НАСТРОЙКИ»**:

**🎯 Режимы приоритета шифрования**
| Режим | Поведение | Когда использовать |
| :--- | :--- | :--- |
| **1 — Mixed** | Все узлы идут в общий пул | Максимум выбора, быстрее наполняется |
| **2 — Strict** | Только TLS-узлы (SS без `method:none`, VLESS с `tls`) | Страны с агрессивным DPI (Китай, Иран) |
| **3 — Fallback**| Сначала TLS, голые как запасной вариант | Компромисс между строгостью и количеством |

> 💡 **Совет:** Хотите **больше цепочек** или **выше требуемую скорость**? Увеличьте `WANTED_CHAINS` / `EXIT_POOL_SIZE` или поднимите `MIN_CHAIN_SPEED_KBPS`. И наоборот — уменьшите их, если приоритет — количество цепочек, а не скорость каждой из них.

##### ✨ Ключевые особенности
* 🛡️ **Uroboros-фильтр** — автоматическое исключение петель. Скрипт не даст скрестить узлы, если Anchor и Exit находятся на одном IP или в одной /24 подсети.
* ⚖️ **Smart-квоты и Anti-OOM** — жёсткое квотирование при парсинге (**1200** SS, **800** VLESS, **500** Trojan), чтобы не забить оперативную память роутера.
* ⚡ **Fast Check** — перед полным сканированием проверяются текущие рабочие цепочки. Если ≥70% выдают целевую скорость — полный пайплайн отменяется, экономя ресурс флешки.
* 🔒 **Три режима шифрования** — Mixed (по умолчанию), Strict (только TLS) и Fallback. Защищает от использования устаревших шифров и открытых портов.
* 🔁 **Кэширование пулов по протоколам** — ноды проверяются на скорость только один раз за прогон, независимо от того, сколько раз они участвуют в матрице каскадов.

##### 🔁 Автообновление и автопереключение
Установщик регистрирует в **cron** периодическую проверку: `update_hybrid.sh` смотрит, сколько уже работающих цепочек всё ещё держат целевую скорость. Если рабочих цепочек **меньше 70%** (порог настраивается через `STABLE_THRESHOLD` / `WANTED_CHAINS`), запускается **полный пересбор** — свежие подписки, тест пулов и повторное скрещивание.
Дополнительно, **сам sing-box** во время работы использует группу `urltest` (Best-Auto): если активная цепочка теряет связь или её пинг сильно проседает, движок автоматически переключается на следующую лучшую цепочку из пула — без перезапуска и без участия cron. Интервал проверки и допустимый разброс (tolerance) тоже настраиваемые.

##### 🚀 Установка (рекомендуемый способ)
Установщик сам определит архитектуру, endianness и прошивку (Padavan/OpenWrt/Merlin/Keenetic/Entware), скачает подходящий бинарник `sing-box`, скрипты и настроит автозапуск. На Padavan/Entware зависимости (`curl jq lua`) обычно уже есть; на других прошивках их наличие пока стоит проверить самостоятельно.

* 📍 **Путь установки:** зависит от найденного установщиком раздела и версии ядра: `<INSTALL_ROOT>/sing-box-<SB_VERSION>/conf_chain6.json` (например, `/opt/tmp_sb_ext/sing-box-1.13.14-extended-2.5.2/conf_chain6.json`) — точный путь установщик печатает в итоговом отчёте.
* 📜 **Логи процесса:** `tail -f sb_chain6.log`

**⭐ Если скрипт оказался полезен — поставьте звёздочку! ⭐**
*Сделано с 💜 для тех, кто верит, что роутер — это не просто коробка с Wi-Fi*

---

#### 🇬🇧 English

> 🌟 *Automatic multi-hop hybrid cascade generation through cross-protocol "breeding" — now across any supported router: MIPS, ARM, RISC-V, and beyond.*

##### 🧩 What is this?
**Cross-Protocol Breeder** 🧬 is an intelligent shell-based system that automatically downloads subscriptions, tests node speeds, and builds **hybrid multi-hop cascades** (e.g., `ss → vless`, `trojan → ss`).

It solves the problem of creating censorship-resistant proxy chains on constrained embedded routers — from classic **MIPS/MIPSLE** (Padavan, Entware) to **ARM** (Merlin, Keenetic) and **RISC-V/LoongArch/s390x** systems. The "Smart Installer" (`install.sh`) automatically detects CPU architecture, endianness, and libc, picks the matching binary, and verifies it with a `version` flag test — while the engine (`update_hybrid.sh`) strictly avoids the "matryoshka effect" (redundant nested TLS).

> 🙏 **Acknowledgements**: under the hood this project runs on the extended **[sing-box-extended](https://github.com/shtorm-7/sing-box-extended)** core by **shtorm-7** — a big thank-you for that build, without it this project wouldn't be possible.

##### 📂 Project Structure
| File | 🎯 Purpose |
| :--- | :--- |
| 🛠️ `install.sh` | One-command installer: dependencies, core binary, scripts, autostart + cron |
| 🧬 `update_hybrid.sh` | The main engine: protocol quotas → pool testing → cross-breeding matrix → hot reload |
| 🌙 `converter.lua` | Self-contained Lua parser that turns share links into JSON on the fly |
| 🗂️ `conf3_final.json` | Base template (inbounds, port shifting) |

##### ⚙️ Engine: Cross-Protocol Breeding
Standard scripts simply sort existing proxies by ping. **Breeder** takes it further: it combines the advantages of different protocols.

**Example of a generated cascade:**
`[Client] 💻 → [SS Node / Anchor] 🟢 → [VLESS Node / Exit] 🔵 → [Internet] 🌐`

This approach allows using Shadowsocks to mask the first hop (bypassing simple DPI) and modern VLESS for penetrating strict firewalls on the exit hop.

---

#### 📊 Supported Cascades

##### ✅ Supported
| Type | Entry (anchor) | Exit | 💡 When to use |
| :--- | :--- | :--- | :--- |
| `ss-ss` | Shadowsocks | Shadowsocks | Budget option, fast pre-selection |
| `ss-vless` | Shadowsocks | VLESS | SS for entry (bypasses DPI), VLESS on exit |
| `ss-trojan` | Shadowsocks | Trojan | SS hides the fact of a proxy, Trojan for speed |
| `vless-ss` | VLESS | Shadowsocks | VLESS obfuscation under heavy DPI, SS on the final hop |
| `trojan-ss` | Trojan | Shadowsocks | Trojan encapsulation + cheap SS on exit |

##### ❌ Blocked by the script
| Type | 🛑 Reason |
| :--- | :--- |
| `vless-vless`, `trojan-trojan` | "Matryoshka" effect — redundant TLS, no benefit |
| `vless-trojan`, `trojan-vless` | Same reason |
| `*-hy2`, `*-tuic` | UDP cascades aren't supported by sing-box yet |

**❓ Can I use hy2/tuic?** Not yet — `sing-box` doesn't support UDP cascades.

---

##### 📥 Proxy Sources (Subscriptions)
Chains are built from nodes downloaded from **public proxy subscription lists** (Shadowsocks/VLESS/Trojan). The list lives in the `SUBS_LIST` variable at the top of `update_hybrid.sh` — feel free to add, remove, or replace links with your own sources.

* ⚠️ **Important**: the link must point to **raw text** (e.g. `raw.githubusercontent.com/.../file.txt`). A regular link to an HTML page (e.g. a GitHub file-viewer page) won't work — the script will download HTML markup instead of a node list, and parsing will fail (0 nodes).
* 🔍 Links that serve the subscription as **Base64** (one long encoded string instead of line-by-line format) are detected and decoded automatically — a separate Lua decoder (`dec.lua`) kicks in on its own.

---

##### ⚙️ Configuration
All settings live at the top of the script, in the **"USER SETTINGS"** block:

**🎯 Encryption priority modes**
| Mode | Behavior | When to use |
| :--- | :--- | :--- |
| **1 — Mixed** | All nodes go into a shared pool | Maximum choice, fills up faster |
| **2 — Strict** | TLS-only nodes (SS without `method:none`, VLESS with `tls`) | Countries with aggressive DPI (China, Iran) |
| **3 — Fallback**| TLS first, naked nodes as backup | Balance between strictness and node count |

> 💡 **Tip:** Want **more chains** or a **higher required speed**? Increase `WANTED_CHAINS` / `EXIT_POOL_SIZE` or raise `MIN_CHAIN_SPEED_KBPS`. Conversely, lower them if you'd rather prioritize the number of chains over the speed of each one.

##### ✨ Key Features
* 🛡️ **Uroboros Filter** — automatic loop prevention. The script prevents breeding nodes if the Anchor and Exit share the same IP or belong to the same /24 subnet.
* ⚖️ **Smart Quotas & Anti-OOM** — strict limits during parsing (**1200** SS, **800** VLESS, **500** Trojan) to prevent exhausting the router's RAM.
* ⚡ **Fast Check** — tests currently active chains before a full scan. If ≥70% meet the target speed, the full heavy pipeline is skipped, saving CPU and flash wear.
* 🔒 **Three Encryption Modes** — Mixed (default), Strict (TLS only), and Fallback. Drops naked and legacy cipher nodes according to the selected strictness.
* 🔁 **Shared Protocol Caching** — nodes are tested for speed exactly once per run, regardless of how many cascade matrices they participate in.

##### 🔁 Auto-refresh & Auto-failover
The installer registers a **cron** job that periodically re-checks the setup: `update_hybrid.sh` verifies how many of the currently active chains still hit the target speed. If **fewer than 70%** of chains are healthy (the threshold is tunable via `STABLE_THRESHOLD` / `WANTED_CHAINS`), a **full rebuild** kicks off — fresh subscriptions, pool testing, and re-breeding.
On top of that, **sing-box itself** uses a `urltest` group (Best-Auto) at runtime: if the active chain loses connectivity or its ping spikes badly, the engine automatically switches to the next-best chain from the pool — no restart, no cron involved. The check interval and tolerance are configurable too.

##### 🚀 Quick Start (recommended)
The installer detects your architecture, endianness, and firmware (Padavan/OpenWrt/Merlin/Keenetic/Entware) on its own, downloads the matching `sing-box` binary and scripts, and configures autostart. On Padavan/Entware the dependencies (`curl jq lua`) are usually already present; on other firmwares it's worth checking for them yourself.

* 📍 **Installation path:** depends on the partition and core version the installer picked: `<INSTALL_ROOT>/sing-box-<SB_VERSION>/conf_chain6.json` (e.g. `/opt/tmp_sb_ext/sing-box-1.13.14-extended-2.5.2/conf_chain6.json`) — the exact path is printed in the installer's final summary.
* 📜 **Process logs:** `tail -f sb_chain6.log`

**⭐ If this script was useful — leave a star! ⭐**
*Made with 💜 for those who believe a router is more than just a Wi-Fi box*

---

#### 🇮🇷 فارسی

> 🌟 *تولید خودکار آبشارهای ترکیبی چندمرحله‌ای (multi-hop) از طریق «پیوند» پروتکل‌های مختلف — اکنون روی هر روتر پشتیبانی‌شده: MIPS، ARM، RISC-V و فراتر از آن.*

##### 🧩 این پروژه چیست؟
**Cross-Protocol Breeder** 🧬 یک سیستم هوشمند مبتنی بر Shell است که اشتراک‌ها را دانلود می‌کند، سرعت گره‌ها را آزمایش کرده و **آبشارهای ترکیبی** (مانند `ss ← vless`، `trojan ← ss`) می‌سازد.

این پروژه مشکل ایجاد زنجیره‌های پروکسی مقاوم در برابر سانسور را روی روترهای ضعیف حل می‌کند — از **MIPS/MIPSLE** کلاسیک (Padavan، Entware) گرفته تا **ARM** (Merlin، Keenetic) و سیستم‌های **RISC-V/LoongArch/s390x**. «نصب‌کننده هوشمند» (`install.sh`) به‌طور خودکار معماری پردازنده، ترتیب بایت (endianness) و نوع libc را تشخیص داده، باینری مناسب را انتخاب کرده و با پرچم `version` آن را تأیید می‌کند؛ موتور اصلی (`update_hybrid.sh`) نیز همچنان به‌طور کامل از «اثر ماتریوشکا» (TLS تو در تو اضافی) جلوگیری می‌کند.

> 🙏 **قدردانی**: در زیرِ کاپوت این پروژه از هستهٔ توسعه‌یافتهٔ **[sing-box-extended](https://github.com/shtorm-7/sing-box-extended)** به‌دست **shtorm-7** استفاده می‌شود — تشکر ویژه بابت این نسخه؛ بدون آن این پروژه ممکن نبود.

##### 📂 ساختار پروژه
| فایل | 🎯 وظیفه |
| :--- | :--- |
| 🛠️ `install.sh` | نصب‌کننده تک‌دستوری: نصب وابستگی‌ها، هسته، اسکریپت‌ها و کرون |
| 🧬 `update_hybrid.sh` | موتور اصلی: سهمیه پروتکل‌ها ← آزمایش استخرها ← ماتریس پیوند ← بارگذاری مجدد |
| 🌙 `converter.lua` | تجزیه‌گر مستقل Lua برای تبدیل لینک‌ها به JSON |
| 🗂️ `conf3_final.json` | قالب پایه (اینباندها، جابه‌جایی پورت) |

##### ⚙️ موتور: ترکیب پروتکل‌ها
اسکریپت‌های معمولی فقط پروکسی‌ها را بر اساس پینگ مرتب می‌کنند. **Breeder** گامی فراتر می‌رود: پروتکل‌های مختلف را با هم ترکیب می‌کند.

**مثال زنجیره نهایی:**
`[کلاینت] 💻 ← [گره SS / لنگر] 🟢 ← [گره VLESS / خروج] 🔵 ← [اینترنت] 🌐`

این روش به شما امکان می‌دهد از Shadowsocks برای پنهان کردن اولین پرش (عبور از DPI ساده) و از VLESS مدرن برای نفوذ به فایروال‌های سخت در هاپ خروجی استفاده کنید.

---

#### 📊 زنجیره‌های پشتیبانی‌شده

##### ✅ پشتیبانی می‌شوند
| نوع | Entry (لنگر) | Exit (خروج) | 💡 چه زمانی استفاده شود |
| :--- | :--- | :--- | :--- |
| `ss-ss` | Shadowsocks | Shadowsocks | گزینه اقتصادی، انتخاب سریع |
| `ss-vless` | Shadowsocks | VLESS | SS برای ورودی (عبور از DPI)، VLESS در خروجی |
| `ss-trojan` | Shadowsocks | Trojan | SS پنهان‌کننده وجود پروکسی، Trojan برای سرعت |
| `vless-ss` | VLESS | Shadowsocks | پنهان‌سازی VLESS در برابر DPI شدید، SS در هاپ نهایی |
| `trojan-ss` | Trojan | Shadowsocks | کپسوله‌سازی Trojan + SS ارزان در خروجی |

##### ❌ توسط اسکریپت مسدود شده‌اند
| نوع | 🛑 دلیل |
| :--- | :--- |
| `vless-vless`, `trojan-trojan` | اثر «ماتریوشکا» — TLS اضافی بدون فایده |
| `vless-trojan`, `trojan-vless` | همان دلیل |
| `*-hy2`, `*-tuic` | زنجیره‌های UDP هنوز توسط sing-box پشتیبانی نمی‌شوند |

**❓ آیا می‌توان از hy2/tuic استفاده کرد؟** هنوز نه — `sing-box` از زنجیره‌های UDP پشتیبانی نمی‌کند.

---

##### 📥 منابع پروکسی (اشتراک‌ها)
زنجیره‌ها از گره‌هایی ساخته می‌شوند که از **لیست‌های عمومی اشتراک پروکسی** (Shadowsocks/VLESS/Trojan) دانلود می‌شوند. این لیست در متغیر `SUBS_LIST` در ابتدای `update_hybrid.sh` قرار دارد — می‌توانید آزادانه لینک‌ها را اضافه، حذف یا با منابع خودتان جایگزین کنید.

* ⚠️ **مهم**: لینک باید به **متن raw** اشاره کند (مثلاً `raw.githubusercontent.com/.../file.txt`). لینک معمولی به صفحه HTML (مثلاً صفحه نمایش فایل در گیت‌هاب) کار نخواهد کرد — اسکریپت به‌جای لیست گره‌ها، کد HTML را دانلود می‌کند و تجزیه با خطا مواجه می‌شود (۰ گره).
* 🔍 لینک‌هایی که اشتراک را به‌صورت **Base64** ارائه می‌دهند (یک رشتهٔ رمزنگاری‌شدهٔ طولانی) به‌طور خودکار شناسایی و رمزگشایی می‌شوند — یک رمزگشای Lua جداگانه (`dec.lua`) خودش وارد عمل می‌شود.

---

##### ⚙️ پیکربندی
تمام تنظیمات در ابتدای اسکریپت، در بخش **«USER SETTINGS»**، قرار دارند:

**🎯 حالت‌های اولویت رمزگذاری**
| حالت | رفتار | چه زمانی استفاده شود |
| :--- | :--- | :--- |
| **۱ — Mixed** | همه گره‌ها وارد استخر مشترک می‌شوند | حداکثر انتخاب، پر شدن سریع‌تر |
| **۲ — Strict** | فقط گره‌های TLS (SS بدون `method:none`، VLESS با `tls`) | کشورهای با DPI شدید (چین، ایران) |
| **۳ — Fallback**| ابتدا TLS، گره‌های بدون رمزگذاری به‌عنوان پشتیبان | تعادل بین سخت‌گیری و تعداد گره‌ها |

> 💡 **نکته:** به‌دنبال **زنجیره‌های بیشتر** یا **سرعت موردنیاز بالاتر** هستید؟ `WANTED_CHAINS` / `EXIT_POOL_SIZE` را افزایش دهید یا `MIN_CHAIN_SPEED_KBPS` را بالا ببرید. برعکس، اگر تعداد برایتان مهم‌تر از سرعت هر زنجیره است، آن‌ها را کاهش دهید.

##### ✨ ویژگی‌های اصلی
* 🛡️ **فیلتر Uroboros** — جلوگیری خودکار از حلقه‌ها؛ در صورت هم‌IP یا هم‌زیرشبکه /24 بودن Anchor و Exit، پیوند انجام نمی‌شود.
* ⚖️ **سهمیه‌های هوشمند (Anti-OOM)** — محدودیت پردازش (**1200** SS، **800** VLESS، **500** Trojan) برای جلوگیری از پر شدن حافظه روتر.
* ⚡ **بررسی سریع (Fast Check)** — پرش از اسکن کامل اگر ۷۰٪ از زنجیره‌های قبلی هنوز سریع باشند.
* 🔒 **سه حالت رمزگذاری** — Mixed، Strict و Fallback — برای جلوگیری از استفاده رمزهای قدیمی و پورت‌های باز.
* 🔁 **کش مشترک پروتکل‌ها** — هر گره فقط یک‌بار در هر اجرا از نظر سرعت آزمایش می‌شود.

##### 🔁 به‌روزرسانی خودکار و سوییچ خودکار
نصب‌کننده یک وظیفهٔ **cron** ثبت می‌کند که به‌طور دوره‌ای بررسی می‌کند: `update_hybrid.sh` تعیین می‌کند چند مورد از زنجیره‌های فعال هنوز سرعت هدف را دارند. اگر **کمتر از ۷۰٪** از زنجیره‌ها سالم باشند (این آستانه از طریق `STABLE_THRESHOLD` / `WANTED_CHAINS` قابل تنظیم است)، یک **بازسازی کامل** آغاز می‌شود — دانلود اشتراک‌های تازه، آزمایش استخرها و ترکیب مجدد.
علاوه بر این، **خودِ sing-box** در حین اجرا از یک گروه `urltest` (Best-Auto) استفاده می‌کند: اگر زنجیرهٔ فعال ارتباط را از دست بدهد یا پینگ آن به‌شدت افت کند، موتور به‌طور خودکار به بهترین زنجیرهٔ بعدی از استخر سوییچ می‌کند — بدون ری‌استارت و بدون دخالت cron. فاصلهٔ بررسی و میزان تحمل (tolerance) هم قابل تنظیم هستند.

##### 🚀 شروع سریع (روش پیشنهادی)
نصب‌کننده معماری روتر شما را به‌طور خودکار پیدا خواهد کرد.

* 📍 **مسیر نصب:** به پارتیشن و نسخهٔ هستهٔ انتخاب‌شده توسط نصب‌کننده بستگی دارد: `<INSTALL_ROOT>/sing-box-<SB_VERSION>/conf_chain6.json` (مثلاً `/opt/tmp_sb_ext/sing-box-1.13.14-extended-2.5.2/conf_chain6.json`) — مسیر دقیق در گزارش نهایی نصب چاپ می‌شود.
* 📜 **لاگ‌های پردازش:** `tail -f sb_chain6.log`

**⭐ اگر این اسکریپت به کارتان آمد — یک ستاره بدهید! ⭐**
*ساخته‌شده با 💜 برای کسانی که باور دارند روتر فقط یک جعبه Wi-Fi نیست*

---

#### 🇨🇳 中文

> 🌟 *通过跨协议“杂交”自动构建混合多跳（multi-hop）级联代理——现已支持任意受支持的路由器架构：MIPS、ARM、RISC-V 等。*

##### 🧩 项目简介
**Cross-Protocol Breeder** 🧬 是一个智能 Shell 脚本系统，能自动下载订阅、测速，并构建 **混合多跳级联** （例如 `ss → vless`，`trojan → ss`）。

该项目解决了在资源受限的嵌入式路由器上创建抗封锁代理链的问题——从经典的 **MIPS/MIPSLE** （Padavan、Entware）到 **ARM** （Merlin、Keenetic）以及 **RISC-V/LoongArch/s390x** 系统。「智能安装器」（`install.sh`）会自动检测 CPU 架构、字节序（endianness）与 libc 类型，选取匹配的二进制文件，并通过 `version` 参数进行验证；核心引擎（`update_hybrid.sh`）则严格避免“套娃效应”（冗余的嵌套 TLS）。

> 🙏 **致谢**: 本项目底层使用了由 **shtorm-7** 提供的增强版核心 **[sing-box-extended](https://github.com/shtorm-7/sing-box-extended)** —— 特别感谢这个版本，没有它这个项目将无法实现。

##### 📂 项目结构
| 文件 | 🎯 作用 |
| :--- | :--- |
| 🛠️ `install.sh` | 一键安装器：安装依赖、内核、脚本与定时任务 |
| 🧬 `update_hybrid.sh` | 主引擎：配额管理 → 节点池测速 → 交叉组合矩阵 → 热重载 |
| 🌙 `converter.lua` | 独立的 Lua 解析器，即时将链接转换为 JSON |
| 🗂️ `conf3_final.json` | 基础模板（入站、端口偏移） |

##### ⚙️ 核心引擎：跨协议混合
标准的脚本仅仅是根据延迟对节点进行排序。 **Breeder** 更进一步：它结合了不同协议的优势。

**生成的级联链路示例：**
`[客户端] 💻 → [SS 节点 / 入口] 🟢 → [VLESS 节点 / 出口] 🔵 → [互联网] 🌐`

这种方式允许在第一跳使用 Shadowsocks 伪装（绕过基本 DPI），而在最终出口使用 VLESS 协议穿透防火墙。

---

#### 📊 支持的级联组合

##### ✅ 支持的组合
| 类型 | Entry（入口） | Exit（出口） | 💡 使用场景 |
| :--- | :--- | :--- | :--- |
| `ss-ss` | Shadowsocks | Shadowsocks | 经济型方案，快速筛选 |
| `ss-vless` | Shadowsocks | VLESS | SS 作为入口（绕过 DPI），VLESS 作为出口 |
| `ss-trojan` | Shadowsocks | Trojan | SS 隐藏代理特征，Trojan 保证速度 |
| `vless-ss` | VLESS | Shadowsocks | 在强 DPI 环境下使用 VLESS 混淆，最终跳使用 SS |
| `trojan-ss` | Trojan | Shadowsocks | Trojan 封装 + 出口使用低成本 SS |

##### ❌ 被脚本屏蔽的组合
| 类型 | 🛑 原因 |
| :--- | :--- |
| `vless-vless`, `trojan-trojan` | “套娃”效应——冗余 TLS，无实际收益 |
| `vless-trojan`, `trojan-vless` | 同上 |
| `*-hy2`, `*-tuic` | sing-box 目前尚不支持 UDP 级联 |

**❓ 可以使用 hy2/tuic 吗？** 暂时不行——`sing-box` 尚不支持 UDP 级联。

---

##### 📥 代理来源（订阅）
级联链路的节点来自 **公开的代理订阅列表** （Shadowsocks/VLESS/Trojan）。该列表位于 `update_hybrid.sh` 开头的 `SUBS_LIST` 变量中——你可以自由添加、删除或替换为自己的来源。

* ⚠️ **重要**: 链接必须指向 **纯文本原始内容** （例如 `raw.githubusercontent.com/.../file.txt`）。普通的 HTML 页面链接（例如 GitHub 文件预览页面）无法使用——脚本会下载到 HTML 代码而不是节点列表，解析将失败（0 个节点）。
* 🔍 以 **Base64** 格式提供订阅的链接（一整段编码字符串）会被自动识别并解码——脚本会自动调用独立的 Lua 解码器（`dec.lua`）。

---

##### ⚙️ 配置
所有设置都位于脚本开头的 **“USER SETTINGS”（用户设置）** 代码块中：

**🎯 加密优先级模式**
| 模式 | 行为 | 使用场景 |
| :--- | :--- | :--- |
| **1 — Mixed** | 所有节点进入同一个池 | 选择最多，池子填充更快 |
| **2 — Strict** | 仅 TLS 节点（不含 `method:none` 的 SS，带 `tls` 的 VLESS） | DPI 严格的国家/地区（中国、伊朗） |
| **3 — Fallback**| 优先 TLS，裸节点作为备用 | 在严格性与节点数量之间取得平衡 |

> 💡 **提示:** 想要 **更多链路** 或 **更高的目标速度**？调高 `WANTED_CHAINS` / `EXIT_POOL_SIZE` 或提高 `MIN_CHAIN_SPEED_KBPS`；反之，如果更看重数量而非单条链路速度，就调低它们。

##### ✨ 核心特性
* 🛡️ **Uroboros 过滤器** — 自动防环路。若入口和出口节点位于同一 IP 或 /24 子网，则禁止组合。
* ⚖️ **智能配额与 Anti-OOM** — 严格限制解析数量（**1200** SS，**800** VLESS，**500** Trojan）以防内存耗尽。
* ⚡ **快速检查 (Fast Check)** — 在全面扫描前测试当前链路。若 ≥70% 达标，则跳过繁重的全量扫描。
* 🔒 **三种加密模式** — 混合（默认）、严格（仅限 TLS）和回退模式，防止使用过时加密或开放端口。
* 🔁 **协议池共享缓存** — 每个节点每次运行只测速一次，无论它参与多少条级联组合。

##### 🔁 自动刷新与自动切换
安装器会在 **cron** 中注册定期检查任务：`update_hybrid.sh` 会核实当前活跃链路中有多少仍能达到目标速度。如果健康链路 **低于 70%** （该阈值可通过 `STABLE_THRESHOLD` / `WANTED_CHAINS` 调整），就会触发一次 **完整重建** ——重新下载订阅、测速节点池并重新组合。
除此之外， **sing-box 本身** 在运行期间会使用一个 `urltest` 分组（Best-Auto）：如果当前活跃链路失去连接或延迟严重恶化，引擎会自动切换到池中次优的链路——无需重启，也不依赖 cron。检测间隔与容差（tolerance）同样可以调整。

##### 🚀 快速开始 (推荐方式)
安装器会自动检测你的架构和固件环境。

* 📍 **安装路径:** 具体路径取决于安装器选定的分区与内核版本：`<INSTALL_ROOT>/sing-box-<SB_VERSION>/conf_chain6.json`（例如 `/opt/tmp_sb_ext/sing-box-1.13.14-extended-2.5.2/conf_chain6.json`）——安装器会在最终汇总中打印确切路径。
* 📜 **进程日志:** `tail -f sb_chain6.log`

**⭐ 如果这个脚本对你有帮助——点个 Star 吧！⭐**
*用 💜 献给相信路由器不只是一个 Wi-Fi 盒子的人们*

---

#### 🇸🇦 العربية

> 🌟 *توليد تلقائي لتتابعات البروكسي الهجينة متعددة القفزات (multi-hop) من خلال «تهجين» البروتوكولات — الآن على أي جهاز توجيه مدعوم: MIPS وARM وRISC-V وأكثر.*

##### 🧩 ما هو هذا المشروع؟
**Cross-Protocol Breeder** 🧬 هو نظام ذكي مبني على Shell يقوم تلقائيًا بتنزيل الاشتراكات واختبار سرعة العقد وبناء **سلاسل هجينة** (مثل `ss ← vless`، `trojan ← ss`).

يحل المشروع مشكلة إنشاء سلاسل بروكسي مقاومة للرقابة على أجهزة توجيه ضعيفة الموارد — من معمارية **MIPS/MIPSLE** الكلاسيكية (Padavan، Entware) إلى **ARM** (Merlin، Keenetic) وأنظمة **RISC-V/LoongArch/s390x**. «المُثبِّت الذكي» (`install.sh`) يكتشف تلقائيًا معمارية المعالج وترتيب البايت (endianness) ونوع libc، ويختار الملف الثنائي المطابق، ويتحقق منه عبر اختبار `version`؛ بينما يستمر المحرك الرئيسي (`update_hybrid.sh`) في تجنب «تأثير الدمية الروسية» (طبقات TLS المتداخلة الزائدة) بشكل كامل.

> 🙏 **شكر وتقدير**: يستخدم هذا المشروع في الخلفية النواة الموسّعة **[sing-box-extended](https://github.com/shtorm-7/sing-box-extended)** من إعداد **shtorm-7** — شكر خاص على هذا الإصدار، فبدونه لم يكن هذا المشروع ممكنًا.

##### 📂 هيكل المشروع
| الملف | 🎯 الوظيفة |
| :--- | :--- |
| 🛠️ `install.sh` | مُثبِّت بأمر واحد: التبعيات، النواة، السكربتات، والجدولة التلقائية |
| 🧬 `update_hybrid.sh` | المحرك الرئيسي: الحصص ← اختبار المجموعات ← مصفوفة التهجين ← إعادة التحميل الساخنة |
| 🌙 `converter.lua` | محلِّل Lua مستقل يحوّل الروابط إلى JSON فورًا |
| 🗂️ `conf3_final.json` | قالب التكوين الأساسي (المداخل، إزاحة المنافذ) |

##### ⚙️ المحرك: تهجين البروتوكولات
السكربتات العادية تقوم فقط بفرز البروكسيات الجاهزة حسب وقت الاستجابة (ping). **Breeder** يذهب إلى أبعد من ذلك: يجمع بين مزايا البروتوكولات المختلفة.

**مثال على السلسلة النهائية:**
`[العميل] 💻 ← [عقدة SS / دخول] 🟢 ← [عقدة VLESS / خروج] 🔵 ← [الإنترنت] 🌐`

هذا النهج يسمح باستخدام Shadowsocks لإخفاء القفزة الأولى (تجاوز DPI البسيط)، وVLESS لاختراق جدران الحماية في القفزة الأخيرة.

---

#### 📊 السلاسل المدعومة

##### ✅ مدعومة
| النوع | Entry (المرساة) | Exit (الخروج) | 💡 متى تُستخدم |
| :--- | :--- | :--- | :--- |
| `ss-ss` | Shadowsocks | Shadowsocks | خيار اقتصادي، اختيار سريع |
| `ss-vless` | Shadowsocks | VLESS | SS للدخول (تجاوز DPI)، VLESS للخروج |
| `ss-trojan` | Shadowsocks | Trojan | SS يخفي وجود البروكسي، Trojan من أجل السرعة |
| `vless-ss` | VLESS | Shadowsocks | تمويه VLESS في ظل DPI صارم، SS في القفزة الأخيرة |
| `trojan-ss` | Trojan | Shadowsocks | تغليف Trojan + SS رخيص في الخروج |

##### ❌ محظورة من قبل السكربت
| النوع | 🛑 السبب |
| :--- | :--- |
| `vless-vless`, `trojan-trojan` | تأثير «الدمية الروسية» — طبقة TLS زائدة دون فائدة |
| `vless-trojan`, `trojan-vless` | نفس السبب |
| `*-hy2`, `*-tuic` | سلاسل UDP غير مدعومة بعد من قِبل sing-box |

**❓ هل يمكن استخدام hy2/tuic؟** ليس بعد — لا يدعم `sing-box` سلاسل UDP.

---

##### 📥 مصادر البروكسي (الاشتراكات)
تُبنى السلاسل من عقد يتم تنزيلها من **قوائم اشتراك بروكسي عامة** (Shadowsocks/VLESS/Trojan). توجد هذه القائمة في المتغير `SUBS_LIST` في بداية `update_hybrid.sh` — يمكنك بحرية إضافة الروابط أو حذفها أو استبدالها بمصادرك الخاصة.

* ⚠️ **مهم**: يجب أن يشير الرابط إلى **نص خام (raw)** (مثل `raw.githubusercontent.com/.../file.txt`). الرابط العادي لصفحة HTML (مثل صفحة عرض ملف على GitHub) لن يعمل — سيقوم السكربت بتنزيل كود HTML بدلاً من قائمة العقد، وسيفشل التحليل (0 عقدة).
* 🔍 الروابط التي تقدم الاشتراك بصيغة **Base64** (سلسلة مشفّرة طويلة واحدة) يتم اكتشافها وفك تشفيرها تلقائيًا — يتم تفعيل مُفكِّك Lua منفصل (`dec.lua`) تلقائيًا.

---

##### ⚙️ الإعدادات
جميع الإعدادات موجودة في بداية السكربت، ضمن كتلة **«USER SETTINGS»**:

**🎯 أوضاع أولوية التشفير**
| الوضع | السلوك | متى تُستخدم |
| :--- | :--- | :--- |
| **1 — Mixed** | تدخل جميع العقد في مجموعة مشتركة | أقصى قدر من الاختيار، امتلاء أسرع |
| **2 — Strict** | عقد TLS فقط (SS بدون `method:none`، VLESS مع `tls`) | الدول ذات DPI الصارم (الصين، إيران) |
| **3 — Fallback**| TLS أولاً، والعقد العارية كاحتياطي | توازن بين الصرامة وعدد العقد |

> 💡 **نصيحة:** تريد **سلاسل أكثر** أو **سرعة مستهدفة أعلى**؟ ارفع قيمة `WANTED_CHAINS` / `EXIT_POOL_SIZE` أو `MIN_CHAIN_SPEED_KBPS`. والعكس صحيح إذا كانت الأولوية للعدد وليس لسرعة كل سلسلة.

##### ✨ المميزات الرئيسية
* 🛡️ **فلتر Uroboros** — منع الحلقات تلقائيًا؛ لا يتم التهجين إذا كانت المرساة والخروج على نفس IP أو نفس الشبكة الفرعية /24.
* ⚖️ **الحصص الذكية (Anti-OOM)** — قيود صارمة على عدد العقد (**1200** SS، **800** VLESS، **500** Trojan) لمنع استنفاد ذاكرة التوجيه.
* ⚡ **الفحص السريع** — يختبر السلاسل النشطة قبل الفحص الكامل. إذا حقق ≥70% السرعة المطلوبة، يتم تخطي الفحص الكامل.
* 🔒 **ثلاثة أوضاع للتشفير** — Mixed (افتراضي)، Strict (TLS فقط)، وFallback — لمنع استخدام تشفير قديم أو منافذ مفتوحة.
* 🔁 **تخزين مؤقت مشترك للبروتوكولات** — يتم اختبار سرعة كل عقدة مرة واحدة فقط لكل تشغيل، بغض النظر عن عدد مرات مشاركتها في مصفوفة السلاسل.

##### 🔁 التحديث التلقائي والتبديل التلقائي
يقوم المُثبِّت بتسجيل مهمة **cron** تتحقق دوريًا: يتأكد `update_hybrid.sh` من عدد السلاسل النشطة التي ما زالت تحقق السرعة المستهدفة. إذا كانت نسبة السلاسل السليمة **أقل من 70%** (يمكن ضبط هذه العتبة عبر `STABLE_THRESHOLD` / `WANTED_CHAINS`)، تبدأ **إعادة بناء كاملة** — تنزيل اشتراكات جديدة، اختبار المجموعات، وإعادة التهجين.
بالإضافة إلى ذلك، يستخدم **sing-box نفسه** أثناء التشغيل مجموعة `urltest` (Best-Auto): إذا فقدت السلسلة النشطة الاتصال أو تدهورت زمن استجابتها بشدة، يقوم المحرك تلقائيًا بالتبديل إلى أفضل سلسلة تالية من المجموعة — دون إعادة تشغيل ودون تدخل من cron. فترة الفحص ونسبة التحمل (tolerance) قابلتان للتعديل أيضًا.

##### 🚀 البداية السريعة (الطريقة الموصى بها)
سيكتشف المثبت المعمارية الخاصة بك تلقائيًا.

* 📍 **مسار التثبيت:** يعتمد المسار على القسم وإصدار النواة الذي اختاره المُثبِّت: `<INSTALL_ROOT>/sing-box-<SB_VERSION>/conf_chain6.json` (مثل `/opt/tmp_sb_ext/sing-box-1.13.14-extended-2.5.2/conf_chain6.json`) — يطبع المُثبِّت المسار الدقيق في الملخص النهائي.
* 📜 **سجلات العملية:** `tail -f sb_chain6.log`

**⭐ إذا كان هذا السكربت مفيدًا — امنحه نجمة! ⭐**
*صُنع بـ 💜 لمن يؤمنون بأن الراوتر ليس مجرد صندوق واي فاي*
```
