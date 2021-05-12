#!/usr/bin/env bash

gitcmd="git -c commit.gpgsign=false"

noapply=1
isreject=0
if [[ $1 == "--noapplied" ]]; then
	noapply=1
	shift
fi

if [ ! -z "$1" ]; then
	file="$1"
elif [ -z "$1" ] && [ -f .git/rebase-apply/patch ]; then
	file=".git/rebase-apply/patch"
	noapply=1
	isreject=1
else
	echo "Please specify a file"
	exit 1
fi
applied=$(echo $file | sed 's/.patch$/-applied\.patch/g')
if [ "$1" == "--reset" ]; then
	$gitcmd am --abort
	$gitcmd reset --hard
	$gitcmd clean -f
	exit 0
fi


(test "$isreject" != "1" && $gitcmd am -3 $file) || (
	echo "Failures - Wiggling"
	$gitcmd reset --hard
	$gitcmd clean -f
	errors=$($gitcmd apply --rej $file 2>&1)
	echo "$errors" >> ~/patch.log
	export missingfiles=""
	export summaryfail=""
	export summarygood=""
	for i in $(find . -name \*.rej); do
        	base=$(echo "$i" | sed 's/.rej//g')
		if [ -f "$i" ]; then
        		sed -e 's/^diff a\/\(.*\) b\/\(.*\)[[:space:]].*rejected.*$/--- \1\n+++ \2/' -i $i && wiggle -v -l --replace "$base" "$i"
        		rm "$base.porig" "$i"
		else
			echo "No such file: $base"
			missingfiles="$missingfiles\n$base"
		fi
	done
	for i in $($gitcmd status --porcelain | awk '{print $2}'); do
		filedata=$(cat "$i")
		if [ -f "$file" ] && [[ "$filedata" == *"<<<<<"* ]]; then
			export summaryfail="$summaryfail\nFAILED TO APPLY: $i"
		else
			$gitcmd add --force "$i"
			export summarygood="$summarygood\nAPPLIED CLEAN: $i"
		fi
	done
	echo -e "$summarygood"
	echo -e "$summaryfail"
	if [[ "$errors" == *"No such file"* ]]; then
		echo "===========================";
		echo " "
		echo " MISSING FILES"
		echo $(echo "$errors" | grep "No such file")
		echo -e "$missingfiles"
		echo " "
		echo "===========================";
	fi
	$gitcmd status
	$gitcmd diff
)
if [[ "$noapply" != "1" ]] && [[ "$file" != *-applied.patch ]]; then
	mv "$file" "$applied"
fi
