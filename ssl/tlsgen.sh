#!/bin/bash

# Create CA cert
cfssl gencert -initca ./ssl/ca-csr.json | cfssljson -bare ca -

# Create server's cert
cfssl gencert \
  -ca=./ssl/ca.pem \
  -ca-key=./ssl/ca-key.pem \
  -config=./ssl/ca-config.json \
  -profile=web-servers \
  ./ssl/server-csr.json | cfssljson -bare server -

# Import to ACM
aws --profile quest \
    --region us-east-1 \
    acm import-certificate \
    --certificate file://./ssl/server.pem \
    --private-key file://./ssl/server-key.pem \
    --certificate-chain file://./ssl/ca.pem \
    --tag Key=Name,Value=questcert