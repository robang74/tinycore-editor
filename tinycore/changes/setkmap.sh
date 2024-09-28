if [ "$1" != "" ]; then
    kn=$(ls -1 /usr/share/kmap/*/$1.kmap)
    if [ -r "$kn" ]; then
        sudo loadkmap < "$kn"
    else
        echo "ERROR: keyboard map file '$1.kmap' not found"
    fi
else
    echo "USAGE: $(basename $0) it"
fi
