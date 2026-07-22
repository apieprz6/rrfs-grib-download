# RRFS GRIB Download

Scripts for downloading RRFS (Rapid Refresh Forecast System) weather data from the NOAA S3 bucket, filtered and cropped to the Lake Michigan region.

## Scripts

### `download_rrfs_lake_michigan.sh`

Downloads the full forecast from the latest complete **main cycle** (00z, 06z, 12z, 18z):

- **f000**: Analysis hour (regular product)
- **f001-f018**: Sub-hourly (15-minute resolution, 72 time steps)
- **f019-f084**: Hourly (66 time steps)

### `download_rrfs_hourly_lake_michigan.sh`

Downloads a shorter forecast from the latest complete cycle (any 3-hourly cycle):

- **f000**: Analysis hour (regular product)
- **f001-f018**: Sub-hourly (15-minute resolution, 72 time steps)

### Variables downloaded

| Variable | Description |
|----------|-------------|
| UGRD 10m | U-component of wind at 10m above ground |
| VGRD 10m | V-component of wind at 10m above ground |
| GUST | Wind gust at surface |
| MSLET | Mean sea level pressure (Eta reduction) |
| APCP | Accumulated precipitation at surface |

### Region

Lake Michigan bounding box:
- Latitude: 41.6N - 46.1N
- Longitude: 85W - 88W

## Dependencies

- **wgrib2** - GRIB2 file manipulation (see installation below)
- **AWS CLI** - for checking S3 bucket availability (`aws s3 ls --no-sign-request`)
- **curl** - for byte-range HTTP downloads

Install AWS CLI and curl via Homebrew:

```bash
brew install awscli curl
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

# Short 18-hour forecast (any 3-hourly cycle, more frequent updates)
./download_rrfs_hourly_lake_michigan.sh
```

Output files are written to `./output/` with naming like:

```
output/rrfs_lake_michigan_20260722_12z.grib2
output/rrfs_hourly_lake_michigan_20260722_15z.grib2
```

The scripts:
1. Find the latest complete forecast cycle on the NOAA S3 bucket
2. Download only the matching variable byte ranges (not full files) using index files
3. Crop each forecast hour to the Lake Michigan bounding box
4. Merge all hours into a single output GRIB2 file

Downloads run with up to 20 parallel jobs for speed.

## Inspecting output

```bash
# List all messages in the output file
wgrib2 output/rrfs_lake_michigan_*.grib2

# Extract a CSV of wind gust values
wgrib2 output/rrfs_lake_michigan_*.grib2 -match ':GUST:' -csv gust.csv
```
