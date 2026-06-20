<p align="center">
  <img src="lib/assets/logo.png" alt="GitItDown logo" width="120" />
</p>

<h1 align="center">GitItDown</h1>

<p align="center"><em>Your notes, versioned and everywhere</em></p>

<p align="center">
  <img alt="GitHub release" src="https://img.shields.io/github/release/MonforteGG/gititdown.svg" />
  <img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg" />
  <img alt="Built with Flutter" src="https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter&logoColor=white" />
</p>

GitItDown is a Flutter app for browsing, editing, and consuming a vault stored in a GitHub repository. It is designed for people who keep notes in an Obsidian-style or Hermes-style folder structure and want a practical way to access that vault across devices.

> [!IMPORTANT]
> One of the main use cases of GitItDown is using GitHub as the sync layer for your vault so you do not need to pay for Obsidian Sync just to keep the same notes available on desktop, laptop, phone, and web.

## Overview

GitItDown treats a GitHub repository as a vault made of:

- folders
- Markdown notes
- audio recordings
- PDF documents

That makes it useful as a:

| Use case | What GitItDown gives you |
| --- | --- |
| Personal knowledge base | Structured vault browsing, search, editing, preview |
| Meeting workflow | Notes, linked audio, timestamp navigation, supporting PDFs |
| Obsidian/Hermes companion | GitHub-backed access to an existing filesystem-first vault |
| Multi-device reader/editor | A lightweight client for a repo-backed vault |

## Table of contents

