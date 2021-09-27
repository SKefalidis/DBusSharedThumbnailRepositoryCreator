#!/bin/bash
directory=$1
if [ ! -e $directory ]; then
    echo "Directory not found"
    exit 2
fi

currentDirectory=$(pwd)
directoryPath="$currentDirectory/$directory"

if [ -z "$XDG_CACHE_HOME" ]
then
	thumbnailsPath="$HOME/.cache/"
else
	thumbnailsPath="$XDG_CACHE_HOME/"
fi

thumbnailsPath+="thumbnails/"
normalThumbnailsPath="${thumbnailsPath}normal/"
largeThumbnailsPath="${thumbnailsPath}large/"

IFS=$'\n' # change separator to newline
for file in $(find $directory -name "*.jpg"); do	
	# important location
	filePath=$(realpath "$file")
	fileDir=$(dirname "$filePath")
	uri="file://$filePath"
	md5_uri=`echo -n "$uri" | md5sum | cut -d" " -f1`
	filePathEncoded=$(python3 -c "import sys, pathlib; print(pathlib.Path(input()).resolve().as_uri())" <<< $filePath)
	md5_shared=`echo -n "$(basename $filePathEncoded)" | md5sum | cut -d" " -f1`

	# shared locations
	sharedRepo="${fileDir}/.sh_thumbnails/"
	sharedNormalFolder="${sharedRepo}normal/"
	sharedLargeFolder="${sharedRepo}large/"
	sharedNormalThumbnail="${sharedNormalFolder}${md5_shared}.png"
	sharedLargeThumbnail="${sharedLargeFolder}${md5_shared}.png"

    
	# If a shared "Normal"-size thumbnail does not exist then create one.
	#
	# 1. Request the creation of a "Normal"-size thumbnail by the dbus thumbnailer.
	# 2. Wait until the thumbnail is created.
	# 3. Copy that thumbnail to the proper Shared Thumbnail Repository.
	if [ ! -e $sharedNormalThumbnail ]; then
		normal="${normalThumbnailsPath}${md5_uri}.png"
		if [ ! -e $normal ]; then
			cmd="dbus-send --session --print-reply --dest=org.freedesktop.thumbnails.Thumbnailer1 /org/freedesktop/thumbnails/Thumbnailer1 org.freedesktop.thumbnails.Thumbnailer1.Queue array:string:\"$uri\" array:string:\"image/png\" string:\"normal\" string:\"default\" uint32:0"
			eval $cmd
		fi
		while [ ! -e $normal ]
		do
			echo "sleep1 $normal"
			$(sleep 0.05)
		done

		$(mkdir -p $sharedNormalFolder)
		$(cp $normal $sharedNormalThumbnail)
		echo "copy $normal to $sharedNormalThumbnail"
	fi
    
	# Do the same for "Large"-size thumbnails
	if [ ! -e $sharedLargeThumbnail ]; then
		large="${largeThumbnailsPath}${md5_uri}.png"
		if [ ! -e $large ]; then
			cmd="dbus-send --session --print-reply --dest=org.freedesktop.thumbnails.Thumbnailer1 /org/freedesktop/thumbnails/Thumbnailer1 org.freedesktop.thumbnails.Thumbnailer1.Queue array:string:\"$uri\" array:string:\"image/png\" string:\"large\" string:\"default\" uint32:0"
			eval $cmd
		fi
		while [ ! -e $large ]
		do
			echo "sleep2"
			$(sleep 0.05)
		done
		
		$(mkdir -p $sharedLargeFolder)
		$(cp $large $sharedLargeThumbnail)
		echo "copy $large to $sharedLargeThumbnail"
	fi
done
