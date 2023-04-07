#!/bin/bash
set-x

echo "
█▀▀ ▄▀█ █▀█ ▀█▀ █▀▀ █▄░█ ▀█   █░░ █ █▀▀ █░█ ▀█▀ █░█ █▀█ █░█ █▀ █▀▀
█▄▄ █▀█ █▀▄ ░█░ ██▄ █░▀█ █▄   █▄▄ █ █▄█ █▀█ ░█░ █▀█ █▄█ █▄█ ▄█ ██▄"

NodesCount=2
LogLevel=info
######## Checker Functions ########
function Log() {
	echo
	echo "--> $@"
}
function CheckGeth()
{
	Log "Checking Your Geth $1"
	test -z $my_ip && my_ip=`curl ifconfig.me 2>/dev/null` && Log "my_ip=$my_ip"
	geth attach --exec "admin.nodeInfo.enode" data/execution/$1/geth.ipc | sed s/^\"// | sed s/\"$//
	echo Peers: `geth attach --exec "admin.peers" data/execution/$1/geth.ipc | grep "remoteAddress" | grep -e $my_ip -e "127.0.0.1"`
	echo Block Number: `geth attach --exec "eth.blockNumber" data/execution/$1/geth.ipc`
}
function CheckBeacon()
{
	Log "Checking Your Beacon $1"
	echo My ID: `curl http://localhost:$((9596 + $1))/eth/v1/node/identity 2>/dev/null | jq -r ".data.peer_id"`
	echo My enr: `curl http://localhost:$((9596 + $1))/eth/v1/node/identity 2>/dev/null | jq -r ".data.enr"`
	echo Peer Count: `curl http://localhost:$((9596 + $1))/eth/v1/node/peers 2>/dev/null | jq -r ".meta.count"`
	curl http://localhost:$((9596 + $1))/eth/v1/node/syncing 2>/dev/null | jq
}
function CheckAll()
{
	for i in $(seq 0 $(($NodesCount-1))); do
		CheckGeth $i
	done
	for i in $(seq 0 $(($NodesCount-1))); do
		CheckBeacon $i
	done
}
######## Checker All Nodes ########

