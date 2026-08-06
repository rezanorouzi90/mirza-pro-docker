#!/bin/bash
# ============================================================
# 🚀 Mirza Pro — اسکریپت Deploy سریع
# بدون نیاز به Docker Compose — فقط Docker
# ============================================================
set -e

# ── رنگ‌ها ──
R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' B='\033[1;34m' C='\033[1;36m' W='\033[0m'

echo -e "${C}"
echo "╔══════════════════════════════════════════════════╗"
echo "║   🤖 Mirza Pro — Docker Deployer               ║"
echo "║   سازنده اصلی: @mohmrzw                        ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${W}"

# ── بررسی Docker ──
if ! command -v docker &> /dev/null; then
    echo -e "${Y}⏳ نصب Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    echo -e "${G}✅ Docker نصب شد${W}"
fi

echo -e "${G}✅ Docker موجود است${W}"

# ── ورودی‌ها ──
echo ""
read -p "$(echo -e ${B}Bot Token:${W}) " BOT_TOKEN
read -p "$(echo -e ${B}Admin ID (شناسه تلگرام):${W}) " ADMIN_ID
read -p "$(echo -e ${B}Bot Username (بدون @):${W}) " BOT_USERNAME
read -p "$(echo -e ${B}Domain (خالی برای IP مستقیم):${W}) " DOMAIN
read -p "$(echo -e ${B}پورت وب \[8080\]:${W}) " PORT
PORT=${PORT:-8080}

# ── اعتبارسنجی ──
if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ] || [ -z "$BOT_USERNAME" ]; then
    echo -e "${R}❌ BOT_TOKEN, ADMIN_ID و BOT_USERNAME اجباری هستند!${W}"
    exit 1
fi

echo ""
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${W}"
echo -e "${G}📋 خلاصه:${W}"
echo -e "  🤖 Bot:       @$BOT_USERNAME"
echo -e "  👑 Admin ID:  $ADMIN_ID"
[ -n "$DOMAIN" ] && echo -e "  🌐 Domain:    https://$DOMAIN"
echo -e "  🔌 Port:      $PORT"
echo -e "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${W}"
echo ""

# ── اجرای Docker ──
echo -e "${Y}🐳 ساخت و اجرای Docker...${W}"

# ساخت ایمیج
docker build -t mirza-pro .

# اجرای کانتینر
docker rm -f mirza-pro 2>/dev/null || true
docker run -d \
    --name mirza-pro \
    --restart unless-stopped \
    -e BOT_TOKEN="$BOT_TOKEN" \
    -e ADMIN_ID="$ADMIN_ID" \
    -e BOT_USERNAME="$BOT_USERNAME" \
    -e DOMAIN="$DOMAIN" \
    -p "$PORT:80" \
    mirza-pro

echo ""
echo -e "${G}╔══════════════════════════════════════════════════╗${W}"
echo -e "${G}║        ✅ Mirza Pro با موفقیت اجرا شد!          ║${W}"
echo -e "${G}╚══════════════════════════════════════════════════╝${W}"
echo ""
echo -e "${C}📋 اطلاعات:${W}"
echo -e "  🌐 آدرس:     http://localhost:$PORT"
[ -n "$DOMAIN" ] && echo -e "  🌐 دامنه:    https://$DOMAIN"
echo -e "  🤖 Bot:       @$BOT_USERNAME"
echo -e "  📋 لاگ‌ها:    docker logs -f mirza-pro"
echo -e "  🛑 توقف:     docker stop mirza-pro"
echo -e "  🗑️  حذف:     docker rm -f mirza-pro"
echo ""
echo -e "${Y}⚠️  به ربات بروید و /start بزنید 🔥${W}"
echo ""
