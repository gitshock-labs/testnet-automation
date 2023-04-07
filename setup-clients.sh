#!/bin/bash
set-x 

# Navigate to the /opt directory
cd ./clients


echo "Checking Github Latest Release"
get_github_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | # Get latest release from GitHub api
    grep '"tag_name":' |                                            # Get tag line
    sed -E 's/.*"([^"]+)".*/\1/'                                    # Pluck JSON value
}

echo "Installing Rustup"
setup_rust() {
  # install rust
  curl https://sh.rustup.rs -sSf | sh -s -- -y
  source "$HOME/.cargo/env"
  rustup update
}

echo "Installing Lighthouse Portable"
setup_lighthouse() {
	lighthouse_release=$(get_github_release sigp/lighthouse)
	wget "https://github.com/sigp/lighthouse/releases/download/$lighthouse_release/lighthouse-${lighthouse_release}-x86_64-unknown-linux-gnu-portable.tar.gz"
	tar xfz ./lighthouse-${lighthouse_release}-x86_64-unknown-linux-gnu-portable.tar.gz
	chmod +x ./lighthouse
	sudo cp ./lighthouse /usr/local/bin
}

echo "Installing Golang"
setup_golang() {
  # install golang
  wget https://go.dev/dl/go1.20.3.linux-amd64.tar.gz
  sudo rm -rf /usr/local/go && sudo  tar -C /usr/local -xzf go1.20.3.linux-amd64.tar.gz
  export PATH=$PATH:/usr/local/go/bin > ~/.bashrc
  source ~/.bashrc
  go version
}

echo "Installing Eth2ValTools Mnemonics"
setup_eth2valtools() {
  # install eth2-val-tools
  go install github.com/protolambda/eth2-val-tools@latest
  go install github.com/protolambda/eth2-testnet-genesis@latest
  sudo cp ~/go/bin/eth2-val-tools /usr/local/bin
  sudo cp ~/go/bin/eth2-testnet-genesis /usr/local/bin
}

echo "Installing Go-Ethereum"
setup_geth() {
  # install geth
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt install software-properties-common curl wget build-essential micro unzip git jq -y
  sudo add-apt-repository -y ppa:ethereum/ethereum -y
  sudo apt-get update -y
  sudo apt-get install ethereum -y
}

setup_depositcli() {
    if ! [ -d ./clients/deposit.sh ]; then
	git clone https://github.com/gitshock-labs/staking-cli.git 
	cd staking-cli 
	git checkout main
	pip3 install -r requirements.txt 
	python3 setup.py install
	./deposit.sh install
}

setup_rust
setup_eth2valtools
setup_lighthouse
setup_golang
#setup_graffiti_daemon
setup_geth
setup_depositcli

echo Lighthouse Version After Installing $1 = `lighthouse --version`
echo Geth Version After Installing $1 = `geth --version`
echo Go Version After Installing $1 = `go version`
