#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export PROFILE_CONFIG="$HOME/.bashrc"

# tooling version
NODEJS_VERSION=16.15.0
PYTHON_VERSION=3.10.4
GOLANG_VERSION=1.18.2
JAVA_VERSION=adoptopenjdk-14.0.2+12
FLUTTER_VERSION=3.0.1-stable

# android cli version
ANDROID_CLI=https://dl.google.com/android/repository/commandlinetools-mac-8512546_latest.zip

# helper script to install asdf plugin and set global tooling version
function tools_install() {
  asdf plugin add $1
  asdf install $1 $2
  asdf global $1 $2
}

# install base package and asdf build requirement
apt update && apt install -y lsb-core locales build-essential git curl make jq unzip \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget llvm libncursesw5-dev xz-utils tk-dev libxml2-dev \
  libxmlsec1-dev libffi-dev liblzma-dev apt-transport-https ca-certificates software-properties-common \
  cmake ninja-build libgtk-3-dev clang gnupg

# install openssl 1.1.1 for backward compatibility (ubuntu:jammy)
export UBUNTU_VERSION=`lsb_release -a | grep Release | cut -d ':' -f2 | sed -e 's/^[[:space:]]*//' | cut -d '.' -f1`
if [ $((UBUNTU_VERSION)) -gt 21 ]; then
    curl -o /tmp/libssl1.1_1.1.0l-1~deb9u6_amd64.deb http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.0l-1~deb9u6_amd64.deb
    apt install -y /tmp/libssl1.1_1.1.0l-1~deb9u6_amd64.deb
fi

# set default locale
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# set locale
echo "" >> $PROFILE_CONFIG
echo "# locale" >> $PROFILE_CONFIG
echo "LC_ALL=en_US.UTF-8" >> $PROFILE_CONFIG
echo "LANG=en_US.UTF-8" >> $PROFILE_CONFIG

# set gpg tty
# if we sign git commit using gpg, this configuration will redirect password prompt to tty
echo "" >> $PROFILE_CONFIG
echo "# gpg" >> $PROFILE_CONFIG
echo 'export GPG_TTY=$(tty)' >> $PROFILE_CONFIG

# install homebrew
git clone --depth=1 https://github.com/Homebrew/brew ~/.brew
echo "" >> $PROFILE_CONFIG
echo "# homebrew" >> $PROFILE_CONFIG
echo 'export PATH="$HOME/.brew/bin:$HOME/.brew/sbin:$PATH"' >> $PROFILE_CONFIG
source $PROFILE_CONFIG

# install asdf-vm, this make our life easier if we use multiple tooling
brew install asdf
echo "" >> $PROFILE_CONFIG
echo "# asdf" >> $PROFILE_CONFIG
echo ". $(brew --prefix asdf)/libexec/asdf.sh" >> $PROFILE_CONFIG
source $PROFILE_CONFIG

# asdf configuration
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

# asdf plugin config
# this will automatically set JAVA_HOME to the preferred version when using asdf-java
echo -e ". ~/.asdf/plugins/java/set-java-home.bash" >> $PROFILE_CONFIG
source $PROFILE_CONFIG

# android sdk and cli setup
export ANDROID_HOME=$HOME/android/sdk
mkdir -p $ANDROID_HOME
curl -o cli-tools.zip $ANDROID_CLI
unzip cli-tools.zip -d $ANDROID_HOME
mv $ANDROID_HOME/cmdline-tools $ANDROID_HOME/latest
mkdir -p $ANDROID_HOME/cmdline-tools
mv $ANDROID_HOME/latest $ANDROID_HOME/cmdline-tools
rm -f cli-tools.zip

# set android home path
echo "" >> $PROFILE_CONFIG
echo "# android" >> $PROFILE_CONFIG
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> $PROFILE_CONFIG
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
