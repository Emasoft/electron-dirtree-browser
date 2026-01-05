declare global {
  interface Window {
    electronAPI: {
      listDirectory: (path: string) => Promise<DirectoryListing>;
      getHomeDirectory: () => Promise<string>;
    };
  }
}

// Make this an ES module to allow global augmentation
export {};

interface FileEntry {
  name: string;
  type: 'file' | 'directory' | 'symlink';
  size: number;
  modified: string;
  permissions: string;
}

interface DirectoryListing {
  path: string;
  entries: FileEntry[];
}

let currentPath = '/';
let navigationHistory: string[] = [];
let historyIndex = -1;

const container = document.getElementById('tree-container')!;
const pathDisplay = document.getElementById('current-path')!;
const btnBack = document.getElementById('btn-back') as HTMLButtonElement;
const btnUp = document.getElementById('btn-up') as HTMLButtonElement;
const btnHome = document.getElementById('btn-home') as HTMLButtonElement;
const btnRefresh = document.getElementById('btn-refresh') as HTMLButtonElement;

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
}

function formatDate(isoDate: string): string {
  const date = new Date(isoDate);
  return date.toLocaleString();
}

function getIcon(type: string): string {
  switch (type) {
    case 'directory': return '📁';
    case 'symlink': return '🔗';
    default: return '📄';
  }
}

async function loadDirectory(path: string, addToHistory = true): Promise<void> {
  container.innerHTML = '<div class="loading">Loading...</div>';
  pathDisplay.textContent = path;

  try {
    const listing = await window.electronAPI.listDirectory(path);
    currentPath = listing.path;
    pathDisplay.textContent = currentPath;

    if (addToHistory) {
      navigationHistory = navigationHistory.slice(0, historyIndex + 1);
      navigationHistory.push(currentPath);
      historyIndex = navigationHistory.length - 1;
    }
    btnBack.disabled = historyIndex <= 0;

    // Sort: directories first, then files
    const sorted = [...listing.entries].sort((a, b) => {
      if (a.type === 'directory' && b.type !== 'directory') return -1;
      if (a.type !== 'directory' && b.type === 'directory') return 1;
      return a.name.localeCompare(b.name);
    });

    container.innerHTML = '';
    for (const entry of sorted) {
      const item = document.createElement('div');
      item.className = 'tree-item';
      item.innerHTML = `
        <span class="icon ${entry.type}">${getIcon(entry.type)}</span>
        <span class="name">${entry.name}</span>
        <span class="size">${entry.type === 'directory' ? '-' : formatSize(entry.size)}</span>
        <span class="modified">${formatDate(entry.modified)}</span>
      `;
      if (entry.type === 'directory') {
        item.addEventListener('dblclick', () => {
          loadDirectory(currentPath === '/' ? `/${entry.name}` : `${currentPath}/${entry.name}`);
        });
      }
      container.appendChild(item);
    }

    if (sorted.length === 0) {
      container.innerHTML = '<div class="loading">Empty directory</div>';
    }
  } catch (err) {
    container.innerHTML = `<div class="error">Error: ${err}</div>`;
  }
}

btnBack.addEventListener('click', () => {
  if (historyIndex > 0) {
    historyIndex--;
    loadDirectory(navigationHistory[historyIndex], false);
  }
});

btnUp.addEventListener('click', () => {
  const parent = currentPath.split('/').slice(0, -1).join('/') || '/';
  loadDirectory(parent);
});

btnHome.addEventListener('click', async () => {
  const home = await window.electronAPI.getHomeDirectory();
  loadDirectory(home);
});

btnRefresh.addEventListener('click', () => {
  loadDirectory(currentPath, false);
});

// Initial load
(async () => {
  const home = await window.electronAPI.getHomeDirectory();
  loadDirectory(home);
})();
