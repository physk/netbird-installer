#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

APP_MAIN_NAME="netbird"
APP_UI_NAME="netbird-ui"
REPO_USER="netbirdio"
REPO_MAIN="netbird"

# Set Default Variables
INSTALL_APP=true
INSTALL_UI=false
INSTALL_DOCKER_BASED=false
INSTALL_SERVICE=true
PRECONFIGURE=true
DISPLAY_PROMPTS=true
SETUP_KEY=""
MANAGEMENT_URL="https://api.wiretrustee.com:33073"
BASE_URL="https://github.com/${REPO_USER}/${REPO_MAIN}/releases/download"
DOCKER_NAME="netbird"
DOCKER_HOSTNAME=$(hostname)

# Color  Variables
green='\e[32m'
blue='\e[34m'
red="\e[31m"
clear='\e[0m'
yellow='\e[33m'

getLatestRelease() {
  curl --silent \
    "https://api.github.com/repos/${REPO_USER}/${REPO_MAIN}/releases/latest" \
    | grep tag_name \
    | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g'
}

showHelp () {
  echo "$0 - Install Netbird"
  echo " "
  echo "$0 [options]"
  echo " "
  echo "options:"
  echo "  -h,   --help                show brief help"
  echo "  -ia,  --install-app         Install Netbird Binary"
  echo "  -iui, --install-ui          Install Netbird UI Binary"
  echo "  -iv,  --install-version     Target Install version (defaults to latest, ${VERSION})"
  echo "  -d,   --docker              Install Netbird in Docker"
  echo "  -ns,  --no-service          Don't install service"
  echo "  -np,  --no-preconfigure     Don't Preconfigure Client"
  echo "  -b,   --base-url            Base URL For downloads (For Air-Gapped Systems)"
  echo "  -m,   --management-url      Management URL (Defaults to Netbird SaaS)"
  echo "  -sk,  --setup-key           Setup Key"
  echo "  -q,   --quiet               Don't present any prompts"
  echo "Docker Options:"
  echo "  -dn,  --docker-name         Set docker container name"
  echo "  -dh,  --docker-hostname     Set docker hostname"
}
VERSION=$(getLatestRelease)

# Pretty Box Functions
function prettyBoxCurrent () {
  echo -e "[ ${yellow}CURRENT${clear}  ] ${1}"
}
function prettyBoxComplete () {
  echo -e "[ ${green}COMPLETE${clear} ] ${1}"
}
function prettyBoxFailed () {
  echo -e "[ ${red}FAILED${clear}   ] ${i}"
}
function prettyError () {
  echo -e "${red}${1}${clear}"
}
# detect the platform
OS="$(uname)"
case $OS in
  Linux)
    OS='linux'
    ;;
  Darwin)
    OS='darwin'
    binTgtDir=/usr/local/bin
    man1TgtDir=/usr/local/share/man/man1
    ;;
  *)
    echo 'OS not supported'
    exit 2
    ;;
esac

OS_type="$(uname -m)"
case "$OS_type" in
  x86_64|amd64)
    OS_type='amd64'
    ;;
  i?86|x86)
    OS_type='386'
    ;;
  aarch64|arm64)
    OS_type='arm64'
    ;;
  *)
    echo "OS type ${OS_TYPE} not supported"
    exit 2
    ;;
esac

