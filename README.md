## Rationale

This project is a proof-of-concept of an Embedded System Building Suite based on
TinyCore Linux Distribution. It is "broken by design" to produce a 
non-certifiable system even under the mildest standards. Its development history
is quite amusing and inspired by a real-life human case.

### Development Model

First of all, it needs to explain the Development Model of this project because
it is particularly educating about how to NOT deal with IT projects and about
how to NOT manage IT senior people.

Born by asking for an emergency immediately available single-use workaround, it
successively grew with a long series of small feature additions out of any
project planning and without any architecture design or redesign. In other
words: in adding a new feature as little redesign as possible has been done.

We can call this kind of development model as

 * monkey-coding design-blind features-addition

This is quite amusing because of explaining how evolution works BUT in this
specific case just the bare-minimum non-competitive natural selection
process-like has been implemented: it works then does not change.

Despite all these limitations in the Developing Model, the result is still
interesting in many aspects and also some good ones.

### History Case

In the past, I worked with a skillful system architect with a deep understanding
of the system on which he was working, but with a surprisingly monkey-coding
attitude. Quickly, I realized that it was the environment and not the man being
broken. It is irrelevant to say anything else about that experience.

Years later that experience, the monkey-coding design-blind features-addition
development model gets real. Moreover, a new motto had a birth:

 * You get what you ask for - is the new - WYSIWYG.
 
To imperishable memory of that colleague who decided to live peacefully as a
paid monkey-coder to devote himself to the things that are important for him.

### Teaching Tool

Despite everything above, this is a great teaching tool because kept fixed the
aim, its redesign implies being able to cope with legacy systems, and trust me:
there are a lot of legacy systems out there in the real world that requires a
progressive redesign because the companies which rely on them are not willing to
invest into a brand new alternative.

From this point of view, it is an opportunity to learn skills for a real-world
market segment: scrum/agile development VS scrum/agile redesign. Both are
progressive and deliverable-based ways of working and bringing value. The main
difference is the starting point.

Finally, we learned that things can work despite an ill-or-none-at-all design.

### Learned Lessons

For those who are more interested in learning some theory than dirtying their
hands deep into the code:

* [My SCRUM in a nutshell for Project Management](https://github.com/robang74/P2C2-Management-Style/raw/main/my-scrum-in-a-nutshell.pdf)

and

* [P²C² Management Style for Team Management](https://github.com/robang74/P2C2-Management-Style/raw/main/p2c2-management-style.pdf)

Dealing properly with a project is as much important as dealing with people
involved in the project and there is no any way to split these two aspects or
avoid it. For sure, it is cheap and this is the main reason because of many
attempts to industrialize intellectual IT work over many years since the 2001's
dot-com bubble burst has been tried.

----

## References

Author: Roberto A. Foglietta <roberto.foglietta@gmail.com>

Repository: https://github.com/robang74/tinycore-editor

Forum: https://github.com/robang74/tinycore-editor/discussions

Google group: https://groups.google.com/g/tinycore-editor

----

## QUICK START AFTER CLONE

	./make.sh download
[1]-->	./make.sh busybox
	./make.sh qemu-test iso
	./make.sh clean image 8GB qemu 8GB ssh

[1] This target do not compile anymore busybox but expand an pre-saved archive.
    However, you can decide to compile the busybox following the instructions
    in the following list at point 16 but then you should do into a TC system.

    IN FACT,

    if your system libraries are incompatible with those included into TinyCore
    the virtual machine will fail to boot. In such a case remove the rootfs.gz
    and repeat the sequence from the start without busybox start. Then you can
    create a rootfs.gz including the customised busybox enabling develop git 
    in tincore.conf and using the virtual machine for the building.

## DEAL WITH POSSIBLE PROBLES

 0. Enabling the qemu virtual network might lead to a conditions in which the
    internet name resolution would not work anymore but the solution is quite
    simple to solve and to check:

    ping www.google.com
    ./make.sh qemu-init
    ping www.google.com

    if the 2nd ping fails then you should explicely add 8.8.8.8 as DNS in your
    network connection. You can do this in three ways depending how is your
    system is configured. First of all check if this package is installed:

    apt list | grep resolvconf

    if is installed then you can add the new DNS address to /etc/resolv.conf.
    Otherwise you can use the graphical network manager to add the DNS to your
    connection (the one that give the system the internet access). If you are
    not using the network manager then you should add the DNS to your network
    plan. Follow this link if you need more support.

    https://linuxize.com/post/how-to-set-dns-nameservers-on-ubuntu-18-04/

# HOW TO DEAL WITH THE SUITE

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

 7. In case you want generate a new USB disk image, do this:

	./make.sh clean; ./make.sh image && ./make.sh close

 8. To create your own real bootable USB disk, you can use this commands:

	on windows: use rufus.exe with tcl-usb.disk.gz
	on linux  : zcat with tcl-usb.disk.gz > $device

    At the first boot, it will create a secondary NTFS partition as large
    as the entire USB disk space left free (USB disk size less 64 MB)

 9. --- deleted ---

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

18. There is an adavantage using the ISO/USB image with VirtualBox: at the
    boot the shared folder named 'Shared' will be mounted in /mnt/sf_Shared

19. When you arrived to a configuration which satisfy your expectations, then
    you can save many seconds at boot time using tczmetamerge.sh. It will
    create a big meta package for each onion layer defined in tinycore.conf.
    The meta packaged named 'test' will be not produced because usefull for
    quick changes in packages configuration for testing. Every time you will
    change the packages configuration (conf.d/*.lst), you will need to redo
    all meta packages and this is time consuming.

20. The USB image written on a USB key will create a secondary partition as
    large as the USB at the first boot. This partition will be formatted in
    NTFS if sshonly, usbkey meta packages are choosen and in EXT4 if the
    develop package is inserted in the list. This allows you to use the USB
    key as a rescue/maintanance/storage usbkey or using it as a developing
    system in which you can compile directly on the EXT4 secondary partition.

----

## USEFULL LINKS TO VISIT

 - https://github.com/pbatard/rufus/releases/download/v3.14/rufus-3.14.exe

 - http://forum.tinycorelinux.net/index.php?topic=18682.0

 - http://tinycorelinux.net/corebook.pdf

 - http://tinycorelinux.net

