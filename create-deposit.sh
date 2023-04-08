amount=32000000000
smin=0
smax=1

eth2-val-tools deposit-data \
  --amount=$amount \
  --fork-version=0x00677693 \
  --source-min=$smin \
  --source-max=$smax \
  --withdrawals-mnemonic="YOUR-MNEMONIC" \
  --validators-mnemonic="YOUR-MNEMONIC" > cartenz_deposits_$smin\_$smax.txt

while read x; do
   account_name="$(echo "$x" | jq '.account')"
   pubkey="$(echo "$x" | jq '.pubkey')"
   echo "Sending deposit for validator $account_name $pubkey"
   ethereal beacon deposit \
      --allow-unknown-contract=true \
      --address="0x4242424242424242424242424242424242424242" \
      --connection=https://rpc-phase1.cartenz.works \
      --data="$x" \
      --allow-excessive-deposit \
      --value="$amount" \
      --from="0x9adddA86C9479C45bD145BBa9FC28146FdF46C83" \
      --privatekey="YOUR-PRIVATEKEY-HERE"
   echo "Sent deposit for validator $account_name $pubkey"
   sleep 2
done < cartenz_deposits_$smin\_$smax.txt
