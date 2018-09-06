#!/usr/bin/env bash

# test the validity of the current certificate
# and only renew if expire in less than a month
openssl s_client -connect invoicer.securing-devops.com:443  <<< Q | openssl x509 -checkend 2592000 -noout
[ $? -eq 0 ] && exit 0

echo Renewing certificate for invoicer.securing-devops.com

go get -u github.com/xenolf/lego 

lego -a --email="julien@securing-devops.com" \
--domains="invoicer.securing-devops.com" \
--dns="gandiv5" --key-type ec256 run

wget https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem
openssl x509 -in .lego/certificates/invoicer.securing-devops.com.crt > invoicer.securing-devops.com.crt

aws iam upload-server-certificate \
--server-certificate-name "invoicer.securing-devops.com-$(date +%Y%m%d)" \
--private-key file://$(pwd)/.lego/certificates/invoicer.securing-devops.com.key \
--certificate-body file://$(pwd)/invoicer.securing-devops.com.crt \
--certificate-chain file://$(pwd)/lets-encrypt-x3-cross-signed.pem

aws elb set-load-balancer-listener-ssl-certificate \
--load-balancer-name awseb-e-y-AWSEBLoa-14N2FU8OYHX7I \
--load-balancer-port 443 \
--ssl-certificate-id "arn:aws:iam::927034868273:server-certificate/invoicer.securing-devops.com-$(date +%Y%m%d)"

for servercertname in $(aws iam list-server-certificates | \
                        jq -r '.ServerCertificateMetadataList[] | select ( .Arn | contains ("invoicer.securing-devops.com") ) | .ServerCertificateName' | \
                        grep -v "$(date +%Y%m%d)"); do
  aws iam delete-server-certificate --server-certificate-name $servercertname
done

