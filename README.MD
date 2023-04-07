### Testnet Automation For Cartenz
This repository contains a collection of scripts and tools for automating the deployment and management of test networks.

# Getting Started
To get started with this project, clone the repository to your local machine:
`git clone https://github.com/gitshock-labs/testnet-automation.git`

## Installation Lighthouse
To install the necessary dependencies, run the following command:
`./setup-clients.sh`

## Create Deposit Json Keys
`cd clients
./deposit.sh new-mnemonic --num_validators 1 --chain cartenz --eth1_withdrawal_address 0x9adddA86C9479C45bD145BBa9FC28146FdF46C83 --folder=validator_keys
set password on password.txt
`

## Run 
./lighthouse.sh

## Installation Lodestar 
`./setup-clients.sh
.setup-nvm-lodestar.sh`

## Create Deposit Json Keys
`cd clients
./deposit.sh new-mnemonic --num_validators 1 --chain cartenz --eth1_withdrawal_address 0x9adddA86C9479C45bD145BBa9FC28146FdF46C83 --folder=validator_keys
set password on password.txt
`

## Run 
`./lodestar.sh`

> For now the deposit phase has not been opened! this is a script for deposit preparation


## Contributing
If you'd like to contribute to this project, please fork the repository and create a new branch for your changes. Then, submit a pull request with your changes.