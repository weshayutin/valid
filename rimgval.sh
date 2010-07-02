#! /bin/bash

HOST=$1

scp * root@$HOST:/root/

ssh root@$HOST /root/imgval.sh

