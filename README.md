# GitItDown

A multi-platform notes application built with Flutter that uses GitHub as a backend. Store your notes as Markdown files in your own GitHub repository.

## Features

- **GitHub Backend**: Your notes are stored as `.md` files in your own GitHub repository
- **Cross-Platform**: Works on iOS, Android, Windows, macOS, and Linux
- **Secure**: Personal Access Token (PAT) is securely stored in device's Keychain/Keystore
- **Markdown Support**: Full Markdown rendering with code syntax highlighting
- **Distraction-Free Design**: Clean, minimal UI focused on writing
- **Offline Awareness**: Handles network errors gracefully
- **Conflict Resolution**: Detects external edits and prompts to reload or overwrite

## Architecture

This project follows **Clean Architecture** with three distinct layers:

```
lib/
├── config/           # Themes, constants
├── core/             # Utilities, errors
├── data/             # Data layer (API, storage)
├── domain/           # Business logic (entities, use cases)
└── presentation/     # UI layer (screens, providers)
```

**State Management**: Riverpod

## Getting Started

### Prerequisites

1. A GitHub account
2. A GitHub repository to store your notes
3. A GitHub Personal Access Token with `repo` scope

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/gititdown.git
cd gititdown
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Creating a GitHub Personal Access Token

1. Click "Create a token on GitHub" in the app, or go to:
   https://github.com/settings/tokens/new

2. Set the token description (e.g., "GitItDown App")

3. Select the `repo` scope

4. Generate and copy the token

5. Paste it in the app along with your GitHub username and repository name

## Development

### Build Commands

```bash
# Get dependencies
flutter pub get

# Run tests
flutter test

# Build for specific platforms
flutter build apk        # Android
flutter build ios        # iOS
flutter build windows    # Windows
flutter build macos      # macOS
flutter build linux      # Linux
```

### Running Tests

```bash
flutter test
```

## Dependencies

- **flutter_riverpod**: State management
- **dio**: HTTP client for GitHub API
- **flutter_markdown**: Markdown rendering
- **flutter_secure_storage**: Secure token storage
- **google_fonts**: Typography
- **url_launcher**: Opening external links

## Security

- Your Personal Access Token is stored securely using platform-specific secure storage
  - iOS/macOS: Keychain
  - Android: Keystore
  - Windows: Credential Locker
  - Linux: Secret Service API
- The token is never transmitted anywhere except to GitHub's API
- No analytics or tracking

## License

MIT License - see LICENSE file for details

## Acknowledgments

- GitHub REST API v3
- Flutter Team
- Riverpod
- All open-source contributors
