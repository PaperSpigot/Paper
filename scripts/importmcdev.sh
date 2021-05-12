#!/usr/bin/env bash

(
set -e
nms="net/minecraft"
export MODLOG=""
PS1="$"
basedir="$(cd "$1" && pwd -P)"
source "$basedir/scripts/functions.sh"
gitcmd="git -c commit.gpgsign=false"

workdir="$basedir/work"
minecraftversion=$(cat "$workdir/BuildData/info.json"  | grep minecraftVersion | cut -d '"' -f 4)
decompiledir="$workdir/Minecraft/$minecraftversion/forge"
# replace for now
decompiledir="$workdir/Minecraft/$minecraftversion/spigot"
export importedmcdev=""
function import {
    export importedmcdev="$importedmcdev $1"
    file="${1}.java"
    target="$workdir/Spigot/Spigot-Server/src/main/java/$nms/$file"
    base="$decompiledir/$nms/$file"

    if [[ ! -f "$target" ]]; then
        export MODLOG="$MODLOG  Imported $file from mc-dev\n";
        #echo "Copying $base to $target"
        mkdir -p "$(dirname "$target")"
        cp "$base" "$target" || exit 1
    else
        echo "UN-NEEDED IMPORT: $file"
    fi
}

function importLibrary {
    group=$1
    lib=$2
    prefix=$3
    shift 3
    for file in "$@"; do
        file="$prefix/$file"
        target="$workdir/Spigot/Spigot-Server/src/main/java/${file}"
        targetdir=$(dirname "$target")
        mkdir -p "${targetdir}"
        base="$workdir/Minecraft/$minecraftversion/libraries/${group}/${lib}/$file"
        if [ ! -f "$base" ]; then
            echo "Missing $base"
            exit 1
        fi
        export MODLOG="$MODLOG  Imported $file from $lib\n";
        sed 's/\r$//' "$base" > "$target" || exit 1
    done
}

(
    cd "$workdir/Spigot/Spigot-Server/"
    lastlog=$($gitcmd log -1 --oneline)
    if [[ "$lastlog" = *"mc-dev Imports"* ]]; then
        $gitcmd reset --hard HEAD^
    fi
)


files=$(cat "$basedir/Spigot-Server-Patches/"* | grep "+++ b/src/main/java/net/minecraft/" | sort | uniq | sed 's/\+\+\+ b\/src\/main\/java\/net\/minecraft\///g')

nonnms=$(grep -R "new file mode" -B 1 "$basedir/Spigot-Server-Patches/" | grep -v "new file mode" | grep -oE --color=none "net\/minecraft\/.*.java" | sed 's/.*\/net\/minecraft\///g')
function containsElement {
	local e
	for e in "${@:2}"; do
		[[ "$e" == "$1" ]] && return 0;
	done
	return 1
}
set +e
for f in $files; do
	containsElement "$f" ${nonnms[@]}
	if [ "$?" == "1" ]; then
		if [ ! -f "$workdir/Spigot/Spigot-Server/src/main/java/net/minecraft/$f" ]; then
      f="$(echo "$f" | sed 's/.java//g')"
			if [ ! -f "$decompiledir/$nms/$f.java" ]; then
				echo "$(color 1 31) ERROR!!! Missing NMS$(color 1 34) $f $(colorend)";
				error=true
			else
				import $f
			fi
		fi
	fi
done
if [ -n "$error" ]; then
  exit 1
fi

########################################################
########################################################
########################################################
#                   NMS IMPORTS
# Temporarily add new NMS dev imports here before you run paper patch
# but after you have paper rb'd your changes, remove the line from this file before committing.
# we do not need any lines added to this file for NMS

# import FileName


########################################################
########################################################
########################################################
#              LIBRARY IMPORTS
# These must always be mapped manually, no automatic stuff
#
#             # group    # lib          # prefix               # many files

# dont forget \ at end of each line but last
importLibrary com.mojang authlib com/mojang/authlib yggdrasil/YggdrasilGameProfileRepository.java
importLibrary com.mojang datafixerupper com/mojang/datafixers DataFixerBuilder.java
importLibrary com.mojang datafixerupper com/mojang/datafixers/util Either.java
importLibrary com.mojang datafixerupper com/mojang/serialization/codecs KeyDispatchCodec.java
importLibrary com.mojang datafixerupper com/mojang/serialization Dynamic.java

########################################################
########################################################
########################################################
set -e
cd "$workdir/Spigot/Spigot-Server/"
rm -rf nms-patches applyPatches.sh makePatches.sh >/dev/null 2>&1
$gitcmd add --force . -A >/dev/null 2>&1
echo -e "mc-dev Imports\n\n$MODLOG" | $gitcmd commit . -F -
)
