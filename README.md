# Nexora WiFi 🌐

**Generic Nodogsplash-based WiFi hotspot system with Voucher Login, WiFi Chat, and Admin Panel.**

Any ISP/admin can deploy this on any OpenWrt router. No personal info, no proprietary code — just clean, reusable infrastructure.

---

## 📁 Structure

```
nexora-wifi/
├── etc/config/           # OpenWrt system configs (network, wireless, firewall, dhcp)
├── etc/nodogsplash/      # Nodogsplash hotspot daemon
│   └── htdocs/           # Splash page HTML/CSS, status, thankyou
├── www/cgi-bin/          # Admin panel CGI scripts (40+ scripts)
├── www/                  # State files, admin chat
└── README.md             # This file
```

## 🎯 Features

| Feature | Description |
|---|---|
| **Voucher Login** | Time-based access keys (1 day / weekly / monthly) |
| **WiFi Chat** | Client ↔ Admin real-time chat via splash page |
| **Admin Panel** | Full device tracking, MAC management, bandwidth control |
| **Watch/Video** | Client-facing media portal |
| **Bandwidth Monitor** | Real-time per-device traffic stats |
| **Mesh Support** | Multi-node WiFi mesh coordination |

## ⚙️ Router Hardware Requirements

### Minimum (Basic Usage)
- **CPU:** ARM9 or ARM Cortex-A7 (100 MHz+)
- **RAM:** 32 MB
- **Flash:** 8 MB (16 MB recommended)
- **WiFi:** 2.4 GHz 802.11n (single band)
- **WAN:** 10/100 Mbps Ethernet
- **Ports:** 1x WAN, 2x LAN minimum
- **OS:** OpenWrt 21.02 or 22.03

### Recommended (Stable Production)
- **CPU:** ARM Cortex-A9/A15 or MIPS 74Kc (400 MHz+)
- **RAM:** 64 - 128 MB
- **Flash:** 16 - 32 MB (SPI or NAND)
- **WiFi:** 2.4 GHz + 5 GHz (802.11ac preferred)
- **WAN:** 10/100 Mbps Ethernet (Gigabit better)
- **Ports:** 1x WAN, 4x LAN
- **OS:** OpenWrt 22.03 or 23.05+

### Best (High Load)
- **CPU:** ARM Cortex-A53+ (700 MHz+, dual-core)
- **RAM:** 128 MB+
- **Flash:** 64 MB+ (with USB storage)
- **WiFi:** 2.4 GHz + 5 GHz (WiFi 5/6, dual-band)
- **WAN:** Gigabit Ethernet
- **Ports:** 1x WAN, 4-5x LAN
- **OS:** OpenWrt 23.05+

### Tested Routers
| Model | Chipset | RAM | Flash |
|---|---|---|---|
| Cheap Soho | Ralink RT2880 | 32 MB | 8 MB |
| Xiaomi Mini | MediaTek MT7620A | 64 MB | 8 MB |
| Xiaomi AC750 | MediaTek MT7621A | 128 MB | 16 MB |
| TP-Link Archer C7 | Qualcomm Atheros QCA9558 | 128 MB | 16 MB |
| GL.iNet AR75M | MediaTek MT7621A | 128 MB | 16 MB |

### Capacity Estimates (per RAM)
| RAM | Max concurrent clients |
|---|---|
| 32 MB | 30 - 50 |
| 64 MB | 80 - 150 |
| 128 MB | 200 - 350 |
| 256 MB | 500+ |
| 512 MB | 1000+ |

### Flash Storage Usage
```
Base system (OpenWrt + Nodogsplash):   ~15 MB
Splash + admin panel:                   ~5 MB
Scripts + state files:                  ~2 MB
Voucher database:                       ~1-5 MB
Total working:                          ~25 MB
```
- **Minimum 8 MB flash** (with compression)
- **16 MB recommended** for smooth operation

## 🚀 Installation

### 1. Flash OpenWrt
Download image from [openwrt.org](https://openwrt.org/) for your router model. Flash via recovery/uboot mode.

### 2. Install Nodogsplash
```bash
opkg update
opkg install nodogsplash uci-defaults
```

### 3. Deploy this repo
```bash
# On your server (not router)
git clone https://github.com/YOUR_USER/nexora-wifi.git
cd nexora-wifi

# Copy files to router
scp -r etc/config/* root@ROUTER_IP:/etc/config/
scp -r etc/nodogsplash/ root@ROUTER_IP:/etc/
scp -r www/cgi-bin/ root@ROUTER_IP:/www/
scp www/* root@ROUTER_IP:/www/

# Reboot router
ssh root@ROUTER_IP reboot
```

### 4. Configure admin password
```bash
# Edit each script to set your password
cd /www/cgi-bin
sed -i 's/CHANGE_ME_ADMIN_PASS/your_password_here/g' *.sh
```

### 5. Create voucher codes
Voucher format: `NEXORA-XXXXXXXX`
```bash
# Example: generate voucher keys
echo "NEXORA-$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')"
```

Duration-based vouchers:
- `NEXORA-XXXX-24H` — 1 day
- `NEXORA-XXXX-7D` — weekly
- `NEXORA-XXXX-30D` — monthly

## 🎨 Customization

### Change branding
```bash
cd /etc/nodogsplash/htdocs
sed -i 's/Nexora/YourBrand/g' splash.html

# Add your logo
cp your_logo.jpg /etc/nodogsplash/htdocs/banner.jpg
```

### Change color scheme
Edit CSS variables in `splash.css` and `admin.css`:
```css
--primary-color: #1560d4;  /* Nexora blue */
--accent-color: #f59e0b;   /* Gold accent */
```

### Add custom plans
Edit the plans section in `splash.html` (search "Pricing Plans").

## 🔐 Security

- **Default password placeholder:** `CHANGE_ME_ADMIN_PASS`
- **Never commit real passwords** to version control
- **Use HTTPS** for admin panel in production
- **Restrict admin access** via firewall rules (admin IP only)

## 📊 Monitoring

- `admin.sh` — Main dashboard (bandwidth, devices, vouchers)
- `ifstat.sh` — Real-time traffic
- `online_count.sh` — Active clients
- `signal_api.sh` — WiFi signal strength

## 🔄 Backup Strategy

```bash
# Backup configs only (safe for sharing)
tar czf backup-configs.tar.gz \
  /etc/config /etc/nodogsplash/nodogsplash.conf \
  /etc/nodogsplash/htdocs
```

## 🆘 Troubleshooting

### Client can't connect
```bash
nodogsplash -c
cat /etc/nodogsplash/vouchers.txt
/etc/init.d/nodogsplash restart
```

### Admin panel not loading
```bash
netstat -tlnp | grep :80
chmod +x /www/cgi-bin/*.sh
```

### WiFi clients not authenticating
```bash
cat /etc/nodogsplash/nodogsplash.conf | grep -E "username|server"
uci show firewall | grep wlan
```

## 📄 License

MIT License — Use, modify, redistribute freely.

---

**Made for Nexora WiFi** — generic hotspot template, ready for any deployment.
