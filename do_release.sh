DEPLOY=deploy/venus
REMOTE=victron_www@updates-origin.victronenergy.com
D=/var/www/victron_www/feeds/venus/
FEED="$REMOTE:$OPKG"

if [ $# -eq 0 ]; then
	echo "Usage: $0 release|candidate|testing"
	exit 1
fi

call() {
	# call ssh to run on a remotely
	ssh $REMOTE "$@"

	# run it locally instead for testing
	# eval "$@"
}

function release ()
{
	from="$D$1"
	to="$D$2"
	exclude=""
	# Set this to only release large images. Note: it will rsync all packages.
	# exclude="--include=images/* --include='images/*/venus-swu-*large-*' --include='images/*/venus-image-*large-*' --exclude=images/*/*"

	echo $from $to
	call "if [ ! -d $to ]; then mkdir $to; fi"

	# upload the files
	call "rsync -v $exclude -rpt --no-links $from/ $to"

	# thereafter update the symlinks and in the end delete the old files
	call "rsync -v $exclude -rptl $from/ $to"

	# keep all released images
	if [ "$2" = "release" ]; then
		exclude="$exclude --exclude=images/"
	fi

	call "rsync -v $exclude -rpt --delete $from/ $to"
}

case $1 in
	release )
		echo "Candidate -> Release"
		release candidate release
		;;
	candidate )
		echo "Testing -> Candidate"
		release testing candidate
		;;
	testing )
		echo "Develop -> Testing"
		release develop testing
		;;
	skip-candidate )
		echo "Testing -> Release (skips candidate!)"
		read -n1 -r -p "Press any key to continue... Or CTRL-C to abort"
		release testing release
		;;
	skip-testing )
		echo "Develop -> Candidate (skips testing!)"
		read -n1 -r -p "Press any key to continue... Or CTRL-C to abort"
		release develop candidate
		;;
	*)
		echo "Not a valid parameter"
		;;
esac
