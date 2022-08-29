#!/bin/bash

MICROK8S_CHANNEL="1.21/stable"
RETAIL_APP_REPO="https://github.com/nikhilgoenkatech/retailapp.git"
RETAIL_APP_DIR="~/retailapp"
CURRENCY_SERVICE_REPO="https://github.com/faulkt/STEP-CurrencyService.git"
CURRENCY_SERVICE_DIR="~/currencyservice"

USER="ubuntu"

# ======================================================================
#          ------- Util Functions -------                              #
#  A set of util functions for logging, validating and                 #
#  executing commands.                                                 #
# ======================================================================
thickline="======================================================================"
halfline="============"
thinline="______________________________________________________________________"



setBashas() {
  # Wrapper for runnig commands for the real owner and not as root
  alias bashas="sudo -H -u ${USER} bash -c"
  # Expand aliases for non-interactive shell
  shopt -s expand_aliases
}
timestamp() {
  date +"[%Y-%m-%d %H:%M:%S]"
}
printInfo() {
  echo "[install-prerequisites|INFO] $(timestamp) |>->-> $1 <-<-<|"
}

printInfoSection() {
  echo "[install-prerequisites|INFO] $(timestamp) |$thickline"
  echo "[install-prerequisites|INFO] $(timestamp) |$halfline $1 $halfline"
  echo "[install-prerequisites|INFO] $(timestamp) |$thinline"
}

printError() {
  echo "[install-prerequisites|ERROR] $(timestamp) |x-x-> $1 <-x-x|"
}

# ======================================================================
#          ----- Installation Functions -------                        #
# The functions for installing the different modules and capabilities. #
# Some functions depend on each other, for understanding the order of  #
# execution see the function doInstallation() defined at the bottom    #
# ======================================================================
updateUbuntu() {
  if [ "$update_ubuntu" = true ]; then
    printInfoSection "Updating Ubuntu apt registry"
    apt update
  fi
}

setupProAliases() {
  if [ "$setup_proaliases" = true ]; then
    printInfoSection "Adding Bash and Kubectl Pro CLI aliases to .bash_aliases for user ubuntu and root "
    echo "
      # Alias for ease of use of the CLI
      alias las='ls -las'
      alias hg='history | grep'
      alias h='history'
      alias vaml='vi -c \"set syntax:yaml\" -'
      alias vson='vi -c \"set syntax:json\" -'
      alias pg='ps -aux | grep' " >/root/.bash_aliases
    homedir=$(eval echo ~$USER)
    cp /root/.bash_aliases $homedir/.bash_aliases
  fi
}

dockerInstall() {
  if [ "$docker_install" = true ]; then
    printInfoSection "Installing Docker"
    printInfo "Installing Docker Prerequisites"
    apt-get install ca-certificates curl gnupg lsb-release -y
    printInfo "Adding Docker's GPG Key"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    printInfo "Installing Docker Engine"
    apt-get update
    apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
    usermod -a -G docker $USER
  fi
}

microk8sInstall() {
  if [ "$microk8s_install" = true ]; then
    printInfoSection "Installing Microk8s with version $MICROK8S_CHANNEL"
    snap install microk8s --channel=$MICROK8S_CHANNEL --classic

    printInfo "Add user $USER to microk8 usergroup"
    usermod -a -G microk8s $USER

    printInfo "Add alias to Kubectl (Bash completion for kubectl is already enabled in microk8s)"
    snap alias microk8s.kubectl kubectl

    printInfo "Add Snap to the system wide environment."
    sed -i 's~/usr/bin:~/usr/bin:/snap/bin:~g' /etc/environment

    printInfo "enabling Microk8s addons."
    bashas "microk8s enable dns"

    printInfoSection "Starting Microk8s"
    bashas 'microk8s.start'
  fi
}

nginxInstall() {
  if [ "$nginx_install" = true ]; then
    printInfoSection "Installing Nginx"
    apt update
    apt install nginx -y
    useradd -r nginx
    printInfo "Nginx installed"
  fi
}

downloadRetailApplication() {
  if [ "$download_retailapp" = true ]; then
    printInfoSection "Cloning the Retailapp repository"
    bashas "git clone -b Open-Telemetry $RETAIL_APP_REPO $RETAIL_APP_DIR"
    printInfo "Cloned the Retailapp repository in $RETAIL_APP_DIR directory."
    printInfo "Installing dependencies"
    apt-get install python3-venv -y
  fi
}

downloadCurrencyService(){
  if [ "$download_currencyservice" = true ]; then
    printInfoSection "Cloning the CurrencyService repository"
    bashas "git clone $CURRENCY_SERVICE_REPO $CURRENCY_SERVICE_DIR"
    printInfo "Cloned the CurrencyService repository in $CURRENCY_SERVICE_DIR directory."
    printInfo "Installing Nodejs"
    snap install node --classic --channel=14
  fi
}

createWorkshopUser() {
  if [ "$create_workshop_user" = true ]; then
    printInfoSection "Creating Workshop User from user($USER) into($NEWUSER)"
    homedirectory=$(eval echo ~$USER)
    printInfo "copy home directories and configurations"
    cp -R $homedirectory /home/$NEWUSER
    printInfo "Create user"
    useradd -s /bin/bash -d /home/$NEWUSER -m -G sudo -p $(openssl passwd -1 $NEWPWD) $NEWUSER
    printInfo "Change diretores rights -r"
    chown -R $NEWUSER:$NEWUSER /home/$NEWUSER
    usermod -a -G docker $NEWUSER
    usermod -a -G microk8s $NEWUSER
    printInfo "Warning: allowing SSH passwordAuthentication into the sshd_config"
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    service sshd restart
  fi
}

# ======================================================================
#       -------- Function boolean flags ----------                     #
#  Each function flag representas a function and will be evaluated     #
#  before execution.                                                   #
# ======================================================================
# If you add varibles here, dont forget the function definition and the priting in printFlags function.
verbose_mode=false
update_ubuntu=false
nginx_install=false
docker_install=false
microk8s_install=false
setup_proaliases=false
download_retailapp=false
download_currencyservice=false
create_workshop_user=false

installStandaloneOpenTelemetryWorkshop() {
  update_ubuntu=true
  setup_proaliases=true 
  nginx_install=true
  download_retailapp=true
  download_currencyservice=true
  create_workshop_user=true
}

installDockerOpenTelemetryWorkshop() {
  update_ubuntu=true
  setup_proaliases=true
  docker_install=true
  download_retailapp=true
  download_currencyservice=true
  create_workshop_user=true
}

installKubernetesOpenTelemetryWorkshop() {
  update_ubuntu=true
  setup_proaliases=true
  docker_install=true
  microk8s_install=true
  download_retailapp=true
  download_currencyservice=true
  create_workshop_user=true
}

# ======================================================================
#            ---- The Installation function -----                      #
#  The order of the subfunctions are defined in a sequencial order     #
#  since ones depend on another.                                       #
# ======================================================================
doInstallation() {
  echo ""
  printInfoSection "Installing ... "
  echo ""

  echo ""
  setBashas

  updateUbuntu
  setupProAliases
  
  nginxInstall
  dockerInstall
  microk8sInstall
  downloadRetailApplication
  downloadCurrencyService
  createWorkshopUser

}

