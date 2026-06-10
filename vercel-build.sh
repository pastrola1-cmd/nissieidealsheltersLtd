#!/bin/bash

# 1. Download the Flutter SDK (stable branch)
echo "Downloading Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $PWD/flutter-sdk

# 2. Add Flutter to PATH
export PATH="$PATH:$PWD/flutter-sdk/bin"

# 3. Enable web builds
flutter config --enable-web

# 4. Run doctor to verify setup (optional but helpful for logs)
flutter doctor

# 5. Build the web app
echo "Building Flutter Web application..."
flutter build web --release

# 6. Move build output to 'public' folder for Vercel to serve
echo "Preparing deployment assets..."
rm -rf public
mv build/web public

echo "Build complete!"
