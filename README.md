# 🤖 Mirza Pro — Docker Version

<p align="center">
  <img src="https://img.shields.io/badge/Version-3.0-blue?style=for-the-badge" alt="Version">
  <img src="https://img.shields.io/badge/PHP-8.2-777BB4?style=for-the-badge&logo=php" alt="PHP">
  <img src="https://img.shields.io/badge/MariaDB-10+-003545?style=for-the-badge&logo=mariadb" alt="MariaDB">
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker" alt="Docker">
</p>

---

## 📋 خلاصه

نسخه Docker ربات **Mirza Pro** — پنل مدیریت VPN با ربات تلگرام.

با یک دستور اجرا کنید، بدون نیاز به نصب دستی Apache, MariaDB, PHP یا هیچ چیز دیگه.

> ⚠️ **پروژه اصلی توسط [Mahdi](https://github.com/mahdiMGF2/mirza_pro/) ساخته شده**
> 
> این نسخه Docker توسط **[@mohmrzw](https://github.com/mohmrzw)** ساخته شده

---

## ✨ امکانات

| ویژگی | توضیح |
|---|---|
| 🐳 **Docker** | بدون نیاز به نصب دستی |
| 🔍 **تشخیص خودکار** | متغیرها را از ENV می‌خواند |
| 🗄️ **MariaDB** | دیتابیس خودکار |
| 🔐 **SSL** | با Certbot (اختیاری) |
| 🔗 **Webhook** | تنظیم خودکار تلگرام |
| 💾 **ذخیره‌持久** | Volume برای فایل‌ها و دیتابیس |

---

## 🚀 نصب سریع

### روش ۱: اسکریپت Deploy (توصیه شده)

```bash
git clone https://github.com/rezanorouzi90/mirza-pro-docker.git
cd mirza-pro-docker
chmod +x deploy.sh
./deploy.sh
```

اسکریپت به صورت خودکار:
- ✅ Docker را بررسی/نصب می‌کند
- ✅ ایمیج را می‌سازد
- ✅ متغیرها را از شما می‌گیرد
- ✅ کانتینر را اجرا می‌کند

### روش ۲: Docker Compose

```bash
# کپی الگوی متغیرها
cp .env.example .env

# ویرایش متغیرها
nano .env
```

محتوای `.env`:
```env
BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
ADMIN_ID=7025776524
BOT_USERNAME=your_bot
DOMAIN=bot.example.com
PORT=8080
```

سپس اجرا کنید:
```bash
docker-compose up -d
```

### روش ۳: Docker Run (دستی)

```bash
# ساخت ایمیج
docker build -t mirza-pro .

# اجرا
docker run -d \
  --name mirza-pro \
  --restart unless-stopped \
  -e BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz" \
  -e ADMIN_ID="7025776524" \
  -e BOT_USERNAME="your_bot" \
  -e DOMAIN="bot.example.com" \
  -p 8080:80 \
  mirza-pro
```

---

## ⚙️ متغیرهای محیطی

### اجباری

| متغیر | توضیح | مثال |
|---|---|---|
| `BOT_TOKEN` | توکن ربات تلگرام | `123456789:ABC...` |
| `ADMIN_ID` | شناسه تلگرام ادمین | `7025776524` |
| `BOT_USERNAME` | نام کاربری ربات (بدون @) | `mybot` |

### اختیاری

| متغیر | پیش‌فرض | توضیح |
|---|---|---|
| `DOMAIN` | `(خالی)` | دامنه ربات |
| `DB_NAME` | `mirza_pro` | نام دیتابیس |
| `DB_USER` | `mirza_user` | کاربر دیتابیس |
| `DB_PASS` | `(خودکار)` | رمز دیتابیس |
| `PORT` | `8080` | پورت وب |

---

## 📁 ساختار پروژه

```
mirza-pro-docker/
├── Dockerfile           # ساخت ایمیج (Apache + PHP + MariaDB)
├── entrypoint.sh        # راه‌اندازی خودکار
├── supervisord.conf     # مدیریت سرویس‌ها
├── docker-compose.yml   # اجرای ساده
├── deploy.sh            # اسکریپت deploy
├── .env.example         # الگوی متغیرها
└── README.md            # این فایل
```

---

## 🛠️ مدیریت

```bash
# مشاهده لاگ‌ها
docker logs -f mirza-pro

# توقف
docker stop mirza-pro

# شروع مجدد
docker restart mirza-pro

# حذف
docker rm -f mirza-pro

# آپدیت
docker build -t mirza-pro . && docker rm -f mirza-pro && docker run -d --name mirza-pro --restart unless-stopped -e BOT_TOKEN=... -e ADMIN_ID=... -e BOT_USERNAME=... -p 8080:80 mirza-pro
```

---

## 🔧 عیب‌یابی

| مشکل | راه‌حل |
|---|---|
| ` BOT_TOKEN اجباری است` | متغیر BOT_TOKEN را تنظیم کنید |
| `Database connection failed` | لاگ‌ها را چک کنید: `docker logs mirza-pro` |
| `Webhook تنظیم نشد` | DOMAIN را تنظیم کنید و دوباره اجرا کنید |
| `Port in use` | پورت دیگری انتخاب کنید: `-p 9090:80` |

---

## 📚 لینک‌ها

| لینک | توضیح |
|---|---|
| [Mirza Pro](https://github.com/mahdiMGF2/mirza_pro/) | پروژه اصلی |
| [Docker Docs](https://docs.docker.com/) | مستندات Docker |

---

## 📜 مجوز

MIT License — از پروژه اصلی به ارث رسیده.

سازنده اصلی: [@mohmrzw](https://github.com/mohmrzw)
پروژه اصلی: [Mahdi / mirza_pro](https://github.com/mahdiMGF2/mirza_pro/)
