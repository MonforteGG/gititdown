# GitItDown

[![GitHub release](https://img.shields.io/github/release/MonforteGG/gititdown.svg)](https://github.com/MonforteGG/gititdown/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Your notes, versioned and everywhere.** A multi-platform markdown notes app built with Flutter that uses GitHub as a backend.

---

## Screenshots


<img width="979" height="975" alt="image" src="https://github.com/user-attachments/assets/35d6b67f-6766-4b21-81d1-5519850ff05e" />


<img width="979" height="975" alt="image" src="https://github.com/user-attachments/assets/7d00db7c-d0b3-4710-80a6-0a33a235be31" />


---

## Features

- **GitHub Backend** - Notes stored as `.md` files in your GitHub repository
- **Markdown Support** - Full rendering with syntax highlighting
- **Version History** - View and restore previous versions of your notes
- **Cross-Platform** - iOS, Android, Windows, macOS, Linux, and Web
- **Secure** - PAT stored securely using platform-specific storage
- **Responsive Design** - Optimized UI for desktop and mobile
- **Conflict Detection** - Handles external edits gracefully

---

## Download

### Windows

[![Download for Windows](https://img.shields.io/badge/Download-Windows-blue?logo=windows)](https://github.com/MonforteGG/gititdown/releases/tag/v1.0.0)

Download the latest Windows release from [GitHub Releases](https://github.com/MonforteGG/gititdown/releases/tag/v1.0.0)

### Web

Access the web version at: **https://gititdown.vercel.app** *(pending deployment)*

---

## Getting Started

### Prerequisites

1. A GitHub account
2. A GitHub repository to store your notes
3. A GitHub Personal Access Token (PAT) with `repo` scope

### Quick Start

```bash
# Clone the repository
git clone https://github.com/MonforteGG/gititdown.git
cd gititdown

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Creating a GitHub Personal Access Token

1. Go to: https://github.com/settings/tokens/new
2. Set description: "GitItDown App"
3. Select `repo` scope
4. Generate and copy the token
5. Enter in the app along with your username and repository name

---

## Architecture

Clean Architecture with three layers:

```
lib/
├── config/           # Themes, constants
├── core/             # Utilities, error handling
├── data/             # Data sources, repositories
├── domain/           # Entities, use cases
└── presentation/     # UI, providers, screens
```

**State Management:** Riverpod with StateNotifier

---

## Development

```bash
# Get dependencies
flutter pub get

# Run tests
flutter test

# Build for specific platforms
flutter build apk        # Android
flutter build ios        # iOS
flutter build windows    # Windows (.exe)
flutter build macos      # macOS
flutter build linux      # Linux
flutter build web        # Web (build/web/)
```

---

## Dependencies

| Package | Purpose |
|---------|---------|
| flutter_riverpod | State management |
| dio | HTTP client for GitHub API |
| flutter_markdown | Markdown rendering |
| flutter_secure_storage | Secure token storage |
| google_fonts | Typography |
| url_launcher | Open external links |
| dartz | Functional programming |
| equatable | Value equality |

---

## Security

- PAT stored using platform-specific secure storage (Keychain, Keystore, Credential Locker)
- Token only transmitted to GitHub API
- No analytics or tracking

---

## Deployment

### Web (Vercel)

```bash
flutter build web
# Deploy build/web/ to Vercel
```

### Windows

```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/gititdown.exe
```

---

## License

MIT License 

---

