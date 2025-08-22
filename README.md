# PhotoGrouping

PhotoGrouping is an iOS app that scans the device’s photo library, generates deterministic values for each photo, and groups them based on predefined ranges. It progressively updates results, persists state across app restarts, and offers a smooth browsing experience with UIKit + SwiftUI integration.  

## 🚀 Features

- 📸 **Photo Scanning**  
  - Uses `PHAsset` to fetch all photos from the user’s library.  
  - Generates a deterministic value for each photo (between 0 and 1).  
  - Assigns the photo into one of 20 predefined groups, or into **Others**.  

- ⚡ **Live Updates**  
  - Group counts and detail views update progressively during the scan.  
  - Horizontal progress bar with percentage label.  

- 💾 **Persistence**  
  - Scan progress and group states are saved using JSON.  
  - App resumes **exactly where it left off** if killed.  
  - Groups remain consistent and photo counts are preserved across launches.  

- 🖼 **Screens**  
  - **Home Screen (UIKit)**: Displays groups in a `UICollectionView`.  
  - **Group Detail (SwiftUI)**: Lazy grid of thumbnails with smooth scrolling.  
  - **Image Detail (SwiftUI)**: Full-size image with swipe navigation between photos.  

- 🎨 **Design**  
  - Hybrid UIKit + SwiftUI, no Storyboards.  
  - Blur effects, floating action button, and smooth navigation animations.  

## 🛠 Technical Highlights

- Language: **Swift 5+**  
- Minimum iOS Target: **15.0**  
- Architecture: **MVVM** (with Combine & async/await)  
- **No Storyboards** — UI built programmatically  
- Memory-efficient thumbnail loading with **PHCachingImageManager**  
- Incremental draining keeps UI smooth, even with thousands of photos

## 📥 Installation

1. Clone the repo  
   ```bash
   git clone https://github.com/utkugokcen13/PhotoGrouping.git
   cd PhotoGrouping
   
2. Open in Xcode
   ```bash
   open PhotoGrouping.xcodeproj