# Test Perams
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      showHelp
      exit 0
      ;;
    -ia|--install-app)
      INSTALL_APP=true
      shift
      ;;
    -iui|--install-ui)
      INSTALL_UI=true
      shift
      ;;
    -d|--docker)
      INSTALL_DOCKER_BASED=true
      if [ ! -x "$(command -v docker)" ]; then
        prettyError "Docker not installed"
        exit 1
      fi
      shift
      ;;
    -dn)
      shift
      DOCKER_NAME=${1}
      shift
      ;;
    --docker-name*)
      DOCKER_NAME=$(echo ${1} | sed -e 's/^[^=]*=//g')
      shift
      ;;
    -dh)
      shift
      DOCKER_HOSTNAME=${1}
      shift
      ;;
    --docker-hostname*)
      DOCKER_HOSTNAME=$(echo ${1} | sed -e 's/^[^=]*=//g')
      shift
      ;;
    -np|--no-preconfigure)
      PRECONFIGURE=false
      shift
      ;;
    -m)
      shift
      MANAGEMENT_URL=${1}
      shift
      ;;
    --management-url*)
      MANAGEMENT_URL=$(echo ${1} | sed -e 's/^[^=]*=//g')
      shift
      ;;
    -b)
      shift
      BASE_URL=${1}
      shift
      ;;
    --base-url*)
      BASE_URL=$(echo ${1} | sed -e 's/^[^=]*=//g')
      shift
      ;;
    -iv)
      shift
      if [ ! "${1}" == "latest" ]; then
        VERSION=${1}
      fi
      shift
      ;;
    --install-version*)
      VTMP=$(echo ${1} | sed -e 's/^[^=]*=//g')
      if [ ! "${VTMP}" == "latest" ]; then
        VERSION=${VTMP}
      fi
      VTMP=
      shift
      ;;
    -sk)
      shift
      SETUP_KEY=${1}
      shift
      ;;
    --setup-key*)
      SETUP_KEY=$(echo ${1} | sed -e 's/^[^=]*=//g')
      shift
      ;;
    -ns|--no-service)
      INSTALL_SERVICE=false
      shift
      ;;
    -q|--quiet)
      DISPLAY_PROMPTS=false
      shift
      ;;
    *)
      break
      ;;
  esac
done

function showInstallSummary () {
  echo -e "------------------------------------------------"
  echo -e "| Install Summary"
  echo -e "------------------------------------------------"
  echo -e "| Target Operating System:       ${green}${OS}${clear}"
  echo -e "| Target Arch:                   ${green}${OS_type}${clear}"
  echo -e "| Target Version:                ${green}v${VERSION}${clear}"
  if ${INSTALL_APP}; then
    echo -e "| Install Netbird Binary:        ${green}Yes${clear}"
  else
    echo -e "| Install Netbird Binary:        ${red}No${clear}"
  fi
  if ${INSTALL_UI}; then
    echo -e "| Install UI Binary:             ${green}Yes${clear}"
  else
    echo -e "| Install UI Binary:             ${red}No${clear}"
  fi

  if ${INSTALL_DOCKER_BASED}; then
    echo -e "| Install Netbird in Docker:     ${green}Yes${clear}"
  else
    echo -e "| Install Netbird in Docker:     ${red}No${clear}"
  fi
  if ${PRECONFIGURE}; then
    echo -e "| Pre-Configure Client:          ${green}Yes${clear}"
  else
    echo -e "| Pre-Configure Client:          ${red}No${clear}"
  fi
  echo -e "| Base URL:                      ${green}${BASE_URL}${clear}"
  echo -e "| Management URL:                ${green}${MANAGEMENT_URL}${clear}"
  echo -e "| Setup Key:                     ${green}${SETUP_KEY}${clear}"
  echo -e "------------------------------------------------"
}

