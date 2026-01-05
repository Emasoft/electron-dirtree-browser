import { app, BrowserWindow, ipcMain } from 'electron';
import * as path from 'path';
import { spawn } from 'child_process';

let mainWindow: BrowserWindow | null = null;

function getXlsPath(): string {
  // In development, use local binary; in production, use bundled binary
  const isDev = !app.isPackaged;
  if (isDev) {
    // Try to find xls in PATH or local build
    return 'xls';
  }
  // Production: binary is in resources/bin/
  const platform = process.platform;
  const ext = platform === 'win32' ? '.exe' : '';
  return path.join(process.resourcesPath, 'bin', `xls${ext}`);
}

async function listDirectory(dirPath: string): Promise<object> {
  return new Promise((resolve, reject) => {
    const xlsPath = getXlsPath();
    const child = spawn(xlsPath, ['--json', '-a', '-l', dirPath]);

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
          resolve(JSON.parse(stdout));
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
