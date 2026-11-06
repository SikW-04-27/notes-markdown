#!/bin/zsh
set -eu
project_dir="${0:A:h:h}"
cd "$project_dir"
xcrun swift "$project_dir/scripts/generate-icon.swift"
iconutil -c icns "$project_dir/.build/AppIcon.iconset" -o "$project_dir/Resources/AppIcon.icns"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
bundle_dir="$project_dir/dist/Notes Markdown.app"
mkdir -p "$bundle_dir/Contents/MacOS" "$bundle_dir/Contents/Resources"
cp "$binary_dir/NotesMarkdown" "$bundle_dir/Contents/MacOS/NotesMarkdown"
cp "$project_dir/Resources/Info.plist" "$bundle_dir/Contents/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$bundle_dir/Contents/Resources/AppIcon.icns"
# Use the default ad hoc identity for preview builds. Public trusted distribution
# requires Developer ID signing and notarization; don't trust a bundle ID alone.
codesign --force --sign - --identifier local.notes-markdown.app "$bundle_dir"
codesign --verify --strict "$bundle_dir"
touch "$bundle_dir"
print "Built: $bundle_dir"
