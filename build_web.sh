#!/bin/bash
set -e

echo "=== Installing Flutter SDK ==="

# Clone Flutter SDK if not already present
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter" --depth 1
fi

export PATH="$HOME/flutter/bin:$PATH"

echo "=== Flutter version ==="
flutter --version

echo "=== Enabling web support ==="
flutter config --no-analytics
flutter precache --web

echo "=== Getting dependencies ==="
flutter pub get

echo "=== Building for web ==="
flutter build web --release --base-href "/"

echo "=== Build complete ==="
ls -la build/web/
