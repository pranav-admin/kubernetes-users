#!/bin/bash
cwd=`pwd`
#Creating NameSpace
echo "please type namespace"
read namespace
kubectl create namespace $namespace

#Create User
echo "please type username"
read username
useradd $username

echo "please type $username password"
read password

#setting up password
echo $password | passwd --stdin $username
echo "------------------------------Generating Certificates----------------------------------------------"
openssl genrsa -out $username.key 2048
openssl req -new -key $username.key -out $username.csr -subj "/CN=$username/O=$namespace"
cp -rvf /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/ca.key $cwd/
openssl x509 -req -in $username.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out $username.crt -days 365

echo "---------------------------------Creating kubeconfig File--------------------------------"
clustername=`kubectl config view | grep cluster | tail -n 1 | awk '{print $2}'`
myipaddress=`ifconfig | grep -A 1 ens192 | tail -1 | awk '{print $2}'`

kubectl --kubeconfig kube.kubeconfig config set-cluster $clustername --server https://$myipaddress:6443 --certificate-authority=ca.crt

echo "------------------------------------ Add user in Kube Config File-----------------------------------"
kubectl --kubeconfig kube.kubeconfig config set-credentials $username --client-certificate $cwd/$username.crt --client-key $cwd/$username.key
kubectl --kubeconfig kube.kubeconfig config set-context $username-kubernetes --cluster $clustername --namespace $namespace --user $username
sed -i "/current-context/c current-context: $username-kubernetes" kube.kubeconfig
mv kube.kubeconfig config


echo "-------------------- Copying Files --------------------------"
mkdir /home/$username/.kube
cp -rvf $cwd/* /home/$username/.kube/
chown -R $username:$username /home/$username/.kube
