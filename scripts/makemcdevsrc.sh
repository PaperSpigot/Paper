#!/usr/bin/env bash

(
set -e
PS1="$"

basedir="$(cd "$1" && pwd -P)"
workdir="$basedir/work"
minecraftversion=$(cat "$workdir/BuildData/info.json"  | grep minecraftVersion | cut -d '"' -f 4)
decompiledir="$workdir/Minecraft/$minecraftversion"
nms="$decompiledir/spigot/net/minecraft"
papernms="$basedir/Paper-Server/src/main/java/net/minecraft"
mcdevsrc="${decompiledir}/src/net/minecraft"
rm -rf "${mcdevsrc}"
mkdir -p "${mcdevsrc}"
cd "${nms}"

for file in $(find . -name '*.java')
do
    if [ ! -f "${papernms}/${file}" ]; then
		destdir="${mcdevsrc}"/$(dirname "${file}")
		mkdir -p "${destdir}"
		cp "${file}" "${destdir}"
    fi
done

cd "$basedir"
echo "Built $decompiledir/src to be included in your project for src access";
)
