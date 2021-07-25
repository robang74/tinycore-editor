This is a shameless modification of the old DSL instructions (written by SaidinUnleashed, to give full credit).  This was performed from a Debian Sid x86 system.  The USB stick is /dev/sdc1.

1) Install necessary tools.  On Debian this is syslinux, mtools, and dosfstools:

Code: [Select]

aptitude install syslinux mtools dosfstools


2) Partition the thumb drive.  I used fdisk to partition the thumb drive into one large FAT32 partition.  The following directions are from memory but should be correct.

Code: [Select]

umount /dev/sdc1 # Never use fdisk on a mounted partition
fdisk /dev/sdc1
d
1
d
2
d
3
d  # These commands delete all partitions currently on the device
n
p
1 # This makes a new primary partition
a
1 # This makes it bootable
t
1
b # This makes it FAT 32
w


Now, I always overwrite the drive's mbr in case it was used for booting from grub sometime in the past.  This is not normally necessary.

Code: [Select]

dd if=/usr/lib/syslinux/mbr.bin of=/dev/sdc


Now, make a FAT 32 partition:

Code: [Select]

mkfs.vfat -F 32 /dev/sdc1


3) Copy over the files

You will need to mount the iso image using loopback and then copy over the files.

Code: [Select]

mkdir /mnt/iso
mount -o loop tinycore_1.0rc1.iso /mnt/iso
mkdir /mnt/usb
mount /dev/sdc1 /mnt/usb
cp /mnt/iso/* /mnt/usb


4) Set up syslinux

Since the ISO uses isolinux, we will need to make some changes

Code: [Select]

mv /mnt/iso/boot/isolinux /mnt/iso/boot/syslinux
mv /mnt/iso/boot/syslinux/isolinux.cfg /mnt/iso/boot/syslinux/syslinux.cfg
rm -f /mnt/iso/boot/syslinux/isolinux.bin # This didn't stop it from working for me, but I'm not sure if this file is necessary.
syslinux /dev/sdc1


5) Cross your finger, unmount the flash drive, and reboot.  If you get an error like "image linux not found" when booting, you forgot to correctly rename the isolinux files to syslinux.

APPENDIX A: Using Grub

You can also use grub to manage booting the pendrive, as described at http://tinycorelinux.com/files/extensions/grub-0.97-splash.tce.info.  However, the process is a bit more involved than that.  After installing grub, you need to do the following:

Code: [Select]

mkdir -p /mnt/usb/boot/grub
rm -rf /mnt/usb/boot/isolinux
cp /usr/lib/grub/i386-pc/*stage* /mnt/usb/boot/grub
grub # now follow the instructions in the .info document
cat > /mnt/usb/boot/grub/menu.lst << EOF
default 0
timeout 5
title tinycorelinux
root (hdX,Y)
kernel /boot/bzImage quiet
initrd /boot/tinycore.gz
EOF


APPENDIX B: Persistent /home

I have not tested this yet, but if you want a persistent, encrypted /home on the thumb drive, the easy method would probably be to use fdisk to make one tiny FAT32 partition on the thumb drive and one larger ext2 partition.  Then specify the ext2 partition using the directions in the "help" file to use an encrypted home.

EDIT 12/2/08: Added grub appendix, corrently cited SaidinUnleashed after discussion on IRC :) 


========================================================================================================

core.gz  can be created by combining  rootfs.gz  and  modules.gz  like this:
Code: [Select]
cat rootfs.gz modules.gz > core.gz
You are probably aware that  rootfs.gz  and  modules.gz  can be found under  release/distribution_files/  for each architecture:
http://tinycorelinux.net/11.x/x86/release/distribution_files/

modules.gz  is created by the  sorter.sh  script available from  Github:
https://github.com/tinycorelinux/sorter

After running  make modules  and  make modules_install  you use  sorter.sh  to create  modules.sh  and all the kernel module
extensions. You can find the instructions included in these kernel compile instructions:
http://forum.tinycorelinux.net/index.php/topic,23272.msg147325.html#msg147325

There may be a script to create  rootfs.gz  or they might just  unpack/repack  the existing  rootfs.gz.  I don't know, but I don't
think it changes very often. You can create a root directory manually in some work directory, or you can modify an existing one.

To unpack:
Code: [Select]
mkdir tempdir
cd tempdir
zcat /path/to/existing/rootfs.gz | sudo cpio -i

To repack:
Code: [Select]
sudo find . | sudo cpio -o -H newc | gzip > /path/to/new/rootfs.gz

Found here:
http://forum.tinycorelinux.net/index.php/topic,22398.msg140327.html#msg140327

========================================================================================================

cd rootfs
sudo find . | sudo cpio -o -H newc | gzip > ../rootfs-new.gz

