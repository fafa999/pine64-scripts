#!/bin/bash

ARDUINO_IDE_VER="1.8.10"
ARDUINO_IDE_URL="https://downloads.arduino.cc/arduino-1.8.10-linuxarm.tar.xz"

#check for root priv
if [ "$(id -u)" != "0" ]; then
	echo -ne "This script must be executed as root. Exiting\n" >&2
	exit 1
fi

#check how being elevated
if [ -z "$SUDO_COMMAND" ]; then
	echo -ne "This script relies on being run via sudo for some operations.\n"
	echo -ne "Expect things to not work, or to have to do some extra stuff\n"
	echo -ne "after running it if you continue.\n"
	echo -ne "\nYou have been warned!\n\n"
fi

main() {
	downloadPackage
	unpackIDE
	armhfEnable
	installDependencies
	fixGTK
	fixSerialMonitor
	fixPermissions
	desktopIcon

	#completion messages
	echo -ne "\nYou should now be able to see an 'Arduino' icon on your desktop ready"
	echo -ne "\nfor you to use! Please note that the first launch will take a while,"
	echo -ne "\nbut it will be pretty quick after that first run."

	#notify user that they will need to log out and in again before will be able to load to a device to allow addition to dialout group to take effect
	if [[ -n "$SUDO_USER" ]]; then
		echo -ne "\n\nYou will need to log out and back in again to allow the addition"
		echo -ne "\nof your username to the 'dialout' group to take effect. Failure"
		echo -ne "\nto do so will prevent you from being able to upload to any"
		echo -ne "\nserial programmed Arduino compatiable devices."
	fi

	#notify user they can also delete the downloaded arduino archive
	echo -ne "\n\nAdditionally, you can delete /tmp/arduino-${ARDUINO_IDE_VER}-linuxarm.tar.xz"
	echo -ne "\nif you wish to as it is no longer needed.\n"
}

#download and unpack
downloadPackage() {
	echo -ne "Arduino IDE ${ARDUINO_IDE_VER} Install Script\n\n"
	echo -ne "Downloading Arduino IDE ${ARDUINO_IDE_VER} ... "
	wget -q -O "/tmp/arduino-linuxarm.tar.xz" ${ARDUINO_IDE_URL} 2>&1
	if [ $? -ne 0 ]; then
		echo -ne "fail\n"
		echo -ne "Unable to successfully download package... please try again!\n\n"
		exit 1
	else
		echo -ne "done\n"
	fi
}

unpackIDE() {
	echo -ne "Unpacking to /opt/arduino-${ARDUINO_IDE_VER}/ ... "
	tar xf /tmp/arduino-linuxarm.tar.xz --directory /opt/ > /dev/null 2>&1 || { echo "Fail! Exiting script!"; exit 1; }
	echo -ne "done\n"
}

#enable armhf packages support
armhfEnable() {
	echo -ne "Enable armhf package support and update software repository ... "
	dpkg --add-architecture armhf
	apt-get -qq update
	echo -ne "done\n"
}

#install required armhf dependencies
installDependencies() {
	echo -ne "Installing required dependencies (this may take several minutes) ... "
	apt-get -f -qq -y install libxtst6:armhf > /dev/null 2>&1
	apt-get -f -qq -y install libxrender1:armhf > /dev/null 2>&1
	apt-get -f -qq -y install libxi6:armhf > /dev/null 2>&1
	apt-get -f -qq -y install openjdk-8-jre:armhf > /dev/null 2>&1
	echo -ne " done\n"
}

#get rid of GTK errors
fixGTK() {
	echo -ne "Install GTK2 engine and required theme ... "
	apt-get -f -qq -y install gtk2-engines:armhf gtk2-engines-murrine:armhf > /dev/null 2>&1
	echo -ne "done\n"
}

#fix serial monitor error caused by wrong ~/.jssc/linux/libjSSC-2.8_armsf.so
fixSerialMonitor() {
	if [[ -n "$SUDO_USER" ]] && [[ -f "/opt/arduino-${ARDUINO_IDE_VER}/lib/jssc-2.8.0-arduino4.jar" ]]; then
		echo -ne "Fixing up serial monitor bug ... "
		#rename old files if present
		[ -f "/home/$SUDO_USER/.jssc/linux/libjSSC-2.8_armsf.so" ] && mv "/home/$SUDO_USER/.jssc/linux/libjSSC-2.8_armsf.so" "/home/$SUDO_USER/.jssc/linux/libjSSC-2.8_armsf.so.old"
		[ -f "/home/$SUDO_USER/.jssc/linux/libjSSC-2.8_armhf.so" ] && mv "/home/$SUDO_USER/.jssc/linux/libjSSC-2.8_armhf.so" "/home/$SUDO_USER/.jssc/linux/libjSSC-2.8_armhf.so.old"

		#create directory if it doesn't actually exist, which it shouldn't on a clean system
		[ ! -d "/home/$SUDO_USER/.jssc/linux" ] && mkdir -p "/home/$SUDO_USER/.jssc/linux"

		unzip -p "/opt/arduino-${ARDUINO_IDE_VER}/lib/jssc-2.8.0-arduino4.jar" "libs/linux/libjSSC-2.8_armhf.so" > "/home/$SUDO_USER/.jssc/linux/libjSSC-2.8_armhf.so"
		ln -s "/home/$SUDO_USER/.jssc/linux/libjSSC-2.8_armhf.so" "/home/$SUDO_USER/.jssc/linux/libjSSC-2.8_armsf.so"
		echo -ne "done\n"
	else
		echo -ne "Unable to apply serial monitor bug fix as not sudo or file missing!\n"
		echo -ne "See post #21 of https://forum.arduino.cc/index.php?topic=400808.15\n"
	fi
}

#add user to dialout group
fixPermissions() {
	if [[ -n "$SUDO_USER" ]]; then
		echo -ne "Add user to the dialout group ... "
		usermod -aG dialout "$SUDO_USER"
		echo -ne "done\n"
	else
		echo -ne "Not running via sudo, can't determine username to add to dialout group!\n"
	fi
}

#add desktop icon using provided install script
desktopIcon() {
	if [[ -n "$SUDO_USER" ]]; then
		echo -ne "Adding desktop shortcut, menu item and file associations for Arduino IDE ... "
		su "$SUDO_USER" /opt/arduino-${ARDUINO_IDE_VER}/install.sh > /dev/null 2>&1
		echo -ne "done\n"
	else
		echo -ne "Not running as sudo, can't run install.sh as normal user\n"
		echo -ne "So you'll need to run /opt/arduino-${ARDUINO_IDE_VER}/install.sh yourself!\n"
	fi
}

main "$@"
