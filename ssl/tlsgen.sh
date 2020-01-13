#!/bin/bash

# Create CA cert
cfssl gencert -initca ./ssl/ca-csr.json | cfssljson -bare ca -

# Create server's cert
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=./ssl/ca-config.json \
  -profile=web-servers \
  ./ssl/server-csr.json | cfssljson -bare server -

# Import to ACM
aws --profile quest \
    --region us-east-1 \
    acm import-certificate \
    --certificate file://server.pem \
    --private-key file://server-key.pem \
    --certificate-chain file://ca.pem \
    --tag Key=Name,Value=questcert