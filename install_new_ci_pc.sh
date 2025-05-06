#!/bin/bash

set -e

# old and unused
loacl NANOPB_HASH="145vjQwQzHvEGYIroXzDxT08A_7f25c5r"
loacl PROTOBUFF_HASH="1oRqRroIRJ1jnW1QAvl236JCeBjna1oaK"

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m' # No color

echo -e "${YELLOW}Starting the installation process...${RESET}"
echo -e "${YELLOW}Please wait while we set things up for you...${RESET}"

echo -e "${GREEN}Checking it the version of ubuntu${RESET}"
if [[ ! -f /etc/os-release ]] || [[ ! $(source /etc/os-release && echo $VERSION_ID) == "20.04" ]]; then
    echo -e "${RED}The current ubuntu version is not supported.${RESET}"
    exit 1
else
    echo -e "${GREEN}Pass.${RESET}"
fi

# timezone
echo -e "${GREEN}Setting time zone to Isreal-Jerusalem${RESET}"
sudo timedatectl set-timezone Asia/Jerusalem

# common installations
echo -e "${GREEN}Installing common packages and software${RESET}"
sudo apt update && sudo apt install -y v4l-utils netplan.io samba \
    minicom cmake rsync libuvc-dev unzip libgtk2.0-dev net-tools \
    libusb-dev libusb-1.0-0-dev protobuf-compiler protobuf-c-compiler libprotobuf-c-dev
sudo snap install --classic code
sudo snap install lnav btop

# disable automatic updates
echo -e "${GREEN}Disabling automatic updates${RESET}"
sudo tee -a /etc/apt/apt.conf.d/10periodic <<EOF
APT::Periodic::Unattended-Upgrade "0";
EOF
sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Unattended-Upgrade "0";
EOF

# set background to solid black
echo -e "${GREEN}Setting desktop background color${RESET}"
gsettings set org.gnome.desktop.background picture-options none
gsettings set org.gnome.desktop.background primary-color black

echo -e "${GREEN}Installing packages${RESET}"
sudo apt update && sudo apt install -y libgstreamer1.0-0 gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    libgtk2.0-dev cifs-utils nfs-common

echo -e "${GREEN}Installing packages${RESET}"
sudo apt install -y git openssh-server curl nano cmake build-essential pybind11-dev \
    gstreamer1.0-rtsp libgstrtspserver-1.0-dev \
    postgresql lnav nmon rclone jq openjdk-11-jre htop gridsite-clients \
    liblz4-dev libspdlog-dev libzmq3-dev ffmpeg libasound2-dev \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libjpeg-dev \
    libpq-dev pkg-config libcairo2-dev libgirepository1.0-dev pybind11-dev \
    xfce4 xfce4-goodies tightvncserver
sudo systemctl enable ssh --now

# install python3.10
echo -e "${GREEN}Installing python3.10${RESET}"
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt install -y python3.10
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
sudo apt install -y libportaudio2 python3.10-distutils python3.10-full python3.10-dev

# install docker
echo -e "${GREEN}Installing Docker${RESET}"
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sudo sh /tmp/get-docker.sh
# disable docker interface as it is interfering with the SSH connection
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
    "bridge": "none"
}
EOF

# install pre-compiled opencv 4.6.0
echo -e "${GREEN}Installing opencv${RESET}"
loacl OPENCV_DOWNLOAD_URL="https://github.com/Q-cue-ai/install-opencv/releases/download/v1.0.0/opencv_4.6.0_ubuntu2004_x86.tar.gz"
OPENCV_TAR_PATH=/tmp/opencv_4.6.0.tar.gz
curl -o ${OPENCV_TAR_PATH} -LJ ${OPENCV_DOWNLOAD_URL}
sudo tar -xzf ${OPENCV_TAR_PATH} -C /usr/local

