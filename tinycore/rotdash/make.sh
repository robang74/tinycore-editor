gcc -m64 rotdash.c -o rotdash64
strip --strip-unneeded rotdash64
sstrip rotdash64

gcc -m32 rotdash.c -o rotdash32
strip --strip-unneeded rotdash32
sstrip rotdash32
