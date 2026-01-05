# DirTree Browser

Cross-platform Electron app for visual directory tree browsing.

## Features

- Visual directory tree display
- Cross-platform (macOS, Windows, Linux)
- Uses Rust CLI backend (xls) for fast directory listing
- Portable executables (no installation required)

## Requirements

- Node.js 18+
- The `xls` binary from [xls-cross-platform](https://github.com/Emasoft/xls-cross-platform)

## Development

```bash
# Install dependencies
npm install

# Start in development mode
npm start

# Build for production
npm run dist
```

## Build

```bash
# macOS
npm run dist:mac

# Windows
npm run dist:win

# Linux
npm run dist:linux
```

## License

MIT
