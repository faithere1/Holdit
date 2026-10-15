# Holdit

A tiny macOS menu bar app that works like a personal **copy center**: a drop zone that lives next to your Wi-Fi and Bluetooth icons and holds copies of anything you put into it.

Click the tray icon and a panel drops down under it. Drag files in, paste your clipboard, and drag them back out whenever you need them. Your items stay until **you** remove them, even after you quit or restart.

## Features

- **Menu bar app.** It has a tray icon in the menu bar and no Dock icon or window clutter.
- **Panel that stays open.** It doesn't close when you click elsewhere. Only the ✕ button hides it, and the app keeps running.
- **Drag & drop in.** You can drop PDFs, Markdown, Excel, images, folders or selected text. Holdit stores a **copy**, so your original is never touched.
- **Paste button.** It adds whatever you copied (text, files or an image) as a new row.
- **Drag out.** You can drag any row into Finder, Mail, a browser upload box or another app. A fresh copy is handed over, so the item stays in your list.
- **Reorder.** Drag rows up and down.
- **Row actions.** Each row can be copied to the clipboard, shown in Finder or removed. Double-click a row to open it.
- **Persistent.** The list survives quitting, restarting and rebooting.
- **Lightweight.** It uses about 13 MB of RAM and 0% CPU when idle, and makes no network access.

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`) to build

## Build & run

```sh
git clone https://github.com/faithere1/Holdit.git
cd Holdit
./build.sh
open Holdit.app
```

`build.sh` compiles the Swift sources, generates the app icon and packages everything into `Holdit.app`. You can move the app to `/Applications` if you like.

**Start at login:** add Holdit under System Settings → General → Login Items.

## Usage

| Action | How |
|---|---|
| Show panel | Left-click the tray icon |
| Hide panel | Click ✕ in the panel |
| Add files | Drag them onto the panel |
| Add clipboard | Click **Paste** |
| Use an item | Drag the row out, or click the copy button |
| Reorder | Drag rows up and down |
| Remove | Click the 🗑 on the row |
| Storage folder / Quit | Right-click the tray icon |

## Where data is stored

```
~/Library/Application Support/Holdit/
├── items.json   # the ordered list
└── files/       # private copies of dropped files
```

Copies take real disk space, so remove items you no longer need.

## Project structure

```
Sources/
├── main.swift        # menu bar icon and panel
├── PanelView.swift   # the list UI (SwiftUI)
└── Store.swift       # copying, saving, paste, drag & drop
Tools/
└── make_icon.swift   # renders the app icon
build.sh              # builds Holdit.app
```

Holdit is built with Swift, AppKit and SwiftUI only, with no third-party dependencies.

## Known limitations

- Attachments dragged directly out of Apple Mail (file promises) may not drop in. Save them first, or copy them and use **Paste**.
