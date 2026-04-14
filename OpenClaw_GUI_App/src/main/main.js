const { app, BrowserWindow, Menu, ipcMain, shell } = require('electron');
const path = require('path');
const Store = require('electron-store');

const store = new Store();

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));

  if (process.argv.includes('--dev')) {
    mainWindow.webContents.openDevTools();
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function createMenu() {
  const template = [
    {
      label: '文件',
      submenu: [
        {
          label: '新建配置',
          accelerator: 'Ctrl+N',
          click: () => {
            if (mainWindow) mainWindow.webContents.send('new-config');
          }
        },
        {
          label: '保存配置',
          accelerator: 'Ctrl+S',
          click: () => {
            if (mainWindow) mainWindow.webContents.send('save-config');
          }
        },
        { type: 'separator' },
        {
          label: '退出',
          accelerator: 'Alt+F4',
          click: () => {
            app.quit();
          }
        }
      ]
    },
    {
      label: '工具',
      submenu: [
        {
          label: 'OpenClaw 诊断',
          click: () => {
            if (mainWindow) mainWindow.webContents.send('run-doctor');
          }
        },
        {
          label: '打开 OpenClaw 面板',
          click: () => {
            if (mainWindow) mainWindow.webContents.send('open-dashboard');
          }
        }
      ]
    },
    {
      label: '帮助',
      submenu: [
        {
          label: '文档',
          click: () => {
            shell.openExternal('https://docs.openclaw.ai/');
          }
        },
        {
          label: '关于',
          click: () => {
            if (mainWindow) mainWindow.webContents.send('show-about');
          }
        }
      ]
    }
  ];

  if (process.platform === 'darwin') {
    template.unshift({
      label: app.getName(),
      submenu: [
        { role: 'about' },
        { type: 'separator' },
        { role: 'services' },
        { type: 'separator' },
        { role: 'hide' },
        { role: 'hideothers' },
        { role: 'unhide' },
        { type: 'separator' },
        { role: 'quit' }
      ]
    });
  }

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}

app.whenReady().then(() => {
  createWindow();
  createMenu();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

ipcMain.handle('get-config', async (event, key) => {
  return store.get(key);
});

ipcMain.handle('set-config', async (event, key, value) => {
  store.set(key, value);
  return true;
});

ipcMain.handle('get-all-config', async () => {
  return store.store;
});
