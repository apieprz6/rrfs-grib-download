# RRFS GRIB Download

Scripts for downloading RRFS (Rapid Refresh Forecast System) weather data from NOAA NOMADS, filtered and cropped to a regional bounding box. There are two pairs of scripts: one for Lake Michigan and one for the Annapolis, MD race area on the Chesapeake Bay.

## Data source

Data comes from NOMADS at `https://nomads.ncep.noaa.gov/pub/data/nccf/com/rrfs`, using the `2dfld` product on the 3 km CONUS grid.

RRFS is still in parallel testing, so the scripts pick the directory by date: `para` before **2026-10-06** and `v1.0` (the operational path) from that date onward. Adjust the cutover date at the top of each script if NOAA's schedule shifts.

## Scripts

### `download_rrfs_lake_michigan.sh`

Downloads the full forecast from the latest complete **main cycle** (00z, 06z, 12z, 18z):

- **f000**: Analysis hour (regular product)
- **f001-f018**: Sub-hourly (15-minute resolution, 72 time steps)
- **f019-f084**: Hourly (66 time steps)

### `download_rrfs_hourly_lake_michigan.sh`

Downloads a shorter forecast from the latest complete cycle. RRFS runs hourly, so this picks up **any** cycle hour, not just the main four — it updates far more often than the full script.

- **f001-f018**: Sub-hourly (15-minute resolution, 72 time steps)

Note this script does *not* include f000; it starts at f001.

### `download_rrfs_annapolis.sh` / `download_rrfs_hourly_annapolis.sh`

Identical to the two Lake Michigan scripts above (same cycles, forecast hours, and variables), but cropped to the Annapolis race area instead.

### Variables downloaded

| Variable | Description |
|----------|-------------|
| UGRD 10m | U-component of wind at 10m above ground |
| VGRD 10m | V-component of wind at 10m above ground |
| GUST | Wind gust at surface |
| MSLET | Mean sea level pressure (Eta reduction) |
| APCP | Accumulated precipitation at surface |

Two APCP caveats when counting messages: the regular (non-subhourly) files carry **two** APCP records per forecast hour — a 1-hour bucket and a run-total — while f000 carries **none**, since nothing has accumulated at analysis time.

### Regions

Lake Michigan bounding box:
- Latitude: 41.6N - 46.1N
- Longitude: 85W - 88W

Annapolis race area bounding box:
- Latitude: 38.6N - 39.1N
- Longitude: 76.15W - 76.65W

The Annapolis box covers the Annapolis Yacht Club Bay Circle (off the mouth of the Severn River), the Inside Circle off Chesapeake Harbor, and every CBYRA Region 3 government mark used for the Bay course (marks K through D, roughly 38.75N-38.99N and 76.32W-76.47W). It is padded about 10 km on each side. The crop comes out to an 18 x 22 grid.

## Dependencies

- **wgrib2** - GRIB2 file manipulation (see installation below)
- **curl** - for byte-range HTTP downloads

These are the only two the scripts check for. No AWS CLI is needed — the scripts read from NOMADS over plain HTTP.

curl ships with macOS. If you want a newer build:

```bash
brew install curl
```

## Installing wgrib2 on macOS (Apple Silicon)

wgrib2 must be compiled from source on macOS. The following instructions have been tested on Apple Silicon (M-series) Macs with GCC 16 and CMake 4.x.

### 1. Install build dependencies

```bash
brew install gcc cmake
```

### 2. Check your GCC version

```bash
ls /opt/homebrew/bin/gcc-*
```

Note the version number (e.g., `14`, `15`, `16`).

### 3. Download and extract wgrib2

```bash
wget https://www.ftp.cpc.ncep.noaa.gov/wd51we/wgrib2/wgrib2.tgz
tar -xzf wgrib2.tgz
cd grib2
```

### 4. Apply makefile fixes for modern toolchains

GCC 16+ defaults to the C23 standard which breaks old C code. Add `-std=gnu17` to CPPFLAGS in the makefile. Find the `CPPFLAGS` line (around line 400-500) and prepend the flag:

```
CPPFLAGS=" -std=gnu17 ...existing flags..."
```

