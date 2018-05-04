#!/bin/bash

echo generating diffie-hellman parameters...
export RANDFILE=~/.rnd
DIR=/usr/local/share/ca-certificates
openssl dhparam -dsaparam -out $DIR/dhparam.pem 4096
echo ...done