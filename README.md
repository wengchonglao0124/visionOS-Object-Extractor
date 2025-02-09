# Object Extractor Prototype

Object Extractor Prototype is an immersive application designed for visionOS, leveraging RealityKit to provide object extraction and AR functionalities. This project is developed in Swift using the MVVM architecture and SwiftUI, and is designed specifically for the Apple Vision Pro, a Mixed Reality (MR) device.

## Demonstration

https://github.com/user-attachments/assets/f4efdb9e-2072-4bcd-827b-c2655087d1f8

## Features
- **Object Detection and Extraction**: Capture and interact with virtual objects in an immersive environment.
- **3D Model Generation**: Leverages the advanced sensors and capabilities of the Apple Vision Pro to capture detailed 3D mesh data of real-world objects, convert them into editable 3D models, and prepare them for later use in immersive environments.
- **Spatial Computing Integration**: Modify the captured models in a spatial computing environment, taking full advantage of the Vision Pro's capabilities.
- **Immersive Space Experience**: Explore and interact with objects in an immersive space designed for visionOS.
- **Augmented Reality Integration**: Uses RealityKit to render AR objects and scenes seamlessly.
- **Custom Models**: Easily extendable to include new 3D models and materials.

## Project Structure

```
ObjectExtractor/
├── ObjectExtractor.xcodeproj/       # Xcode project configuration files
├── ObjectExtractor/                # Main application source files
│   ├── View/                       # UI Views for the app (SwiftUI)
│   ├── ViewModel/                  # ViewModel layer for data and logic (MVVM architecture)
│   ├── Model/                      # Model definitions (e.g., Edge.swift)
│   ├── Extension/                  # Extensions for utilities and additional functionalities
│   ├── Assets.xcassets/            # App assets including icons and color schemes
│   ├── Info.plist                  # App configuration file
├── Packages/                       # Included packages (e.g., RealityKitContent)
│   ├── RealityKitContent/          # RealityKit content and resources
│       ├── Sources/                # Source files for RealityKit
│       ├── Package.swift           # Swift Package Manager file
├── .git/                           # Git repository metadata
```

## Requirements
- **macOS** with the latest version of Xcode installed.
- **visionOS 1.0+** for the target device.
- **Apple Vision Pro** (MR device).
- **Swift 5.5+**.
- **RealityKit** framework.
- **SwiftUI** framework for UI design.

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/wengchonglao0124/visionOS-Object-Extractor.git
   ```

2. Open the project in Xcode:
   ```bash
   open ObjectExtractor.xcodeproj
   ```

3. Build and run the app on a visionOS simulator or connected Apple Vision Pro device.

## Usage
- Launch the app on an Apple Vision Pro device.
- Use the advanced sensors to capture details and 3D data of real-world objects.
- Modify and manipulate the captured models in a spatial computing environment.
- Interact with objects in an immersive space using intuitive SwiftUI-based UI.

## Contributing
Contributions are welcome! Please follow these steps:
1. Fork the repository.
2. Create a new feature branch.
3. Commit your changes and push them to your fork.
4. Create a pull request for review.

## License
This project is licensed under the MIT License. See the `LICENSE` file for details.

## Acknowledgments
- Apple RealityKit and ARKit documentation.
- Community tutorials and resources on immersive AR and spatial computing experiences.
- Swift and SwiftUI development best practices.