CMake 4.x rejects the old `cmake_minimum_required` in the bundled openjpeg. Find the openjpeg cmake command in the makefile (around line 984) and add `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`:

```
cd ${openjpegdir}/build && cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ...rest of flags...
```

The openjpeg build also fails linking the optional CLI tools against libtiff. Add `-DBUILD_CODEC=OFF` to the same cmake line to skip them (wgrib2 only needs the static library):

```
cd ${openjpegdir}/build && cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_CODEC=OFF ...rest of flags...
```

### 5. Build

```bash
export CC=gcc-16    # match your installed version
export FC=gfortran-16
make
```

The build takes several minutes. Warnings are expected from the older bundled libraries.

### 6. Install the binary

```bash
sudo cp wgrib2/wgrib2 /opt/homebrew/bin/
```

Or for Intel Macs:

```bash
sudo cp wgrib2/wgrib2 /usr/local/bin/
```

### 7. Verify

```bash
wgrib2 --version
```

## Usage

```bash
# Full 84-hour forecast (main cycles only)
./download_rrfs_lake_michigan.sh

# Short 18-hour forecast (any hourly cycle, more frequent updates)
./download_rrfs_hourly_lake_michigan.sh

# Same two, for the Annapolis race area
./download_rrfs_annapolis.sh
./download_rrfs_hourly_annapolis.sh
```

Output files are written to `./output/` with naming like:

```
output/rrfs_lake_michigan_20260722_12z.grib2
output/rrfs_hourly_lake_michigan_20260722_15z.grib2
output/rrfs_annapolis_20261008_12z.grib2
output/rrfs_hourly_annapolis_20261008_15z.grib2
```

The scripts:
1. Find the latest complete forecast cycle on NOMADS
2. Read each forecast hour's `.idx` file to locate the byte ranges for the variables above
3. Fetch all of those ranges in a **single** multi-range HTTP request per forecast hour
4. Crop each forecast hour to the region's bounding box
5. Merge all hours into a single output GRIB2 file

Step 3 matters for staying under NOMADS' rate limits. NOMADS' Apache honors multi-range requests and answers with `multipart/byteranges`; wgrib2 scans for the `GRIB` magic bytes, so it skips the MIME boundaries and the response can be handed to it as-is. That makes a run cost two requests per forecast hour (one `.idx`, one data) instead of one request per variable — 36 requests for the hourly script and 170 for the full one.

Downloads run with 4 parallel jobs. Higher parallelism gains little now that each hour is only two requests, and it risks tripping NOMADS' throttle.

### If a run fails

NOMADS throttles clients that request too aggressively, and a throttled response can arrive as an HTTP 200 with an empty body. The scripts guard against this: every fetch has timeouts and retries with backoff, idx bodies are validated before use, and each download is checked for the number of GRIB messages the idx asked for.

If forecast hours still fail, the script says so rather than exiting quietly, and reports the count it actually merged:

```
WARNING: only 82 of 85 forecast hours succeeded.
         Output will have gaps. Re-run to fill them.
```

A completed run prints `85 of 85 forecast hours`. Check that line — output with gaps is still a valid GRIB2 file and will not otherwise announce itself. If you see a shortfall, delete the output file and re-run.

## Inspecting output

Pass one file at a time. wgrib2 takes a single input file and aborts with `FATAL ERROR: too many grib files` if a glob expands to more than one, which it will as soon as `output/` holds a second run:

```bash
F=output/rrfs_lake_michigan_20260904_12z.grib2

# List all messages in the output file
wgrib2 "$F"

# Extract a CSV of wind gust values
wgrib2 "$F" -match ':GUST:' -csv gust.csv

# Confirm the file is complete: 760 for the full script, 360 for the hourly one
wgrib2 "$F" | grep -c ':d='

# Per-variable breakdown (full script: 139 each of GUST/MSLET/UGRD/VGRD, 204 APCP)
wgrib2 "$F" | awk -F: '{print $4}' | sort | uniq -c

# Verify the crop actually applied -- expect Lambert Conformal 100 x 176 (Annapolis: 18 x 22)
wgrib2 -grid "$F" | head -3
```