- [Why GitItDown](#why-gititdown)
- [Core features](#core-features)
- [Obsidian and Hermes workflow](#obsidian-and-hermes-workflow)
- [Screenshots](#screenshots)
- [Platform support](#platform-support)
- [Getting started](#getting-started)
- [Vault conventions](#vault-conventions)
- [Development](#development)
- [Security](#security)
- [Current scope](#current-scope)

## Why GitItDown

If your vault is already just files and folders, GitHub is a strong backend:

- Markdown notes remain plain text
- repository history gives you versioning for free
- folders stay intact
- audio and PDFs can live beside their related notes
- your content stays portable instead of locked inside a proprietary sync layer

GitItDown turns that repository into something you can actually use comfortably:

- browse the vault
- search by path, title, and note content
- edit Markdown notes
- open internal wikilinks
- play linked audio
- read PDFs
- inspect note history

## Core features

### At a glance

| Area | Included |
| --- | --- |
| Vault navigation | Folders, root/up navigation, optional tree view |
| Search | File name, path, and Markdown content search with snippets |
| Markdown | Edit mode, preview mode, formatting toolbar, frontmatter-friendly preview |
| Linking | Obsidian-style wikilinks for notes, audio, and PDFs |
| Audio | Authenticated loading, playback controls, timestamped jumps |
| PDF | In-app viewer, zoom controls, page indicator, quick vertical scroll |
| Library UX | Favorites and quick access |
| Repo awareness | History, conflict handling, GitHub-backed storage |

### Vault browsing

- Browse repository folders as if they were a note vault
- Open notes, audio files, and PDFs directly from GitHub
- Navigate through nested folder structures
- Use tree view when you want a full vault overview

### Global search

- Search by note title
- Search by path
- Search inside Markdown content
- See contextual snippets for matches

### Markdown editing and preview

- Create, edit, rename, and delete notes
- Create folders and delete empty folders
- Switch between edit and preview mode
- Use a formatting toolbar instead of memorizing syntax
- Render headings, tables, blockquotes, links, and code blocks cleanly
- Show frontmatter in a more readable preview format

### Wikilinks

GitItDown supports vault-style wikilinks such as:

```md
[[note]]
[[folder/note]]
[[audio.mp3#03:44|Important moment]]
[[audio.mp3?t=754|Exact timestamp]]
[[document.pdf]]
```

What that means in practice:

- `[[note]]` opens another note
- timestamped audio links open the player at the right moment
- PDF links open the in-app PDF viewer

### Audio support

- Open `.mp3` files from the repo
- Fetch them through authenticated GitHub access
- Show download progress
- Play, pause, seek, and change playback speed
- Jump to exact referenced moments from related notes

Good fit for:

- meeting recordings
- interview notes
- voice memos
- study sessions

### PDF support

- Open `.pdf` files directly from the repository
- Download them through authenticated GitHub access
- View them inside the app without leaving the vault
- Zoom in and out
- Use a vertical quick-scroll thumb for long documents
- See the current page over total pages

Good fit for:

- research papers
- project briefs
- scanned references
- attached reading material

### Favorites and quick access

- Mark entries as favorites
- Keep common notes or folders near the top of your workflow
- Persist preferences inside the repository

<details>
<summary><strong>More implementation details</strong></summary>

- Notes are stored directly in GitHub
- Preferences are also saved in the repository
- The app uses authenticated GitHub API access for protected content
- Vault entries are filtered to the supported content model of the app

</details>

## Obsidian and Hermes workflow

GitItDown works especially well if your notes already live in a filesystem-first vault.

If you use Obsidian or Hermes and your vault is stored in GitHub:

- folder structure remains intact
- Markdown files stay portable
- attachments can live beside the notes
- wikilinks stay useful
- GitHub becomes the synchronization layer

> [!NOTE]
> This is the main value proposition for many users: keep your vault in GitHub and use GitItDown as the access layer instead of paying for Obsidian Sync only to move the same files between devices.

### Typical vault layout

```text
MyVault/
  Areas/
  Projects/
  Meetings/
  References/
  Inbox/
```

### Example meeting folder

```text
Meetings/2026-06-13 - Follow-up/
  2026-06-13 - Follow-up.md
  2026-06-13 - Follow-up.mp3
  Slides.pdf
```

With this structure, GitItDown lets you:

1. Read the meeting note
2. Jump to referenced audio moments
3. Open the supporting PDF
4. Keep the whole folder versioned in GitHub

## Screenshots

<img width="979" height="975" alt="Main notes view" src="https://github.com/user-attachments/assets/35d6b67f-6766-4b21-81d1-5519850ff05e" />

<img width="979" height="975" alt="Editor view" src="https://github.com/user-attachments/assets/7d00db7c-d0b3-4710-80a6-0a33a235be31" />

## Platform support

GitItDown is built with Flutter and targets:

| Desktop | Mobile | Web |
| --- | --- | --- |
| Windows | Android | Web |
| macOS | iOS |  |
| Linux |  |  |

## Getting started

### Requirements

You need:

1. A GitHub account
2. A repository that will act as your vault
3. A GitHub Personal Access Token with `repo` scope

### Quick start

```bash
git clone https://github.com/MonforteGG/gititdown.git
cd gititdown
flutter pub get
flutter run
```

### First-time setup

When the app opens, enter:

- your GitHub username
- your repository name
- your Personal Access Token

The app will then treat that repository as your vault backend.

### Create a Personal Access Token

1. Open `https://github.com/settings/tokens/new`
2. Set a description such as `GitItDown App`
3. Grant `repo` scope
4. Generate the token
5. Paste it into the app

## Vault conventions

For the smoothest experience:

- keep related files together in folders
- use Markdown for written notes
- store meeting audio beside the matching note when possible
- use stable, descriptive file names

Recommended example:

```text
Meetings/
  2026-06-13 - Follow-up/
    2026-06-13 - Follow-up.md
    2026-06-13 - Follow-up.mp3
    Context.pdf
```

This makes it easier to:

- navigate by context
- search effectively
- open related assets together
- preserve compatibility with Obsidian-style workflows

## Development

### Useful commands

```bash
flutter pub get
flutter test
flutter build web
flutter build windows
flutter build macos
flutter build linux
flutter build apk
flutter build ios
```

### Architecture

```text
lib/
|-- config/         # App constants and theme
|-- core/           # Shared utilities and error handling
|-- data/           # GitHub data sources, models, repository implementations
|-- domain/         # Entities, repositories, use cases
`-- presentation/   # Riverpod providers, screens, widgets
```

### Main stack

| Package | Purpose |
| --- | --- |
| `flutter_riverpod` | State management |
| `dio` | GitHub API access |
| `flutter_markdown` | Markdown rendering |
| `audioplayers` | Audio playback |
| `pdfrx` | PDF rendering |
| `flutter_secure_storage` | Token storage |

## Security

- The GitHub token is stored using platform-secure storage where available
- The app talks directly to the GitHub API
- No analytics or tracking are built into the app

## Current scope

GitItDown is designed around a GitHub-backed vault model, so:

- it is not a full Git client
- it focuses on supported vault file types
- it assumes GitHub is the source of truth for synchronization

Today it is strongest for:

- Markdown-centric vaults
- audio-linked notes
- PDF-backed reference folders
- personal knowledge systems stored in GitHub

## License

MIT License
