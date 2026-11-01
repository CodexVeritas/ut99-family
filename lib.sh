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

set_ini_value() {
    local file="$1" section="$2" key="$3" value="$4"
    awk -v section="[$section]" -v key="$key" -v value="$value" '
        /^\[/ { inside = ($0 == section) }
        inside && index($0, key "=") == 1 { print key "=" value; next }
        { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}
