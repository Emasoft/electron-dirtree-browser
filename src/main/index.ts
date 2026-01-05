import { app, BrowserWindow, ipcMain } from 'electron';
import * as path from 'path';
import { spawn } from 'child_process';

let mainWindow: BrowserWindow | null = null;

function getXlsPath(): string {
  // In development, use local binary; in production, use bundled binary
  const isDev = !app.isPackaged;
  const platform = process.platform;
  const ext = platform === 'win32' ? '.exe' : '';

  if (isDev) {
    // Development: use local bin/ directory
    return path.join(__dirname, '../../bin', `xls${ext}`);
  }
  // Production: binary is in resources/bin/
  return path.join(process.resourcesPath, 'bin', `xls${ext}`);
}

interface RawFileEntry {
  name: string;
  size: number;
  modified: string;
  is_dir: boolean;
  is_symlink: boolean;
  permissions?: string;
  file_type?: string;
}

interface RawCliOutput {
  path: string;
  total: number;
  entries: RawFileEntry[];
}

interface TransformedEntry {
  name: string;
  type: 'file' | 'directory' | 'symlink';
  size: number;
  modified: string;
  permissions: string;
}

interface TransformedOutput {
  path: string;
  entries: TransformedEntry[];
}

async function listDirectory(dirPath: string): Promise<TransformedOutput> {
  return new Promise((resolve, reject) => {
    const xlsPath = getXlsPath();
    // Use --format json (not --json) and include -a for all files, -l for long format
    const child = spawn(xlsPath, ['--format', 'json', '-a', '-l', dirPath]);

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    child.on('close', (code) => {
      if (code === 0) {
        try {
          const rawOutput: RawCliOutput = JSON.parse(stdout);

          // Transform entries to match renderer's expected format
          const transformedEntries: TransformedEntry[] = rawOutput.entries.map(entry => ({
            name: entry.name,
            type: entry.is_dir ? 'directory' : entry.is_symlink ? 'symlink' : 'file',
            size: entry.size,
            modified: entry.modified,
            permissions: entry.permissions || '-'
          }));

          resolve({
            path: rawOutput.path,
            entries: transformedEntries
          });
        } catch (e) {
          reject(new Error(`Failed to parse JSON: ${stdout}`));
        }
      } else {
        reject(new Error(`xls exited with code ${code}: ${stderr}`));
      }
    });

    child.on('error', (err) => {
      reject(new Error(`Failed to spawn xls: ${err.message}`));
    });
  });
}

function createWindow(): void {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      preload: path.join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// IPC handlers
ipcMain.handle('list-directory', async (_event, dirPath: string) => {
  return listDirectory(dirPath);
});

ipcMain.handle('get-home-directory', () => {
  return app.getPath('home');
});

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (mainWindow === null) {
    createWindow();
  }
});
