#!/bin/bash
# Super Mario 64 PC on Raspberry Pi
# Find latest updates and code on https://www.github.com/sm64pc/sm64ex
# NOTE: If you clone the repo, source must be copied in ~/src/sm64pc/sm64ex/
# ToDo: Test on more Pi models with fresh Raspbian and allow existing src folders to be updated.
#
clear
echo "This script will assist with compiling Super Mario 64 on Raspberry Pi's"
echo "Checking Raspberry Pi model..."
origdir=$PWD
lowmem=0
pi=1
pimodel=$(uname -m 2>/dev/null || echo unknown)
pitype=$(tr -d '\0' < /sys/firmware/devicetree/base/model)
repo_url="https://github.com/AloUltraExt/sm64ex-alo"

if [[ $pimodel =~ "armv6" ]]
then
   echo -e "\nRaspberry Pi Model 1/0(W) detected (LOWMEM)"
   echo "Warning: Additional steps may be required to safely compile and maximize performance"
   pi=1;
   lowmem=1;
   exp=1;
fi

if [[ $pimodel =~ "armv7" && $pitype =~ "Pi 2" || $pitype =~ "Pi 3" ]]
then
   echo -e "\nRaspberry Pi Model 2/3/4 detected (32bit)"
   pi=2;
   lowmem=0;
fi

if [[ $pimodel =~ "aarch64" ]]
   then
   pi=4;
   exp=1;
   lowmem=0;
   echo -e "64bit Raspbian / Pi detected. Pi model defaulted to Pi 4"
fi

if [[ $pitype =~ "Model 4" ]]
then
   echo -e "\nRaspberry Pi Model 4 (64 bits) detected"
   echo "Audio errors reported for Pulseaudio users. Fix by adding tsched=0 to module-udev-detect in /etc/pulse/default.pa"
   #echo "Fixing audio config, reboot after compilation completes to activate"
   #sudo sed -i 's/load-module module-udev-detect/load-module module-udev-detect tsched=0/' /etc/pulse/default.pa
   #load-module module-udev-detect tsched=0
   pi=4;
   lowmem=0;
   exp=1;
fi

#//////////////////////////////////////////////////////////////////////////////////////////////////////////
#//////////////////////////////////////////////////////////////////////////////////////////////////////////
clear
echo "Super Mario 64 RPi Initial Setup"
# On Pi Pi4 only enable FKMS.

inxinf=$(inxi -Gx 2>&1)
echo "Checking for pre-enabled VC4 acceleration (inxi -Gx)"

if [[ $inxinf =~ "not found" ]]
then
echo "Error: inxi not installed. Installing..."
sudo apt-get update
sudo apt-get install -y inxi
sync
sleep 1
inxi=$(bash inxi -Gx 2>&1)
sleep 1

	if [[ $inxinf =~ "not found" ]]
	then
	echo -e "Please reload the script to detect installed inxi"
	sleep 3
	exit
	fi
fi

if [[ $inxinf =~ "vc4_drm" ]]
then
echo "Success: VC4 OpenGL acceleration found!"
echo ""
sleep 4

	else
	echo ""
	echo "OpenGL driver not found. opening Raspi-Config..."
	if [[ $pi == 4 ]]
	then
	echo "Please enable raspi-config -> ADV Opt -> OpenGL -> Enable FAKE KMS Renderer"
	else
	echo "Please enable raspi-config -> ADV Opt -> OpenGL -> Enable Full KMS Renderer"
	fi
	echo ""
	sleep 5
	sudo raspi-config
	sync
	if [[ $pi == 4 ]]
	then
        vc4add=$(cat /boot/config.txt | grep -e "dtoverlay=vc4-fkms-v3d")
	else
	vc4add=$(cat /boot/config.txt | grep -e "dtoverlay=vc4-kms-v3d")
        fi
		if [[ $vc4add =~ "vc4" ]]
		then
		echo "OGL driver now enabled on reboot"
		else
		echo "OGL driver not detected / enabled in /boot/config.txt"
		fi
fi

if [[ $lowmem == 1 ]]
then
fixmem=$(cat /boot/cmdline.txt | grep cma=128M)

	if [[ $fixmem =~ "cma=128M" ]]
		then
		echo ""
		echo "Notice: Low-RAM RasPi model detected, BUT fixes already applied."
		echo "Continuing setup."

		else
		echo ""
		echo "Warning: VC4 enabled, but your RasPi has 512MB or less RAM"
		echo "To ensure VC4_DRM and game compilation is succesful, video memory will be reduced"
		echo "gpu_mem=48M (config.txt) | cma=128M (cmdline.txt) will be written to /boot "
		echo ""
		read -p "Fix mem? (Y/N): " fixmem

			if [[ $fixmem =~ [Yy] ]]
			then
			sudo sh -c "echo 'gpu_mem=48' >> /boot/config.txt"
			sudo sh -c "echo 'cma=128M' >> /boot/cmdline.txt"
			sync
			echo "Wrote configuration changes to SD card."
	       	 	sleep 2
			else
			echo ""
			echo "Warning: Compilation freezes & errors are likely to occur on your Pi"
			echo ""
			sleep 3
		fi
	fi
fi

if [[ $fixmem =~ [Yy] || $vc4add =~ "vc4" ]]
then
clear
echo "System configuration has changed!"
read -p "Reboot to enable changes? (Y/N): " fixstart
	if [[ $fixstart =~ [Yy] ]]
	then
	echo ""
	echo "Rebooting RasPi in 4 seconds! Press Control-C to cancel."
	sleep 4
	sudo reboot