function checkContinueInstall () {
  if ${DISPLAY_PROMPTS}; then
    echo
    read -p "Are you sure you want to continue? [Y/n]: " CONTINUE_INSTALL
    if [[ ! ${CONTINUE_INSTALL} =~ ^[Yy]$ ]]; then
      echo "Cool, See you soon!"
      exit 0
    fi
  fi
}
function installNativeDownloadBinarys () {
  # Download Binary tar files
  if ${INSTALL_APP}; then
    prettyBoxCurrent "Downloading ${APP_MAIN_NAME}"
    curl -OLfsS "${APP_URL}"
    if [ $? == 0 ]; then
      prettyBoxComplete "Downloaded ${APP_MAIN_NAME}"
    else
      echo -e "[ ${red}FAILED${clear}     ] Failed to download ${APP_MAIN_NAME}"
      exit 1
    fi
  fi
  if ${INSTALL_UI}; then
    prettyBoxCurrent "Downloading ${APP_UI_NAME}"
    curl -OLfsS "${UI_URL}"
    if [ $? == 0 ]; then
      prettyBoxComplete "Downloaded ${APP_UI_NAME}"
    else
      prettyBoxFailed "Failed to download ${APP_UI_NAME}"
      exit 1
    fi
  fi
}
function installNativeExtractBinarys () {
  # Extract Binary tar files
  if ${INSTALL_APP}; then
    prettyBoxCurrent "Extracting ${APP_MAIN_NAME}"
    tar xf "${APP_FILENAME}.tar.gz"
    if [ $? == 0 ]; then
      prettyBoxComplete "Extracted ${APP_MAIN_NAME}"
    else
      prettyBoxFailed "Failed to extract ${APP_MAIN_NAME}"
      exit 1
    fi
  fi

  if ${INSTALL_UI}; then
    prettyBoxCurrent "Extracting ${APP_UI_NAME}"
    tar xf "${UI_FILENAME}.tar.gz"
    if [ $? == 0 ]; then
      prettyBoxComplete "Extracted ${APP_UI_NAME}"
    else
      prettyBoxFailed "Failed to extract ${APP_UI_NAME}"
      exit 1
    fi
  fi
}
function installNativePlaceBinarys () {
  if ${INSTALL_APP}; then
    case "${OS}" in
      'linux')
        # Copy File
        prettyBoxCurrent "Copying ${APP_MAIN_NAME} to /usr/bin/${APP_MAIN_NAME}.new"
        cp "${APP_MAIN_NAME}" "/usr/bin/${APP_MAIN_NAME}.new"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary copied succesfully"
        else
          prettyBoxFailed "Failed to copy Binary"
          exit 1
        fi

        # Set Binary Mode
        prettyBoxCurrent "Setting /usr/bin/${APP_MAIN_NAME}.new to 0755"
        chmod 775 "/usr/bin/${APP_MAIN_NAME}.new"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary modes set succesfully"
        else
          prettyBoxFailed "Failed to set Binary file modes"
          exit 1
        fi

        # Set owner and group
        prettyBoxCurrent "Setting /usr/bin/${APP_MAIN_NAME}.new owner and group to root"
        chown root:root "/usr/bin/${APP_MAIN_NAME}.new"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary owner and group set succesfully"
        else
          prettyBoxFailed "Failed to set Binary File owner and group"
          exit 1
        fi

        # Overwrite /usr/bin/netbird
        prettyBoxCurrent "Overwriting /usr/bin/${APP_MAIN_NAME} with /usr/bin/${APP_MAIN_NAME}.new"
        mv "/usr/bin/${APP_MAIN_NAME}.new" "/usr/bin/${APP_MAIN_NAME}"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary Overwritten succesfully"
        else
          prettyBoxFailed "Failed to overwrite /usr/bin/${APP_MAIN_NAME}"
          exit 1
        fi
        ;;
      'darwin')
        # Make sure /usr/local/bin exists
        if [ -d /usr/local/bin ]; then
          prettyBoxCurrent "Create /usr/local/bin"
          mkdir -m 0555 -p /usr/local/bin
          if [ $? == 0 ]; then
            prettyBoxComplete "/usr/local/bin Created Successfully"
          else
            prettyBoxFailed "Failed to create /usr/local/bin"
            exit 1
          fi
        fi

        # Copy Binary
        prettyBoxCurrent "Copying ${APP_MAIN_NAME} to /usr/local/bin/${APP_MAIN_NAME}.new"
        cp "${APP_MAIN_NAME}" "/usr/local/bin/${APP_MAIN_NAME}.new"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary copied succesfully"
        else
          prettyBoxFailed "Failed to copy Binary"
          exit 1
        fi

        # Set Binary Mode
        prettyBoxCurrent "Setting /usr/local/bin/${APP_MAIN_NAME}.new to a=x"
        chmod a=x "/usr/local/bin/${APP_MAIN_NAME}.new"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary File modes set succesfully"
        else
          prettyBoxFailed "Failed to set Binary File modes"
          exit 1
        fi
        
        # Overwrite /usr/bin/netbird
        prettyBoxCurrent "Overwriting /usr/local/bin/${APP_MAIN_NAME} with /usr/local/bin/${APP_MAIN_NAME}.new"
        mv "/usr/local/bin/${APP_MAIN_NAME}.new" "/usr/local/bin/${APP_MAIN_NAME}"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary Overwritten succesfully"
        else
          prettyBoxFailed "Failed to overwrite /usr/bin/${APP_MAIN_NAME}"
          exit 1
        fi
        ;;
    esac
  fi

  if ${INSTALL_UI}; then
    case "${OS}" in
      'linux')
        # Copy Binary
        prettyBoxCurrent "Copying ${APP_UI_NAME} to /usr/bin/${APP_UI_NAME}.new"
        cp "${APP_UI_NAME}" "/usr/bin/${APP_UI_NAME}.new"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary copied succesfully"
        else
          prettyBoxFailed "Failed to copy Binary"
          exit 1
        fi

        # Set Binary Mode
        prettyBoxCurrent "Setting /usr/bin/${APP_UI_NAME}.new to 0755"
        chmod 775 "/usr/bin/${APP_UI_NAME}.new"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary file modes set succesfully"
        else
          prettyBoxFailed "Failed to set Binary file modes"
          exit 1
        fi

        # Set owner and group
        prettyBoxCurrent "Setting /usr/bin/${APP_UI_NAME}.new owner and group to root"
        chown root:root "/usr/bin/${APP_UI_NAME}.new"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary file owner and group set succesfully"
        else
          prettyBoxFailed "Failed to set Binary file owner and group"
          exit 1
        fi

        # Overwrite /usr/bin/netbird
        prettyBoxCurrent "Overwriting /usr/bin/${APP_UI_NAME} with /usr/bin/${APP_UI_NAME}.new"
        mv "/usr/bin/${APP_UI_NAME}.new" "/usr/bin/${APP_UI_NAME}"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary Overwritten succesfully"
        else
          prettyBoxFailed "Failed to overwrite /usr/bin/${APP_UI_NAME}"
          exit 1
        fi
        ;;
      'darwin')
        # Make sure /usr/local/bin exists
        if [ -d /usr/local/bin ]; then
          prettyBoxCurrent "Create /usr/local/bin"
          mkdir -m 0555 -p /usr/local/bin
          if [ $? == 0 ]; then
            prettyBoxComplete "/usr/local/bin Created Successfully"
          else
            prettyBoxFailed "Failed to create /usr/local/bin"
            exit 1
          fi
        fi

        # Copy Binary
        prettyBoxCurrent "Copying ${APP_UI_NAME} to /usr/local/bin/${APP_UI_NAME}.new"
        cp "${APP_UI_NAME}" "/usr/local/bin/${APP_UI_NAME}.new"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary copied succesfully"
        else
          prettyBoxFailed "Failed to copy Binary"
          exit 1
        fi

        # Set Binary Mode
        prettyBoxCurrent "Setting /usr/local/bin/${APP_UI_NAME}.new to a=x"
        chmod a=x "/usr/local/bin/${APP_UI_NAME}.new"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary file modes set succesfully"
        else
          prettyBoxFailed "Failed to set Binary file modes"
          exit 1
        fi
        
        # Overwrite /usr/bin/netbird
        prettyBoxCurrent "Overwriting /usr/local/bin/${APP_UI_NAME} with /usr/local/bin/${APP_MAIN_NAME}.new"
        mv "/usr/local/bin/${APP_UI_NAME}.new" "/usr/local/bin/${APP_UI_NAME}"
        if [ $? == 0 ]; then
          prettyBoxComplete "Binary Overwritten succesfully"
        else
          prettyBoxFailed "Failed to overwrite /usr/bin/${APP_UI_NAME}"
          exit 1
        fi
        ;;
    esac
  fi
}
function installNativeService () {
  if ${INSTALL_APP}; then
    if ${INSTALL_SERVICE}; then
      case ${OS} in
        'linux')
          NETBIRD_BIN=/usr/bin/netbird
          ;;
        'darwin')
          NETBIRD_BIN=/usr/local/bin/netbird
          ;;
      esac
      
      # Install Service
      prettyBoxCurrent "Installing Service"
      ${NETBIRD_BIN} service install >/dev/null
      if [ $? == 0 ]; then
        prettyBoxComplete "Service Successfully Installed"
      else
        prettyBoxFailed "Failed to install service"
        echo
        prettyError "*****************************************************"
        prettyError "* IF ABOVE SAYS \"INIT ALREADY EXISTS\" OR SOMETHING SIMMILAR"
        prettyError "* RUN sudo ${NETBIRD_BIN} service uninstall"
        prettyError "*****************************************************"
        exit 1
      fi

      # Start Service
      prettyBoxCurrent "Starting Service"
      ${NETBIRD_BIN} service start >/dev/null
      if [ $? == 0 ]; then
        prettyBoxComplete "Service Successfully Started"
      else
        prettyBoxFailed "Failed to start service"
        exit 1
      fi
    fi
  fi
}
function installNativePreconfigure () {
  if ${PRECONFIGURE}; then
    case ${OS} in
      'linux')
        NETBIRD_BIN=/usr/bin/netbird
        ;;
      'darwin')
        NETBIRD_BIN=/usr/local/bin/netbird
        ;;
    esac

    CONFIGURE_ARGS="up"
    if [ ! "${MANAGEMENT_URL}" == "https://api.wiretrustee.com:33073" ]; then
      CONFIGURE_ARGS+=" --management-url ${MANAGEMENT_URL}"
    fi
    if [ ! "${SETUP_KEY}" == "" ]; then
      CONFIGURE_ARGS+=" --setup-key ${SETUP_KEY}"
    fi
  fi
  ${NETBIRD_BIN} ${CONFIGURE_ARGS}
}

