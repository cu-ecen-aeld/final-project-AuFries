echo "=== RUNNING BBB NETBOOT boot.scr ==="

setenv ipaddr 192.168.7.2
setenv serverip 192.168.7.1
setenv netmask 255.255.255.0

setenv loadaddr 0x82000000
setenv fdtaddr  0x88000000

# Filenames in /srv/tftp
setenv bootfile zImage
setenv fdtfile  am335x-boneblack.dtb

# NFS export path
setenv nfsroot /srv/nfs/bbb

setenv bootargs "console=ttyS0,115200n8 vt.global_cursor_default=0 root=/dev/nfs rw nfsroot=${serverip}:${nfsroot},vers=3,tcp ip=${ipaddr}:${serverip}::${netmask}:bbb:eth0:off"

echo "TFTP kernel..."
tftpboot ${loadaddr} ${bootfile}
echo "TFTP dtb..."
tftpboot ${fdtaddr}  ${fdtfile}

echo "Booting kernel..."
bootz ${loadaddr} - ${fdtaddr}
EOF