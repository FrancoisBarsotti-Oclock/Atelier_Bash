#!/usr/bin/env bash
# monitor.sh — version Git Bash (Windows)

set -euo pipefail

# ---------- Helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }

# WMIC (Windows) -> possible "No Instance(s) Available." ou vide
wmic_value() {
  local query="$1"
  local out
  out="$(wmic $query 2>/dev/null | tr -d '\r' | sed '/^[[:space:]]*$/d' || true)"
  # Retourne la 2e ligne (valeur), sinon vide
  echo "$out" | awk 'NR==2 {print $1}'
}

to_gb() { # KB -> GB (2 décimales)
  awk -v kb="$1" 'BEGIN { printf "%.2f", kb/1024/1024 }'
}

pct() { # used total -> %
  awk -v u="$1" -v t="$2" 'BEGIN { if(t>0) printf "%.1f", (100*u/t); else print "N/A" }'
}

# ---------- Hostname / Date ----------
HOST="$(hostname 2>/dev/null || echo "N/A")"
NOW="$(date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || echo "N/A")"

# ---------- Uptime ----------
UPTIME_PRETTY="N/A"
if have uptime; then
  # Git Bash peut avoir uptime -p, sinon uptime simple
  UPTIME_PRETTY="$(uptime -p 2>/dev/null || uptime 2>/dev/null || echo "N/A")"
elif have net; then
  # fallback Windows
  UPTIME_PRETTY="$(net stats workstation 2>/dev/null | tr -d '\r' | sed -n 's/^Statistiques depuis[[:space:]]*//p' || true)"
  [ -z "$UPTIME_PRETTY" ] && UPTIME_PRETTY="N/A"
fi

# ---------- CPU % ----------
CPU_PCT="N/A"
# WMIC (souvent présent)
CPU_PCT_WMIC="$(wmic_value "cpu get loadpercentage")"
if [[ "${CPU_PCT_WMIC:-}" =~ ^[0-9]+$ ]]; then
  CPU_PCT="$CPU_PCT_WMIC"
else
  # fallback PowerShell
  if have powershell.exe; then
    CPU_PCT="$(powershell.exe -NoProfile -Command \
      "(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average" \
      2>/dev/null | tr -d '\r' | awk 'NF{print int($1)}' | head -n1 || true)"
    [[ "${CPU_PCT:-}" =~ ^[0-9]+$ ]] || CPU_PCT="N/A"
  fi
fi

# ---------- Memory (Go + %) ----------
MEM_USED_GB="N/A"
MEM_TOTAL_GB="N/A"
MEM_PCT="N/A"

# ---------- Helpers ----------
# --- [AJOUT ICI] Couleurs + alertes ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'   # reset

# Retourne la couleur selon un % (nombre)
color_for_pct() {
  local p="$1"
  if [ "$p" -lt 70 ]; then
    echo -e "$GREEN"
  elif [ "$p" -le 85 ]; then
    echo -e "$YELLOW"
  else
    echo -e "$RED"
  fi
}

# Convertit "12.3" -> 12 (pour comparer en bash)
to_int() { awk -v x="$1" 'BEGIN{ printf "%d", x+0 }'; }


# Via WMIC OS: TotalVisibleMemorySize / FreePhysicalMemory (en KB)
MEM_TOTAL_KB="$(wmic_value "OS get TotalVisibleMemorySize")"
MEM_FREE_KB="$(wmic_value "OS get FreePhysicalMemory")"

if [[ "${MEM_TOTAL_KB:-}" =~ ^[0-9]+$ ]] && [[ "${MEM_FREE_KB:-}" =~ ^[0-9]+$ ]]; then
  MEM_USED_KB=$((MEM_TOTAL_KB - MEM_FREE_KB))
  MEM_USED_GB="$(to_gb "$MEM_USED_KB")"
  MEM_TOTAL_GB="$(to_gb "$MEM_TOTAL_KB")"
  MEM_PCT="$(pct "$MEM_USED_KB" "$MEM_TOTAL_KB")"
else
  # fallback PowerShell (bytes)
  if have powershell.exe; then
    read -r totalB freeB < <(powershell.exe -NoProfile -Command \
      "\$os=Get-CimInstance Win32_OperatingSystem; [string]\$os.TotalVisibleMemorySize+' '+[string]\$os.FreePhysicalMemory" \
      2>/dev/null | tr -d '\r' | awk 'NF{print $1" "$2; exit}' || true)

    if [[ "${totalB:-}" =~ ^[0-9]+$ ]] && [[ "${freeB:-}" =~ ^[0-9]+$ ]]; then
      MEM_TOTAL_KB="$totalB"
      MEM_FREE_KB="$freeB"
      MEM_USED_KB=$((MEM_TOTAL_KB - MEM_FREE_KB))
      MEM_USED_GB="$(to_gb "$MEM_USED_KB")"
      MEM_TOTAL_GB="$(to_gb "$MEM_TOTAL_KB")"
      MEM_PCT="$(pct "$MEM_USED_KB" "$MEM_TOTAL_KB")"
    fi
  fi
fi

# ---------- Partitions ----------
DISK_INFO="N/A"
if have df; then
  # -P pour format stable ; on affiche source + mountpoint + %
  DISK_INFO="$(df -P | tail -n +2 | awk '{printf "%-20s %-25s %s\n",$1,$6,$5}')"
else
  # fallback PowerShell (lettres de lecteurs)
  if have powershell.exe; then
    DISK_INFO="$(powershell.exe -NoProfile -Command \
      "Get-CimInstance Win32_LogicalDisk -Filter \"DriveType=3\" |
       ForEach-Object {
         \$used=\$_.Size-\$_.FreeSpace
         \$pct=[math]::Round((\$used/\$_.Size)*100,1)
         \"{0,-20} {1,-25} {2}%\" -f \$_.DeviceID, \$_.DeviceID, \$pct
       }" \
      2>/dev/null | tr -d '\r' | sed '/^[[:space:]]*$/d' || true)"
    [ -z "$DISK_INFO" ] && DISK_INFO="N/A"
  fi
fi

# ---------- Process count ----------
PROC_COUNT="N/A"
if have ps; then
  PROC_COUNT="$(ps -e 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
elif have tasklist; then
  PROC_COUNT="$(tasklist 2>/dev/null | tr -d '\r' | tail -n +4 | wc -l | tr -d ' ')"
fi

# ---------- Output ----------
echo "===== MONITOR (Git Bash / Windows) ====="
echo "Hostname                 : $HOST"
echo "Date/Heure               : $NOW"
echo "Uptime                   : $UPTIME_PRETTY"
echo "Utilisation CPU          : ${CPU_PCT}%"
echo "Memoire                  : ${MEM_USED_GB} Go / ${MEM_TOTAL_GB} Go (${MEM_PCT}%)"
echo
echo "Partitions (Utilisation) :"
echo "$DISK_INFO"
echo
echo "Processus en cours       : $PROC_COUNT"
echo "======================================="
