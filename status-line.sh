#!/bin/bash
data=$(cat)
eval "$(echo "$data" | jq -r '@sh "mdl=\(.model.display_name // "unknown") ctx=\(.context_window.used_percentage // 0) ctx_size=\(.context_window.context_window_size // 0) ctx_used=\((.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.cache_read_input_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0) + (.context_window.current_usage.output_tokens // 0)) cost=\(.cost.total_cost_usd // 0) dur_ms=\(.cost.total_duration_ms // 0) in_t=\(.context_window.total_input_tokens // 0) out_t=\(.context_window.total_output_tokens // 0) cache_t=\(.context_window.current_usage.cache_read_input_tokens // 0) rl5=\((.rate_limits.five_hour.used_percentage // 0) | floor) rl5_reset=\(.rate_limits.five_hour.resets_at // 0) rl7=\((.rate_limits.seven_day.used_percentage // 0) | floor) rl7_reset=\(.rate_limits.seven_day.resets_at // 0) is_wt=\(if .worktree then "1" else "" end)"')"
effort=$(jq -r '.effortLevel // "medium"' ~/.claude/settings.json 2>/dev/null)
cwd=$(echo "$data" | jq -r '.cwd // ""')
repo=$(basename "$cwd")
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
[ "$branch" = "HEAD" ] && branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null || echo "")

# Worktree detection: JSON field or git worktree check
if [ -z "$is_wt" ]; then
  git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
  [[ "$git_dir" == *".git/worktrees/"* ]] && is_wt="1"
fi
# Git dirty check — color branch and worktree by status
dirty=$(git -C "$cwd" status --porcelain 2>/dev/null | head -1)
if [ -z "$dirty" ]; then bc="\033[36m"; else bc="\033[33m"; fi
wt_tag=""; [ -n "$is_wt" ] && wt_tag=" ${bc}⧉\033[0m"

ft(){ local t=$1; if [ "$t" -ge 1000000 ] 2>/dev/null; then printf "%.1fM" "$(echo "$t/1000000"|bc -l)"; elif [ "$t" -ge 1000 ] 2>/dev/null; then printf "%.1fK" "$(echo "$t/1000"|bc -l)"; else printf "%s" "$t"; fi; }

# Session duration
dur_s=$((dur_ms / 1000))
if [ "$dur_s" -ge 3600 ] 2>/dev/null; then dur_str=$(printf "%dh%dm" $((dur_s/3600)) $((dur_s%3600/60)))
elif [ "$dur_s" -ge 60 ] 2>/dev/null; then dur_str=$(printf "%dm%ds" $((dur_s/60)) $((dur_s%60)))
else dur_str=$(printf "%ds" "$dur_s"); fi

# Time until rate limit resets
now=$(date +%s)
fmt_reset(){ local rem=$(($1 - now)); if [ "$rem" -le 0 ] 2>/dev/null; then printf "now"
elif [ "$rem" -ge 86400 ] 2>/dev/null; then printf "%dd%dh" $((rem/86400)) $((rem%86400/3600))
elif [ "$rem" -ge 3600 ] 2>/dev/null; then printf "%dh%dm" $((rem/3600)) $((rem%3600/60))
else printf "%dm" $((rem/60)); fi; }
r5_str=$(fmt_reset "$rl5_reset")
r7_str=$(fmt_reset "$rl7_reset")

# Shared color: <50 green, 50-80 yellow, >80 orange
pcc(){ if [ "$1" -gt 80 ] 2>/dev/null; then printf "\033[38;5;208m"; elif [ "$1" -ge 50 ] 2>/dev/null; then printf "\033[33m"; else printf "\033[32m"; fi; }
ci=${ctx%%.*}
cc=$(pcc "$ci")
rc5=$(pcc "$rl5"); rc7=$(pcc "$rl7")

case "$effort" in
  high) ec="\033[35m";; low) ec="\033[34m";; *) ec="\033[32m";;
esac
r="\033[0m"; d="\033[2m"

# Build segments
if [ -n "$branch" ]; then
  seg1=$(printf "\033[1m%s${r}${d}/${r}${bc}%s${r}%b" "$repo" "$branch" "$wt_tag")
else
  seg1=$(printf "\033[1m%s${r}" "$repo")
fi
seg2=$(printf "${ec}%s${r}" "$mdl")
# Context progress bar (10 blocks)
filled=$(( (ci + 5) / 10 )); [ "$filled" -gt 10 ] && filled=10
bar=""; for i in $(seq 1 10); do
  if [ "$i" -le "$filled" ]; then bar="${bar}${cc}▰${r}"; else bar="${bar}${d}▱${r}"; fi
done
seg3=$(printf "%b ${cc}%s%%${r}${d} %s/%s${r}" "$bar" "$ci" "$(ft "$ctx_used")" "$(ft "$ctx_size")")
seg4=$(printf "${d}⇣${r}%s ${d}⇡${r}%s ${d}⟳${r}%s" "$(ft "$in_t")" "$(ft "$out_t")" "$(ft "$cache_t")")
r7_date=$(date -r "$rl7_reset" "+%b%d" 2>/dev/null || date -d "@$rl7_reset" "+%b%d" 2>/dev/null || echo "—")
seg5=$(printf "${d}⚡rate${r} ${rc5}%s%%${r}${d} 5h ~%s${r} ${rc7}%s%%${r}${d} 7d ~%s %s${r}" "$rl5" "$r5_str" "$rl7" "$r7_str" "$r7_date")
seg6=$(printf "${d}⧗ session${r} %s ${d}│ \$%.1f${r}" "$dur_str" "$cost")

sep="${d} │ ${r}"

printf "%b\n" "${seg1}"
printf "%b" "${seg2} ${seg3}${sep}${seg4}${sep}${seg5}${sep}${seg6}"
