#!/bin/bash
set -e

echo "Starting Flutter APK build inside Docker..."

# Run flutter pub get
flutter pub get

# Build Release APK
flutter build apk --release

# Get variables
GIT_SHA=${GIT_SHA:-"unknown"}
TIMESTAMP=${TIMESTAMP:-"latest"}

# Fallback to local git CLI if Git SHA is unknown (useful for automated stack builds like Portainer)
if [ "${GIT_SHA}" = "unknown" ]; then
  GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi

# Generate dynamic timestamp if set to latest
if [ "${TIMESTAMP}" = "latest" ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
fi

APK_NAME="app-${GIT_SHA}-${TIMESTAMP}.apk"
OUTPUT_PATH="/artifacts/${APK_NAME}"

# Ensure output directory exists
mkdir -p /artifacts

# Copy and rename the built APK
cp build/app/outputs/flutter-apk/app-release.apk "${OUTPUT_PATH}"

echo "----------------------------------------"
echo "DONE: APK generated successfully!"
echo "Location: ${OUTPUT_PATH}"
echo "File Size: $(stat -c%s "${OUTPUT_PATH}") bytes"
echo "Checksum (SHA256): $(sha256sum "${OUTPUT_PATH}" | cut -d' ' -f1)"
echo "----------------------------------------"
