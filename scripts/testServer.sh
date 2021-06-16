#!/usr/bin/env bash

set -e
PS1="$"
basedir="$(cd "$1" && pwd -P)"
workdir="$basedir/work"
minecraftversion="$(grep minecraftVersion "$workdir/BuildData/info.json" | cut -d '"' -f 4)"
gitcmd="git -c commit.gpgsign=false"

#
# FUNCTIONS
#
source "$basedir"/scripts/functions.sh

updateTest() {
    paperstash
    $gitcmd reset --hard origin/master
    paperunstash
}

papertestdir="${PAPER_TEST_DIR:-$workdir/test-server}"

mkdir -p "$papertestdir"
cd "$papertestdir"

#
# SKELETON CHECK
#

if [ ! -d .git ]; then
    $gitcmd init
    $gitcmd remote add origin "${PAPER_TEST_SKELETON:-https://github.com/PaperMC/PaperTestServer}"
    $gitcmd fetch origin
    updateTest
elif [ "$2" == "update" ] || [ "$3" == "update" ]; then
    updateTest
fi

if [ ! -f server.properties ] || [ ! -d plugins ]; then
    echo " "
    echo " Checking out Test Server Skeleton"
    updateTest
fi


#
# EULA CHECK
#

if ! grep -q true eula.txt 2>/dev/null; then
    echo
    echo "$(color 32)  It appears you have not agreed to Mojangs EULA yet! Press $(color 1 33)y$(colorend) $(color 32)to confirm agreement to"
    read -p "  Mojangs EULA found at:$(color 1 32) https://account.mojang.com/documents/minecraft_eula $(colorend) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "$(color 1 31)Aborted$(colorend)"
        exit;
    fi
    echo "eula=true" > eula.txt
fi

#
# JAR CHECK
#

folder="$basedir/Paper-Server"
jar="$folder/target/paper-${minecraftversion}.jar"
if [ -n "$PAPER_JAR" ]; then
    jar="$PAPER_JAR"
fi
if [ ! -d "$folder" ]; then
(
    echo "Building Patched Repo"
    cd "$basedir"
    ./paper patch
)
fi

if [ "$2" == "build" ] || [ "$3" == "build" ]; then
(
    echo "Building Paper"
    cd "$basedir"
    mvn package
)
fi
#
# JVM FLAGS
#

if [ -f "$jar" ]; then
    cp "$jar" paper.jar
fi
baseargs="-server -Xms${PAPER_MIN_TEST_MEMORY:-512M} -Xmx${PAPER_TEST_MEMORY:-2G} -Dfile.encoding=UTF-8 -XX:MaxGCPauseMillis=150 -XX:+UseG1GC "
baseargs="$baseargs -DIReallyKnowWhatIAmDoingISwear=1 "
baseargs="$baseargs -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=40 -XX:G1MaxNewSizePercent=60 "
baseargs="$baseargs -XX:InitiatingHeapOccupancyPercent=10 -XX:G1MixedGCLiveThresholdPercent=80 "
baseargs="$baseargs -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5100"


cmd="java ${PAPER_TEST_BASE_JVM_ARGS:-$baseargs} ${PAPER_TEST_EXTRA_JVM_ARGS} -jar paper.jar ${PAPER_TEST_APP_ARGS:-} nogui"
screen_command="screen -DURS papertest $cmd"
tmux_command="tmux new-session -A -s Paper -n 'Paper Test' -c '$(pwd)' '$cmd'"

#
# MULTIPLEXER CHOICE
#

multiplex=${PAPER_TEST_MULTIPLEXER}

if [ -n "$PAPER_NO_MULTIPLEX" ]; then
	cmd="$cmd"
elif [ "$multiplex" == "screen" ]; then
    if command -v "screen" >/dev/null 2>&1 ; then
        cmd="$screen_command"
    else
        echo "screen not found"
        exit 1
    fi
elif [ "$multiplex" == "tmux" ] ; then
    if command -v "tmux" >/dev/null 2>&1 ; then
        cmd="$tmux_command"
    else
        echo "tmux not found"
        exit 1
    fi
else
    if command -v "screen" >/dev/null 2>&1 ; then
        cmd="$screen_command"
    elif command -v "tmux" >/dev/null 2>&1 ; then
        cmd="$tmux_command"
    else
        echo "screen or tmux not found - it is strongly recommended to install either"
        echo "No terminal multiplexer will be used"
    fi
fi

#
# START / LOG
#

if [ -n "$PAPER_TEST_COMMAND_WRAPPER" ]; then
    $PAPER_TEST_COMMAND_WRAPPER "$cmd"
else
    echo "Running command: $cmd"
    echo "In directory: $(pwd)"
    #sleep 1
    /usr/bin/env bash -c "$cmd"
fi
