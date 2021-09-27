#!/bin/bash

# Notes:
# - local thumbnails are the thumbnails stored in the standard thumbnail location of the system
# - shared thumbnails are the ones placed in Shared Thumbnail Repositories
# - this script was created and tested for Thunar and Tumbler, different file-manager/thumbnailer
# combos might require some small changes regarding the exact form of the paths/uris given but 
# the main logic should be the same 

directory=$1
if [ ! -e $directory ]; then
    echo "Directory not found"
    exit 2
fi

if [ -z "$XDG_CACHE_HOME" ]
then
	localThumbnailsRepo="$HOME/.cache/"
else
	localThumbnailsRepo="$XDG_CACHE_HOME/"
fi

localThumbnailsRepo+="thumbnails/"
localNormalFolder="${localThumbnailsRepo}normal/"
localLargeFolder="${localThumbnailsRepo}large/"

# change separator to newline to iterate through filepaths correctly
IFS=$'\n'

# recursively create shared thumbnail repositories
for file in $(find $directory -name "*.jpg"); do # TODO: Support more filetypes
	filePath=$(realpath "$file")
	fileDir=$(dirname "$filePath")

	# used request the creation of a local thumbnail
	#
	fakeUri="file://$filePath"
	md5FakeUri=`echo -n "$fakeUri" | md5sum | cut -d" " -f1`

	# used to copy the local thumbnail to a shared repository
	#
	realUri=$(python3 -c "import sys, pathlib; print(pathlib.Path(input()).resolve().as_uri())" <<< $fakeUri) # encode special chars like ' '
	md5Shared=`echo -n "$(basename $realUri)" | md5sum | cut -d" " -f1`

	# shared locations
	#
	sharedThumbnailsRepo="${fileDir}/.sh_thumbnails/"
	sharedNormalFolder="${sharedThumbnailsRepo}normal/"
	sharedLargeFolder="${sharedThumbnailsRepo}large/"
	sharedNormalThumbnail="${sharedNormalFolder}${md5Shared}.png"
	sharedLargeThumbnail="${sharedLargeFolder}${md5Shared}.png"

    
	# If a shared "Normal"-size thumbnail does not exist then create one.
	#
	if [ ! -e $sharedNormalThumbnail ]; then
		# 1. Request the creation of a "Normal"-size thumbnail by the dbus thumbnailer.
		normal="${localNormalFolder}${md5FakeUri}.png"
		if [ ! -e $normal ]; then
			cmd="dbus-send --session --print-reply --dest=org.freedesktop.thumbnails.Thumbnailer1 /org/freedesktop/thumbnails/Thumbnailer1 org.freedesktop.thumbnails.Thumbnailer1.Queue array:string:\"$fakeUri\" array:string:\"image/png\" string:\"normal\" string:\"default\" uint32:0"
			eval $cmd
		fi
		# 2. Wait until the thumbnail is created.
		while [ ! -e $normal ]
		do
			# echo "sleep1 $normal"
			$(sleep 0.05)
		done
		# 3. Copy that thumbnail to the proper Shared Thumbnail Repository.
		$(mkdir -p $sharedNormalFolder)
		$(cp $normal $sharedNormalThumbnail)
		# echo "copy $normal to $sharedNormalThumbnail"
	fi
    
	# Do the same for "Large"-size thumbnails
	#
	if [ ! -e $sharedLargeThumbnail ]; then
		large="${localLargeFolder}${md5FakeUri}.png"
		if [ ! -e $large ]; then
			cmd="dbus-send --session --print-reply --dest=org.freedesktop.thumbnails.Thumbnailer1 /org/freedesktop/thumbnails/Thumbnailer1 org.freedesktop.thumbnails.Thumbnailer1.Queue array:string:\"$fakeUri\" array:string:\"image/png\" string:\"large\" string:\"default\" uint32:0"
			eval $cmd
		fi
		while [ ! -e $large ]
		do
			# echo "sleep2"
			$(sleep 0.05)
		done
		
		$(mkdir -p $sharedLargeFolder)
		$(cp $large $sharedLargeThumbnail)
		# echo "copy $large to $sharedLargeThumbnail"
	fi
done