function KillAll() {
	Log "Kill Your All Node Apps Running"
	killall geth beacon-chain validator
	pkill -f ./prysm.*
	pkill -f lodestar.js
	docker compose -f /home/danapoetri/eth-kzg/docker-run.yml down || echo Looks like docker is not running.
}
function PrepareEnvironment() {
	Log "Prepare Cleaning Environment, Create Validator Key & Beacon Nodes"
	KillAll
	
	git clean -fxd
	rm execution/bootnodes.txt consensus/bootnodes.txt

	test -d logs || mkdir logs
	test -d data || mkdir data
	test -d data/wallet_dir || mkdir data/wallet_dir
	#if [[ -d ../validator_keys8 ]]; then
	#	rm consensus/validator_keys/*
	#	cp -R ../validator_keys8/* consensus/validator_keys
	#fi
	if [[ -d validator_keys8 ]]; then
		rm validator_keys/*
		cp -R validator_keys8/* validator_keys
	fi

	my_ip=`curl ifconfig.me 2>/dev/null` && Log "my_ip=$my_ip"
}
function InitGeth()
{
	Log "Initializing Your Geth $1"
	geth init \
	  --datadir "./data/execution/$1" \
	  ./execution/genesis.json
}
function ImportGethAccount()
{
	Log Importing Account 0xF359C69a1738F74C044b4d3c2dEd36c576A34d9f
	echo "password" > ./data/geth_password.txt
	echo "28fb2da825b6ad656a8301783032ef05052a2899a81371c46ae98965a6ecbbaf" > ./data/account_geth_privateKey
	geth --datadir=data/execution/0 account import --password ./data/geth_password.txt ./data/account_geth_privateKey
}
function RunGeth()
{
	Log "Running Your Geth $1 On Port $((8551 + $1))"
	local bootnodes=$(cat execution/bootnodes.txt 2>/dev/null | tr '\n' ',' | sed s/,$//g)
	echo "Your Bootnode Keys = $bootnodes"
	nohup geth \
	  --http \
	  --http.port $((8545 + $1)) \
	  --http.api=eth,net,web3,admin \
	  --http.addr=0.0.0.0 \
	  --http.vhosts=* \
	  --http.corsdomain=* \
	  --identity "Your-Identity" \
	  --light.maxpeers 30 \
	  --bloomfilter.size 2048 \
	  --cache 1024 \
	  --gcmode="archive" \
	  --networkid 1881 \
	  --datadir "./data/execution/$1" \
	  --authrpc.port $((8551 + $1)) \
	  --port $((30303 + $1)) \
	  --discovery.port $((30303 + $1)) \
	  --syncmode full \
	  --bootnodes=$bootnodes \
	  > ./logs/geth_$1.log &
	sleep 1 
	local my_enode=$(geth attach --exec "admin.nodeInfo.enode" data/execution/$1/geth.ipc | sed s/^\"// | sed s/\"$// | sed s/'127.0.0.1'/$my_ip/)
	echo $my_enode >> ./data/your_bootnodes.txt
	Log "Saving Your Bootnode Keys"
}
function RunBeacon() {
	Log "Start Running Your Beacon $1"
	local bootnodes=`cat consensus/bootnodes.txt 2>/dev/null | grep . | tr '\n' ',' | sed s/,$//g`
	echo "Your Ethereum Node Records = $bootnodes"
	
	nohup lighthouse beacon \
	  --http \
	  --eth1 \
	  --http-address "http://127.0.0.1" \
	  --http-allow-sync-stalled \
	  --execution-endpoints "http://127.0.0.1:$((8551 + $1))" \
	  --http-port=$((5052 + $1)) \
	  --enr-udp-port=$((9000 + $1)) \
	  --enr-tcp-port=$((9000 + $1)) \
	  --discovery-port=$((9000 + $1)) \
	  --port=$((9000 + $1)) \
	  --testnet-dir "./data/consensus/$1" \
	  --datadir "./data/exeecution/$1" \
	  --jwt-secrets="./jwt.hex/$1" \
	  --suggested-fee-recipient 0x36f5e59bcfa6e194eadfbc8dc40113098f21d530 \
	  > ./logs/beacon_$1.log &
	  
	echo Waiting for Beacon enr ...
	local my_enr=''
	while [[ -z $my_enr ]]
	do
		sleep 1
		my_enr=`curl http://localhost:$((5052 + $1))/eth/v1/node/identity 2>/dev/null | jq -r ".data.enr"`
	done
	echo "My Enr = $my_enr"
	echo $my_enr >> ./data/your_bootenr.txt
}
function RunValidator()
{
	Log "Start Running Your Validators"
	#cp -R consensus/validator_keys consensus/validator_keys_$1
	#cp -R validator_keys validator_keys_$1
	nohup lighthouse vc \
	  --http \
	  --unencrypted-http-transport \
	  --http-address 0.0.0.0 \
	  --metrics-port 8801 \
	  --datadir "./data/consensus/1" \
	  --testnet-dir "./data/consensus/1" \
	  --suggestedFeeRecipient "0x8082cf33365f53195a46c839b47131acb6f1af45" \
	  --graffiti "Your-Validator-Graffiti" \
	  --beacon-nodes "http://127.0.0.1:5053" \
	  --logLevel $LogLevel \
	  > ./logs/validator_1.log &
}


#for i in $(seq 0 $(($NodesCount-1))); do
#	InitGeth $i
#	if [[ $i == 0 ]]; then
#	fi
#done

for i in $(seq 0 $(($NodesCount-1))); do
	RunBeacon $i
done

sleep 5

#for i in $(seq 0 $(($NodesCount-1))); do
#	RunValidator $i
#done

ImportGethAccount
PrepareEnvironment
RunGeth 1
InitGeth 1
#RunValidator 1

#RunStaker

CheckAll

echo "
clear && tail -f logs/geth_0.log -n1000
clear && tail -f logs/beacon_0.log -n1000
clear && tail -f logs/beacon_1.log -n1000
clear && tail -f logs/validator_0.log -n1000

curl http://localhost:5052/eth/v1/node/identity | jq
curl http://localhost:5052/eth/v1/node/peers | jq
curl http://localhost:5052/eth/v1/node/syncing | jq

curl http://localhost:5053/eth/v1/node/identity | jq
curl http://localhost:5053/eth/v1/node/peers | jq
curl http://localhost:5053/eth/v1/node/syncing | jq
"