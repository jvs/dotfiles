#!/usr/bin/env bash

wget -O ~/jvs-bashrc.sh \
    https://raw.githubusercontent.com/jvs/dotfiles/ubuntu/jvs-bashrc.sh

cat >>~/.bashrc <<EOL

# Source jvs-bashrc.sh if it exists.
if [ -f "$HOME/jvs-bashrc.sh" ]; then
    . "$HOME/jvs-bashrc.sh"
fi
EOL

sudo apt update
sudo apt install default-jre git terminator

echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list
curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | sudo apt-key add
sudo apt install sbt

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt install yarn

sudo snap install code --classic
sudo apt autoremove
