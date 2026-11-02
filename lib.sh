# Helpers shared by setup.sh and play.sh.

# Prints the focused (Hyprland) or primary (X11) screen size as WIDTHxHEIGHT, or nothing if unknown.
detect_resolution() {
    local resolution=""
    if command -v hyprctl >/dev/null; then
        resolution=$(hyprctl monitors 2>/dev/null | awk '
            /^Monitor/ { size = "" }
            /^[[:space:]]+[0-9]+x[0-9]+@/ { split($1, parts, "@"); size = parts[1]; if (first == "") first = size }
            /focused: yes/ && size != "" { print size; found = 1; exit }
            END { if (!found && first != "") print first }
        ')
    fi
    if [[ -z "$resolution" ]] && command -v xrandr >/dev/null; then
        resolution=$(xrandr --query 2>/dev/null | grep ' connected primary' | grep -oE '[0-9]+x[0-9]+' | head -1 || true)
        [[ -n "$resolution" ]] || resolution=$(xrandr --query 2>/dev/null | grep -oE 'current [0-9]+ x [0-9]+' | head -1 | awk '{print $2"x"$4}')
    fi
    echo "$resolution"
}

# Prints a UT server's raw status reply (\key\value\... pairs), or nothing if it does not answer.
# The query port is the game port + 1. Uses bash's /dev/udp so no netcat is needed; cat (not
# bash's read, which takes one byte per packet and drops the rest) collects the reply packets for 2 seconds.
query_server_status() {
    local host="$1" query_port="$2" socket
    exec {socket}<>"/dev/udp/$host/$query_port" 2>/dev/null || return 0
    printf '\\status\\' >&"$socket" 2>/dev/null || true
    timeout 2 cat <&"$socket" 2>/dev/null || true
    exec {socket}>&-
}

set_ini_value() {
    local file="$1" section="$2" key="$3" value="$4"
    awk -v section="[$section]" -v key="$key" -v value="$value" '
        /^\[/ { inside = ($0 == section) }
        inside && index($0, key "=") == 1 { print key "=" value; next }
        { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}
