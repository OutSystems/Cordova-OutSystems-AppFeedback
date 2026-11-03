# Cordova Plugin for OutSystems App Feedback

## OutSystems App Feedback

OutSystems App Feedback allows customers to collect user feedback from their mobile applications. To submit feedback, users can draw on the screen, add voice notes, or type text directly on their tablets or smartphones. All user interactions and annotations are compiled into a comprehensive user story that developers can review through an intuitive interface, enabling them to navigate directly to the relevant screen and begin implementing changes.

## Supported Platforms

- iOS
- Android

## How to Deploy

Test your features in the `master` branch.

To make features available to OutSystems 11 customers, create or update a branch named `mabsX`, where `X` is the major MABS version (e.g., `mabs11` for MABS 11).

When apps that include App Feedback are built in MABS, the plugin is included automatically. The `mabsX` branch name determines which plugin commit MABS will use for the build.

## Update Mobile ECT

### Android

The Android code depends on the shell for AndroidX AppCompat and androidx.core (CordovaLib), `androidx.localbroadcastmanager` and the Broadcaster plugin's `Event` class (both from `cordova-outsystems-core`).

To update the Mobile ECT library used by the plugin, build `MobileECT.aar` from the [outsystems-appfeedback-android-sdk](https://github.com/OutSystems/outsystems-appfeedback-android-sdk) repository (`./gradlew :MobileECT:assembleRelease`, JDK 21) and replace `src/android/MobileECT/MobileECT.aar` with `MobileECT/build/outputs/aar/MobileECT-release.aar`. The AAR is added through `flatDir`, which carries no POM: if the library's dependencies change, update `src/android/osappfeedback.gradle` to match.

### iOS

To update the Mobile ECT framework used by the plugin, replace the `OutSystemsMobileECT.xcframework` file located in the `src/ios` folder with the new version of the framework. The framework can be obtained from the [outsystems-appfeedback-ios-sdk](https://github.com/OutSystems/outsystems-appfeedback-ios-sdk) repository. Follow the instructions in the repository README to build the framework.
