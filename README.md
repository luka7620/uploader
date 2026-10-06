# Uploader

这是一个独立的本地上传工具目录，只保留：

- 配置文件
- Node 上传脚本
- Windows 托盘运行
- 开机自启

不再包含 GUI 工程。

## 目录内容

- `package.json`
- `upload-data.mjs`
- `upload.config.example.json`
- `tray-launcher.ps1`
- `install-startup.ps1`
- `uninstall-startup.ps1`
- `start-tray.cmd`
- `install-startup.cmd`
- `uninstall-startup.cmd`

## 运行前提

- Windows
- `Node.js 20+`
- PowerShell 可用

## 1. 配置文件

先复制模板：

```bat
copy upload.config.example.json upload.config.json
```

示例：

```json
{
  "url": "http://服务器IP:7001",
  "token": "your-upload-token",
  "accountsPath": "C:/path/to/accounts.txt",
  "logPath": "C:/path/to/log.txt",
  "watchIntervalMs": 1000
}
```

## 2. 普通运行

### 单次上传

```bat
npm run upload -- --config upload.config.json
```

### 持续监听

```bat
npm run watch -- --config upload.config.json
```

## 3. 托盘运行

### 直接启动

双击：

- `start-tray.cmd`

或者执行：

```bat
npm run tray
```

启动后会：

- 在后台启动上传监听
- 最小化到系统托盘
- 托盘菜单显示必要信息和控制项

当前托盘菜单包含：

- 当前运行状态
- Start Upload Watcher
- Restart Upload Watcher
- Stop Upload Watcher
- Open Config
- Open Runtime Folder
- Exit

双击托盘图标会打开运行日志目录。

## 4. 开机自启

### 安装

双击：

- `install-startup.cmd`

或者执行：

```bat
npm run startup:install
```

### 卸载

双击：

- `uninstall-startup.cmd`

或者执行：

```bat
npm run startup:uninstall
```

## 5. 运行日志

托盘模式下日志会写到：

- `runtime/uploader.stdout.log`
- `runtime/uploader.stderr.log`

## 6. 推荐使用方式

如果你的目标只是：

- 开机自动运行
- 最小化到托盘
- 自动监听并上传文件

那推荐直接这样用：

1. 配好 `upload.config.json`
2. 运行 `start-tray.cmd`
3. 运行 `install-startup.cmd`

## 7. 不依赖主项目

这个目录可以单独拷走使用，不依赖：

- `src/`
- `server/`
- `admin-dist/`
- `docker-compose`
- 主项目根目录 `package.json`

只要有：

- `uploader/`
- `Node.js 20+`

就能独立运行。