# Download pylon from our google drive
# Install according to install.sh script instructions
echo -e "${GREEN}Setting-up pylon${RESET}"
loacl PYLON_DOWNLOAD_HASH="1tC7D6BlOZ2BilNpEtVCY6Wx9siHy4jtK"
PYLON_DEB_PATH=/tmp/pylon_7.2.1.deb
${HOME}/.local/bin/pip3 install gdown &&
    ${HOME}/.local/bin/gdown -O ${PYLON_DEB_PATH} ${PYLON_DOWNLOAD_HASH} &&
    sudo mkdir -p /opt/pylon &&
    sudo apt install -y ${PYLON_DEB_PATH} &&
    sudo chmod 755 /opt/pylon &&
    ${HOME}/.local/bin/gdown -O /tmp/PYLON_INSTALL.sh 1UBKhTsc22I31L9VDKbq58pJnvVvnie_9 &&
    sudo mv /tmp/PYLON_INSTALL.sh /opt/pylon/share/pylon/PYLON_INSTALL.sh &&
    sudo sh /opt/pylon/share/pylon/PYLON_INSTALL.sh

# config pypi to use the Q servers
echo -e "${GREEN}Setting-up Q pypi proxy${RESET}"
mkdir -p ${HOME}/.config/pip/
tee -a {} <<EOF
[global]
index-url = https://pypi.q.ai/root/pypi
extra-index-url =
        https://pypi.q.ai/signals/development
        https://pypi.q.ai/machine_learning/development
        https://pypi.q.ai/software/development
        https://pypi.q.ai/atoms/development
        https://pypi.q.ai/signals/production
        https://pypi.q.ai/machine_learning/production
        https://pypi.q.ai/software/production
        https://pypi.q.ai/atoms/production
trusted-host = pypi.q.ai
[search]

EOF

# install nlohmann-json 3.11.2
echo -e "${GREEN} install nlohmann-json${RESET}"
loacl NLOHMANN_JSON_HASH="1pDFHDkzOyrqyoQvgt4dnuBdIV0q4CB2W"
NLOHMANN_JSON_PATH=/tmp/nlohmann_json-3.11.2.tar.gz
${HOME}/.local/bin/gdown -O ${NLOHMANN_JSON_PATH} ${NLOHMANN_JSON_HASH}
sudo tar -xzf ${NLOHMANN_JSON_PATH} -C /usr/local

# set Q Earbud UDEV rules
echo -e "${GREEN}Setting-up Q Earbud UDEV rules${RESET}"
sudo tee /etc/udev/rules.d/90-cyusb.rules <<EOF
# CX3 ROM bootloader
SUBSYSTEM=="usb", ATTRS{idVendor}=="04b4",  ATTR{idProduct}=="00f3", GROUP="plugdev", MODE="0664"
# CX3 Q SBL
SUBSYSTEM=="usb", ATTRS{idVendor}=="04b4",  ATTR{idProduct}=="00f0", GROUP="plugdev", MODE="0664"
# CX3 Q APP
SUBSYSTEM=="usb", ATTRS{idVendor}=="04b4",  ATTR{idProduct}=="00c3", GROUP="plugdev", MODE="0664"
# STM32 DFU
SUBSYSTEM=="usb", ATTRS{idVendor}=="0483",  ATTR{idProduct}=="df11", GROUP="plugdev", MODE="0660",
# STM32 Q MCU (old)
SUBSYSTEM=="usb", ATTRS{idVendor}=="1209",  ATTR{idProduct}=="0001", GROUP="plugdev", MODE="0664"
# STM32 Q MCU
SUBSYSTEM=="usb", ATTRS{idVendor}=="1209",  ATTR{idProduct}=="00c3", GROUP="plugdev", MODE="0664"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger

