#
# Authore: Roberto A. Foglietta <roberto.foglietta@gmail.com>
#
# Repository: https://github.com/robang74/tinycore-editor
#
# Forum: https://github.com/robang74/tinycore-editor/discussions
#
# Google group: https://groups.google.com/g/tinycore-editor
#
###############################################################################
			QUICK START AFTER CLONE
###############################################################################

	./make.sh download
	./make.sh busybox
	./make.sh qemu-test iso
	./make.sh clean image 8GB qemu 8GB ssh

###############################################################################
			HOW TO DEAL WITH THE SUITE
###############################################################################

 This is a suite for quickly editing and testing a USB bootable disk based on 
 TinyCore Linux. It makes use of qemu and it should be installed in advance.

 USB firt partition label: T1NYC0R3 (but you can change it in rcS)

 0. Please read copyright.txt for the license terms

 1. Download the TinyCore 12.0 x86 64 bit components:

	tinycore/provides/tcgetdistro.sh

 2. Create the TinyCore 12.0 tcz package database:

	tinycore/provides/tcupdatedb.sh

 3. Everytime you modify the tinycore/changes/rcS rebuild the tinycore/rootfs.gz:

	cd tinycore && ./rootfs.sh update && cd ..

 4. Everytime you need to add a component, for example bin/tar, then do this:

	cd tinycore/tcz
	../provides/tcprovides.sh bin/tar
	../provides/tcdownload.sh tar.tcz
	cd -

    if you like the new TCZs stay into your distro add them to tinycore/tinycore.conf

 5. You can launch a qemu test with a simple image with this command:

	./make.sh clean; ./make.sh qemu-test

 6. You can launch a qemu test with a full image with this command:

	./make.sh clean; ./make.sh qemu-test 8GB

 7. In case you want generate a new 64MB USB disk image, do this:

	./make.sh clean; ./make.sh image && ./make.sh close

 8. To create your own real bootable USB disk, you can use this commands:

	on windows: use rufus.exe with tcl-64MB-usb.disk.gz
	on linux  : zcat with tcl-64MB-usb.disk.gz > $device

    At the first boot, it will create a secondary NTFS partition as large
    as the entire USB disk space left free (USB disk size less 64 MB)

 9. At the first boot you can decide to have a TCE compliant distro with this:

	tcz2tce.sh

    You can lately change your mind with tcz2tce.sh reverse

10. To explore all make.sh features call it without any parameter.

11. To access your customised TinyCore via SSH without password:

	add you .pub key into sshkeys.pub

    You can add into the USB disk folder or into the editor folder
    depending if you want that every future distro have it or not.

12. To modify the USB disk with your custom changes:

	cd tinycore; mkdir tmp
	tar xvzf tccustom.tgz -C tmp
	# make the changes you like
	cd tmp; tar cvzf ../tccustom.tgz .
	cd ..; rm -rf tmp

    All these changes will be applied to the rootfs without permission time
    and user preferences (tar uses -mo option) after the all TCZs loading.
    Obviously, you have to recreate the image to apply the changes.

13. To update a qemu running instance or any machine connected to network:

	./make.sh ssh-copy            # for qemu running instance
	./make.sh ssh-copy $ipaddr    # for a connected machine

14. The customised TinyCore is able to install an Ubuntu on a machine.
    Enter in ubuntu folder and follow the instruction to build system.tgz
    then copy system.tgz, bootrd.gz and an update.tgz (if you like to
    cutomise the Ubuntu installation) into the NTFS partition.
    Boot with USB disk on the machine you like to install and type

	system-install.sh             # for the help

    Pay attention to this command because wrong use might destroy data.
    Please, test how it works in a empty virtual machine before using.

15. Edit syslinux.cfg for changing the default keyboard and any other boot
    options which is required or optimal for your system. When you reach the
    definitive boot configuration edit the tinycore/changes/syslinux.cfg

16. It is possible to download and compile a specific version of busybox
    In order to integrate busybox into root filesystem follow these steps:

	busybox/busybox.sh download
	busybox/busybox.sh all

    Instead to edit the source and try the compiled new version do this after:

	busybox/busybox.sh open [suid|nosuid]
	busybox/busybox.sh editconfig
	# change the source here
	busybox/busybox.sh update
	# test the new changes
	busybox/busybox.sh saveconfig
	busybox/busybox.sh close

   The no|suid parameter let you choose if you want update in the rootfs.gz
   the busybox binary or the busybox.suid binary which is root user suided

17. The following file contains the SSH host keys for the host:

	tinycore/changes/sshdhostkeys.tgz

    They are saved in PEM format to be compatible with dropbear. With these
    file every instance will have the same host keys of the others. If this
    is not what you want, simple delete that file. You can also change the
    tarball content using host keys of your own choice.

###############################################################################
			USEFULL LINKS TO VISIT
###############################################################################

https://github.com/pbatard/rufus/releases/download/v3.14/rufus-3.14.exe

http://forum.tinycorelinux.net/index.php?topic=18682.0

http://tinycorelinux.net/corebook.pdf

http://tinycorelinux.net

