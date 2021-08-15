Extension Creation

- how to to compile, create and submit Tiny Core (TC) extensions (extension_name.tcz)



Prerequisites:

- moderate Linux experience
- good working knowledge of TC
- read Into the Core: A Look at Tiny Core Linux (Lauri Kasanen et al),
  especially chapter 15, PP 73-75, Creating an Extension
     http://distro.ibiblio.org/tinycorelinux/book.html
- review TC wiki, especially:
     http://wiki.tinycorelinux.net/wiki:creating_extensions



Process overview:

- generally utilize configure, make and make install process
- typically separate out docs, locale and development files to keep extensions small
- consider creating additional data extensions if it might help others, example:
     extension_name-doc.tcz
     extension_name-dev.tcz
     extension_name-locale.tcz
- include copyright/license info as required by the software (most GPL don't require this)
- squash everything into your newly created extension (extension_name.tcz)
- prepare addional support files:
     extension_name.tcz.dep        # only if extension requires dependencies
     extension_name.tcz.info       # displayed by Apps, tce-ab
     extension_name.tcz.list       # lists all files/pathways of extension
     extension_name.tcz.md5.txt    # used to verify extension integrity and flag updates
     extension_name.tcz.zsync      # auto-generated when running submitqc6 prior to submission
     extension_name.tcz.build-dep  # optional information to help with future re-compiles
- note: personal extensions/not submitted only require the exension_name.tcz and if applicable extension_name.tcz.dep file
- note: personal data extensions are the easiest to create (no compiling)
     - data extension creation is good practice (terminal work, creating directories, squash tools, etc)
     - see Chapter 14 (Creating a Personal Data Extension), PP 71-72 of the Core book
- tar everything up and gmail as an attachment to TC
- note: many examples below are based on preparing the roguelike game extension named rogue.tcz from within /tmp:
     - temporary compile directory used was /tmp/rog
     - destination directory used was /tmp/rogue
     - finalized extension was named rogue.tcz
     - easy for practice with only one dependency (ncurses-dev.tcz)
     - source code downloaded directly from website:
       http://rogue.rogueforge.net/rogue-5-4/



Preparation:

- load compiletc and squashfs-tools
- may optionally need to load automake.tcz and autoconf.tcz
- may optionally need to load gettext.tcz if translations are involved
- load all known dependency_name.tcz and dependency_name-dev.tcz extensions listed as program dependencies
- note: dependency_name-dev.tcz extensions automatically load and install the dependency_name.tcz, example:
     - loading and installing ncurses-dev.tcz automatically installs ncurses.tcz
- note: if re-compiling existing or outdated extensions, check the repositories for source and previous compile notes:
     http://tinycorelinux.net/4.x/x86/tcz/src/
     http://tinycorelinux.net/5.x/x86/tcz/src/
     http://tinycorelinux.net/6.x/x86/tcz/src/
- note: old TC extensions may work in the latest TC release, negating the need to recompile from source, search here:
     http://packages.tinycorelinux.net/
- note: old extensions and applicable dependencies can be downloaded from here:
          http://tinycorelinux.net/4.x/x86/tcz/
          http://tinycorelinux.net/5.x/x86/tcz/
- note: notify developers of any old extensions found to work in the latest TC release
- otherwise download source from the software's website
- confirm source download, example:
     md5sum rogue5.4.4-linux32.tar.gz
- extract your source code, example:
     tar xvf package_name.tar.bz2
- create a temporary working directory and copy source code, example:
     mkdir /tmp/rog
     mv /home/tc/Desktop/extracted_rogue_source/ /tmp/rog



Configure:

- change to temporary working directory, example:
     cd /tmp/rog
- review source code README files for compiling and build instructions
- to list and review source code configuration options run:
     ./configure --help
- note: some sources won't compile without specifying compile time options in the ./configure command
- note: some source code does not require ./configure, just make (review source READMEs, see Make section below)
- choose from various configure commands:
   - basic ./configure command for personal extensions only (may not work on other hardware, do not submit):
        ./configure --prefix=/usr/local --some-options # replace '--some-options' with desired build options
   - the following flags are required to ensure TC compliance for submission, example ./configure command:
        CC="gcc -march=i486 -mtune=i686 -Os -pipe" CXX="g++ -march=i486 -mtune=i686 -Os -pipe -fno-exceptions -fno-rtti" ./configure --prefix=/usr/local --disable-static --localstatedir=/var
   - an alternative compile command that may result in smaller extensions but may not work on older 32-bit systems:
        CC="gcc -flto -fuse-linker-plugin -march=i486 -mtune=i686 -Os -pipe" CXX="g++ -flto -fuse-linker-plugin -march=i486 -mtune=i686 -Os -pipe -fno-exceptions -fno-rtti" ./configure --prefix=/usr/local --disable-static --localstatedir=/var
- for applications that need speed (math library or so), may try '-O2' flag instead of the '-Os' flag listed above
- if the -O2 flag was used can try removing the flag to reduce extension size by running this after ./configure but before make:
     find . -name Makefile -type f -exec sed -i 's/-O2//g' {} \;
- if problems are encountered when compiling:
     - add missing dependencies and re-run ./configure command
     - read and research the error messages (google, old forum posts, request assistance)
     - review and enable applicable configure options to assist with troubleshooting, example:
          --enable-debug              # Runtime debugging
          --enable-compile-warnings   # Enable verbose compiler warnings
- additional useful wiki information:
     - the standard install prefix for TC is /usr/local
     - suggested compiler flags for x86 compatibility:
          export CFLAGS="-march=i486 -mtune=i686 -Os -pipe"
          export CXXFLAGS="-march=i486 -mtune=i686 -Os -pipe"
          export LDFLAGS="-Wl,-O1"
     - suggested compiler flags for x86_64 compatibility:
          export CFLAGS="-mtune=generic -Os -pipe"
          export CXXFLAGS="-mtune=generic -Os -pipe"
          export LDFLAGS="-Wl,-O1"
     - suggested compiler flags for RPi:
          export CFLAGS="-Os -pipe"
          export CXXFLAGS="-Os -pipe"
          export LDFLAGS="-Wl,-O1"
     - to attempt to get a lower sized C++ app:
          - try adding '-fno-exceptions -fno-rtti' to CXXFLAGS (as above)
          - only on C++ applications, libraries should use the same flags as in CFLAGS above
     - for applications that do not use threads (pthread_cancel), the following flag reduces binary size:
          -fno-asynchronous-unwind-tables
     - flags not allowed (may provide good performance but not likely compatible on other systems):
          -march=native -mtune=native



Make:

- review the source code's Makefile to determine the build process
- note: Makefile editing may be required to successfully complete build (eg install pathway, compiler flags) 
- run make provided ./configure completes without errors:
     make
- some packages support make install-strip to strip debugging information:
     make install-strip
- if make fails:
     - close and re-open a fresh terminal, try again
     - run 'make distclean' and re-attempt make
     - re-check ./configure options and restart from beginning
     - delete source code working directory, untar source again, restart
     - read and research the error messages (google, old forum posts, request assistance)



Make install:

- create a temporary destination directory, example:
     mkdir /tmp/rogue
- from within the working directory (eg. /tmp/rog) run 'sudo make install', example:
     sudo make DESTDIR=/tmp/rogue install
- note: 'DESTDIR=/tmp/rogue' points 'make install' to the intended destination directory
- if -strip is supported then can try running this instead for a smaller extension:
     sudo make DESTDIR=/tmp/rogue install-strip
- move to the destination directory and review the pathways and contents of your soon-to-be extension:
     cd /tmp/rogue   # explore contents as desired
- note: some applications do not appear to support 'DESTDIR= ...', if so:
     - may need to manually create extension pathways, example:
          sudo mkdir -p /tmp/rogue/usr/local/bin
          sudo mkdir -p /tmp/rogue/usr/local/share/doc
     - and manually place all executables and support files, example:
          sudo cp /tmp/rog/rogue /tmp/rogue/usr/local/bin/
          sudo cp /tmp/rog/rogue-5.4.4 /tmp/rogue/usr/local/share/doc/



Clean-up and optimize:

- run strip from the destination directory's binary location to reduce binary size, example:
     cd /tmp/rogue/usr/local/bin
     sudo strip -g *
- if applicable these commands may further reduce extension size:
     strip --strip-all        # try running on executable files in bin, sbin, libexec
     sstrip                   # try running on executable files in bin, sbin, libexec
     strip --strip-unneeded   # try running on dynamic libraries, *.so* files in lib
     strip --strip-debug      # try running on static libraries, *.a files in lib
     strip -g                 # try running on static libraries, *.a files in lib
- may want to remove documentation/man pages and locale information to reduce extension size, example:
     sudo rm -rf /tmp/rogue/usr/local/share
- optionally create and submit separate extensions for these files (eg. extension_name-doc.tcz)



Desktop file and program icon:

- a desktop file and program icon should be provided for most extensions
- the file should be placed into the /usr/local/share/applicatons pathway, MFM file manager example:
     mkdir -p /tmp/mfm/user/local/share/applications
     touch /tmp/mfm/user/local/share/applications/mfm.desktop
- simple desktop file example:
     [Desktop Entry]
     Type=Application
     Name=mfm
     Exec=/usr/local/bin/mfm
     Icon=mfm
     X-FullPathIcon=/usr/local/share/pixmaps/mfm.png
     Categories=Utility
- an icon pathway will need to be created, example:
     mkdir -p /tmp/mfm/user/local/share/pixmaps/
- then place the .png, example:
     cp /tmp/mfm.png /tmp/mfm/user/local/share/pixmaps/



Permissions:

- extension permissions and ownership should be good if sudo was used with 'sudo make DESTDIR=/tmp/rogue install' above
- otherwise check directory and file ownership and permissions
- various preferences were noted during research, some conflicting:
     - double-check to ensure root:staff ownership and 775 permissions for binary (eg. /usr/local/bin/rogue)
     - note shared object lib files (end in .so or .so*) are treated as executable (root:staff ownership, 775 permission)
     - static object lib files (end in .a or .la) are classified as normal files (644 permission)
     - permissions of symbolic links will show as 777 which is normal
     - all files root:root, 644 for files, 755 for executables, 755 for directories
- personal preference is the last one listed: all files root:root, 644 for files, 755 for executables, 755 for directories
- to change ownership, example:
     sudo chown -R root:root /tmp/rogue
- to update file permission, example:
     sudo chmod 755 /tmp/rogue/usr/local/bin/rogue



Start-up script:

- some extensions require start-up scripts (extension-name) to:
     - avoid run errors
     - set up config files
     - link system files
     - load features
- start-up script pathway is /usr/local/tce.installed
- browse this pathway in your TC install to review example scripts
- note: if installed extensions don't require a start-up script, TC simply places an empty extension_name file into /tce.installed
- if a start-up script is required, it should be created and placed into your extension before squashing up, example:
     touch /tmp/file-roller/usr/local/tce.installed/file-roller
- example of a file-roller run error after re-compile:
     (process:4759): GLib-GIO-ERROR **: Settings schema 'org.gnome.FileRoller.Listing' is not installed Trace/breakpoint trap
- to avoid the schemas error a start-up script with the following information was needed:
     glib-compile-schemas /usr/local/share/glib-2.0/schemas
- example start-up script for file-roller:
     #!/bin/sh
     glib-compile-schemas /usr/local/share/glib-2.0/schemas
     gtk-update-icon-cache -q -f -t /usr/local/share/icons/hicolor
- owner and group should be tc:staff with 755 permissions, example:
     chown tc:staff /tmp/file-roller/usr/local/tce.installed/file-roller
     chmod 755 /tmp/file-roller/usr/local/tce.installed/file-roller
- proper start-up script name and pathway, example:
     /usr/local/tce.installed/file-roller     (correct)
     /usr/local/tce.installed/file-roller.sh  (incorrect)



Squash up your new extension:

- finally squash up a newly created extension, example:
     mksquashfs /tmp/rogue tmp/rogue.tcz



Create a dependency file if required (extension_name.tcz.dep):

- create a dependency file only if dependencies are required (eg. rogue.tcz.dep)
- file contents should not list the extension name, only dependencies
- the rogue.tcz.dep file, for example, should only contain ncurses.tcz
- to check dependencies load the extension, navigating to the executable (/usr/local/bin) and run:
     ldd binary_name (eg. ldd rogue)
- can also try the following to find dependencies, examples:
     ldd `which rogue`
     ldd /usr/local/lib/librogue.so



Create an md5sum file (extension_name.tcz.md5.txt), example:

     md5sum /tmp/rogue.tcz > /tmp/rogue.tcz.md5.txt



Testing:

- reboot TC with the following boot codes:
     base norestore
- manually load the new extension and test
- this ensures the new extension works well and can independently load all required dependencies
- note: it is against forum policy to provide external links to personal extensions on the public forum
- note: PM (private message) should be used to exchange personal extensions for testing purposes



Create a .list file (extension_name.tcz.list):

- create a .list file, which lists the pathway and names of all extension files, example:
     unsquashfs -l rogue.tcz > rogue.tcz.list
- edit the .list file to remove squashfs-root and duplicated pathway names
- example of an edited/cleaned-up .list file:
     /usr/local/bin/rogue
     /usr/local/share/doc/rogue-5.4.4/LICENSE.TXT
     /usr/local/share/doc/rogue-5.4.4/rogue.cat
     /usr/local/share/doc/rogue-5.4.4/rogue.doc
     /usr/local/share/doc/rogue-5.4.4/rogue.html



Create an .info file (extension_name.tcz.info):

- create an .info file to provide extension information (displayed by Apps, tce-ab)
- include helpful and important information required to run or configure the extension
- note: as the Apps utility does not word wrap, personal preference is to use short statements
- this rogue.tcz.info file example lists all required fields and can be used as a template:
     Title:          rogue.tcz
     Description:    Rogue: Exploring the Dungeons of Doom
     Version:        5.4.4
     Author:         Michael Toy, Ken Arnold and Glenn Wichman
     Original-site:  http://rogue.rogueforge.net/rogue-5-4/
     Copying-policy: Copyright (C) 1980-1983, 1985, 1999 Michael Toy, Ken Arnold and Glenn Wichman
                     Copyright (C) 1999, 2000, 2005 Nicholas J. Kisseberth
                     Copyright (C) 1994 David Burren
                     All rights reserved, see /usr/local/share/doc/rogue-5.4.4/LICENSE.TXT (included)
     Size:           104K
     Extension_by:   nitram
     Tags:           rogue roguelike dungeon crawl game
     Comments:       -locate the Amulet of Yendor...and get it out
                     -run 'rogue' in terminal to start new game
                     -default game save pathway /home/tc/rogue.save
                     -to restore saved game open terminal to /home/tc and run 'rogue rogue.save' 
                     -press ? during play to review game commands
     Change-log:     ----
                     Compiled for TC 6
                     ----
     Current:        2015/05/05 first version (nitram)



Create an optional build-dep file (extension_name.tcz.build-dep):

- this plain text file provides information to help with future re-compiles
- it may include extensions required to build, compile flags used, configuration options, etc
- rogue.tcz.build-dep example:
     Required extensions to build:
          ncurses-dev.tcz
     ./configure command utilized:
          CC="gcc -march=i486 -mtune=i686 -O2 -pipe" CXX="g++ -march=i486 -mtune=i686 -O2 -pipe -fno-exceptions -fno-rtti" ./configure --prefix=/usr/local --enable-allscores --enable-numscores=10 --disable-static --localstatedir=/var
     Configure options (outlined above):
          * used 02 flag
          * --enable-allscores
          * --enable-numscores=10



Quality Control prior to submission:

- place all extension files (tcz, info, dep, etc) into a temporary directory (eg. /tmp/rogue_submission)
- install and run submitqc6 from within this folder:
     sudo submitqc6
- submitqc6 generates the extension_name.tcz.zsync file, which should be submitted
- fix any reported errors before submitting the extension



Submit extension:

- tar all necessary and optional files, example:
     tar cvzf rogue.tar.gz rogue/
- attach and email to tcesubmit@gmail.com
- note: encryption of the extension attachment is not required
- submission must include:
     - extension_name.tcz extension file
     - extension_name.tcz.list file
     - extension_name.tcz.md5.txt file
     - extension_name.tcz.info file
     - extension_name.tcz.dep file (if dependencies required, otherwise report no dependencies in submission gmail)
     - extension_name.tcz.zsync file (autogenerated when running submitqc6 prior to submission)
     - optional exension_name.tcz.build-dep file
     - optionally create and submit additional related extensions, which may be useful for others:
          - extension_name-src.tcz     (contains source code)
          - extension_name-locale.tcz  (contains locale information)
          - extension_name-dev.tcz     (contains development files)
          - extension_name-doc.tcz     (contains documentation/man page)



Thanks and resources:

Juanito, Misalf, curaga, Rich, coreplayer2, gutmensch
Developers and forum discussion contributors
Wiki contributors
Into the Core contibutors
Into the Core: A Look at Tiny Core Linux (Lauri Kasanen et al), chapter 15, PP 73-75, Creating an Extension
http://wiki.tinycorelinux.net/wiki:creating_extensions
http://forum.tinycorelinux.net/
