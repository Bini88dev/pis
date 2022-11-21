#!/usr/bin/env bash

## Variables to use with $variable
inst="sudo apt install -y"
upd="sudo apt update"
upg="sudo apt upgrade -y"
ac="sudo apt autoclean"
ar="sudo apt autoremove -y"
ap="sudo apt autopurge -y"
us=$USER
green="32"
bgreen="\e[1;${green}m"
endcolor="\e[0m"

## Start auto post-install script
if [[ "${UID}" -ne 0 ]]
then
 echo -e "${bgreen}This script must be run as admin bzw. root: use sudo or curl | sudo bash${endcolor}" >&2
 exit 1
fi
echo -e '
########################################################################
# /$$$$$$$                                           /$$$$$$   /$$$$$$\#
#| $$__  $$                                         /$$__  $$ /$$__  $$#
#| $$  \ $$  /$$$$$$  /$$$$$$$  /$$$$$$$  /$$   /$$| $$  \ $$| $$  \ $$#
#| $$$$$$$  /$$__  $$| $$__  $$| $$__  $$| $$  | $$|  $$$$$$/|  $$$$$$/#
#| $$__  $$| $$$$$$$$| $$  \ $$| $$  \ $$| $$  | $$  $$__  $$  $$__  $$#
#| $$  \ $$| $$_____/| $$  | $$| $$  | $$| $$  | $$| $$  \ $$| $$  \ $$#
#| $$$$$$$/|  $$$$$$$| $$  | $$| $$  | $$|  $$$$$$$|  $$$$$$/|  $$$$$$/#
#|_______/  \_______/|__/  |__/|__/  |__/ \____  $$ \______/  \______/ #
#                                         /$$  | $$/                   #
#                                        |  $$$$$$/                    #
#                                         \______/                     #
########################################################################
########################################################################
#                      Welcome to Bennys scripting...                  #
#            Initiating the sequences and preparing disto...           #
########################################################################'
 sleep 1
 
echo -e "${bgreen}Update and upgrade distro...${endcolor}"
 $upd;
 $upg;
 sleep 1

echo -e "${bgreen}Checking linux standard apps...${endcolor}"
 $inst curl;
 $inst wget;
 $inst software-properties-common;
 $inst net-tools;
 $inst nmap;
 $inst htop;
 $inst fontconfig;
 $inst zip;
 $inst unrar;
 $inst p7zip;
 $inst p7zip-rar;
 $inst dconf-cli;
 $inst bash-completion;
 $inst nano;
 $inst tmux;
 $inst zsh;
 sleep 1

echo -e "${bgreen}Install python3${endcolor}"
 $inst python3;
 $inst python3-psutil;
 sleep 1

echo -e "${bgreen}Install git${endcolor}"
 $inst git;
 sleep 1

echo -e "${bgreen}Install yadm${endcolor}"
 $inst yadm;
 sleep 1

echo -e "${bgreen}Install ansible${endcolor}"
 sudo apt-add-repository ppa:ansible/ansible -y
 $upd;
 $inst ansible;
 sleep 1

echo -e "${bgreen}Cleaning up...${endcolor}"
 $ac;
 $ar;
 $ap;
 sleep 1

echo -e "${bgreen}All almoste done!${endcolor}"
 sleep 1

echo -e "${bgreen}
################################################################################################
Would you like to restart your Linux? Its recommended...If so enter y / If you dont want enter n
################################################################################################
 ${endcolor}"
 read -p "And... " -r res
 if [[ $res = "y" ]] || [[ $res = "yes" ]] ; then 
 sudo reboot
 elif [[ $res = "n" ]] || [[ $res = "no" ]] ; then 
 echo "Linux Distro will not be restarted..."
 exit 1
 else
 echo "Please restart your Linux Distro..."
 exit 1
 fi
 
exit 0
