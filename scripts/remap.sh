#!/usr/bin/env bash

(
set -e
PS1="$"
basedir="$(cd "$1" && pwd -P)"
workdir="$basedir/work"
minecraftversion="$(cat "${workdir}/BuildData/info.json" | grep minecraftVersion | cut -d '"' -f 4)"
minecraftserverurl=$(cat "${workdir}/BuildData/info.json" | grep serverUrl | cut -d '"' -f 4)
minecrafthash=$(cat "${workdir}/BuildData/info.json" | grep minecraftHash | cut -d '"' -f 4)
accesstransforms="$workdir/BuildData/mappings/"$(cat "${workdir}/BuildData/info.json" | grep accessTransforms | cut -d '"' -f 4)
classmappings="$workdir/BuildData/mappings/"$(cat "${workdir}/BuildData/info.json" | grep classMappings | cut -d '"' -f 4)
membermappings="$workdir/BuildData/mappings/"$(cat "${workdir}/BuildData/info.json" | grep memberMappings | cut -d '"' -f 4)
packagemappings="$workdir/BuildData/mappings/"$(cat "${workdir}/BuildData/info.json" | grep packageMappings | cut -d '"' -f 4)
decompiledir="$workdir/Minecraft/$minecraftversion"
jarpath="$decompiledir/$minecraftversion"
mkdir -p "$decompiledir"

echo "Downloading unmapped vanilla jar..."
if [ ! -f  "$jarpath.jar" ]; then
    curl -s -o "$jarpath.jar" "$minecraftserverurl"
    if [ "$?" != "0" ]; then
        echo "Failed to download the vanilla server jar. Check connectivity or try again later."
        exit 1
    fi
fi

# OS X & FreeBSD don't have md5sum, just md5 -r
command -v md5sum >/dev/null 2>&1 || {
    command -v md5 >/dev/null 2>&1 && {
        shopt -s expand_aliases
        alias md5sum='md5 -r'
        echo "md5sum command not found, using an alias instead"
    } || {
        echo >&2 "No md5sum or md5 command found"
        exit 1
    }
}

checksum=$(md5sum "$jarpath.jar" | cut -d ' ' -f 1)
if [ "$checksum" != "$minecrafthash" ]; then
    echo "The MD5 checksum of the downloaded server jar does not match the BuildData hash."
    exit 1
fi

# These specialsource commands are from https://hub.spigotmc.org/stash/projects/SPIGOT/repos/builddata/browse/info.json
echo "Applying class mappings..."
if [ ! -f "$jarpath-cl.jar" ]; then
    java -jar "$workdir/BuildData/bin/SpecialSource-2.jar" map --only . --only net/minecraft --only com/mojang/math --auto-lvt BASIC --auto-member SYNTHETIC -i "$jarpath.jar" -m "$classmappings" -o "$jarpath-cl.jar" 1>/dev/null
    if [ "$?" != "0" ]; then
        echo "Failed to apply class mappings."
        exit 1
    fi
fi

echo "Applying member mappings..."
if [ ! -f "$jarpath-m.jar" ]; then
    java -jar "$workdir/BuildData/bin/SpecialSource-2.jar" map --only . --only net/minecraft --only com/mojang/math --auto-member LOGGER --auto-member TOKENS -i "$jarpath-cl.jar" -m "$membermappings" -o "$jarpath-m.jar" 1>/dev/null
    if [ "$?" != "0" ]; then
        echo "Failed to apply member mappings."
        exit 1
    fi
fi

echo "Creating remapped jar..."
if [ ! -f "$jarpath-mapped.jar" ]; then
    java -jar "$workdir/BuildData/bin/SpecialSource.jar" --only . --only net/minecraft --only com/mojang/math -i "$jarpath-m.jar" --access-transformer "$accesstransforms" -m "$packagemappings" -o "$jarpath-mapped.jar" 1>/dev/null
    if [ "$?" != "0" ]; then
        echo "Failed to create remapped jar."
        exit 1
    fi
fi

echo "Installing remapped jar..."
cd "$workdir/CraftBukkit" # Need to be in a directory with a valid POM at the time of install.
mvn install:install-file -q -Dfile="$jarpath-mapped.jar" -Dpackaging=jar -DgroupId=io.papermc -DartifactId=minecraft-server -Dversion="$minecraftversion-SNAPSHOT"
if [ "$?" != "0" ]; then
    echo "Failed to install remapped jar."
    exit 1
fi
)
