#!/bin/bash
set-x

echo "
█▄█ █▀█ █░░ █▀█   █▀▄▀█ █▀▀ █▀█ █▀▀ █▀▀ █▀▄ █▄░█ █▀▀ ▀█▀   █░░ █▀█ █▀▄ █▀▀ █▀ ▀█▀ ▄▀█ █▀█
░█░ █▄█ █▄▄ █▄█   █░▀░█ ██▄ █▀▄ █▄█ ██▄ █▄▀ █░▀█ ██▄ ░█░   █▄▄ █▄█ █▄▀ ██▄ ▄█ ░█░ █▀█ █▀▄"

######## Checker Functions
function Log() {
	echo
	echo "--> $1"
}

# Navigate to the /clients directory
cd ./clients

setup_nvm() {
	# Install NVM 
	wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

	# Bind Bash
	export NVM_DIR="$HOME/.nvm"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
	[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

	# Checking NVM
	source ~/.bashrc
	source ~/.profile

	# Install LTS Version
	nvm install --lts
	nvm use --lts
}

setup_yarn() {
	# add GPG Key
	curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -

	# add Repo
	echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
	sudo apt update && sudo apt install yarn -y
}

setup_lodestar() {
	git clone -b stable https://github.com/chainsafe/lodestar.git
	cd lodestar
	yarn install --ignore-optional
	yarn run build
}

setup_nvm
setup_yarn
setup_lodestar


echo $1 = `./clients/lodestar --version`
echo $1 = `yarn --version`
echo $1 = `nvm --version`
