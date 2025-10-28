# Data Generator

High-performance data generator for Azure Blob Storage replication testing. Generates massive amounts of text or binary data using efficient streaming and simple duplication algorithms.

## Features

- ✅ **Text Generation**: Repeating text patterns for readable test data
- ✅ **Binary Generation**: Various binary patterns (sequence, random, zeros, ones)
- ✅ **Streaming**: Memory-efficient streaming for files of any size
- ✅ **Fast**: Generates GB of data in seconds
- ✅ **Progress Tracking**: Real-time progress and speed indicators
- ✅ **Flexible Sizing**: Support for B, KB, MB, GB, TB
- ✅ **Bulk Upload**: Automated script for generating and uploading multiple files

## Installation

```bash
cd src/data-generator
npm install
```

## Usage

### Basic Examples

Generate a 100MB text file:
```bash
node generate.js --type text --size 100MB --output data/test-100mb.txt
```

Generate a 1GB binary file:
```bash
node generate.js --type binary --size 1GB --output data/test-1gb.bin
```

Generate a 500KB text file:
```bash
node generate.js --type text --size 500KB --output test-small.txt
```

### Text Generation Options

**Custom Pattern:**
```bash
node generate.js \
  --type text \
  --size 10MB \
  --output custom.txt \
  --pattern "My custom repeating text. "
```

**Custom Chunk Size:**
```bash
node generate.js \
  --type text \
  --size 100MB \
  --output data.txt \
  --chunk-size 128KB
```

### Binary Generation Options

**Sequential Pattern (default):**
```bash
node generate.js --type binary --size 100MB --output data.bin
```

**Random Binary Data:**
```bash
node generate.js \
  --type binary \
  --size 100MB \
  --output random.bin \
  --binary-pattern random
```

**All Zeros:**
```bash
node generate.js \
  --type binary \
  --size 100MB \
  --output zeros.bin \
  --binary-pattern zeros
```

**All Ones (0xFF):**
```bash
node generate.js \
  --type binary \
  --size 100MB \
  --output ones.bin \
  --binary-pattern ones
```

## Command-Line Options

| Option | Alias | Description | Required |
|--------|-------|-------------|----------|
| `--type` | `-t` | Data type: `text` or `binary` | Yes |
| `--size` | `-s` | Target size (e.g., 100MB, 1GB) | Yes |
| `--output` | `-o` | Output file path | Yes |
| `--pattern` | `-p` | Custom text pattern (text mode only) | No |
| `--binary-pattern` | `-b` | Binary pattern: `sequence`, `random`, `zeros`, `ones` | No |
| `--chunk-size` | `-c` | Streaming chunk size (default: 64KB) | No |

## Size Format

Supports various size units:
- `B` - Bytes
- `KB` - Kilobytes (1024 bytes)
- `MB` - Megabytes (1024 KB)
- `GB` - Gigabytes (1024 MB)
- `TB` - Terabytes (1024 GB)

Examples: `500B`, `10KB`, `100MB`, `1.5GB`, `2TB`

## Performance

Typical generation speeds (will vary by system):
- **Text Data**: 200-500 MB/s
- **Binary Sequential**: 300-600 MB/s
- **Binary Random**: 100-200 MB/s (slower due to randomization)
- **Binary Zeros/Ones**: 400-800 MB/s (fastest)

Memory usage is minimal (~64KB buffer) regardless of file size thanks to streaming.

## How It Works

### Text Generation
1. Creates a base text pattern (Lorem ipsum by default)
2. Duplicates the pattern to create larger chunks
3. Streams chunks to file until target size is reached
4. Memory efficient: only holds one chunk in memory at a time

### Binary Generation
1. Creates a binary pattern based on selected type
2. Duplicates the pattern into fixed-size chunks
3. Streams chunks to file until target size is reached
4. Memory efficient: only holds one chunk in memory at a time

## Examples

### Generate Test Suite