# install the arm toolchain
echo -e "${GREEN}Install the arm toolchain${RESET}"
FOLDER_PATH=${HOME}/toolchains
mkdir -p "${FOLDER_PATH}"
curl -o "${FOLDER_PATH}" -sS https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz
tar -xfv "${FOLDER_PATH}"/arm-gnu-toolchain-*.tar.xz
rm "${FOLDER_PATH}"/arm-gnu-toolchain-*.tar.xz
unset FOLDER_PATH

## install the "cusbi" software to control the managed USB Hub
echo -e "${GREEN}Install the cusbi to control the USB Hub${RESET}"
FOLDER_PATH=${HOME}/tmp
mkdir -p "${FOLDER_PATH}"
curl -o "${FOLDER_PATH}" -sS https://sgcdn.startech.com/005329/media/sets/Managed_USB_HUB_Software/Linux.zip
unzip "${FOLDER_PATH}"/Linux.zip
tar "${FOLDER_PATH}""/Linux/x86-64/xvf cusbi-r1.03.tar.gz" /bin/
rm -r "${FOLDER_PATH}"
unset FOLDER_PATH

# create jenkins user
echo -e "${GREEN}Setting-up jenkins user${RESET}"
echosudo groupadd -g 5000 services
sudo useradd -u 5000 -m -d /var/lib/jenkins -G sudo,services jenkins
sudo chsh -s /bin/bash jenkins
while true; do
    read -sp "Enter password for user jenkins: " PASSWORD
    echo
    read -sp "Confirm password: " PASSWORD_CONFIRM
    echo

    if [ "$PASSWORD" == "$PASSWORD_CONFIRM" ]; then
        break
    else
        echo -e "${RED}Passwords do not match. Please try again.${RESET}"
    fi
done
echo "jenkins:$PASSWORD" | sudo chpasswd

# config udev setting
echo -e "${GREEN}Setting-up udev setting${RESET}"
sudo usermod -aG video,dialout $(whoami)
sudo usermod -aG video,dialout jenkins

# config ca
echo -e "${GREEN}Config Q CA${RESET}"
cp ./ca.crt /usr/local/share/ca-certificates/CA.crt
sudo su - root
cd /usr/local/share/ca-certificates/
update-ca-certificates

# set bashrc config
echo -e "${GREEN}Config .bashrc for Q and q-v1r${RESET}"
cp ~/.bashrc ~/.bashrc.OLD
tee -a ~/.bashrc <<EOF

# test if a dir exist and not already in the PATH
function add_to_path() {
	if [[ ! "$PATH" == *"$1"* ]] && test -d "$1"; then
		export PATH="${PATH:+${PATH}:}$1"
	fi
}

# test if dir exist
function add_to_environment_variables() {
	if test -d "$2"; then
		export "$1"="$2"
	fi
}

add_to_path "${HOME}/bin"

add_to_environment_variables LD_LIBRARY_PATH "/usr/local/lib:${LD_LIBRARY_PATH}"

add_to_environment_variables ARMGCC_INSTALL_PATH "$HOME/toolchains/arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi"
add_to_path "${ARMGCC_INSTALL_PATH}/bin"
add_to_path "${HOME}/.local/bin"

EOF

# setup q-v1r repo
echo -e "${GREEN}Cloning the q-v1r repo${RESET}"
while true; do
    echo -e "${GREEN}Please insert git user name${RESET}"
    read -sp "user name: " USER_NAME
    echo
    echo -e "${GREEN}Please insert git email${RESET}"
    read -sp "Email: " EMAIL
    echo

    git clone -c user.name="$USER_NAME" -c user.email="$EMAIL" https://github.com/Q-cue-ai/q-v1r.git "${HOME}/"
    if [[ $? -eq 0 ]]; then
        break
    else
        echo -e "${RED}Can't clone repo. Please try again.${RESET}"
    fi
done

echo -e "${GREEN}To connect to this pc use \"ssh $(whoami)@$(hostname -I)\"$(RESET)"

# done, requst reboot
read -p "Succesfully installed requirements. Press ENTER to reboot the system."
sudo reboot
