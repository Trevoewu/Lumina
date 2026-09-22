#!/bin/sh
# Xcode Cloud must generate Flutter's local Swift package before resolving packages.
set -eu

cd "${CI_PRIMARY_REPOSITORY_PATH:?Run this script in Xcode Cloud}"

# Match the SDK used for the verified local Release build.
LUMINA_FLUTTER_VERSION=3.44.4
LUMINA_FLUTTER_DIR="${CI_DERIVED_DATA_PATH:-${TMPDIR:-/tmp}}/lumina-flutter-${LUMINA_FLUTTER_VERSION}"
if [ ! -x "$LUMINA_FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$LUMINA_FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$LUMINA_FLUTTER_DIR"
fi
export PATH="$LUMINA_FLUTTER_DIR/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
export HOMEBREW_NO_AUTO_UPDATE=1

if ! command -v pod >/dev/null 2>&1; then
  brew install cocoapods
fi

python3 ios/ci_scripts/normalize_xcode_scripts.py
flutter precache --ios
flutter pub get
flutter build ios --release --no-codesign --config-only --no-pub

test -f ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
test -f ios/Flutter/Generated.xcconfig
# Also ensure the plugins still using CocoaPods are installed.
cd ios
pod install
