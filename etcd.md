sudo mkdir -p /etc/etcd/ssl
cd /etc/etcd/ssl
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -subj "/CN=etcd-ca" -days 1000 -out ca.crt

openssl genrsa -out etcd.key 4096

openssl req -new -key etcd.key -out etcd.csr -config openssl.cnf

openssl.conf

[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = etcd-server

[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = localhost
IP.1 = 127.0.0.1
IP.2 = 192.168.1.4


openssl x509 -req -in etcd.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out etcd.crt -days 1000 -extensions v3_req -extfile openssl.cnf


openssl genrsa -out client.key 2048

openssl req -new -key client.key   -out etcd-client.csr   -config etcd-client-openssl.conf


etcd-client-openssl.conf

[ req ]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = etcd-client

[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth





openssl x509 -req   -in etcd-client.csr   -CA ca.crt -CAkey ca.key -CAcreateserial   -out client.crt   -days 365   -extensions v3_req   -extfile etcd-client-openssl.conf



ETCDCTL_API=3 etcdctl   --endpoints=https://192.168.1.4:2379   --cert=client.crt   --key=client.key   --cacert=ca.crt   endpoint health

ETCDCTL_API=3 etcdctl   --endpoints=https://192.168.1.4:2379   --cert=client.crt   --key=client.key   --cacert=ca.crt   put foo bar


ETCDCTL_API=3 etcdctl   --endpoints=https://192.168.1.4:2379   --cert=client.crt   --key=client.key   --cacert=ca.crt   get foo