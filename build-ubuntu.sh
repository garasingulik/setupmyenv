#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
export UBUNTU_VERSION=`lsb_release -a | grep Release | cut -d ':' -f2 | sed -e 's/^[[:space:]]*//' | cut -d '.' -f1`
export PROFILE_CONFIG=~/.profile

# check if using zsh
if  [ -z "$1" ] && [ "$1" == "-zsh" ]; then
  export PROFILE_CONFIG=~/.zprofile
fi

# tooling version
NODEJS_VERSION=16.15.0
PYTHON_VERSION=3.10.4
GOLANG_VERSION=1.18.2
JAVA_VERSION=adoptopenjdk-14.0.2+12
FLUTTER_VERSION=3.0.1-stable

# android cli
ANDROID_CLI=https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip

# install plugin and tooling
function tools_install() {
  asdf plugin add $1
  asdf install $1 $2
  asdf global $1 $2
}

# install base package
sudo apt update && sudo apt install -y lsb-core locales build-essential git curl make jq unzip \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget llvm libncursesw5-dev xz-utils tk-dev libxml2-dev \
  libxmlsec1-dev libffi-dev liblzma-dev apt-transport-https ca-certificates software-properties-common \
  cmake ninja-build libgtk-3-dev

# install open ssl 1.1.1 for backward compatibility (ubuntu:jammy)
if [ $((UBUNTU_VERSION)) -gt 21 ]; then
    curl -o /tmp/libssl1.1_1.1.0l-1~deb9u6_amd64.deb http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.0l-1~deb9u6_amd64.deb
    sudo apt install -y /tmp/libssl1.1_1.1.0l-1~deb9u6_amd64.deb
fi

# set locale
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# install homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo "" >> $PROFILE_CONFIG
echo "# homebrew" >> $PROFILE_CONFIG
echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> $PROFILE_CONFIG
source $PROFILE_CONFIG

# install asdf
brew install asdf
echo "" >> $PROFILE_CONFIG
echo "# asdf" >> $PROFILE_CONFIG
echo ". /home/linuxbrew/.linuxbrew/opt/asdf/libexec/asdf.sh" >> $PROFILE_CONFIG
source $PROFILE_CONFIG

# asdf configuration
echo "legacy_version_file = yes" >> ~/.asdfrc

# install tooling
tools_install nodejs $NODEJS_VERSION
tools_install python $PYTHON_VERSION
tools_install golang $GOLANG_VERSION
tools_install java $JAVA_VERSION
tools_install flutter $FLUTTER_VERSION

# plugin config
if [ $1 == "-zsh" ]; then
  echo -e ". ~/.asdf/plugins/java/set-java-home.zsh" >> $PROFILE_CONFIG
else
  echo -e ". ~/.asdf/plugins/java/set-java-home.bash" >> $PROFILE_CONFIG
fi
source $PROFILE_CONFIG

# android sdk setup
mkdir -p ~/android/sdk
curl -o cli-tools.zip $ANDROID_CLI
unzip cli-tools.zip -d ~/android/sdk
mv ~/android/sdk/cmdline-tools ~/android/sdk/latest
mkdir -p ~/android/sdk/cmdline-tools
mv ~/android/sdk/latest ~/android/sdk/cmdline-tools
rm -f cli-tools.zip

# set path
echo "" >> $PROFILE_CONFIG
echo "# android" >> $PROFILE_CONFIG
echo 'export ANDROID_HOME=$HOME/android/sdk' >> $PROFILE_CONFIG
echo 'export PATH=$PATH:$ANDROID_HOME/emulator' >> $PROFILE_CONFIG
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest' >> $PROFILE_CONFIG
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> $PROFILE_CONFIG
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> $PROFILE_CONFIG
echo 'export ANDROID_SDK_ROOT=$ANDROID_HOME' >> $PROFILE_CONFIG
source $PROFILE_CONFIG

# android sdkmanager
yes | sdkmanager --licenses
sdkmanager --install "platform-tools" "platforms;android-30" "build-tools;32.0.0"