fi # "Should never run on a Pi 4" part ends here

#--------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
clear
echo "Beginning installation"
echo ""
echo "Step 1. Installing latest dependencies"
echo "Allow installation & checking of Super Mario 64 compile dependencies?"
read -p "Install? (Y/N): " instdep

if [[ $instdep =~ [Yy] ]]
then
echo ""
sudo apt-get update
sudo apt install -y build-essential git python3 libaudiofile-dev libglew-dev libsdl2-dev
sync
else
echo ""
echo "Super Mario 64 dependencies not installed."
echo "Please manually install if Raspbian is modified from stock"
echo ""
sleep 3
fi

#--------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------
clear
echo "Optional: Compile SDL2 with 'KMSDRM' for enhanced performance?"
echo "KMSDRM allows Super Mario 64 to be run without GUI/Desktop (Xorg) enabled on boot"
echo ""
echo "Warning: Compile could take up to an hour on older Raspberry Pi models"
read -p "Proceed? (Y/N): " sdlcomp

if [[ $sdlcomp =~ [Yy] ]]
then
echo ""
echo "Installing dependencies for SDL2 compilation"

sudo sed -i -- 's/#deb-src/deb-src/g' /etc/apt/sources.list && sudo sed -i -- 's/# deb-src/deb-src/g' /etc/apt/sources.list
sync
sudo apt-get update
sync
sudo apt-get build-dep libsdl2
sudo apt-get install libdrm-dev libgbm-dev
sync

echo ""
echo "Creating folder src in HOME directory for compile"
echo ""

mkdir $HOME/src
cd $HOME/src
mkdir $HOME/src/sdl2
cd $HOME/src/sdl2
sleep 1

echo "Downloading SDL2 from libsdl.org and unzipping to HOME/src/sdl2/SDL2"
wget https://www.libsdl.org/release/SDL2-2.0.12.tar.gz -O sdl2.tar.gz
sync
tar xzf ./sdl2.tar.gz
sync
cd SDL2*/

echo "Configuring SDL2 library to enable KMSDRM (Xorg free rendering)"
./configure --enable-video-kmsdrm
echo "Compiling modified SDL2 and installing."
make -j$pi
sudo make install
sync
cd $origdir
fi

#----------------------------------------------------------------------
#---------------------------------------------------------------------
sleep 2
clear
echo "Super Mario 64 RPi preparation & downloader"
echo ""
sm64dircur=$(ls ./Makefile)
sm64dir=$(ls ./Makefile)

#-------------------------------------------------------------------
#------------------------------------------------------------------
clear
echo "Super Mario 64 RPi compilation"
echo ""
echo "Step 3. Compiling Super Mario 64 for the Raspberry Pi"
echo ""
echo "Warning: Super Mario 64 assets are required in order to compile"
if [[ $curdir == 1 ]]
then
echo "Assets will be extracted from "$PWD" "
else
echo "Assets will be extracted from $HOME/src/sm64pc/sm64ex/baserom.us.z64 "
fi

if [[ $curdir == 1 ]]
then
sm64z64=$(find ./* -maxdepth 1 | grep baserom) #See if current directory is prepped
else
sm64z64=$(find $HOME/src/sm64pc/sm64ex/* | grep baserom) #see if fresh compile directory is prepped
fi

if [[ $sm64z64 =~ "baserom" ]]
then
echo ""
echo "Super Mario 64 assets found in compilation directory"
echo "Continuing with compilation"

else
echo ""
echo "Please satisfy this requirement before continuing."
echo "Exiting Super Mario 64 RasPi setup and compilation script."
echo ""
echo "Note: Re-run script once baserom(s) are inserted into"

sleep 5
exit

fi

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
sleep 3
clear
echo ""

echo "Beginning Super Mario 64 RasPi compilation!"
echo ""
echo "Warning: Compilation may take up to an hour on weaker hardware"
echo "At least 300MB of free storage AND RAM is recommended"
echo ""
make clean
sync
make -j$pi TARGET_RPI=1 BETTERCAMERA=1 BETTERCAMERA=1 EXT_OPTIONS_MENU=1 EXTERNAL_DATA=1 TEXTSAVES=1 QOL_FIXES=1 QOL_FEATURES=1 MOUSE_ACTIONS=1
sync


#---------------------------------------------------------------------------
#--------------------------------------------------------------------------

if [[ $curdir == 1 ]]
then
sm64done=$(find $PWD/build/*/* | grep .arm)
else
sm64done=$(find $HOME/*/build/*/* | grep .arm)
fi

echo ""
if [[ $sm64done =~ ".arm" ]]
then
echo "Super Mario 64 RasPi compilation successful!"
echo "You may find it in"

if [[ $curdir == 1 ]]
then
$sm64loc=$(ls $PWD/build/*pc/*.arm)
else
$sm64loc=$(ls $HOME/src/sm64pc/sm64ex/build/*pc/*.arm)
fi

echo $sm64loc

echo ""
echo "Execute compiled Super Mario 64 RasPi?"
read -p "Run game (Y/N): " sm64run

if [[ $sm64run =~ [Yy] ]]
then
cd
chmod +x $sm64loc
bash $sm64loc
sleep 1
fi

else
echo "Cannot find compiled sm64*.arm binary..."
echo "Please note of any errors during compilation process and report them to"
echo "${repo_url}"
sleep 5
fi

exit
