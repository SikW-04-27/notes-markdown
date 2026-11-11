#!/bin/zsh
set -eu
project_dir="${0:A:h:h}"
cd "$project_dir"

if [[ "${1:-}" != "--skip-build" ]]; then
    zsh "$project_dir/scripts/build.sh"
fi

bundle_dir="$project_dir/dist/Notes Markdown.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle_dir/Contents/Info.plist")"
architectures="$(lipo -archs "$bundle_dir/Contents/MacOS/NotesMarkdown")"
if [[ "$architectures" != "arm64" ]]; then
    print -u2 "This packaging guide currently describes arm64 only; found: $architectures"
    exit 1
fi
codesign --verify --strict "$bundle_dir"

release_name="Notes-Markdown-${version}-arm64-preview"
stage_dir="$(mktemp -d "$project_dir/.build/package.XXXXXX")"
release_dir="$stage_dir/$release_name"
mkdir -p "$release_dir"
cp "$project_dir/docs/start.html" "$release_dir/00-先读我-START-HERE.html"
ditto "$project_dir/docs/guide-assets" "$release_dir/guide-assets"
ditto "$bundle_dir" "$release_dir/Notes Markdown.app"
cp "$project_dir/INSTALL.zh-CN.md" "$release_dir/INSTALL.zh-CN.md"
cp "$project_dir/INSTALL.en.md" "$release_dir/INSTALL.en.md"
cp "$project_dir/README.md" "$release_dir/README.md"
cp "$project_dir/README.en.md" "$release_dir/README.en.md"
cp "$project_dir/LICENSE" "$release_dir/LICENSE"

archive_path="$project_dir/dist/$release_name.zip"
if [[ -e "$archive_path" ]]; then
    archive_backup_dir="$(mktemp -d "$project_dir/dist/previous.XXXXXX")"
    mv "$archive_path" "$archive_backup_dir/"
    if [[ -e "$archive_path.sha256" ]]; then
        mv "$archive_path.sha256" "$archive_backup_dir/"
    fi
fi
ditto -c -k --sequesterRsrc --keepParent "$release_dir" "$archive_path"
(
    cd "$project_dir/dist"
    LC_ALL=C /usr/bin/shasum -a 256 "$release_name.zip" > "$release_name.zip.sha256"
)
print "Package: $archive_path"
print "Checksum: $archive_path.sha256"
