#!/usr/bin/env bash
set -euo pipefail

NOMADS_BASE="https://nomads.ncep.noaa.gov/pub/data/nccf/com/rrfs"
if [[ $(date -u +%Y%m%d) -ge 20261006 ]]; then
    NOMADS_BASE="${NOMADS_BASE}/v1.0"
else
    NOMADS_BASE="${NOMADS_BASE}/para"
fi
PRODUCT="2dfld"
DOMAIN="conus"
RESOLUTION="3km"

# Annapolis race area bounding box (lon must be 0-360 for wgrib2 -small_grib)
# Covers the AYC Bay Circle (off the Severn River mouth), the Inside Circle off
# Chesapeake Harbor, and every Region 3 government mark in SI Attachment 3
# (K 38.75N to D 38.99N, F 76.32W to T/Y 76.47W), padded ~10 km so the 3 km
# grid has context around the course.
LON_W="283.35"   # 76.65W
LON_E="283.85"   # 76.15W
LAT_S="38.6"
LAT_N="39.1"

IDX_MATCH=":(UGRD:10 m above ground|VGRD:10 m above ground|GUST:surface|MSLET:mean sea level|APCP:surface):"

# NOMADS throttles aggressive clients. Each forecast hour costs exactly two
# requests (one .idx + one multi-range fetch), so a low parallelism is plenty.
MAX_PARALLEL=4

# Shared curl options: bounded waits so a throttled connection can never hang
# the script, plus retry with backoff for transient 5xx/reset responses.
CURL_OPTS=(--http1.1 -sf --connect-timeout 15 --max-time 600
           --retry 5 --retry-delay 3 --retry-all-errors)

OUTDIR="$(pwd)/output"
TMPDIR_BASE="${OUTDIR}/.rrfs_tmp_$$"

mkdir -p "$OUTDIR"

SUBH_MAX_HOUR=18

cleanup() {
    if [[ -d "$TMPDIR_BASE" ]]; then
        rm -rf "$TMPDIR_BASE"
    fi
}
trap cleanup EXIT

# --- Dependency checks ---
for cmd in wgrib2 curl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: '$cmd' is required but not found in PATH." >&2
        exit 1
    fi
done

# --- Determine latest complete cycle (any cycle hour) ---
echo "Searching for latest complete forecast cycle..."

now_utc=$(date -u +%s)
found_cycle=""
found_date=""
found_hour=""

for offset in $(seq 0 24); do
    check_time=$((now_utc - offset * 3600))
    check_date=$(date -u -r "$check_time" +%Y%m%d)
    check_hour=$(date -u -r "$check_time" +%H)

    # Check that subhour f018 exists via HTTP HEAD
    subh_final_url="${NOMADS_BASE}/rrfs.${check_date}/${check_hour}/rrfs.t${check_hour}z.${PRODUCT}.${RESOLUTION}.subh.f$(printf '%03d' $SUBH_MAX_HOUR).${DOMAIN}.grib2"

    echo "  Checking cycle ${check_date}/${check_hour}z..."

    if curl --http1.1 -sf --connect-timeout 15 --max-time 30 --head "$subh_final_url" &>/dev/null; then
        found_cycle="${check_date}/${check_hour}"
        found_date="$check_date"
        found_hour="$check_hour"
        echo "  Found complete cycle: ${found_cycle}z"
        break
    fi
done

if [[ -z "$found_cycle" ]]; then
    echo "ERROR: Could not find a complete forecast cycle in the last 24 hours." >&2
    exit 1
fi

# --- Download, filter, and crop ---
output_file="${OUTDIR}/rrfs_hourly_annapolis_${found_date}_${found_hour}z.grib2"

if [[ -f "$output_file" ]]; then
    echo "Output file already exists: ${output_file}"
    echo "Delete it first if you want to re-download."
    exit 0
fi

mkdir -p "$TMPDIR_BASE"

# Write worker script with config baked in to avoid environment size limits with xargs
WORKER="${TMPDIR_BASE}/worker.sh"
cat > "$WORKER" << WORKER_EOF
#!/usr/bin/env bash
set -euo pipefail

file_url="\$1"
out_prefix="\$2"

TMPDIR_BASE="${TMPDIR_BASE}"
IDX_MATCH="${IDX_MATCH}"
LON_W="${LON_W}"
LON_E="${LON_E}"
LAT_S="${LAT_S}"
LAT_N="${LAT_N}"
# KEEP IN SYNC with CURL_OPTS at the top of the parent script. Spelled out
# literally rather than interpolated: bash 3.2 (the macOS default) silently
# drops the quoting from \${array[@]@Q}.
CURL_OPTS=(--http1.1 -sf --connect-timeout 15 --max-time 600
           --retry 5 --retry-delay 3 --retry-all-errors)

idx_url="\${file_url}.idx"
local_raw="\${TMPDIR_BASE}/raw_\${out_prefix}.grib2"
local_filtered="\${TMPDIR_BASE}/filt_\${out_prefix}.grib2"

# Fetch the idx file. A throttled NOMADS can answer 200 with a truncated or
# empty body, which curl's own retry logic will not catch -- so validate that
# the payload actually parses as an idx and retry with backoff if it does not.
idx_content=""
for attempt in 1 2 3 4 5; do
    idx_content=\$(curl "\${CURL_OPTS[@]}" "\$idx_url" || true)
    if grep -qE '^[0-9]+:[0-9]+:d=' <<< "\$idx_content"; then
        break
    fi
    idx_content=""
    sleep \$((attempt * 3))
