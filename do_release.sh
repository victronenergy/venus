DEPLOY=deploy/venus
REMOTE=victron_www@updates.victronenergy.com
D=/var/www/victron_www/feeds/venus/
FEED="$REMOTE:$OPKG"

if [ $# -eq 0 ]; then
	echo "Usage: $0 release|candidate|testing"
	exit 1
fi

function release ()
{
	from="$D$1"
	to="$D$2"
	exclude="--exclude=images/ccgxhf/"

	echo $from $to
	ssh $REMOTE "if [ ! -d $to ]; then mkdir $to; fi"

	# upload the files
	ssh $REMOTE "rsync -v $exclude -rpt --no-links $from/ $to"

	# thereafter update the symlinks and in the end delete the old files
	ssh $REMOTE "rsync -v $exclude -rptl $from/ $to"

	# keep all released images
	if [ "$to" = "release" ]; then
		exclude="$exclude --exclude=images/"
	fi

	ssh $REMOTE "rsync -v $exclude -rpt --delete $from/ $to"
}

case $1 in
	release )
		echo "Publish release"
		release candidate release
		;;
	candidate )
		echo "Publish candidate"
		release testing candidate
		;;
	testing )
		release develop testing
		;;
	*)
		echo "Not a valid parameter"
		;;
esac
