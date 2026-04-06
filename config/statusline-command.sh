#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract current directory from workspace
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$cwd")
term_width=$(tput cols 2>/dev/null || echo 120)

# --- Colour helper: muted palette based on percentage ---
pct_colour() {
    local p=$(printf "%.0f" "$1")
    if [ "$p" -ge 90 ]; then printf '\033[38;5;167m'
    elif [ "$p" -ge 75 ]; then printf '\033[38;5;173m'
    elif [ "$p" -ge 50 ]; then printf '\033[38;5;179m'
    else printf '\033[38;5;108m'
    fi
}

# --- Bar builder ---
build_bar() {
    local pct_val=$1 bar_w=$2
    local f=$(printf "%.0f" "$(echo "scale=2; $pct_val / 100 * $bar_w" | bc)")
    local e=$((bar_w - f))
    local colour=$(pct_colour "$pct_val")
    local b="${colour}["
    for ((i=0; i<f; i++)); do b+="█"; done
    b+="\033[38;5;240m"
    for ((i=0; i<e; i++)); do b+="░"; done
    b+="${colour}]"
    echo -e "$b"
}

# --- Helper: right-align text on a line ---
print_line() {
    local left="$1" right="$2"
    local left_vis=$(echo -e "$left" | sed 's/\x1b\[[0-9;]*m//g')
    local right_vis=$(echo -e "$right" | sed 's/\x1b\[[0-9;]*m//g')
    local sp=$((term_width - ${#left_vis} - ${#right_vis}))
    [ $sp -lt 1 ] && sp=1
    printf '%s%*s%s' "$left" "$sp" "" "$right"
}

# =====================================================================
# LINE 1: Git & project info
# =====================================================================
line1_left=$(printf '\033[38;5;109m➜ %s\033[0m' "$dir_name")

if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        if git -C "$cwd" diff --quiet 2>/dev/null && git -C "$cwd" diff --cached --quiet 2>/dev/null; then
            dirty_str=""
        else
            file_count=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            dirty_str=$(printf ' \033[38;5;179m✗%s\033[0m' "$file_count")
        fi
        line1_left=$(printf '%s \033[34mgit:\033[38;5;167m%s\033[0m%s' "$line1_left" "$branch" "$dirty_str")

        # Worktree badge — try Claude's JSON first, fall back to git detection
        worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')
        if [ -z "$worktree_name" ]; then
            # Detect git worktree: if .git is a file (not a dir), we're in a worktree
            git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
            if [ -f "$cwd/.git" ] 2>/dev/null; then
                worktree_name=$(basename "$cwd")
            fi
        fi
        if [ -n "$worktree_name" ]; then
            line1_left=$(printf '%s \033[38;5;139m[wt:%s]\033[0m' "$line1_left" "$worktree_name")
        else
            line1_left=$(printf '%s \033[38;5;245m[main tree]\033[0m' "$line1_left")
        fi
    fi
fi

# Stash count (right side of line 1)
line1_right=""
stash_count=$(git -C "$cwd" stash list 2>/dev/null | wc -l | tr -d ' ')
if [ "$stash_count" -gt 0 ]; then
    line1_right=$(printf '\033[38;5;139m⚑ %s stash%s\033[0m' "$stash_count" "$([ "$stash_count" -ne 1 ] && echo 'es')")
fi

print_line "$line1_left" "$line1_right"

# =====================================================================
# LINE 2: Application info (Docker, queue)
# =====================================================================

# Docker project prefix (main stack vs worktree)
# Worktree .env files have WORKTREE_NAME set; main repo does not.
docker_prefix="street"
wt_name=$(grep '^WORKTREE_NAME=' "$cwd/.env" 2>/dev/null | cut -d= -f2)
if [ -n "$wt_name" ]; then
    docker_prefix="street-${wt_name}"
fi

line2_left=""
if command -v docker &>/dev/null; then
    app_state=$(docker inspect -f '{{.State.Status}}' "${docker_prefix}-app-1" 2>/dev/null)
    vite_state=$(docker inspect -f '{{.State.Status}}' "${docker_prefix}-vite-1" 2>/dev/null)
    queue_state=$(docker inspect -f '{{.State.Status}}' "${docker_prefix}-queue-1" 2>/dev/null)

    if [ -n "$app_state" ] || [ -n "$vite_state" ]; then
        dot_running=$(printf '\033[38;5;108m●\033[0m')
        dot_stopped=$(printf '\033[38;5;167m●\033[0m')

        [ "$app_state" = "running" ] && app_d="$dot_running" || app_d="$dot_stopped"
        [ "$vite_state" = "running" ] && vite_d="$dot_running" || vite_d="$dot_stopped"

        line2_left=$(printf ' \033[38;5;245m%s\033[0m  %s \033[38;5;245mapp\033[0m  %s \033[38;5;245mvite\033[0m' "${docker_prefix}" "$app_d" "$vite_d")

        if [ -n "$queue_state" ]; then
            [ "$queue_state" = "running" ] && q_d="$dot_running" || q_d="$dot_stopped"
            # Queue job count inline
            q_count=""
            if command -v docker &>/dev/null; then
                q_count=$(docker exec street-redis-1 redis-cli llen queues:default 2>/dev/null)
                q_count=${q_count:-0}
            fi
            if [ -n "$q_count" ]; then
                if [ "$q_count" -ge 100 ] 2>/dev/null; then
                    q_label=$(printf '\033[38;5;167m(%s jobs)\033[0m' "$q_count")
                elif [ "$q_count" -ge 10 ] 2>/dev/null; then
                    q_label=$(printf '\033[38;5;179m(%s jobs)\033[0m' "$q_count")
                else
                    q_label=$(printf '\033[38;5;245m(%s jobs)\033[0m' "$q_count")
                fi
                line2_left=$(printf '%s  %s \033[38;5;245mqueue\033[0m %s' "$line2_left" "$q_d" "$q_label")
            else
                line2_left=$(printf '%s  %s \033[38;5;245mqueue\033[0m' "$line2_left" "$q_d")
            fi
        fi
    fi
fi

if command -v docker &>/dev/null; then
    printf '\n'
    print_line "$line2_left" ""
fi

# =====================================================================
# LINE 3: Claude info — model, ctx bar, 5h bar, 7d bar, cost
# =====================================================================
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

line3_left=""

if [ -n "$model_name" ]; then
    line3_left=$(printf ' \033[38;5;179m%s\033[0m' "$model_name")
fi

if [ -n "$used" ]; then
    ctx_bar=$(build_bar "$used" 12)
    ctx_pct=$(printf "%.0f%%" "$used")
    ctx_colour=$(pct_colour "$used")
    line3_left=$(printf '%s  %sctx:%s %s\033[0m' "$line3_left" "$ctx_colour" "$ctx_bar" "$ctx_pct")
fi

if [ -n "$five_pct" ]; then
    five_bar=$(build_bar "$five_pct" 8)
    five_fmt=$(printf '%.0f%%' "$five_pct")
    five_col=$(pct_colour "$five_pct")
    line3_left=$(printf '%s  %s5h:%s %s\033[0m' "$line3_left" "$five_col" "$five_bar" "$five_fmt")
fi

if [ -n "$week_pct" ]; then
    week_bar=$(build_bar "$week_pct" 8)
    week_fmt=$(printf '%.0f%%' "$week_pct")
    week_col=$(pct_colour "$week_pct")
    line3_left=$(printf '%s  %s7d:%s %s\033[0m' "$line3_left" "$week_col" "$week_bar" "$week_fmt")
fi

# Session cost (right-aligned)
line3_right=""
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
if [ "$total_in" -gt 0 ] || [ "$total_out" -gt 0 ]; then
    last_in=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
    last_cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
    last_cache_write=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')

    cost=$(echo "scale=6;
        in_toks = $total_in;
        out_toks = $total_out;
        last_total_in = $last_in + $last_cache_read + $last_cache_write;
        if (last_total_in > 0) {
            cache_read_ratio = $last_cache_read / last_total_in;
            cache_write_ratio = $last_cache_write / last_total_in;
        } else {
            cache_read_ratio = 0;
            cache_write_ratio = 0;
        };
        regular_in_ratio = 1 - cache_read_ratio - cache_write_ratio;
        if (regular_in_ratio < 0) regular_in_ratio = 0;
        input_cost  = in_toks * (regular_in_ratio * 15.00 + cache_read_ratio * 1.50 + cache_write_ratio * 18.75) / 1000000;
        output_cost = out_toks * 75.00 / 1000000;
        input_cost + output_cost" | bc)

    cost_str=$(echo "$cost" | awk '{
        if ($1 < 0.01) printf "~$0.00"
        else if ($1 < 1.00) printf "~$%.3f", $1
        else printf "~$%.2f", $1
    }')
    line3_right=$(printf '\033[38;5;108m%s\033[0m' "$cost_str")
fi

if [ -n "$line3_left" ]; then
    printf '\n'
    print_line "$line3_left" "$line3_right"
fi
