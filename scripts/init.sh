#!/usr/bin/env bash

(
set -e
PS1="$"
basedir="$(cd "$1" && pwd -P)"
workdir="$basedir/work"
minecraftversion=$(cat "$workdir/BuildData/info.json"  | grep minecraftVersion | cut -d '"' -f 4)
spigotdecompiledir="$workdir/Minecraft/$minecraftversion/spigot"
nms="$spigotdecompiledir"
cb="src/main/java"
gitcmd="git -c commit.gpgsign=false"

# https://stackoverflow.com/a/38595160
# https://stackoverflow.com/a/800644
if sed --version >/dev/null 2>&1; then
  strip_cr() {
    sed -i -- "s/\r//" "$@"
  }
else
  strip_cr () {
    sed -i "" "s/$(printf '\r')//" "$@"
  }
fi

patch=$(which patch 2>/dev/null)
if [ "x$patch" == "x" ]; then
    patch="$basedir/hctap.exe"
fi

# apply patches directly to the file tree
# used to fix issues from upstream source repos
cd "$basedir"
prepatchesdir="$basedir/scripts/pre-source-patches"
for file in $(ls "$prepatchesdir")
do
    if [ $file == "README.md" ]; then
        continue
    fi

    echo "--==-- Applying PRE-SOURCE patch: $file --==--"
    $patch -p0 < "$prepatchesdir/$file"
done

echo "Applying CraftBukkit patches to NMS..."
cd "$workdir/CraftBukkit"
$gitcmd checkout -B patched HEAD >/dev/null 2>&1
rm -rf "$cb/net"
# create baseline NMS import so we can see diff of what CB changed
while IFS= read -r -d '' file
do
    patchFile="$file"
    file="$(echo "$file" | cut -d "/" -f2- | cut -d. -f1).java"
    mkdir -p "$(dirname $cb/"$file")"
    cp "$nms/$file" "$cb/$file"
done <   <(find nms-patches -type f -print0)
$gitcmd add --force src
$gitcmd commit -m "Minecraft $ $(date)" --author="Vanilla <auto@mated.null>"

# apply patches
while IFS= read -r -d '' file
do
    patchFile="$file"
    file="$(echo "$file" | cut -d "/" -f2- | cut -d. -f1).java"

    echo "Patching $file < $patchFile"
    set +e
    strip_cr "$nms/$file" > /dev/null
    set -e

    "$patch" -d src/main/java -p 1 < "$patchFile"
done <   <(find nms-patches -type f -print0)

$gitcmd add --force src
$gitcmd commit -m "CraftBukkit $ $(date)" --author="CraftBukkit <auto@mated.null>"
$gitcmd checkout -f HEAD~2
)
