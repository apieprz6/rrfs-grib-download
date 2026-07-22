#!/usr/bin/env bash
set -euo pipefail

BUCKET="noaa-rrfs-pds"
PREFIX="rrfs_a"
PRODUCT="2dfld"
DOMAIN="conus"
RESOLUTION="3km"

# Lake Michigan bounding box (lon must be 0-360 for wgrib2 -small_grib)
LON_W=$((360 - 88))   # 87.8W ~ 272
LON_E=$((360 - 85))   # 85.5W ~ 275
LAT_S="41.6"
LAT_N="46.1"

IDX_MATCH=":(UGRD:10 m above ground|VGRD:10 m above ground|GUST:surface|MSLET:mean sea level|APCP:surface):"

HTTPS_BASE="https://${BUCKET}.s3.amazonaws.com"
MAX_PARALLEL=20

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
for cmd in wgrib2 aws curl; do
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
    cycle_int=$((10#$check_hour))

    # Only check valid cycle hours (multiples of 3)
    if (( cycle_int % 3 != 0 )); then
        continue
    fi

    # Check that subhour f018 exists
    subh_final="${PREFIX}/rrfs.${check_date}/${check_hour}/rrfs.t${check_hour}z.${PRODUCT}.${RESOLUTION}.subh.f$(printf '%03d' $SUBH_MAX_HOUR).${DOMAIN}.grib2"

    echo "  Checking cycle ${check_date}/${check_hour}z..."

    if aws s3 ls "s3://${BUCKET}/${subh_final}" --no-sign-request &>/dev/null; then
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
output_file="${OUTDIR}/rrfs_hourly_lake_michigan_${found_date}_${found_hour}z.grib2"

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

idx_url="\${file_url}.idx"
local_raw="\${TMPDIR_BASE}/raw_\${out_prefix}.grib2"
local_filtered="\${TMPDIR_BASE}/filt_\${out_prefix}.grib2"

# Fetch the idx file
idx_content=\$(curl -sf "\$idx_url") || { echo "  WARNING: Failed to fetch idx for \${out_prefix}" >&2; exit 1; }

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

# Download each byte range and concatenate
> "\$local_raw"
for r in "\${offsets[@]}"; do
    if ! curl -sf -H "Range: bytes=\${r}" "\$file_url" >> "\$local_raw"; then
        echo "  WARNING: Failed to download range \${r} for \${out_prefix}" >&2
        rm -f "\$local_raw"
        exit 1
    fi
done

# Crop to Lake Michigan bounding box
if ! wgrib2 "\$local_raw" -small_grib "\${LON_W}:\${LON_E}" "\${LAT_S}:\${LAT_N}" "\$local_filtered" >/dev/null 2>&1; then
    echo "  WARNING: wgrib2 crop failed on \${out_prefix}" >&2
    rm -f "\$local_raw"
    exit 1
fi

rm -f "\$local_raw"
WORKER_EOF
chmod +x "$WORKER"

echo "Downloading and processing..."
echo "  Phase 1: f000 (regular hourly)"
echo "  Phase 2: f001-f018 (subhour, 15-min resolution)"
echo "  Using byte-range downloads with ${MAX_PARALLEL} parallel jobs..."

# Phase 1: f000 from regular product
file_url="${HTTPS_BASE}/${PREFIX}/rrfs.${found_date}/${found_hour}/rrfs.t${found_hour}z.${PRODUCT}.${RESOLUTION}.f000.${DOMAIN}.grib2"
"$WORKER" "$file_url" "000_reg_f000"

# Phase 2: f001-f018 from subhour product (parallel)
for i in $(seq 1 "$SUBH_MAX_HOUR"); do
    fhr_str=$(printf "f%03d" "$i")
    seq_num=$(printf "%03d" "$i")
    file_url="${HTTPS_BASE}/${PREFIX}/rrfs.${found_date}/${found_hour}/rrfs.t${found_hour}z.${PRODUCT}.${RESOLUTION}.subh.${fhr_str}.${DOMAIN}.grib2"
    echo "${file_url} ${seq_num}_subh_${fhr_str}"
done | xargs -P "$MAX_PARALLEL" -L1 "$WORKER"

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

# Sort to ensure proper ordering (000_reg_f000, 001_subh_f001..018_subh_f018)
IFS=$'\n' sorted_files=($(printf '%s\n' "${filtered_files[@]}" | sort)); unset IFS

cat "${sorted_files[@]}" > "$output_file"

echo "Done. Output: ${output_file}"
echo "  Cycle: ${found_date} ${found_hour}z"
echo "  Subhour (15-min): f001-f018 (72 time steps)"
echo "  Hourly: f000 (1 time step)"
echo "  Variables: UGRD 10m, VGRD 10m, GUST, MSLET, APCP"
echo "  Region: Lake Michigan (${LAT_S}-${LAT_N}N, $((360 - LON_E))-$((360 - LON_W))W)"
