#!/bin/bash

#
# Copies all DLL dependencies of executable "$executable" and all GST plugins to "$output_dir"
#

set -e

# Blacklist plugins we don't need that cause problems (fail to load)
GST_BLACKLISTED_PLUGINS="libgstcodec2json"

executable=$(cygpath -u "$1")
output_dir=$(cygpath -u "$2")

gst_plugins_path=$(dirname "$(which gst-launch-1.0.exe)")/../lib/gstreamer-1.0
gst_output_dir="$output_dir/gst/plugins"

pylon_plugins_path="$(cygpath -u "$3")/../Runtime/x64/"

declare -A deps

function copy_pe_deps() {
    local pe="$1"
    local dest="$2"

    local dep
    while read dep; do
        if [[ "$dep" =~ ^\s*$ ]]; then
           continue
        fi
        if [ -f "$dest/$(basename "$dep")" ]; then
            continue
        fi
        local old_val=${deps[$dep]}
        deps[$dep]=1
        if [ "$old_val" != "1" ]; then
            copy_pe_deps "$dep" "$dest"
        fi
        cp "$dep" "$dest"
    done < <(ldd "$pe" | sed -n -r '/=> .*\.dll/s,.*=> (\S+).*,\1,p' | grep -v '^/c/' | sort -u)
}

copy_pe_deps "$executable" "$output_dir"

# copy GST plugins and their dependencies
mkdir -p "$gst_output_dir"
for plugin in "$gst_plugins_path"/*.dll; do
    plugin_name=$(basename "$plugin")
    if grep -qw "${plugin_name%%.*}" <<< "$GST_BLACKLISTED_PLUGINS"; then
        continue
    fi
    if [ -f "$gst_output_dir/$plugin_name" ]; then
        continue
    fi
    cp "$plugin" "$gst_output_dir"
    copy_pe_deps "$plugin" "$output_dir"
done

if test -d "$pylon_plugins_path"; then
    echo "Copying Pylon DLLs."
    for plugin in "$pylon_plugins_path"/*.dll; do
        cp "$plugin" "$output_dir"
    done
fi
