#!/bin/bash
set -e

FILES=(
# arch
arch/arm/mach-rk29/clock.c
arch/arm/mach-rk29/ddr.c
arch/arm/mach-rk29/vpu*.c
arch/arm/mach-rk29/verifyID.c

arch/arm/plat-rk/vpu*.c

#drivers/staging/rk29/ipp/rk29-ipp.c
)

EXCLUDES=(
pack-kernel*

arch/arm/mach-rk30/*.c
arch/arm/mach-rk30/*.h
arch/arm/mach-rk30/*.S
arch/arm/mach-rk30/Makefile*
arch/arm/mach-rk30/include
arch/arm/configs/rk30*
sound/*rk30*.c
drivers/*rk30*.c
drivers/*rk30*.h

drivers/*rk28*.c
include/*rk28*

arch/arm/mach-rk29/ddr_reconfig.c

drivers/staging/rk29/vivante

drivers/staging/rk29/ipp/rk29-ipp.c

arch/arm/mach-rk29/board-rk29sdk.c
arch/arm/configs/rk29_sdk_defconfig
arch/arm/configs/rk29_sdk_yaffs2_defconfig

arch/arm/mach-rk29/board-malata.c
arch/arm/mach-rk29/board-rk29malata-key.c
arch/arm/configs/rk29_malata_defconfig

arch/arm/mach-rk29/board-rk29-winaccord.c
arch/arm/configs/rk29_Winaccord_defconfig

arch/arm/mach-rk29/board-rk29-a22*
arch/arm/configs/rk29_a22_defconfig

arch/arm/mach-rk29/board-rk29-fih*
arch/arm/configs/rk29_FIH_defconfig

arch/arm/mach-rk29/board-rk29-k97*
arch/arm/mach-rk29/board-rk29k97*
arch/arm/configs/rk29_k97_defconfig

arch/arm/mach-rk29/board-rk29-newton*
arch/arm/mach-rk29/board-newton*
arch/arm/configs/rk29_newton_defconfig

arch/arm/mach-rk29/board-rk29-p91*
arch/arm/configs/rk29_p91_defconfig

arch/arm/mach-rk29/board-rk29-phonesdk*
arch/arm/configs/rk29_phonesdk_defconfig

arch/arm/mach-rk29/board-rk29-td8801*
arch/arm/configs/rk29_td8801_v2_defconfig

arch/arm/mach-rk29/board-rk29-z5*
arch/arm/configs/rk29_z5_defconfig
)

# ---------------------------------------------------------------------------
usage() {
	echo usage: $0 kerneldir defconfig
	echo example: $0 . rk29_ddr3sdk_defconfig
	exit
}

while getopts "h" options; do
  case $options in
    h ) usage;;
  esac
done
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
kerndir=${1-.}
kerndir=$(cd $kerndir; pwd)	# get absolute path
[ -d $kerndir ] || usage

defconfig=${2-rk29_ddr3sdk_defconfig}
if [ "$defconfig" = ".config" ]; then
	[ -f $kerndir/.config ] || usage
else
	[ -f $kerndir/arch/arm/configs/$defconfig ] || usage
fi
# ---------------------------------------------------------------------------

# make .uu
pushd $kerndir >/dev/null

declare -a files

for file in ${FILES[@]}; do
	[ -e ${file} ] && files=( ${files[@]} ${file} ) || echo No such file: ${file}
	[ -f ${file/.[cS]/.uu} ] && rm -f ${file/.[cS]/.uu}
done

for d in ${DIRS[@]}; do
	[ -d $d ] && find $d -type f -name '*.uu' -print0 | xargs -0 rm -f
done

echo build kernel on $kerndir with $defconfig
make clean >/dev/null 2>&1
make $defconfig >/dev/null 2>&1
make -j`grep 'processor' /proc/cpuinfo | wc -l` ${files[@]/.[cS]/.o} ${DIRS[@]}

for file in ${FILES[@]}; do
	filename=${file##*/} 
	base=${filename%%.*}
	dir=${file%/*}
	[ -f $dir/$base.o ] && echo UU $dir/$base.uu && uuencode $dir/$base.o $base.o > $dir/$base.uu
done

for d in ${DIRS[@]}; do
	for file in `find $d -type f -name '*.o'`; do
		filename=${file##*/} 
		base=${filename%%.*}
		dir=${file%/*}
		echo UU $dir/$base.uu && uuencode $dir/$base.o $base.o > $dir/$base.uu
	done
done

make distclean >/dev/null 2>&1

popd >/dev/null

# fix local version
echo "+" > $kerndir/.scmversion

# tar kernel
pushd $kerndir/../ >/dev/null
package=$(basename $kerndir).tar
ex=$package.ex
> $ex
for file in ${FILES[@]}; do
	echo "$file" >> $ex
done
for file in ${EXCLUDES[@]}; do
	echo "$file" >> $ex
done
echo TAR $(pwd)/$package
tar cf $package --numeric-owner --exclude-from $ex --exclude=.git --exclude=`basename $0` $(basename $kerndir)
tar rf $package --numeric-owner --exclude=.git prebuilt/linux-x86/toolchain/arm-eabi-4.4.0
echo GZIP $(pwd)/$package.gz
gzip -9 -c $package > $package.gz
rm $ex
popd >/dev/null

rm -f $kerndir/.scmversion

echo done