```bash
# Create output directory
mkdir -p data

# Small files for quick tests
node generate.js -t text -s 1MB -o data/test-1mb.txt
node generate.js -t binary -s 1MB -o data/test-1mb.bin

# Medium files for standard tests
node generate.js -t text -s 100MB -o data/test-100mb.txt
node generate.js -t binary -s 100MB -o data/test-100mb.bin

# Large files for stress tests
node generate.js -t text -s 1GB -o data/test-1gb.txt
node generate.js -t binary -s 1GB -o data/test-1gb.bin
```

### Generate with Custom Patterns

```bash
# Realistic log-like data
node generate.js \
  -t text \
  -s 50MB \
  -o logs.txt \
  -p "2025-10-27 12:00:00 INFO Application started successfully\n"

# Test compression behavior
node generate.js -t binary -s 100MB -o compressible.bin -b zeros
node generate.js -t binary -s 100MB -o incompressible.bin -b random
```

## Integration with Azure

### Single File Upload

After generating data, you can upload to Azure Blob Storage:

```bash
# Generate data
node generate.js -t text -s 100MB -o test-data.txt

# Upload using Azure CLI (after sourcing deployment-outputs.env)
source ../../infra/deployment-outputs.env
az storage blob upload \
  --account-name $AZURE_STORAGE_ACCOUNT \
  --container-name data-grav \
  --name test-data.txt \
  --file test-data.txt \
  --auth-mode key
```

### Bulk Upload (Automated)

For stress testing and large-scale uploads, use the **bulk upload script** that automatically generates, uploads, and cleans up files in a loop:

```bash
# Default: 100 files × 1GB each with alphanumeric pattern
./bulk-upload.sh

# Custom configuration
NUM_FILES=50 FILE_SIZE=500MB PATTERN="CustomPattern" ./bulk-upload.sh

# Small test run
NUM_FILES=5 FILE_SIZE=10MB ./bulk-upload.sh

# Your original requirement: 100 files × 1GB with pattern 'ABCDEF'
NUM_FILES=100 FILE_SIZE=1GB PATTERN='ABCDEF' ./bulk-upload.sh
```

**Configuration Options (via environment variables):**

| Variable | Default | Description |
|----------|---------|-------------|
| `NUM_FILES` | `100` | Number of files to generate and upload |
| `FILE_SIZE` | `1GB` | Size of each file (KB, MB, GB, TB) |
| `PATTERN` | `ABCD...0123456789` | Text pattern to repeat |
| `CONTAINER` | `data-grav` | Azure Blob Storage container |
| `PREFIX` | `test-data` | Filename prefix (creates PREFIX-0001.txt, etc.) |
| `KEEP_LOCAL` | `false` | Keep local files after upload (true/false) |

**Features:**
- Automatically generates, uploads, and deletes files in a loop
- Real-time progress tracking with statistics
- Smart cleanup (local files deleted after upload by default)
- Error handling and verification
- Shows total duration and average time per file

## Troubleshooting

**Issue**: Out of memory errors
- **Solution**: Reduce `--chunk-size` to use less memory (e.g., `--chunk-size 32KB`)

**Issue**: Slow generation speed
- **Solution**: Use `zeros` or `ones` pattern for binary data, or increase chunk size

**Issue**: Permission denied
- **Solution**: Ensure you have write permissions to the output directory

**Issue**: Invalid size format
- **Solution**: Use format like `100MB`, `1GB`, etc. (no spaces between number and unit)

## Development

Run in development:
```bash
npm start -- --type text --size 10MB --output test.txt
```

Make executable:
```bash
chmod +x generate.js
./generate.js --type text --size 10MB --output test.txt
```

## Notes

- Generation is CPU-bound for random patterns, I/O-bound for sequential patterns
- Large files (>10GB) may take several minutes depending on disk speed
- Generated data is deterministic (same input = same output) except for random pattern
- Files are created immediately and filled with data (no sparse files)

## See Also

- [Replication Monitor](../replication-monitor/README.md) - Monitor data replication
- [Infrastructure Deployment](../../infra/README.md) - Deploy Azure resources
- [Examples Script](examples.sh) - Run example generations
