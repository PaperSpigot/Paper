#!/bin/bash
set -e
PS1="$"
basedir="$(cd "$1" && pwd -P)"
workdir="$basedir/work"
minecraftversion=$(cat "$workdir/BuildData/info.json"  | grep minecraftVersion | cut -d '"' -f 4)
decompiledir="$workdir/$minecraftversion"


#
# FUNCTIONS
#

c() {
    if [ $2 ]; then
            echo -e "\e[$1;$2m"
    else
            echo -e "\e[$1m"
    fi
}
ce() {
    echo -e "\e[m"
}

updateTest() {
    git stash -u >/dev/null 2>&1 || (return 0) # errors are ok
    git reset --hard origin/master
    git stash pop >/dev/null 2>&1 || (return 0) # errors are ok
}

papertestdir="${PAPER_TEST_DIR:-$workdir/test-server}"

mkdir -p "$papertestdir"
cd "$papertestdir"

#
# SKELETON CHECK
#

if [ ! -d .git ]; then
    git init
    git remote add origin ${PAPER_TEST_SKELETON:-https://github.com/PaperMC/PaperTestServer}
    git fetch origin
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

if [ -z "$(grep true eula.txt 2>/dev/null)" ]; then
    echo
    echo "$(c 32)  It appears you have not agreed to Mojangs EULA yet! Press $(c 1 33)y$(ce) $(c 32)to confirm agreement to"
    read -p "  Mojangs EULA found at:$(c 1 32) https://account.mojang.com/documents/minecraft_eula $(ce) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "$(c 1 31)Aborted$(ce)"
        exit;
    fi
    echo "eula=true" > eula.txt
fi

#
# JAR CHECK
#

jar="$basedir/Paper-Server/target/paper-${minecraftversion}.jar"
if [ ! -f "$jar" ] || [ "$2" == "build" ] || [ "$3" == "build" ]; then
(
    echo "Building Paper"
    cd "$basedir"
    ./paper jar
)
fi


#
# JVM FLAGS
#

baseargs="-server -Xmx${PAPER_TEST_MEMORY:-2G} -Dfile.encoding=UTF-8 -XX:MaxGCPauseMillis=50 -XX:+UseG1GC"
baseargs="$baseargs -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=70 "

cmd="java ${PAPER_TEST_BASE_JVM_ARGS:-$baseargs} ${PAPER_TEST_EXTRA_JVM_ARGS} -jar $jar"

#
# MULTIPLEXER CHOICE
#

multiplex=${PAPER_TEST_MULTIPLEXER:-screen}
if [ "$multiplex" == "tmux" ]; then
    echo "tmux is currently not supported. Please submit a PR to add tmux support if you need it.";
    multiplex="screen"
fi

if [ "$multiplex" == "tmux" ] && [ ! -z "$(which tmux)" ]; then
    echo "tmux not supported"
elif [ ! -z "$(which screen)" ]; then # default screen last as final fallback
    cmd="screen -DURS papertest $cmd >> logs/screen.log 2>&1"
else
    echo "Screen not found - It is strongly recommended to install screen"
    sleep 3
fi

#
# START / LOG
#

$cmd | tee ${PAPER_TEST_OUTPUT_LOG:-logs/output.log}
