#!/bin/bash

# Notes:
# - local thumbnails are the thumbnails stored in the standard thumbnail location of the system
# - shared thumbnails are the ones placed in Shared Thumbnail Repositories
# - this script was created and tested for Thunar and Tumbler, different file-manager/thumbnailer
# combos might require some small changes regarding the exact form of the paths/uris given but 
# the main logic should be the same 
# - currently the script supports local files only (only 'file://' uri prefixes)

# Prerequisites
# - python3
# - realpath
# - a Thumbnailer that works as described in the Thumbnail management DBus specification

directory=$1
if [ ! -e $directory ]; then
    echo "Directory not found"
    exit 1
fi

if [ ! "python3 --version &> /dev/null" ]; then
	echo "python3 not found"
	exit 2
fi

if [ ! "realpath --version &> /dev/null" ]; then
	echo "realpath not found"
	exit 3
fi

if [ -z "$XDG_CACHE_HOME" ]; then
	localThumbnailsRepo="$HOME/.cache/"
else
	localThumbnailsRepo="$XDG_CACHE_HOME/"
fi
localThumbnailsRepo+="thumbnails/"

# create find-arguments from supported filetypes
#
args=()
# args+=(-o -name "*.jpg")
# args+=(-o -name "*.png")

# get supported file types 
#
filetypes=($(dbus-send --session --print-reply --dest=org.freedesktop.thumbnails.Thumbnailer1 /org/freedesktop/thumbnails/Thumbnailer1 org.freedesktop.thumbnails.Thumbnailer1.GetSupported))

# echo ${#filetypes[@]}
let "total_entries = ${#filetypes[@]} - 8"
let "offset = $total_entries / 2"

for (( i=11; i<$offset+8; i+=2 )); do
	# get uri type
	type=${filetypes[i]}
	type="${type:1:-1}"
	if [ $type != "file" ]; then
		continue
	fi
	# get mime
	let "mime_index = $i + $offset"
	mime=${filetypes[mime_index]}
	mime="${mime:1:-1}"
	# echo $mime
	# get extensions
	extensions="$(grep "$mime" /etc/mime.types)"
	if [ -z "$extensions" ]; then
		continue
	fi
	for ext in $extensions; do
		if [[ $ext != *"/"* ]]; then
			if [[ $ext != *":"* ]]; then 
				if [[ $ext != *","* ]]; then 
					if [[ $ext != "#" ]] && [[ $ext != "obsoleted" ]]; then 
						# echo $ext
						args+=(-o -name "*.$ext")
					fi
				fi
			fi
		fi
	done
	# echo $extensions	
done
unset 'args[0]'

# get supported thumbnail sizes
#
sizes=($(dbus-send --session --print-reply --dest=org.freedesktop.thumbnails.Thumbnailer1 /org/freedesktop/thumbnails/Thumbnailer1 org.freedesktop.thumbnails.Thumbnailer1.GetFlavors))

for (( i=11; i<${#sizes[@]}; i+=2 )); do
	size=${sizes[i]}
	# remove quotes at the beginning and end
	size="${size:1:-1}"

	localNormalFolder="${localThumbnailsRepo}${size}/"

	# change separator to newline to iterate through filepaths correctly
	IFS=$'\n'

	# recursively create shared thumbnail repositories
	for file in $(find "$directory" -type f \( "${args[@]}" \) ); do
		filePath=$(realpath "$file")
		fileDir=$(dirname "$filePath")

		# skip existing shared thumbnails
		#
		if [[ $fileDir == *".sh_thumbnails"* ]]; then
			continue
		fi

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
		sharedNormalFolder="${sharedThumbnailsRepo}${size}/"
		sharedNormalThumbnail="${sharedNormalFolder}${md5Shared}.png"

		
		# If a shared "Normal"-size thumbnail does not exist then create one.
		#
		if [ ! -e $sharedNormalThumbnail ]; then
			# 1. Request the creation of a "Normal"-size thumbnail by the dbus thumbnailer.
			normal="${localNormalFolder}${md5FakeUri}.png"
			file_mime=$(file -b --mime-type "$filePath")
			# echo $file_mime
			if [ ! -e $normal ]; then
				cmd="dbus-send --session --print-reply --dest=org.freedesktop.thumbnails.Thumbnailer1 /org/freedesktop/thumbnails/Thumbnailer1 org.freedesktop.thumbnails.Thumbnailer1.Queue array:string:\"$fakeUri\" array:string:\"$file_mime\" string:\"$size\" string:\"default\" uint32:0"
				# echo $cmd
				eval $cmd
			fi
			# 2. Wait until the thumbnail is created.
			while [ ! -e $normal ]; do
				# echo "sleep1 $normal"
				$(sleep 0.05)
			done
			# 3. Copy that thumbnail to the proper Shared Thumbnail Repository.
			$(mkdir -p $sharedNormalFolder)
			$(cp $normal $sharedNormalThumbnail)
			# echo "copy $normal to $sharedNormalThumbnail"
		fi
	done
done
