#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/logs
xcodegen generate
case "${1:-archive}" in
  test)
    device_id=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(v["udid"] for k,a in d["devices"].items() if "iOS" in k for v in a if v["name"].startswith("iPhone")))')
    xcodebuild test -project BiliPai.xcodeproj -scheme BiliPai -destination "platform=iOS Simulator,id=$device_id" -resultBundlePath build/Tests.xcresult CODE_SIGNING_ALLOWED=NO | tee build/logs/test.log
    ;;
  archive)
    xcodebuild archive -project BiliPai.xcodeproj -scheme BiliPai -configuration Release -destination 'generic/platform=iOS' -archivePath build/BiliPai.xcarchive CODE_SIGNING_ALLOWED=NO | tee build/logs/archive.log
    mkdir -p build/Payload
    ditto build/BiliPai.xcarchive/Products/Applications/BiliPai.app build/Payload/BiliPai.app
    (cd build && zip -qr BiliPai-iOS-unsigned.ipa Payload)
    shasum -a 256 build/BiliPai-iOS-unsigned.ipa > build/BiliPai-iOS-unsigned.ipa.sha256
    ;;
  *) echo 'Usage: scripts/build-ios.sh [test|archive]' >&2; exit 2 ;;
esac
