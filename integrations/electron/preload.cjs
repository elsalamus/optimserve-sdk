const {contextBridge, ipcRenderer} = require('electron');
contextBridge.exposeInMainWorld('optimserve', Object.freeze({authorize: input => ipcRenderer.invoke('optimserve:authorize', input)}));
