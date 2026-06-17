# Background Remover

<p align="center">
  <img src=".github/assets/logo_transparent.png" alt="Background Remover Logo" width="160"><br><br>
  <img src="https://github.com/vicajilau/background-remover/actions/workflows/ci.yml/badge.svg" alt="CI Status">
  <img src="https://github.com/vicajilau/background-remover/actions/workflows/deploy_web.yml/badge.svg" alt="Web CD Status">
</p>

The open-source companion for all your image processing needs in Flutter. 

Background Remover automatically extracts subjects and generates transparent backgrounds. Instead of relying on restrictive paid tools, you can process your images directly using this robust, cross-platform application.

---

## 🚀 Key Features

* **Zero-Cost Processing:** Completely free and open-source. No subscriptions or hidden API limits.
* **Instant Background Removal:** Select an image and let the application cleanly separate the foreground subject from the background.
* **Cross-Platform Support:** Fully developed in Flutter, ensuring a smooth, native-like experience across different operating systems.
* **Privacy First:** Process images securely without necessarily sending your personal photos to third-party cloud servers.

---

## ✨ The User Experience (UX)

1. **Simple Selection:** Choose any photo from your device's gallery or take a new one directly from the app.
2. **Auto-Discovery:** The app's processing engine automatically identifies the main subject of your image.
3. **Seamless Export:** Save the resulting transparent PNG directly to your local storage or share it with other applications.

---

## 📁 Project Structure

This repository is structured as a standard Flutter application.

| Directory | Description |
| --- | --- |
| [`lib`](./lib) | The core Dart code and UI components of the application. |
| [`assets`](./assets) | Static resources, including placeholder images and icons. |
| [`android`](./android) / [`ios`](./ios) | Native platform configurations and bindings. |

---

## 🛠️ Getting Started

### Prerequisites

Ensure you have the latest stable **Flutter SDK** installed on your machine. 

### Setup the Workspace

Clone the repository and resolve dependencies:

```bash
git clone [https://github.com/vicajilau/background-remover.git](https://github.com/vicajilau/background-remover.git)
cd background-remover

# Fetch dependencies
flutter pub get

```

### Running the Application

To launch the app on your connected device or emulator, run:

```bash
flutter run

```

---

## 📖 Usage Example

Since this is a client-facing application rather than a library, usage is entirely through the graphical interface:

1. Launch the app on your preferred device.
2. Tap the **"Upload Image"** or **"Camera"** button.
3. Wait for the processing to complete.
4. Tap **"Save"** to download the isolated subject to your gallery.

*If you wish to integrate the underlying background removal logic into your own code, check the core processing services located within the `lib/services/` directory.*

---

## 📄 License

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see [https://www.gnu.org/licenses/](https://www.google.com/search?q=https://www.gnu.org/licenses/).

Copyright (C) 2026 Víctor Carreras