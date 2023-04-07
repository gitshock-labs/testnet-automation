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
function RunGeth()
{
	Log "Running Your Geth $1 On Port $((8551 + $1))"
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
	  --bootnodes="enode://0e2b41699b95e8c915f4f5d18962c0d2db35dc22d3abbebbd25fc48221d1039943240ad37a6e9d853c0b4ea45da7b6b5203a7127b5858c946fc040cace8d2d63@147.75.71.217:30303,enode://45b4fff6ab970e1e490deea8a5f960d806522fafdb33c8eaa38bc0ae970efc2256fc5746f0ecfec770af24c44864a3e6772a64f2e9f031f96fd4af7fd0483110@147.75.71.217:30304,enode://e3b6cbacb5b918ea46104ca295101a53f159d06769e4d5730b4edd95e0880b4ca84bccb5d0c7ca70cf95dfeccef92bb6caa0533be667e4bb0114fc12051989cb@212.47.241.173:30303,enode://787282effee17f9a9da49b3376f475b1521846ee924c962595e672ee9b90290e39b9f2fb67a5f34fb1f4964353cd6ef2a989c110d53b8fd169d8481c44f93119@44.202.92.152:30303" \
	  > ./logs/geth_$1.log &
	sleep 1 
	local my_enode=$(geth attach --exec "admin.nodeInfo.enode" data/execution/$1/geth.ipc | sed s/^\"// | sed s/\"$// | sed s/'127.0.0.1'/$my_ip/)
	echo $my_enode >> execution/bootnodes.txt
	Log "Saving Your Bootnode Keys"
}
function RunBeacon() {
	Log "Start Running Your Beacon $1"
	local bootnodes=`cat consensus/bootnodes.txt 2>/dev/null | grep . | tr '\n' ',' | sed s/,$//g`
	echo "Your Ethereum Node Records = $bootnodes"
	
	nohup clients/lodestar beacon \
	  --suggestedFeeRecipient "0x8082cf33365f53195a46c839b47131acb6f1af45" \
	  --execution.urls "http://127.0.0.1:$((8551 + $1))" \
	  --jwt-secret "./data/execution/$1/geth/jwtsecret" \
	  --dataDir "./data/consensus/$1" \
	  --paramsFile "./consensus/config.yaml" \
	  --genesisStateFile "./consensus/genesis.ssz" \
	  --enr.ip $my_ip \
	  --rest.port $((9596 + $1)) \
	  --port $((9000 + $1)) \
	  --network.connectToDiscv5Bootnodes true \
	  --logLevel $LogLevel \
	  --bootnodes=$bootnodes \
	  > ./logs/beacon_$1.log &
	  
	echo Waiting for Beacon enr ...
	local my_enr=''
	while [[ -z $my_enr ]]
	do
		sleep 1
		my_enr=`curl http://localhost:$((9596 + $1))/eth/v1/node/identity 2>/dev/null | jq -r ".data.enr"`
	done
	echo "My Enr = $my_enr"
	echo $my_enr >> consensus/bootnodes.txt
}
function RunValidator()
{
	Log "Start Running Your Validators $1"
	#cp -R consensus/validator_keys consensus/validator_keys_$1
	cp -R validator_keys validator_keys_$1
	nohup clients/lodestar validator \
	  --dataDir "./data/consensus/$1" \
	  --beaconNodes "http://127.0.0.1:$((9596 + $1))" \
	  --suggestedFeeRecipient "0x8082cf33365f53195a46c839b47131acb6f1af45" \
	  --graffiti "Your-Validator-Graffiti" \
	  --paramsFile "./consensus/config.yaml" \
	  --importKeystores "validator_keys_$1" \
	  --importKeystoresPassword "validator_keys_$1/password.txt" \
	  --logLevel $LogLevel \
	  > ./logs/validator_$1.log &
}
function RunStaker {
	local folder=/root/validator_keys8_other
	echo {\"keys\":$(cat `ls -rt $folder/deposit_data* | tail -n 1`), \"address\":\"0xF359C69a1738F74C044b4d3c2dEd36c576A34d9f\", \"privateKey\": \"0x476a21a2139275aed75518da897e171bd1ca18ab2d5847297a08f0025e06c627\"} > $folder/payload.txt
	
	curl -X POST -H "Content-Type: application/json" -d @$folder/payload.txt http://localhost:8005/api/account/stake

	nohup lodestar validator \
	  --dataDir "./data/consensus/1" \
	  --beaconNodes "http://127.0.0.1:9597" \
	  --suggestedFeeRecipient "0x8082cf33365f53195a46c839b47131acb6f1af45" \
	  --graffiti "Your-Validator-Graffiti" \
	  --paramsFile "./consensus/config.yaml" \
	  --importKeystores "$folder" \
	  --importKeystoresPassword "$folder/password.txt" \
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

for i in $(seq 0 $(($NodesCount-1))); do
	RunValidator $i
done

PrepareEnvironment
RunGeth 1
InitGeth 1
#RunValidator 0

#RunStaker

CheckAll

echo "
clear && tail -f logs/geth_0.log -n1000
clear && tail -f logs/geth_1.log -n1000
clear && tail -f logs/beacon_0.log -n1000
clear && tail -f logs/beacon_1.log -n1000
clear && tail -f logs/validator_0.log -n1000
clear && tail -f logs/validator_1.log -n1000

curl http://localhost:9596/eth/v1/node/identity | jq
curl http://localhost:9596/eth/v1/node/peers | jq
curl http://localhost:9596/eth/v1/node/syncing | jq
"
