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
	filePath=$(realpath "$file")
	uri="file://$filePath"
	echo $uri
	md5=`echo -n "$uri" | md5sum | cut -d" " -f1`
    echo "$md5"
    
    normal="${normalThumbnailsPath}${md5}.png"
    if [ ! -e $normal ]; then
    	cmd="dbus-send --session --print-reply --dest=org.freedesktop.thumbnails.Thumbnailer1 /org/freedesktop/thumbnails/Thumbnailer1 org.freedesktop.thumbnails.Thumbnailer1.Queue array:string:\"$uri\" array:string:\"image/png\" string:\"normal\" string:\"default\" uint32:0"
    	eval $cmd
	fi
	while [ ! -e $normal ]
	do
		$(sleep 0.05)
	done
    
    large="${largeThumbnailsPath}${md5}.png"
    if [ ! -e $large ]; then
    	cmd="dbus-send --session --print-reply --dest=org.freedesktop.thumbnails.Thumbnailer1 /org/freedesktop/thumbnails/Thumbnailer1 org.freedesktop.thumbnails.Thumbnailer1.Queue array:string:\"$uri\" array:string:\"image/png\" string:\"large\" string:\"default\" uint32:0"
    	eval $cmd
	fi
	while [ ! -e $large ]
	do
		$(sleep 0.05)
	done
    
    fileDir=$(dirname "$filePath")
	localRepo="${fileDir}/.sh_thumbnails/"
	normalLocalRepo="${localRepo}normal/"
	largeLocalRepo="${localRepo}large/"
	
	$(mkdir -p $normalLocalRepo)
	$(mkdir -p $largeLocalRepo)
	
	md5=`echo -n "$(basename $filePath)" | md5sum | cut -d" " -f1`
	localNormal="${normalLocalRepo}${md5}.png"
	localLarge="${largeLocalRepo}${md5}.png"
	$(cp $normal $localNormal)
	$(cp $large $localLarge)
done

