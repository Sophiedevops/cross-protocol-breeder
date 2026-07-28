🧬 cross-protocol-breeder
text
      /\_/\   [PROXY HYBRID MODULE • ENGINE v6 • SMART INSTALLER v3.3]
     ( o.o )  
      > ^ <   Cross-Protocol Breeder
           |\__/,|   (`\
         _.|o o  |_   ) )
        -(((---(((--------
<p align="center"> <img alt="platform" src="https://img.shields.io/badge/Firmware-OpenWrt%20%C2%B7%20Padavan%20%C2%B7%20Merlin%20%C2%B7%20Keenetic%20%C2%B7%20Entware-1f6feb?style=for-the-badge&logo=openwrt&logoColor=white"> <img alt="arch" src="https://img.shields.io/badge/Arch-Multi--Architecture%20(9%20targets)-orange?style=for-the-badge&logo=linux&logoColor=white"> <img alt="libc" src="https://img.shields.io/badge/libc-auto--detect%20(musl%20%2F%20glibc%20%2F%20uClibc)-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white"> <img alt="installer" src="https://img.shields.io/badge/Installer-v3.3%20Smart%20Detect-9c27b0?style=for-the-badge&logo=cachet&logoColor=white"> <img alt="langs" src="https://img.shields.io/badge/Docs-5%20languages-e91e63?style=for-the-badge&logo=googletranslate&logoColor=white"> </p> <h3 align="center">🌈 Hybrid Multi-Hop Proxy Chain Builder — Now Multi-Architecture 🌈</h3> <div align="center">

🖥️ Поддерживаемые платформы / Supported targets

Семейство	Варианты
🦾 ARM	armv6 · armv7 · aarch64
🧩 MIPS	mips (BE) · mipsel (LE) · mips64 · mips64el
🚀 RISC-V	riscv64
🐉 LoongArch	loongarch64
🖥️ IBM Z	s390x
📚 libc	musl · glibc · uClibc — определяется автоматически
🏠 Прошивка	OpenWrt · Padavan · Merlin (Asuswrt) · Keenetic · Entware
</div>
🌐 Доступные языки / Available languages

Show Image Show Image Show Image Show Image Show Image

🇷🇺 Русский

🧬 Автоматическое построение каскадных multi-hop конфигураций путём кросс-протокольного «скрещивания» — теперь на любом поддерживаемом роутере: MIPS, ARM, RISC-V и не только.

🧩 Что это такое?

Cross-Protocol Breeder — интеллектуальный шелл-скрипт, который автоматически загружает подписки, тестирует скорость узлов и строит гибридные каскады (например, ss → vless, trojan → ss).

Скрипт решает задачу создания устойчивых к блокировкам цепочек на слабых встраиваемых роутерах — от классических MIPS/MIPSLE (Padavan, Entware) до ARM (Merlin, Keenetic) и RISC-V / LoongArch / s390x систем. «Умный установщик» (install.sh v3.3) сам определяет архитектуру процессора, порядок байт (endianness) и тип libc (musl/glibc/uClibc), подбирает нужный бинарник и проверяет его флагом version — а движок (update_hybrid.sh) полностью избегает «эффекта матрёшки» (избыточного вложенного TLS).
---
<details>
<summary>📦 <b>Состав проекта (нажмите, чтобы развернуть)</b></summary>
<br>

| Файл | 🎯 Назначение |
|---|---|
| 🛠️ `install.sh` | Установщик «в одну команду»: ставит зависимости, ядро, скрипты и крон |
| 🧬 `update_hybrid.sh` | Основной движок: квотирование → тест пулов → кросс-скрещивание → горячий перезапуск |
| 🌙 `converter.lua` | Lua-парсер: превращает прокси-ссылки в JSON на лету без внешних утилит |
| 🗂️ `conf3_final.json` | Базовый шаблон (инбаунды, сдвиг портов) |

</details>

### ⚙️ Движок: Скрещивание протоколов (Cross-Breeding)

Обычные скрипты просто сортируют готовые прокси по пингу. **Breeder** идёт дальше: он объединяет преимущества разных протоколов.

**🔗 Матрица поддерживаемых каскадов:**

| 🟢 Anchor (вход) | 🔵 Exit (выход) | Статус |
|---|---|:---:|
| Shadowsocks | Shadowsocks | ✅ |
| Shadowsocks | VLESS | ✅ |
| Shadowsocks | Trojan | ✅ |
| VLESS | Shadowsocks | ✅ |
| Trojan | Shadowsocks | ✅ |

**Пример итоговой цепочки:**
`[Клиент] 💻 → [SS-узел / Якорь] 🟢 → [VLESS-узел / Выход] 🔵 → [Интернет] 🌐`

Такой подход позволяет использовать Shadowsocks для маскировки первого прыжка (обход простого DPI), а современный VLESS — для пробития файрволов на выходе.

### ✨ Ключевые особенности

* 🛡️ **Uroboros-фильтр** — автоматическое исключение петель. Скрипт не даст скрестить узлы, если Anchor и Exit находятся на одном IP или в одной `/24` подсети.
* ⚖️ **Smart-квоты и Anti-OOM** — жёсткое квотирование при парсинге (**1200** SS, **800** VLESS, **500** Trojan), чтобы не забить оперативную память роутера.
* ⚡ **Fast Check** — перед полным сканированием проверяются текущие рабочие цепочки. Если ≥70% выдают целевую скорость — полный пайплайн отменяется, экономя ресурс флешки.
* 🔒 **Три режима шифрования** — Mixed (по умолчанию), Strict (только TLS) и Fallback. Защищает от использования устаревших шифров и открытых портов.
* 🔁 **Кэширование пулов по протоколам** — ноды проверяются на скорость только один раз за прогон, независимо от того, сколько раз они участвуют в матрице каскадов.

<details>
<summary>📊 <b>Расширенные технические параметры (нажмите, чтобы развернуть)</b></summary>
<br>

| ⚙️ Параметр | Значение |
|---|:---:|
| 🟢 Anchor Pool (входные узлы) | `5` |
| 🔵 Exit Pool (выходные узлы) | `10` |
| 🎯 Целевое число цепочек (`WANTED_CHAINS`) | `6` |
| 🚀 Мин. скорость пула (`MIN_POOL_SPEED_KBPS`) | `700 kbps` |
| 🔗 Мин. скорость готовой цепочки (`MIN_CHAIN_SPEED_KBPS`) | `400 kbps` |
| ⚡ Порог Fast-Check (сохранение прогона) | `70%` |

**🔐 Режимы шифрования подробно:**

| Режим | 🎨 | Описание |
|---|:---:|---|
| Mode 1 — Mixed | 🟢 | Secure и Naked узлы обрабатываются вместе, без ограничений |
| Mode 2 — Strict | 🟡 | Naked-узлы (без TLS / `method:none`) полностью исключаются |
| Mode 3 — Fallback | 🔵 | Сначала тестируются Secure-узлы, Naked используются только как резерв |

</details>

### 🚀 Установка (рекомендуемый способ)

Установщик проверит Entware, поставит зависимости (`curl jq lua`), скачает скрипты и настроит автозапуск.

```bash
# 📥 Скачайте и запустите установщик
curl -k -L -o install.sh https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh
chmod +x install.sh
./install.sh
```

📍 После установки целевой конфиг будет доступен по пути: `/opt/tmp_sb_ext/sing-box-1.13.12-extended-2.4.1-linux-mipsle/conf_chain6.json`.
📜 Логи процесса: `tail -f sb_chain6.log`.

---

## 🇬🇧 English

> 🧬 *Automatic multi-hop hybrid cascade generation through cross-protocol "breeding" directly on a low-end MIPS router.*

### 🧩 What is this?

**Cross-Protocol Breeder** is an intelligent shell-based system for **Padavan/Entware** routers that automatically downloads subscriptions, tests node speeds, and builds **hybrid multi-hop cascades** (e.g., `ss → vless`, `trojan → ss`).

It solves the problem of creating censorship-resistant proxy chains on a **RAM-constrained Padavan router with a MIPSLE CPU**, strictly avoiding the "matryoshka effect" (redundant nested TLS).

<details>
<summary>📦 <b>Project components (click to expand)</b></summary>
<br>

| File | 🎯 Purpose |
|---|---|
| 🛠️ `install.sh` | One-command installer: dependencies, core binary, scripts, autostart + cron |
| 🧬 `update_hybrid.sh` | The main engine: protocol quotas → pool testing → cross-breeding matrix → hot reload |
| 🌙 `converter.lua` | Self-contained Lua parser that turns share links into JSON on the fly |
| 🗂️ `conf3_final.json` | Base template (inbounds, port shifting) |

</details>

### ⚙️ Engine: Cross-Protocol Breeding

Standard scripts simply sort existing proxies by ping. **Breeder** takes it further: it combines the advantages of different protocols.

**🔗 Supported cascade matrix:**

| 🟢 Anchor (entry) | 🔵 Exit | Status |
|---|---|:---:|
| Shadowsocks | Shadowsocks | ✅ |
| Shadowsocks | VLESS | ✅ |
| Shadowsocks | Trojan | ✅ |
| VLESS | Shadowsocks | ✅ |
| Trojan | Shadowsocks | ✅ |

**Example of a generated cascade:**
`[Client] 💻 → [SS Node / Anchor] 🟢 → [VLESS Node / Exit] 🔵 → [Internet] 🌐`

This approach allows using Shadowsocks to mask the first hop (bypassing simple DPI) and modern VLESS for penetrating strict firewalls on the exit hop.

### ✨ Key Features

* 🛡️ **Uroboros Filter** — automatic loop prevention. The script prevents breeding nodes if the Anchor and Exit share the same IP or belong to the same `/24` subnet.
* ⚖️ **Smart Quotas & Anti-OOM** — strict limits during parsing (**1200** SS, **800** VLESS, **500** Trojan) to prevent exhausting the router's RAM.
* ⚡ **Fast Check** — tests currently active chains before a full scan. If ≥70% meet the target speed, the full heavy pipeline is skipped, saving CPU and flash wear.
* 🔒 **Three Encryption Modes** — Mixed (default), Strict (TLS only), and Fallback. Drops naked and legacy cipher nodes according to the selected strictness.
* 🔁 **Shared Protocol Caching** — nodes are tested for speed exactly once per run, regardless of how many cascade matrices they participate in.

<details>
<summary>📊 <b>Extended technical specs (click to expand)</b></summary>
<br>

| ⚙️ Parameter | Value |
|---|:---:|
| 🟢 Anchor Pool size | `5` |
| 🔵 Exit Pool size | `10` |
| 🎯 Target chain count (`WANTED_CHAINS`) | `6` |
| 🚀 Min. pool speed (`MIN_POOL_SPEED_KBPS`) | `700 kbps` |
| 🔗 Min. final chain speed (`MIN_CHAIN_SPEED_KBPS`) | `400 kbps` |
| ⚡ Fast-Check retention threshold | `70%` |

**🔐 Encryption modes in detail:**

| Mode | 🎨 | Description |
|---|:---:|---|
| Mode 1 — Mixed | 🟢 | Secure and Naked nodes are processed together, no restrictions |
| Mode 2 — Strict | 🟡 | Naked nodes (no TLS / `method:none`) are explicitly dropped |
| Mode 3 — Fallback | 🔵 | Secure nodes are tested first; Naked nodes are used only as backup |

</details>

### 🚀 Quick Start (recommended)

The installer will check Entware, install dependencies (`curl jq lua`), download the scripts, and configure autostart.

```bash
# 1️⃣ Connect to your router via SSH
ssh admin@192.168.1.1

# 2️⃣ Download and run the installer
wget -O install.sh https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh
chmod +x install.sh
./install.sh
```

📍 Target configuration path: `/opt/tmp_sb_ext/sing-box-1.13.12-extended-2.4.1-linux-mipsle/conf_chain6.json`.
📜 Process logs: `tail -f sb_chain6.log`.

---

## 🇮🇷 فارسی

> 🧬 *تولید خودکار آبشارهای ترکیبی چندمرحله‌ای (multi-hop) از طریق «پیوند» پروتکل‌های مختلف، مستقیماً روی روتر ضعیف MIPS.*

### 🧩 این پروژه چیست؟

**Cross-Protocol Breeder** یک سیستم هوشمند مبتنی بر Shell برای روترهای **Padavan/Entware** است که اشتراک‌ها را دانلود می‌کند، سرعت گره‌ها را آزمایش کرده و **آبشارهای ترکیبی** (مانند `ss ← vless`، `trojan ← ss`) می‌سازد.

این پروژه مشکل ایجاد زنجیره‌های پروکسی مقاوم در برابر سانسور را روی روترهایی با **حافظه رم محدود و پردازنده MIPSLE** حل می‌کند، و از «اثر ماتریوشکا» (TLS تو در تو اضافی) جلوگیری می‌کند.

<details>
<summary>📦 <b>اجزای پروژه (برای مشاهده کلیک کنید)</b></summary>
<br>

| فایل | 🎯 وظیفه |
|---|---|
| 🛠️ `install.sh` | نصب‌کننده تک‌دستوری: نصب وابستگی‌ها، هسته، اسکریپت‌ها و کرون |
| 🧬 `update_hybrid.sh` | موتور اصلی: سهمیه پروتکل‌ها ← آزمایش استخرها ← ماتریس پیوند ← بارگذاری مجدد |
| 🌙 `converter.lua` | تجزیه‌گر مستقل Lua برای تبدیل لینک‌ها به JSON |
| 🗂️ `conf3_final.json` | قالب پایه (اینباندها، جابه‌جایی پورت) |

</details>

### ⚙️ موتور: ترکیب پروتکل‌ها

اسکریپت‌های معمولی فقط پروکسی‌ها را بر اساس پینگ مرتب می‌کنند. **Breeder** گامی فراتر می‌رود: پروتکل‌های مختلف را با هم ترکیب می‌کند.

**🔗 جدول زنجیره‌های پشتیبانی‌شده:**

| 🟢 لنگر (ورودی) | 🔵 خروج | وضعیت |
|---|---|:---:|
| Shadowsocks | Shadowsocks | ✅ |
| Shadowsocks | VLESS | ✅ |
| Shadowsocks | Trojan | ✅ |
| VLESS | Shadowsocks | ✅ |
| Trojan | Shadowsocks | ✅ |

**مثال زنجیره نهایی:**
`[کلاینت] 💻 ← [گره SS / لنگر] 🟢 ← [گره VLESS / خروج] 🔵 ← [اینترنت] 🌐`

### ✨ ویژگی‌های اصلی

* 🛡️ **فیلتر Uroboros** — جلوگیری خودکار از حلقه‌ها؛ در صورت هم‌IP یا هم‌زیرشبکه `/24` بودن Anchor و Exit، پیوند انجام نمی‌شود.
* ⚖️ **سهمیه‌های هوشمند (Anti-OOM)** — محدودیت پردازش (**1200** SS، **800** VLESS، **500** Trojan) برای جلوگیری از پر شدن حافظه روتر.
* ⚡ **بررسی سریع (Fast Check)** — پرش از اسکن کامل اگر ۷۰٪ از زنجیره‌های قبلی هنوز سریع باشند.
* 🔒 **سه حالت رمزگذاری** — Mixed، Strict و Fallback — برای جلوگیری از استفاده رمزهای قدیمی و پورت‌های باز.
* 🔁 **کش مشترک پروتکل‌ها** — هر گره فقط یک‌بار در هر اجرا از نظر سرعت آزمایش می‌شود.

<details>
<summary>📊 <b>مشخصات فنی تکمیلی (کلیک کنید)</b></summary>
<br>

| ⚙️ پارامتر | مقدار |
|---|:---:|
| 🟢 اندازه استخر Anchor | `5` |
| 🔵 اندازه استخر Exit | `10` |
| 🎯 تعداد زنجیره‌های هدف (`WANTED_CHAINS`) | `6` |
| 🚀 حداقل سرعت استخر (`MIN_POOL_SPEED_KBPS`) | `700 kbps` |
| 🔗 حداقل سرعت زنجیره نهایی (`MIN_CHAIN_SPEED_KBPS`) | `400 kbps` |
| ⚡ آستانه Fast-Check | `70%` |

**🔐 حالت‌های رمزگذاری به‌تفصیل:**

| حالت | 🎨 | توضیح |
|---|:---:|---|
| Mode 1 — Mixed | 🟢 | گره‌های Secure و Naked با هم و بدون محدودیت پردازش می‌شوند |
| Mode 2 — Strict | 🟡 | گره‌های Naked (بدون TLS / `method:none`) به‌طور کامل حذف می‌شوند |
| Mode 3 — Fallback | 🔵 | ابتدا گره‌های Secure آزمایش می‌شوند؛ Naked فقط به‌عنوان پشتیبان است |

</details>

### 🚀 شروع سریع

```bash
ssh admin@192.168.1.1
wget -O install.sh https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh
chmod +x install.sh
./install.sh
```

📍 مسیر پیکربندی هدف: `/opt/tmp_sb_ext/sing-box-1.13.12-extended-2.4.1-linux-mipsle/conf_chain6.json`
📜 لاگ‌ها: `tail -f sb_chain6.log`

---

## 🇨🇳 中文

> 🧬 *在低端 MIPS 路由器上，通过跨协议“杂交”自动构建混合多跳（multi-hop）级联代理。*

### 🧩 项目简介

**Cross-Protocol Breeder** 是一个专为 **Padavan/Entware** 路由器设计的智能 Shell 脚本系统。它能自动下载订阅、测速，并构建 **混合多跳级联**（例如 `ss → vless`，`trojan → ss`）。

它解决了在 **RAM 受限的 MIPSLE 路由器** 上创建抗封锁代理链的问题，同时严格避免了“套娃效应”（冗余的嵌套 TLS）。

<details>
<summary>📦 <b>项目组成部分（点击展开）</b></summary>
<br>

| 文件 | 🎯 作用 |
|---|---|
| 🛠️ `install.sh` | 一键安装器：安装依赖、内核、脚本与定时任务 |
| 🧬 `update_hybrid.sh` | 主引擎：配额管理 → 节点池测速 → 交叉组合矩阵 → 热重载 |
| 🌙 `converter.lua` | 独立的 Lua 解析器，即时将链接转换为 JSON |
| 🗂️ `conf3_final.json` | 基础模板（入站、端口偏移） |

</details>

### ⚙️ 核心引擎：跨协议混合

标准的脚本仅仅是根据延迟对节点进行排序。**Breeder** 更进一步：它结合了不同协议的优势。

**🔗 支持的级联组合表：**

| 🟢 入口 (Anchor) | 🔵 出口 (Exit) | 状态 |
|---|---|:---:|
| Shadowsocks | Shadowsocks | ✅ |
| Shadowsocks | VLESS | ✅ |
| Shadowsocks | Trojan | ✅ |
| VLESS | Shadowsocks | ✅ |
| Trojan | Shadowsocks | ✅ |

**生成的级联链路示例：**
`[客户端] 💻 → [SS 节点 / 入口] 🟢 → [VLESS 节点 / 出口] 🔵 → [互联网] 🌐`

### ✨ 核心特性

* 🛡️ **Uroboros 过滤器** — 自动防环路。若入口和出口节点位于同一 IP 或 `/24` 子网，则禁止组合。
* ⚖️ **智能配额与 Anti-OOM** — 严格限制解析数量（**1200** SS，**800** VLESS，**500** Trojan）以防内存耗尽。
* ⚡ **快速检查 (Fast Check)** — 在全面扫描前测试当前链路。若 ≥70% 达标，则跳过繁重的全量扫描。
* 🔒 **三种加密模式** — 混合（默认）、严格（仅限 TLS）和回退模式，防止使用过时加密或开放端口。
* 🔁 **协议池共享缓存** — 每个节点每次运行只测速一次，无论它参与多少条级联组合。

<details>
<summary>📊 <b>扩展技术参数（点击展开）</b></summary>
<br>

| ⚙️ 参数 | 数值 |
|---|:---:|
| 🟢 入口节点池大小 (Anchor Pool) | `5` |
| 🔵 出口节点池大小 (Exit Pool) | `10` |
| 🎯 目标链路数量 (`WANTED_CHAINS`) | `6` |
| 🚀 节点池最低速度 (`MIN_POOL_SPEED_KBPS`) | `700 kbps` |
| 🔗 最终链路最低速度 (`MIN_CHAIN_SPEED_KBPS`) | `400 kbps` |
| ⚡ Fast-Check 保留阈值 | `70%` |

**🔐 加密模式详情：**

| 模式 | 🎨 | 说明 |
|---|:---:|---|
| Mode 1 — Mixed | 🟢 | Secure 与 Naked 节点一起处理，不加限制 |
| Mode 2 — Strict | 🟡 | 彻底剔除 Naked 节点（无 TLS / `method:none`） |
| Mode 3 — Fallback | 🔵 | 优先测试 Secure 节点，Naked 节点仅作为备用 |

</details>

### 🚀 快速开始

```bash
ssh admin@192.168.1.1
wget -O install.sh https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh
chmod +x install.sh
./install.sh
```

📍 目标配置路径：`/opt/tmp_sb_ext/sing-box-1.13.12-extended-2.4.1-linux-mipsle/conf_chain6.json`
📜 日志：`tail -f sb_chain6.log`

---

## 🇸🇦 العربية

> 🧬 *توليد تلقائي لتتابعات البروكسي الهجينة متعددة القفزات (multi-hop) من خلال «تهجين» البروتوكولات مباشرةً على جهاز توجيه MIPS ضعيف.*

### 🧩 ما هو هذا المشروع؟

**Cross-Protocol Breeder** هو نظام ذكي مبني على Shell لأجهزة توجيه **Padavan/Entware** يقوم تلقائيًا بتنزيل الاشتراكات واختبار سرعة العقد وبناء **سلاسل هجينة** (مثل `ss ← vless`، `trojan ← ss`).

يحل المشروع مشكلة إنشاء سلاسل بروكسي مقاومة للرقابة على أجهزة توجيه ذات **ذاكرة RAM محدودة ومعالج MIPSLE**، مع تجنب «تأثير الدمية الروسية» (طبقات TLS المتداخلة الزائدة).

<details>
<summary>📦 <b>مكونات المشروع (انقر للعرض)</b></summary>
<br>

| الملف | 🎯 الوظيفة |
|---|---|
| 🛠️ `install.sh` | مُثبِّت بأمر واحد: التبعيات، النواة، السكربتات، والجدولة التلقائية |
| 🧬 `update_hybrid.sh` | المحرك الرئيسي: الحصص ← اختبار المجموعات ← مصفوفة التهجين ← إعادة التحميل الساخنة |
| 🌙 `converter.lua` | محلِّل Lua مستقل يحوّل الروابط إلى JSON فورًا |
| 🗂️ `conf3_final.json` | قالب التكوين الأساسي (المداخل، إزاحة المنافذ) |

</details>

### ⚙️ المحرك: تهجين البروتوكولات

السكربتات العادية تقوم فقط بفرز البروكسيات الجاهزة حسب وقت الاستجابة (ping). **Breeder** يذهب إلى أبعد من ذلك: يجمع بين مزايا البروتوكولات المختلفة.

**🔗 جدول السلاسل المدعومة:**

| 🟢 المرساة (دخول) | 🔵 الخروج | الحالة |
|---|---|:---:|
| Shadowsocks | Shadowsocks | ✅ |
| Shadowsocks | VLESS | ✅ |
| Shadowsocks | Trojan | ✅ |
| VLESS | Shadowsocks | ✅ |
| Trojan | Shadowsocks | ✅ |

**مثال على السلسلة النهائية:**
`[العميل] 💻 ← [عقدة SS / دخول] 🟢 ← [عقدة VLESS / خروج] 🔵 ← [الإنترنت] 🌐`

### ✨ المميزات الرئيسية

* 🛡️ **فلتر Uroboros** — منع الحلقات تلقائيًا؛ لا يتم التهجين إذا كانت المرساة والخروج على نفس IP أو نفس الشبكة الفرعية `/24`.
* ⚖️ **الحصص الذكية (Anti-OOM)** — قيود صارمة على عدد العقد (**1200** SS، **800** VLESS، **500** Trojan) لمنع استنفاد ذاكرة التوجيه.
* ⚡ **الفحص السريع** — يختبر السلاسل النشطة قبل الفحص الكامل. إذا حقق ≥70% السرعة المطلوبة، يتم تخطي الفحص الكامل.
* 🔒 **ثلاثة أوضاع للتشفير** — Mixed (افتراضي)، Strict (TLS فقط)، وFallback — لمنع استخدام تشفير قديم أو منافذ مفتوحة.
* 🔁 **تخزين مؤقت مشترك للبروتوكولات** — يتم اختبار سرعة كل عقدة مرة واحدة فقط لكل تشغيل، بغض النظر عن عدد مرات مشاركتها في مصفوفة السلاسل.

<details>
<summary>📊 <b>التفاصيل التقنية الموسعة (انقر للعرض)</b></summary>
<br>

| ⚙️ المعيار | القيمة |
|---|:---:|
| 🟢 حجم مجموعة المرساة (Anchor Pool) | `5` |
| 🔵 حجم مجموعة الخروج (Exit Pool) | `10` |
| 🎯 عدد السلاسل المستهدف (`WANTED_CHAINS`) | `6` |
| 🚀 الحد الأدنى لسرعة المجموعة (`MIN_POOL_SPEED_KBPS`) | `700 kbps` |
| 🔗 الحد الأدنى لسرعة السلسلة النهائية (`MIN_CHAIN_SPEED_KBPS`) | `400 kbps` |
| ⚡ عتبة الفحص السريع (Fast-Check) | `70%` |

**🔐 أوضاع التشفير بالتفصيل:**

| الوضع | 🎨 | الوصف |
|---|:---:|---|
| Mode 1 — Mixed | 🟢 | تتم معالجة عقد Secure وNaked معًا دون قيود |
| Mode 2 — Strict | 🟡 | يتم استبعاد عقد Naked (بدون TLS / `method:none`) بالكامل |
| Mode 3 — Fallback | 🔵 | يتم اختبار عقد Secure أولاً، وتُستخدم عقد Naked فقط كاحتياطي |

</details>

### 🚀 البداية السريعة

```bash
ssh admin@192.168.1.1
wget -O install.sh https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh
chmod +x install.sh
./install.sh
```

📍 مسار التكوين المستهدف: `/opt/tmp_sb_ext/sing-box-1.13.12-extended-2.4.1-linux-mipsle/conf_chain6.json`
📜 سجلات العملية: `tail -f sb_chain6.log`

---

<p align="center">
🐈‍⬛ <i>Сделано с любовью к свободной маршрутизации и старым добрым MIPS-роутерам</i> ❤️<br>
🇷🇺 🇬🇧 🇮🇷 🇨🇳 🇸🇦
</p>
