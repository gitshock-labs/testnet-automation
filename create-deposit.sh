#!/bin/bash
set-x

function_deposit() {
    ./clients/deposit.sh new-mnemonic --num_validators 1 --chain cartenz --eth1_withdrawal_address 0x9adddA86C9479C45bD145BBa9FC28146FdF46C83 --folder=./validator_keys
}