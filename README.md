# TigerDen : Team 10
# Members
Project Manager: Logan Hebert ([https://github.com/Logan-Hebert]) \
Communications Lead: Kade Whitman ([https://github.com/kmwhitman]) \
Git Master: James Sigler ([https://github.com/melloon]) \
Design Lead: Kauai Cooper ([GitHub Name]) \
Quality Assurance Tester: Eric Chau ([https://github.com/ericchau01])

# About Our Software

TigerDen is an app designed to help users find and get involved in events around LSU campus, whether that be through student organizations or person-led events.
## Platforms Tested on
- Android
- iOS
# Important Links
Kanban Board: [https://3380-project.atlassian.net/jira/software/projects/B1/boards/2?filter=&groupBy=none]\
Designs: [https://www.figma.com/design/W2Sc5nP9yKgJCXBtLv4Ojg/TigerDen?node-id=0-1&t=FzU4nuiyiyK1d94U-1]\
Styles Guide(s): [https://dart.dev/effective-dart]

# How to Run Dev and Test Environment

## Dependencies
- Flutter 3.47.6
- Dart 3.13.5
- Android Studio Rabbit 1 (for Android Testing)
- Xcode 27.0 (for iOS Testing)
- Firebase CLI (Optional, for Backend Testing)
### Downloading Dependencies
Describe where to download the dependencies here. Some will likely require a web download. Provide links here. For IDE extensions, make sure your project works with the free version of them, and detail which IDE(s) these are available in. 

Follow the instructions on [https://docs.flutter.dev/install] to install the Flutter SDK, either standalone or through the VS Code extension. This will include the latest version of Dart as well. From there, install either Xcode via the Mac App Store or Android Studio from [https://developer.android.com/studio] to begin setting up testing enviroments ([https://docs.flutter.dev/platform-integration/android/setup] for Android Studio and [https://docs.flutter.dev/platform-integration/ios/setup] for iOS). If needed, follow the instructions to install Firebase CLI at [https://firebase.google.com/docs/cli].

## Commands
Describe how the commands and process to launch the project on the main branch in such a way that anyone working on the project knows how to check the affects of any code they add.

Once your emulator for iOS or Android is set up, clone the repository and make sure you're in the directory for the TigerDen project. Once there, check to make sure you have all Flutter dependencies by running the following command:
```sh
flutter pub get
```
Once you're sure you have all dependencies, you can then launch the app in the emulator by opening the emulator you plan to use and running the command:

```sh
flutter run
```
