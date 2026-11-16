# KshonGCS Interface

SwiftUI macOS interface foundation for KshonGCS. The Rust AI, engine, asset-generation and game-runtime systems are not implemented in this UI preview repository yet.

## Included
- Native SwiftUI macOS app shell with a compact, translucent macOS-inspired visual style.
- Dashboard and recent project workspaces.
- Create 2D, 3D or hybrid project workspaces.
- Optional imported project thumbnails.
- Project folder scaffolding and metadata.
- Open existing workspaces.
- Interactive gameplay tutorial checklists.
- Native menu commands and subtle UI transitions.

## Build on a Mac
Requires macOS 12+, Swift 5.7+ and Xcode Command Line Tools:
```bash
swift run
```

## Download a Mac build from GitHub
The GitHub Actions workflow builds on a hosted macOS runner for each push to `main`.
Open **Actions → Build KshonGCS for macOS → Artifacts** and download `KshonGCS-macOS`.
This is an unsigned development build, not a notarized public release.

## Important
The workspace dashboard and project creation are implemented. The actual game editor, AI model, Rust engine, asset-generation pipeline, and game export are future implementation work. Tutorials are currently guided checklists and are not yet wired to editor operations.
