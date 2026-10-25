# TestFlight via Xcode Cloud

Everything the iOS build needs is in the repo:

- `ios/ci_scripts/ci_post_clone.sh` installs Flutter on the Xcode Cloud runner and writes `ios/Flutter/Generated.xcconfig` plus the generated plugin Swift package. Xcode Cloud runs it automatically because it sits next to `Runner.xcworkspace`. Plugins are Swift packages, so there is no Podfile and no `pod install`.
- `ios/Runner/Info.plist` sets `ITSAppUsesNonExemptEncryption` to false (HTTPS only), which skips the export-compliance prompt on every TestFlight build.
- Bundle identifier: `com.brilliantdisruptions.fraudSignal`. Version `0.1.0`, build `1` (from `pubspec.yaml`). Xcode Cloud replaces the build number with its own on each archive.

## Why the Xcode target is called FraudSignal

Every `flutter create` project ships an Xcode target named `Runner` with the same internal identifiers. Xcode Cloud derives a product's identity partly from the target, so onboarding a second Flutter app re-points the existing product (and drags its workflows along) instead of creating a new one. Apple developers report the same behavior in [this thread](https://developer.apple.com/forums/thread/839723). This project's target is therefore named `FraudSignal`. The product stays `Runner.app` and the scheme stays `Runner`, so every Flutter command works unchanged.

If a Cardex (or other) workflow still shows under this product in App Store Connect, untangle it once:

1. App Store Connect → Apps → Fraud Signal → Xcode Cloud → Settings → **Delete Xcode Cloud Data**. This removes the merged product and its workflows; builds are not affected.
2. Do the same on the other app if its product is also wrong.
3. On the Mac, quit Xcode and clear `~/Library/Developer/Xcode/UserData/XcodeCloud`.
4. Open each project in its own Xcode launch and re-create its workflow (section 3 below). Make sure the scheme shown in the toolbar is `Runner` for that project before Integrate → Create Workflow.
5. Commit any `ios/Runner.xcodeproj/xcshareddata/xcodecloud/manifest.json` Xcode writes.

## 1. Register the app

1. Apple Developer → Certificates, Identifiers & Profiles → Identifiers → **+** → App IDs → App. Description `Fraud Signal`, Bundle ID explicit `com.brilliantdisruptions.fraudSignal`. No capabilities needed. Register.
2. App Store Connect → Apps → **+** → New App. Platform iOS, name `Fraud Signal`, primary language, the bundle ID above, any SKU (e.g. `fraud-signal-ios`), full access. Create.

## 2. Open the project once on a Mac

```sh
git clone https://github.com/michaeljwilt/fraud-signal.git
cd fraud-signal
flutter pub get
flutter build ios --config-only --no-codesign
open ios/Runner.xcworkspace
```

In Xcode select the Runner target → Signing & Capabilities → tick **Automatically manage signing** and pick your team. Commit the `project.pbxproj` change if Xcode makes one (it writes `DEVELOPMENT_TEAM`).

## 3. Create the Xcode Cloud workflow

1. Xcode → **Integrate → Create Workflow…** (or Product → Xcode Cloud → Create Workflow). Choose the **Runner** product.
2. Grant Xcode Cloud access to GitHub when prompted. It installs the Xcode Cloud GitHub App on `michaeljwilt/fraud-signal`.
3. Edit the workflow before saving:
   - **General**: name `TestFlight`, repository `fraud-signal`, primary branch `main`.
   - **Environment**: latest released Xcode and macOS. Add environment variables only if you want a production build: `SUPABASE_URL` and `SUPABASE_ANON_KEY` (mark secret). Leave them out for the demo build.
   - **Start Conditions**: Branch Changes on `main`, or Manual while you iterate.
   - **Actions**: Archive, platform iOS, scheme Runner, deployment preparation **TestFlight (Internal Testing Only)**. Delete the default Build/Test actions if present (the Flutter unit tests run with `flutter test`, not here).
   - **Post-Actions**: TestFlight Internal Testing → pick a group (create one in App Store Connect → TestFlight → Internal Testing first). Add a notify-on-failure email if you like.
4. Save, then **Start Build**. The first run takes about 15 minutes: Flutter clone, precache, pod install, archive, upload.

## 4. Testers

App Store Connect → TestFlight → Internal Testing → your group → add App Store Connect users. They get an email; the TestFlight app installs the build. Internal builds do not need Beta App Review.

## Check these when a build fails

| Symptom | Fix |
| --- | --- |
| `Generated.xcconfig must exist` | The post-clone script did not run. Confirm the file is at `ios/ci_scripts/ci_post_clone.sh` and executable (`git ls-files -s ios/ci_scripts` shows mode `100755`). |
| Code signing error | Signing & Capabilities must be automatic with a team selected, committed in `project.pbxproj`. Xcode Cloud uses cloud-managed signing; do not add manual profiles. |
| `No valid code signing certificates were found` in `ci_post_clone.log` | The script ran `flutter build ios` without `--no-codesign`. Keep that flag; Xcode Cloud signs the archive in its own step. |
| A plugin needs a newer iOS | Raise `IPHONEOS_DEPLOYMENT_TARGET` in Xcode (Runner project and target). |
| Build number rejected as a duplicate | Xcode Cloud normally sets its own build number. If you turned that off in the workflow's archive action, bump `+N` in `pubspec.yaml`. |

## Later

- Production backend: add the two Supabase variables to the workflow environment; the script passes them as `--dart-define`.
- External TestFlight groups need Beta App Review once; same workflow, change the post-action to External Testing.
