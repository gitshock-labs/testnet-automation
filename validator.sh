#!/bin/bash
set-x

echo "
█▀█ █░█ █▄░█ █▄░█ █ █▄░█ █▀▀   █░█ ▄▀█ █░░ █ █▀▄ ▄▀█ ▀█▀ █▀█ █▀█
█▀▄ █▄█ █░▀█ █░▀█ █ █░▀█ █▄█   ▀▄▀ █▀█ █▄▄ █ █▄▀ █▀█ ░█░ █▄█ █▀▄"

function CreateWallet {
	echo 123456789012 > data/wallet_dir/password.txt
	lighthouse account wallet create \
	  --testnet-dir ./data/consensus \
	  --datadir ./data/wallet_dir \
	  --password-file ./data/wallet_dir/password.txt \
	  --name I_Gusti_Dana_Poetrry \
	  --mnemonic-output-path ./data/wallet_dir/mnemonic.txt
}
function ImportValidator()
{
	Log "Running Validators"
	lighthouse account validator import \
	  --testnet-dir "./data/consensus" \
	  --datadir "./data/validator/1" \
	  --directory ./validator_keys \
	  --password-file ./validator_keys/password.txt \
	  --reuse-password
}
function WaitForPosTransition {
	Log "Waiting for PoS Transitions to Be Accepted. This can take a while (Estimated 24 - 57hours)..."
	local pos=''
	while [[ -z $pos ]]
	do
		sleep 12
		pos=`cat logs/beacon_0.log | grep "Proof of Stake Activated" || :`
		local slot=$(cat logs/beacon_0.log | grep "slot: " | tail -1 | sed s/'.*slot: '//g | sed s/,.*//g)
		echo "Slot = $slot"
	done
	echo $pos
}