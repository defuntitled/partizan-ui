# partizan-ui

Flutter client for partizan: the UI is shared with the future desktop app, the tunnel is the
Rust core from the [partizan](../partizan) repository, linked in as an AAR. The specification is
`spec/partizan_android_spec.md` (in Russian).

```sh
flutter test                       # unit and widget tests
scripts/core-aar.sh                # build the core AAR in ../partizan and copy it to android/app/libs
flutter build apk --debug --target-platform android-arm64
flutter test integration_test -d <device>   # on a device: Dart ↔ core through the bridge
```
