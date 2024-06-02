#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export PROFILE_CONFIG="$HOME/.profile"

# check for environment to setup
if [ "$ENV" == "zsh" ]; then
  echo "Configuring for zsh ..."
  export PROFILE_CONFIG="$HOME/.zshrc"
else
  echo "Configuring for bash ..."
fi

# tooling version
NODEJS_VERSION=16.19.0
PYTHON_VERSION=3.10.9
GOLANG_VERSION=1.20
JAVA_VERSION=adoptopenjdk-14.0.2+12
FLUTTER_VERSION=3.7.1-stable
TERRAFORM_VERSION=1.3.7
KUBECTL_VERSION=1.26.1
HELM_VERSION=3.11.0
SOPS_VERSION=3.7.3

# android cli version
ANDROID_CLI=https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip

# helper script to install asdf plugin and set global tooling version
function tools_install() {
  asdf plugin add $1
  asdf install $1 $2
  asdf global $1 $2
}

# install base package and asdf build requirement
sudo apt update && sudo apt install -y lsb-core locales build-essential git curl make jq unzip \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget llvm libncursesw5-dev xz-utils tk-dev libxml2-dev \
  libxmlsec1-dev libffi-dev liblzma-dev apt-transport-https ca-certificates software-properties-common \
  cmake ninja-build libgtk-3-dev clang gnupg

# install openssl 1.1.1 for backward compatibility (ubuntu:jammy)
export UBUNTU_VERSION=`lsb_release -a | grep Release | cut -d ':' -f2 | sed -e 's/^[[:space:]]*//' | cut -d '.' -f1`
if [ $((UBUNTU_VERSION)) -gt 21 ]; then
    OPENSSL_DOWNLOAD_FILENAME=libssl1.1_1.1.1n-0+deb10u6_amd64.deb
    curl -o /tmp/$OPENSSL_DOWNLOAD_FILENAME http://security.debian.org/debian-security/pool/updates/main/o/openssl/$OPENSSL_DOWNLOAD_FILENAME
    sudo apt install -y /tmp/$OPENSSL_DOWNLOAD_FILENAME
fi

# set default locale
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# set gpg tty
# if we sign git commit using gpg, this configuration will redirect password prompt to tty
echo "" >> $PROFILE_CONFIG
echo "# gpg" >> $PROFILE_CONFIG
echo 'export GPG_TTY=$(tty)' >> $PROFILE_CONFIG

# install homebrew / linuxbrew (yeah that's right, homebrew is not only for macOS)
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo "" >> $PROFILE_CONFIG
echo "# homebrew" >> $PROFILE_CONFIG
echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> $PROFILE_CONFIG
source $PROFILE_CONFIG

# install asdf-vm, this make our life easier if we use multiple tooling
brew install asdf fastlane awscli terraform ruby
echo "" >> $PROFILE_CONFIG
echo "# asdf" >> $PROFILE_CONFIG
echo ". /home/linuxbrew/.linuxbrew/opt/asdf/libexec/asdf.sh" >> $PROFILE_CONFIG
source $PROFILE_CONFIG

# asdf configuration
#
# this specific configuration is to make asdf compatible with nvm
# so when the Node.js project has .nvmrc, asdf will honor this file
# if .tool-versions is not found
echo "legacy_version_file = yes" >> ~/.asdfrc

# actually install the tooling
tools_install nodejs $NODEJS_VERSION
tools_install python $PYTHON_VERSION
tools_install golang $GOLANG_VERSION
tools_install java $JAVA_VERSION
tools_install flutter $FLUTTER_VERSION
tools_install terraform $FLUTTER_VERSION
tools_install kubectl $FLUTTER_VERSION
tools_install helm $FLUTTER_VERSION
tools_install sops $FLUTTER_VERSION

# asdf plugin config
# this will automatically set JAVA_HOME to the preferred version when using asdf-java
if [ "$ENV" == "zsh" ]; then
  echo -e ". ~/.asdf/plugins/java/set-java-home.zsh" >> $PROFILE_CONFIG
else
  echo -e ". ~/.asdf/plugins/java/set-java-home.bash" >> $PROFILE_CONFIG
fi
source $PROFILE_CONFIG

# android sdk and cli setup
mkdir -p ~/android/sdk
curl -o cli-tools.zip $ANDROID_CLI
unzip cli-tools.zip -d ~/android/sdk
mv ~/android/sdk/cmdline-tools ~/android/sdk/latest
mkdir -p ~/android/sdk/cmdline-tools
mv ~/android/sdk/latest ~/android/sdk/cmdline-tools
rm -f cli-tools.zip

# set android home path
echo "" >> $PROFILE_CONFIG
echo "# android" >> $PROFILE_CONFIG
echo 'export ANDROID_HOME=$HOME/android/sdk' >> $PROFILE_CONFIG
echo 'export PATH=$PATH:$ANDROID_HOME/emulator' >> $PROFILE_CONFIG
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest' >> $PROFILE_CONFIG
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> $PROFILE_CONFIG
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> $PROFILE_CONFIG
echo 'export ANDROID_SDK_ROOT=$ANDROID_HOME' >> $PROFILE_CONFIG
source $PROFILE_CONFIG

# android sdkmanager basic tools installation
yes | sdkmanager --licenses
sdkmanager --install "platform-tools" "platforms;android-30" "build-tools;32.0.0"

# prompt for restart the session
echo ""
echo "Please restart this terminal session to load the new configuration ..."