done

if [[ -z "\$idx_content" ]]; then
    echo "  WARNING: Failed to fetch a valid idx for \${out_prefix}" >&2
    exit 1
fi

# Parse idx to find byte ranges for our variables
prev_offset=""
prev_match=0
offsets=()

while IFS= read -r line; do
    offset=\$(echo "\$line" | cut -d: -f2)

    if (( prev_match )); then
        offsets+=("\${prev_offset}-\$((offset - 1))")
        prev_match=0
    fi

    if echo "\$line" | grep -qE "\$IDX_MATCH"; then
        prev_offset="\$offset"
        prev_match=1
    fi
done <<< "\$idx_content"

# Handle last matched message (extends to EOF)
if (( prev_match )); then
    offsets+=("\${prev_offset}-")
fi

if (( \${#offsets[@]} == 0 )); then
    echo "  WARNING: No matching variables in idx for \${out_prefix}" >&2
    exit 1
fi

# Fetch every range in ONE request. Apache answers with multipart/byteranges;
# wgrib2 scans for the GRIB magic and skips the MIME boundaries, so the body
# can be handed to it as-is. This is 1 request per forecast hour instead of one
# per variable -- the difference between ~380 and ~36 requests per run, which is
# what was tripping NOMADS' rate limiter.
range_header=\$(IFS=,; echo "\${offsets[*]}")

if ! curl "\${CURL_OPTS[@]}" -H "Range: bytes=\${range_header}" "\$file_url" -o "\$local_raw"; then
    echo "  WARNING: Failed to download ranges for \${out_prefix}" >&2
    rm -f "\$local_raw"
    exit 1
fi

# Guard against a throttled 200/206 that returns fewer messages than requested.
got=\$(wgrib2 "\$local_raw" 2>/dev/null | grep -c ':d=' || true)
if (( got != \${#offsets[@]} )); then
    echo "  WARNING: \${out_prefix} returned \${got} of \${#offsets[@]} messages" >&2
    rm -f "\$local_raw"
    exit 1
fi

# Crop to Annapolis race area bounding box
if ! wgrib2 "\$local_raw" -small_grib "\${LON_W}:\${LON_E}" "\${LAT_S}:\${LAT_N}" "\$local_filtered" >/dev/null 2>&1; then
    echo "  WARNING: wgrib2 crop failed on \${out_prefix}" >&2
    rm -f "\$local_raw"
    exit 1
fi

rm -f "\$local_raw"
WORKER_EOF
chmod +x "$WORKER"

echo "Downloading and processing..."
echo "  f001-f018 (subhour, 15-min resolution)"
echo "  Using byte-range downloads with ${MAX_PARALLEL} parallel jobs..."

# f001-f018 from subhour product (parallel)
for i in $(seq 1 "$SUBH_MAX_HOUR"); do
    fhr_str=$(printf "f%03d" "$i")
    seq_num=$(printf "%03d" "$i")
    file_url="${NOMADS_BASE}/rrfs.${found_date}/${found_hour}/rrfs.t${found_hour}z.${PRODUCT}.${RESOLUTION}.subh.${fhr_str}.${DOMAIN}.grib2"
    echo "${file_url} ${seq_num}_subh_${fhr_str}"
done | xargs -P "$MAX_PARALLEL" -L1 "$WORKER" || xargs_status=$?

# xargs exits 123 when any worker failed. Don't let `set -e` abort here -- report
# the shortfall below and still merge whatever did succeed.
if [[ -n "${xargs_status:-}" ]]; then
    echo "  NOTE: one or more forecast hours failed (see warnings above)."
fi

echo "  Downloads complete."

# --- Merge ---
echo "Merging filtered files..."

shopt -s nullglob
filtered_files=("${TMPDIR_BASE}"/filt_*.grib2)
shopt -u nullglob

if (( ${#filtered_files[@]} == 0 )); then
    echo "ERROR: No forecast hours were successfully processed." >&2
    exit 1
fi

if (( ${#filtered_files[@]} < SUBH_MAX_HOUR )); then
    echo "  WARNING: only ${#filtered_files[@]} of ${SUBH_MAX_HOUR} forecast hours succeeded." >&2
    echo "           Output will have gaps. Re-run to fill them." >&2
fi

# Sort to ensure proper ordering (001_subh_f001..018_subh_f018)
IFS=$'\n' sorted_files=($(printf '%s\n' "${filtered_files[@]}" | sort)); unset IFS

cat "${sorted_files[@]}" > "$output_file"

echo "Done. Output: ${output_file}"
echo "  Cycle: ${found_date} ${found_hour}z"
echo "  Subhour (15-min): ${#filtered_files[@]} of ${SUBH_MAX_HOUR} forecast hours ($(wgrib2 "$output_file" 2>/dev/null | grep -c ':d=' || echo '?') messages)"
echo "  Variables: UGRD 10m, VGRD 10m, GUST, MSLET, APCP"
echo "  Region: Annapolis race area (${LAT_S}-${LAT_N}N, 76.15-76.65W)"
