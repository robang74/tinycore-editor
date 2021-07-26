#
# Author: Roberto A. Foglietta
#

 boot-grub.tgz : /boot/grub which are files created by grub configuration

 FILE TO COPY IN THE NTFS PARTITION OF THE BOOTABLE USB DISK

 bootrd.gz     : boot record for the specific grub version used here (AS-IS)
 system.tgz    : ubuntu-base-20.04.2-base-amd64.tar.gz + debs + update-initramfs 
 update.tgz    : explode after the untar of system.tgz to customise the installation

 LIST OF PACKAGES INSTALLED IN THE TARGET UBUNTU INSTALLATION

 deb files: debfiles.txt
 deb names: debnames.txt


 ####### HOW TO CREATE THE SYSTEM TARBALL #######

 ./make.sh rootfs
 
