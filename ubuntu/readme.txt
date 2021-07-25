
 boot-grub.tgz : /boot/grub which are files created by grub configuration

 bootrd.gz     : boot record for the specific grub version used here (AS-IS)
 system.tgz    : ubuntu-base-20.04.2-base-amd64.tar.gz + debs + update-initramfs 
 update.tgz    : explode after the untar of system.tgz to customise the installation

 deb files: debfiles.txt
 deb names: debnames.txt

 ####### HOW TO CREATE THE SYSTEM TARBALL #######

 repo=https://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release
 distro=ubuntu-base-20.04.2-base-amd64.tar.gz
 nointr="debconf debconf/frontend select Noninteractive"
 user=$(whoami)

 mkdir tmp; cd tmp
 wget -c $repo/$distro
 mkdir rootfs
 sudo tar xzf $distro -C rootfs
 sudo tar xzf ../boot-grub.tgz -C rootfs
  
 sudo mount -t proc proc rootfs/proc
 sudo mount --rbind /sys rootfs/sys
 sudo mount --rbind /dev rootfs/dev

 cp ../debnames.txt rootfs
 sudo chroot rootfs
 echo -e "root\nroot\n" | passwd

 echo "nameserver 8.8.8.8" >/etc/resolv.conf
 apt update
#export DEBIAN_FRONTEND=noninteractive
 echo "$nointr" | debconf-set-selections
 apt install -y $(cat debnames.txt)
 rm -f /etc/resolv.conf

# when asked on which disk grub should automatically installed
# select none pressing ENTER then answer yes to grub installation

 cd /boot/grub
 cp -arf grub.cfg grub.cfg.old
 srt=$(grep -ne "BEGIN .*/30_os-prober" grub.cfg | cut -d: -f1)
 end=$(grep -ne "END .*/30_os-prober" grub.cfg | cut -d: -f1)
 len=$(cat grub.cfg | wc -l)
 head -n$srt grub.cfg > grub.cfg.1
 tail -n$[len-end+1] grub.cfg > grub.cfg.2
 cat grub.cfg.1 grub.cfg.2 >grub.cfg
 rm -f grub.cfg.1 grub.cfg.2
 cd -
 
 exit
 cd rootfs

 sudo umount ./proc/
 sudo mount --make-rslave sys
 sudo mount --make-rslave dev
 sudo umount -R ./sys/
 sudo umount -R ./dev/

 sudo tar czf ../system.tgz .
 cd ..

 sudo chown $user.$user system.tgz
 mv system.tgz ../../ntfs
 cd ../..

 