function installNative () {
  # Create Tempory Directory
  tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t 'netbird-install.XXXXXXXXXX')
  cd "$tmp_dir"

  APP_FILENAME="${APP_MAIN_NAME}_${VERSION}_${OS}_${OS_type}"
  UI_FILENAME="${APP_UI_NAME}-${OS}_${VERSION}_${OS}_${OS_type}"

  # Generate App Binary URLS
  APP_URL="${BASE_URL}/v${VERSION}/${APP_FILENAME}.tar.gz"
  UI_URL="${BASE_URL}/v${VERSION}/${UI_FILENAME}.tar.gz"

  installNativeDownloadBinarys
  installNativeExtractBinarys
  installNativePlaceBinarys
  installNativeService
  installNativePreconfigure
}
function installDocker () {
  if ${INSTALL_DOCKER_BASED}; then
    if [ "${SETUP_KEY}" == "" ]; then
      prettyError "You MUST enter a Setup Key for a docker install"
      exit 1
    fi

    prettyBoxCurrent "Pulling Container"
    docker pull "netbirdio/netbird:${VERSION}"
    if [ $? == 0 ]; then
      prettyBoxComplete "Pull Complete"
    else
      prettyBoxFailed "Failed to pull container"
      exit 1
    fi
    DOCKER_COMMAND="docker run --rm --cap-add=NET_ADMIN -d"
    DOCKER_COMMAND+=" --name ${DOCKER_NAME}"
    DOCKER_COMMAND+=" --hostname ${DOCKER_HOSTNAME}"
    DOCKER_COMMAND+=" -e NB_SETUP_KEY=${SETUP_KEY}"
    DOCKER_COMMAND+=" -e NB_MANAGEMENT_URL=${MANAGEMENT_URL}"
    DOCKER_COMMAND+=" -v netbird-client:/etc/netbird"
    DOCKER_COMMAND+=" netbirdio/netbird:${VERSION}"
    prettyBoxCurrent "Starting Container"
    ${DOCKER_COMMAND}
    if [ $? == 0 ]; then
      prettyBoxComplete "Successfully Started"
    else
      prettyBoxFailed "Failed to start container"
      exit 1
    fi
  fi
}
showInstallSummary
checkContinueInstall
if ${INSTALL_DOCKER_BASED}; then
  installDocker
else
  installNative
fi