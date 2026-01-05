import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('electronAPI', {
  listDirectory: (path: string) => ipcRenderer.invoke('list-directory', path),
  getHomeDirectory: () => ipcRenderer.invoke('get-home-directory')
});
