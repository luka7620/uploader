import fs from 'node:fs/promises';
import { watchFile, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function parseArgs(argv) {
  const result = {
    watch: false
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--watch') {
      result.watch = true;
      continue;
    }

    if (!arg.startsWith('--')) {
      continue;
    }

    const key = arg.slice(2);
    const value = argv[i + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`Missing value for ${arg}`);
    }

    result[key] = value;
    i += 1;
  }

  return result;
}

async function loadConfig(configPath) {
  if (!configPath || !existsSync(configPath)) {
    return {};
  }

  const raw = await fs.readFile(configPath, 'utf-8');
  return JSON.parse(raw.replace(/^\uFEFF/, ''));
}

function getDefaultConfigPath() {
  const scriptDirConfig = path.join(__dirname, 'upload.config.json');
  if (existsSync(scriptDirConfig)) {
    return scriptDirConfig;
  }

  return path.resolve('upload.config.json');
}

function resolveFromBase(baseDir, targetPath) {
  if (!targetPath) {
    return '';
  }

  if (path.isAbsolute(targetPath)) {
    return targetPath;
  }

  return path.resolve(baseDir, targetPath);
}

function getOption(args, config, argKey, envKey, configKey, fallback = '') {
  if (args[argKey] !== undefined) {
    return args[argKey];
  }
  if (process.env[envKey] !== undefined) {
    return process.env[envKey];
  }
  if (config[configKey] !== undefined) {
    return config[configKey];
  }
  return fallback;
}

function normalizeBaseUrl(input) {
  return input.replace(/\/+$/, '');
}

async function readFileBase64(filePath) {
  const buffer = await fs.readFile(filePath);
  return {
    base64: buffer.toString('base64'),
    bytes: buffer.length
  };
}

function parseInterval(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function formatError(error) {
  const message = error?.message || String(error);
  const cause = error?.cause;

  if (!cause) {
    return message;
  }

  const details = [
    cause.code,
    cause.address && cause.port ? `${cause.address}:${cause.port}` : '',
    cause.syscall
  ].filter(Boolean);

  return details.length > 0 ? `${message} (${details.join(' ')})` : message;
}

async function uploadOnce(options) {
  const payload = {};
  const summary = [];

  if (options.accountsPath) {
    const accounts = await readFileBase64(options.accountsPath);
    payload.accountsBase64 = accounts.base64;
    summary.push(`accounts=${accounts.bytes}B`);
  }

  if (options.logPath) {
    const log = await readFileBase64(options.logPath);
    payload.logBase64 = log.base64;
    summary.push(`log=${log.bytes}B`);
  }

  if (summary.length === 0) {
    throw new Error('No input files configured');
  }

  const response = await fetch(`${options.baseUrl}/api/upload/files`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-upload-token': options.token
    },
    body: JSON.stringify(payload)
  });

  const result = await response.json().catch(() => ({}));
  if (!response.ok || !result.success) {
    throw new Error(result.message || `Upload failed with status ${response.status}`);
  }

  console.log(`[upload] ok ${summary.join(' ')} -> ${options.baseUrl}`);
}

function createDebouncedUploader(options) {
  let timer = null;
  let running = false;
  let pending = false;

  const run = async () => {
    if (running) {
      pending = true;
      return;
    }

    running = true;
    try {
      await uploadOnce(options);
    } catch (error) {
      console.error(`[upload] failed: ${formatError(error)}`);
    } finally {
      running = false;
      if (pending) {
        pending = false;
        schedule();
      }
    }
  };

  const schedule = () => {
    clearTimeout(timer);
    timer = setTimeout(run, 800);
  };

  return schedule;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const defaultConfigPath = getDefaultConfigPath();
  const configPath = args.config ? path.resolve(args.config) : defaultConfigPath;
  const config = await loadConfig(configPath);
  const configBaseDir = existsSync(configPath) ? path.dirname(configPath) : process.cwd();

  const baseUrl = normalizeBaseUrl(
    getOption(args, config, 'url', 'UPLOAD_BASE_URL', 'url', '')
  );
  const token = getOption(args, config, 'token', 'UPLOAD_TOKEN', 'token', '');
  const accountsPath = resolveFromBase(
    configBaseDir,
    getOption(args, config, 'accounts', 'LOCAL_ACCOUNTS_FILE', 'accountsPath', 'data/accounts.txt')
  );
  const logPath = resolveFromBase(
    configBaseDir,
    getOption(args, config, 'log', 'LOCAL_LOG_FILE', 'logPath', 'data/log.txt')
  );
  const watchIntervalMs = parseInterval(
    getOption(args, config, 'interval', 'UPLOAD_WATCH_INTERVAL_MS', 'watchIntervalMs', 1000),
    1000
  );

  if (!baseUrl) {
    throw new Error('Missing upload base URL. Use --url or UPLOAD_BASE_URL');
  }

  if (!token) {
    throw new Error('Missing upload token. Use --token or UPLOAD_TOKEN');
  }

  const options = {
    baseUrl,
    token,
    accountsPath,
    logPath,
    watchIntervalMs
  };

  try {
    await uploadOnce(options);
  } catch (error) {
    if (!args.watch) {
      throw error;
    }

    console.error(`[upload] initial upload failed: ${formatError(error)}`);
  }

  if (!args.watch) {
    return;
  }

  console.log('[watch] enabled');
  if (existsSync(configPath)) {
    console.log(`[watch] config: ${configPath}`);
  }
  console.log(`[watch] accounts: ${accountsPath}`);
  console.log(`[watch] log: ${logPath}`);
  console.log(`[watch] interval: ${watchIntervalMs}ms`);

  const scheduleUpload = createDebouncedUploader(options);
  watchFile(accountsPath, { interval: watchIntervalMs }, (_curr, prev) => {
    if (prev.mtimeMs !== 0) {
      console.log('[watch] accounts changed');
    }
    scheduleUpload();
  });
  watchFile(logPath, { interval: watchIntervalMs }, (_curr, prev) => {
    if (prev.mtimeMs !== 0) {
      console.log('[watch] log changed');
    }
    scheduleUpload();
  });

  await new Promise(() => {});
}

main().catch((error) => {
  console.error(`[upload] ${formatError(error)}`);
  process.exit(1);
});
