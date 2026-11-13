#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
    printf 'Использование: %s [файл_лога]\n' "$0" >&2
    exit 1
fi

log_file=${1:-access.log}

if [[ $# -eq 0 && ! -e "$log_file" ]]; then
    awk 'BEGIN {
        split("192.168.1.10 10.0.0.5 172.16.0.3 192.168.1.20 10.0.0.8", ips, " ")
        split("GET POST PUT DELETE", methods, " ")
        split("/api/users /api/login /api/health /api/items", paths, " ")
        split("200 200 200 201 200 301 400 401 404 500 502 503", codes, " ")
        for (i = 0; i < 360; i++) {
            slot = i % 10
            ip = slot < 4 ? ips[1] : slot < 7 ? ips[2] : slot < 9 ? ips[3] : ips[4 + int(i / 10) % 2]
            printf "%s - - [15/Aug/2026:10:%02d:%02d] \"%s %s HTTP/1.1\" %d\n", \
                ip, int(i / 60), i % 60, methods[i % 4 + 1], paths[i % 4 + 1], codes[i % 12 + 1]
        }
    }' > "$log_file"
    printf 'Создан тестовый лог: %s (360 строк)\n' "$log_file"
fi

if [[ ! -f "$log_file" || ! -r "$log_file" ]]; then
    printf 'Не удалось прочитать лог: %s\n' "$log_file" >&2
    exit 1
fi

filtered_log=$(mktemp "${TMPDIR:-/tmp}/analyze-logs.XXXXXX")
trap 'rm -f "$filtered_log"' EXIT

octet='(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])'
ip_pattern="${octet}(\.${octet}){3}"
record_pattern="^${ip_pattern} - - \[[^]]+\] \"[A-Z]+ [^\"]+ HTTP/[0-9.]+\" [1-5][0-9]{2}[[:space:]]*$"

if grep -E "$record_pattern" "$log_file" > "$filtered_log"; then
    :
else
    grep_status=$?
    if [[ "$grep_status" -ne 1 ]]; then
        printf 'Ошибка чтения лога\n' >&2
        exit 1
    fi
fi

printf 'Всего запросов: %s\n' "$(awk 'END { print NR + 0 }' "$filtered_log")"
printf 'Топ-3 IP-адреса:\n'
awk '{ print $1 }' "$filtered_log" |
    sort |
    uniq -c |
    sort -k1,1nr -k2,2 |
    awk 'NR <= 3 { printf "  %s - %d запросов\n", $2, $1 }'

awk '
    $NF ~ /^4[0-9][0-9]$/ { client_errors++ }
    $NF ~ /^5[0-9][0-9]$/ { server_errors++ }
    END {
        printf "Запросов с кодами 4xx: %d\n", client_errors + 0
        printf "Запросов с кодами 5xx: %d\n", server_errors + 0
        printf "Всего ошибок 4xx и 5xx: %d\n", client_errors + server_errors
    }
' "$filtered_log"
