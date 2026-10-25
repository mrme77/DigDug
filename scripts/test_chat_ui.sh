#!/bin/bash
# Link the real app objects into the CLT-compatible test runner, excluding its entry point.
# This tests UI code without changing the package's executable/module boundaries.
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/digdug-clang-cache}"
sdk_path="${DIGDUG_SDK_PATH:-$(xcrun --show-sdk-path)}"
swift build --disable-sandbox --build-system native --sdk "$sdk_path" --product DigDug
bin_path="$(swift build --disable-sandbox --build-system native --sdk "$sdk_path" --show-bin-path)"
objects=()
while IFS= read -r object; do
    case "$object" in
        */DigDugApp.build/DigDugApp.swift.o) ;;
        *) objects+=("$object") ;;
    esac
done < "$bin_path/DigDug.product/Objects.LinkFileList"
frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
swiftc -swift-version 6 -parse-as-library -sdk "$sdk_path" \
    -plugin-path "$(xcode-select -p)/usr/lib/swift/host/plugins/testing" \
    -I "$bin_path/Modules" \
    -I .build/checkouts/swift-cmark/src/include \
    -I .build/checkouts/swift-cmark/extensions/include \
    -F "$frameworks" -Xlinker -rpath -Xlinker "$frameworks" \
    -Xlinker -rpath -Xlinker "$(xcode-select -p)/Library/Developer/usr/lib" \
    UITests/ChatInteractionTests.swift Tests/Runner.swift "${objects[@]}" \
    -o "$bin_path/DigDugChatUITests"
"$bin_path/DigDugChatUITests"
