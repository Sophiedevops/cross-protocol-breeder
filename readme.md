```python
content = """# cross-protocol-breeder

```text
      /\\_/\\   [PROXY HYBRID MODULE]
     ( o.o )  
      > ^ <   Cross-Protocol Breeder
           |\\__/,|   (`\\
         _.|o o  |_   ) )
        -(((---(((--------

```

**Hybrid Multi-Hop Proxy Chain Builder for Embedded Routers**

---

**🌐 Доступные языки / Available languages:**
[🇷🇺 Русский](#-русский) · [🇬🇧 English](#-english) · [🇮🇷 فارسی](#-فارسی) · [🇨🇳 中文](#-中文) · [🇸🇦 العربية](#-العربية)

---

## 🇷🇺 Русский

*Автоматическое построение каскадных multi-hop конфигураций путём кросс-протокольного «скрещивания» прямо на слабом MIPS-роутере.*

---

### 🧩 Что это такое?

**Cross-Protocol Breeder** — это интеллектуальный шелл-скрипт для роутеров под управлением **Entware/Padavan**, который автоматически загружает подписки, тестирует скорость узлов и строит **гибридные каскады** (например, `ss → vless`, `trojan → ss`).

Скрипт решает задачу создания устойчивых к блокировкам цепочек на роутере с **дефицитом ОЗУ и слабым процессором MIPSLE**, полностью избегая «эффекта матрёшки» (избыточного вложенного TLS).

Состав проекта:

* **`install.sh`** — установщик «в одну команду»: ставит зависимости, ядро, скрипты и крон.
* **`update_hybrid.sh`** — основной движок: квотирование → тест пулов → кросс-скрещивание → горячий перезапуск.
* **`converter.lua`** — Lua-парсер: превращает прокси-ссылки в JSON на лету без внешних утилит.
* **`conf3_final.json`** — базовый шаблон (инбаунды, сдвиг портов).

---

### ⚙️ Движок: Скрещивание протоколов (Cross-Breeding)

Обычные скрипты просто сортируют готовые прокси по пингу. **Breeder** идёт дальше: он объединяет преимущества разных протоколов. Поддерживаемые каскады: `ss-ss`, `ss-vless`, `ss-trojan`, `vless-ss`, `trojan-ss`.

Пример итоговой цепочки:
`[Клиент] → [SS-узел (Якорь / Anchor)] → [VLESS-узел (Выход / Exit)] → [Интернет]`

Такой подход позволяет использовать Shadowsocks для маскировки первого прыжка (обход простого DPI), а современный VLESS — для пробития файрволов на выходе.

---

### ✨ Ключевые особенности

* **🛡️ Uroboros-фильтр** — автоматическое исключение петель. Скрипт не даст скрестить узлы, если Anchor и Exit находятся на одном IP или в одной `/24` подсети.
* **⚖️ Smart-квоты и Anti-OOM** — жесткое квотирование при парсинге (1200 SS, 800 VLESS, 500 Trojan), чтобы не забить оперативную память роутера.
* **⚡ Fast Check** — перед полным сканированием проверяются текущие рабочие цепочки. Если ≥70% выдают целевую скорость — полный пайплайн отменяется, экономя ресурс флешки.
* **🔒 Три режима шифрования** — Mixed (по умолчанию), Strict (только TLS) и Fallback. Защищает от использования устаревших шифров и открытых портов.
* **🔁 Кэширование пулов по протоколам** — ноды проверяются на скорость только один раз за прогон, независимо от того, сколько раз они участвуют в матрице каскадов.

---

### 🚀 Установка (рекомендуемый способ)

Установщик проверит Entware, поставит зависимости (`curl jq lua`), скачает скрипты и настроит автозапуск.

```bash
# 1. Подключитесь к роутеру по SSH
ssh admin@192.168.1.1

# 2. Скачайте и запустите установщик
wget -O install.sh [https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh](https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh)
chmod +x install.sh
./install.sh

```

После установки целевой конфиг будет доступен по пути: `/opt/tmp_sb_ext/sing-box-1.13.12-extended-2.4.1-linux-mipsle/conf_chain6.json`.
Логи процесса: `tail -f sb_chain6.log`.

---

## 🇬🇧 English

*Automatic multi-hop hybrid cascade generation through cross-protocol "breeding" directly on a low-end MIPS router.*

---

### 🧩 What is this?

**Cross-Protocol Breeder** is an intelligent shell-based system for **Padavan/Entware** routers that automatically downloads subscriptions, tests node speeds, and builds **hybrid multi-hop cascades** (e.g., `ss → vless`, `trojan → ss`).

It solves the problem of creating censorship-resistant proxy chains on a **RAM-constrained Padavan router with a MIPSLE CPU**, strictly avoiding the "matryoshka effect" (redundant nested TLS).

Project components:

* **`install.sh`** — one-command installer: dependencies, core binary, scripts, autostart + cron.
* **`update_hybrid.sh`** — the main engine: protocol quotas → pool testing → cross-breeding matrix → hot reload.
* **`converter.lua`** — self-contained Lua parser that turns share links into JSON on the fly.
* **`conf3_final.json`** — base template (inbounds, port shifting).

---

### ⚙️ Engine: Cross-Protocol Breeding

Standard scripts simply sort existing proxies by ping. **Breeder** takes it further: it combines the advantages of different protocols. Supported chains: `ss-ss`, `ss-vless`, `ss-trojan`, `vless-ss`, `trojan-ss`.

Example of a generated cascade:
`[Client] → [SS Node (Anchor)] → [VLESS Node (Exit)] → [Internet]`

This approach allows using Shadowsocks to mask the first hop (bypassing simple DPI) and modern VLESS for penetrating strict firewalls on the exit hop.

---

### ✨ Key Features

* **🛡️ Uroboros Filter** — automatic loop prevention. The script prevents breeding nodes if the Anchor and Exit share the same IP or belong to the same `/24` subnet.
* **⚖️ Smart Quotas & Anti-OOM** — strict limits during parsing (1200 SS, 800 VLESS, 500 Trojan) to prevent exhausting the router's RAM.
* **⚡ Fast Check** — tests currently active chains before a full scan. If ≥70% meet the target speed, the full heavy pipeline is skipped, saving CPU and flash wear.
* **🔒 Three Encryption Modes** — Mixed (default), Strict (TLS only), and Fallback. Drops naked and legacy cipher nodes according to the selected strictness.
* **🔁 Shared Protocol Caching** — nodes are tested for speed exactly once per run, regardless of how many cascade matrices they participate in.

---

### 🚀 Quick Start (recommended)

The installer will check Entware, install dependencies (`curl jq lua`), download the scripts, and configure autostart.

```bash
# 1. Connect to your router via SSH
ssh admin@192.168.1.1

# 2. Download and run the installer
wget -O install.sh [https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh](https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh)
chmod +x install.sh
./install.sh

```

Target configuration path: `/opt/tmp_sb_ext/sing-box-1.13.12-extended-2.4.1-linux-mipsle/conf_chain6.json`.
Process logs: `tail -f sb_chain6.log`.

---

## 🇮🇷 فارسی

*تولید خودکار آبشارهای ترکیبی چندمرحله‌ای (multi-hop) از طریق «پیوند» پروتکل‌های مختلف، مستقیماً روی روتر ضعیف MIPS.*

---

### 🧩 این پروژه چیست؟

**Cross-Protocol Breeder** یک سیستم هوشمند مبتنی بر Shell برای روترهای **Padavan/Entware** است که اشتراک‌ها را دانلود می‌کند، سرعت گره‌ها را آزمایش کرده و **آبشارهای ترکیبی** (مانند `ss ← vless`، `trojan ← ss`) می‌سازد.

این پروژه مشکل ایجاد زنجیره‌های پروکسی مقاوم در برابر سانسور را روی روترهایی با **حافظه رم محدود و پردازنده MIPSLE** حل می‌کند، و از "اثر ماتریوشکا" (TLS تو در تو اضافی) جلوگیری می‌کند.

اجزای پروژه:

* **`install.sh`** — نصب‌کننده تک‌دستوری.
* **`update_hybrid.sh`** — موتور اصلی: سهمیه پروتکل‌ها ← آزمایش استخرها ← ماتریس پیوند ← بارگذاری مجدد.
* **`converter.lua`** — تجزیه‌گر مستقل Lua.
* **`conf3_final.json`** — قالب پایه.

---

### ⚙️ موتور: ترکیب پروتکل‌ها

اسکریپت‌های معمولی فقط پروکسی‌ها را بر اساس پینگ مرتب می‌کنند. **Breeder** گامی فراتر می‌رود: پروتکل‌های مختلف را با هم ترکیب می‌کند تا یک زنجیره قدرتمند ایجاد کند (مانند `ss-vless`).

مثال زنجیره نهایی:
`[کلاینت] ← [گره SS (لنگر)] ← [گره VLESS (خروج)] ← [اینترنت]`

---

### ✨ ویژگی‌های اصلی

* **🛡️ فیلتر Uroboros** — جلوگیری از حلقه‌های شبکه و تداخل زیرشبکه /24.
* **⚖️ سهمیه‌های هوشمند (Anti-OOM)** — محدودیت پردازش (1200 SS، 800 VLESS) برای جلوگیری از پر شدن حافظه روتر.
* **⚡ بررسی سریع هوشمند** — پرش از اسکن کامل اگر 70٪ زنجیره‌های قبلی هنوز سریع باشند.
* **🔒 سه حالت رمزگذاری** — از جمله حالت Strict برای حذف اتصالات بدون TLS.

---

### 🚀 شروع سریع

```bash
ssh admin@192.168.1.1
wget -O install.sh [https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh](https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh)
chmod +x install.sh
./install.sh

```

---

## 🇨🇳 中文

*在低端 MIPS 路由器上，通过跨协议“杂交”自动构建混合多跳（multi-hop）级联代理。*

---

### 🧩 项目简介

**Cross-Protocol Breeder** 是一个专为 **Padavan/Entware** 路由器设计的智能 Shell 脚本系统。它能自动下载订阅、测速，并构建 **混合多跳级联**（例如 `ss → vless`，`trojan → ss`）。

它解决了在 **RAM 受限的 MIPSLE 路由器** 上创建抗封锁代理链的问题，同时严格避免了“套娃效应”（冗余的嵌套 TLS）。

项目组成部分：

* **`install.sh`** — 一键安装器。
* **`update_hybrid.sh`** — 主引擎：配额管理 → 节点池测速 → 交叉组合矩阵 → 热重载。
* **`converter.lua`** — 独立的 Lua 解析器。
* **`conf3_final.json`** — 基础模板（入站、端口偏移）。

---

### ⚙️ 核心引擎：跨协议混合

标准的脚本仅仅是根据延迟对节点进行排序。**Breeder** 更进一步：它结合了不同协议的优势，支持的链路包括：`ss-ss`、`ss-vless`、`ss-trojan`、`vless-ss`、`trojan-ss`。

生成的级联链路示例：
`[客户端] → [SS 节点 (入口)] → [VLESS 节点 (出口)] → [互联网]`

---

### ✨ 核心特性

* **🛡️ Uroboros 过滤器** — 自动防环路。防止入口和出口节点位于同一 IP 或 `/24` 子网。
* **⚖️ 智能配额与 Anti-OOM** — 严格限制解析数量（1200 SS, 800 VLESS, 500 Trojan）以防内存耗尽。
* **⚡ 快速检查 (Fast Check)** — 在全面扫描前测试当前链路。如果 ≥70% 达标，则跳过繁重的全量扫描。
* **🔒 三种加密模式** — 混合（默认）、严格（仅限 TLS）和回退模式。

---

### 🚀 快速开始

```bash
ssh admin@192.168.1.1
wget -O install.sh [https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh](https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh)
chmod +x install.sh
./install.sh

```

---

## 🇸🇦 العربية

*توليد تلقائي لتتابعات البروكسي الهجينة متعددة القفزات (multi-hop) من خلال "تهجين" البروتوكولات مباشرةً على جهاز توجيه MIPS ضعيف.*

---

### 🧩 ما هو هذا المشروع؟

**Cross-Protocol Breeder** هو نظام ذكي مبني على Shell لأجهزة توجيه **Padavan/Entware** يقوم تلقائيًا بتنزيل الاشتراكات واختبار سرعة العقد وبناء **سلاسل هجينة** (مثل `ss ← vless`، `trojan ← ss`).

يحل المشروع مشكلة إنشاء سلاسل بروكسي مقاومة للرقابة على أجهزة توجيه ذات **ذاكرة RAM محدودة ومعالج MIPSLE**، مع تجنب "تأثير الدمية الروسية" (طبقات TLS المتداخلة الزائدة).

مكونات المشروع:

* **`install.sh`** — مُثبِّت بأمر واحد.
* **`update_hybrid.sh`** — المحرك الرئيسي: الحصص ← اختبار المجموعات ← مصفوفة التهجين ← إعادة التحميل الساخنة.
* **`converter.lua`** — محلِّل Lua مستقل.
* **`conf3_final.json`** — قالب التكوين الأساسي.

---

### ⚙️ المحرك: تهجين البروتوكولات

السكربتات العادية تقوم فقط بفرز البروكسيات الجاهزة حسب وقت الاستجابة (ping). **Breeder** يذهب إلى أبعد من ذلك: يجمع بين مزايا البروتوكولات المختلفة (مثل `ss-vless`).

مثال على السلسلة النهائية:
`[العميل] ← [عقدة SS (دخول)] ← [عقدة VLESS (خروج)] ← [الإنترنت]`

---

### ✨ المميزات الرئيسية

* **🛡️ فلتر Uroboros** — منع الحلقات تلقائيًا وتجنب تعارض الشبكات الفرعية /24.
* **⚖️ الحصص الذكية (Anti-OOM)** — قيود صارمة على عدد العقد (1200 SS، 800 VLESS) لمنع استنفاد ذاكرة التوجيه.
* **⚡ الفحص السريع** — يختبر السلاسل النشطة حاليًا قبل إجراء فحص كامل. إذا كان ≥70% يحقق السرعة المطلوبة، يتم تخطي الفحص الكامل لتوفير الموارد.
* **🔒 ثلاثة أوضاع للتشفير** — وضع Mixed (الافتراضي)، Strict (فقط TLS)، وFallback.

---

### 🚀 البداية السريعة

```bash
ssh admin@192.168.1.1
wget -O install.sh [https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh](https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install.sh)
chmod +x install.sh
./install.sh

```

---

*Сделано с любовью к свободной маршрутизации и старым добрым MIPS-роутерам ❤️*
"""

with open("README.md", "w", encoding="utf-8") as f:
f.write(content)

print("[file-tag: README.md]")

```

```text?code_stdout&code_event_index=1
[file-tag: README.md]

