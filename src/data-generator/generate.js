#!/usr/bin/env node

/**
 * Data Generator for Azure Blob Storage Replication Testing
 * Generates massive amounts of text or binary data using simple duplication algorithms
 */

import { createWriteStream } from 'fs';
import { mkdir } from 'fs/promises';
import { dirname } from 'path';
import { pipeline } from 'stream/promises';
import { Readable } from 'stream';
import { program } from 'commander';

// Parse size strings like "100MB", "1GB", "500KB"
function parseSize(sizeStr) {
  const match = sizeStr.match(/^(\d+(?:\.\d+)?)\s*(B|KB|MB|GB|TB)?$/i);
  if (!match) {
    throw new Error(`Invalid size format: ${sizeStr}. Use format like: 100MB, 1GB, 500KB`);
  }

  const value = parseFloat(match[1]);
  const unit = (match[2] || 'B').toUpperCase();

  const multipliers = {
    B: 1,
    KB: 1024,
    MB: 1024 * 1024,
    GB: 1024 * 1024 * 1024,
    TB: 1024 * 1024 * 1024 * 1024,
  };

  return Math.floor(value * multipliers[unit]);
}

// Format bytes to human-readable format
function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`;
}

// Text data generator using string duplication
class TextDataGenerator extends Readable {
  constructor(targetSize, options = {}) {
    super(options);
    this.targetSize = targetSize;
    this.generated = 0;
    
    // Base pattern to duplicate
    this.basePattern = options.pattern || 
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' +
      'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ' +
      'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris. ' +
      'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum. ' +
      'Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia. ';
    
    // Add newline for better text formatting
    this.basePattern += '\n';
    
    // Create a larger chunk by duplicating the pattern multiple times
    this.chunkSize = options.chunkSize || 64 * 1024; // 64KB chunks
    const repetitions = Math.ceil(this.chunkSize / this.basePattern.length);
    this.chunk = this.basePattern.repeat(repetitions).slice(0, this.chunkSize);
  }

  _read() {
    if (this.generated >= this.targetSize) {
      this.push(null); // Signal end of stream
      return;
    }

    const remaining = this.targetSize - this.generated;
    const toWrite = Math.min(remaining, this.chunk.length);
    const data = this.chunk.slice(0, toWrite);
    
    this.generated += data.length;
    this.push(data);
  }
}

// Binary data generator using buffer duplication
class BinaryDataGenerator extends Readable {
  constructor(targetSize, options = {}) {
    super(options);
    this.targetSize = targetSize;
    this.generated = 0;
    
    // Create a base pattern of bytes
    this.chunkSize = options.chunkSize || 64 * 1024; // 64KB chunks
    this.chunk = this.createBinaryPattern(this.chunkSize, options.pattern);
  }

  createBinaryPattern(size, pattern) {
    const buffer = Buffer.allocUnsafe(size);
    
    if (pattern === 'random') {
      // Fill with pseudo-random data (fast)
      for (let i = 0; i < size; i++) {
        buffer[i] = Math.floor(Math.random() * 256);
      }
    } else if (pattern === 'zeros') {
      buffer.fill(0);
    } else if (pattern === 'ones') {
      buffer.fill(255);
    } else {
      // Default: repeating sequence
      const sequence = Buffer.from([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);
      for (let i = 0; i < size; i++) {
        buffer[i] = sequence[i % sequence.length];
      }
    }
    
    return buffer;
  }

  _read() {
    if (this.generated >= this.targetSize) {
      this.push(null); // Signal end of stream
      return;
    }

    const remaining = this.targetSize - this.generated;
    const toWrite = Math.min(remaining, this.chunk.length);
    const data = this.chunk.slice(0, toWrite);
    
    this.generated += data.length;
    this.push(data);
  }
}

// Main generation function
async function generateData(type, size, output, options = {}) {
  const startTime = Date.now();
  const targetBytes = parseSize(size);
  
  console.log(`📊 Data Generation Started`);
  console.log(`   Type: ${type}`);
  console.log(`   Target Size: ${formatBytes(targetBytes)}`);
  console.log(`   Output: ${output}`);
  console.log('');

  // Ensure output directory exists
  await mkdir(dirname(output), { recursive: true });

  // Create appropriate generator
  let generator;
  if (type === 'text') {
    generator = new TextDataGenerator(targetBytes, {
      pattern: options.pattern,
      chunkSize: options.chunkSize,
    });
  } else if (type === 'binary') {
    generator = new BinaryDataGenerator(targetBytes, {
      pattern: options.binaryPattern,
      chunkSize: options.chunkSize,
    });
  } else {
    throw new Error(`Unknown type: ${type}. Use 'text' or 'binary'`);
  }

  // Progress tracking
  let lastProgress = 0;
  let bytesWritten = 0;
  
  generator.on('data', (chunk) => {
    bytesWritten += chunk.length;
    const progress = Math.floor((bytesWritten / targetBytes) * 100);
    
    if (progress >= lastProgress + 10 || bytesWritten === targetBytes) {
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
      const speed = formatBytes(bytesWritten / (Date.now() - startTime) * 1000);
      process.stdout.write(`   Progress: ${progress}% (${formatBytes(bytesWritten)} / ${formatBytes(targetBytes)}) - ${speed}/s\r`);
      lastProgress = progress;
    }
  });

  // Write to file using streaming pipeline
  const writeStream = createWriteStream(output);
  await pipeline(generator, writeStream);

  const duration = ((Date.now() - startTime) / 1000).toFixed(2);
  const avgSpeed = formatBytes(targetBytes / (Date.now() - startTime) * 1000);
  
  console.log('');
  console.log('');
  console.log(`✅ Generation Complete!`);
  console.log(`   File: ${output}`);
  console.log(`   Size: ${formatBytes(targetBytes)}`);
  console.log(`   Duration: ${duration}s`);
  console.log(`   Avg Speed: ${avgSpeed}/s`);
}

// CLI Setup
program
  .name('generate')
  .description('Generate massive amounts of text or binary data for Azure Storage testing')
  .version('1.0.0');

program
  .requiredOption('-t, --type <type>', 'Data type: text or binary')
  .requiredOption('-s, --size <size>', 'Target size (e.g., 100MB, 1GB, 500KB)')
  .requiredOption('-o, --output <path>', 'Output file path')
  .option('-p, --pattern <text>', 'Custom text pattern to repeat (text mode only)')
  .option('-b, --binary-pattern <type>', 'Binary pattern: sequence (default), random, zeros, ones', 'sequence')
  .option('-c, --chunk-size <size>', 'Chunk size for streaming (default: 64KB)', '64KB')
  .action(async (options) => {
    try {
      const chunkSize = parseSize(options.chunkSize);
      
      await generateData(
        options.type,
        options.size,
        options.output,
        {
          pattern: options.pattern,
          binaryPattern: options.binaryPattern,
          chunkSize: chunkSize,
        }
      );
    } catch (error) {
      console.error(`❌ Error: ${error.message}`);
      process.exit(1);
    }
  });

program.parse();
