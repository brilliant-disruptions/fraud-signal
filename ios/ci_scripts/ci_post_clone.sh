#!/bin/sh
# Xcode Cloud post-clone step for a Flutter app.
# Installs Flutter and generates the iOS build config so the Runner archive
# action can build. Plugins are Swift packages, so there is no CocoaPods step.
# Xcode Cloud runs this from ios/ci_scripts.
set -e

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
echo "Installing Flutter ($FLUTTER_CHANNEL)"
git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_CHANNEL" "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"
flutter --version
flutter precache --ios

cd "$CI_PRIMARY_REPOSITORY_PATH"
flutter pub get

# Optional production backend. Set SUPABASE_URL and SUPABASE_ANON_KEY as
# environment variables on the Xcode Cloud workflow; without them the app
# ships in demo mode.
DEFINES=""
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
  DEFINES="--dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
fi
# Writes ios/Flutter/Generated.xcconfig (including DART_DEFINES) and the
# generated Swift package without building. --no-codesign is required here:
# the runner has no signing identity at this point; Xcode Cloud signs the
# archive itself in the next step.
flutter build ios --release --config-only --no-codesign $DEFINES
exit 0
