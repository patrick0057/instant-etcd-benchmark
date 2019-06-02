#!/bin/bash
red=$(tput setaf 1)
green=$(tput setaf 2)
reset=$(tput sgr0)
START_TIME=$(date +%Y-%m-%d--%H%M%S)
SCRIPT_NAME="gen-clusterRegistrationToken-yamls.sh"
function helpmenu() {
    echo "Usage: ${SCRIPT_NAME}
"
    exit 1
}
while getopts "h" opt; do
    case ${opt} in
    h) # process option h
        helpmenu
        ;;
    \?)
        helpmenu
        exit 1
        ;;
    esac
done
function checkpipecmd() {
    RC=("${PIPESTATUS[@]}")
    if [[ "$2" != "" ]]; then
        PIPEINDEX=$2
    else
        PIPEINDEX=0
    fi
    if [ "${RC[${PIPEINDEX}]}" != "0" ]; then
        echo "${green}$1${reset}"
        exit 1
    fi
}
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi
#set os and install dependencies
if [[ -f /etc/lsb_release ]]; then
    OS=ubuntu
    echo You are using Ubuntu
    apt update && apt install -y git wget
fi
if [[ -f /etc/redhat-release ]]; then
    OS=redhat
    echo You are using Red Hat
    yum -y install git wget
fi

#install go
if ! hash go 2>/dev/null; then
    #install go
    wget https://dl.google.com/go/go1.12.2.linux-amd64.tar.gz
    checkpipecmd "Download of go failed."
    tar -xzf go1.12.2.linux-amd64.tar.gz
    checkpipecmd "tar extract of go failed"
    mv go /usr/local
fi
    #checkpipecmd "Moving go to /usr/local failed"
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/Projects/Proj1
    export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
    echo ${green}'If you installed go with this script then set these environment variables either temporarily or permanently by adding them to your ~/.bash_profile.'${red}'
export GOROOT=/usr/local/go
export GOPATH=$HOME/Projects/Proj1
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
'${reset}
echo
echo
echo


#Install Benchmark:
if ! hash benchmark 2>/dev/null; then
    echo ${green}'getting benchmark with "go get go.etcd.io/etcd/tools/benchmark"'${reset}
    go get go.etcd.io/etcd/tools/benchmark
    checkpipecmd "go get benchmark failed"
fi

#Set and verify ETCDCTL_CACERT, ETCDCTL_CERT and ETCDCTL_KEY:
echo "${green}Set these environment variables either temporarily or permanently by adding them to your ~/.bash_profile.${red}"
export $(docker exec -ti etcd env | grep \/kubernetes)
for var in $(docker inspect --format '{{ .Config.Env }}' etcd | sed 's/[][]//g'); do
    if [[ "$var" == *"ETCDCTL_CACERT"* ]] || [[ "$var" == *"ETCDCTL_CERT"* ]] || [[ "$var" == *"ETCDCTL_KEY"* ]]; then
        export ${var}
        echo export ${var}
    fi
done
echo "${reset}"
echo
echo

#The following command will provide metrics which I think will be more important in figuring out what is going on than the benchmark.  Please run this command on one of your etcd nodes.
#curl -k -L https://localhost:2379/metrics  --cert $ETCDCTL_CERT --key $ETCDCTL_KEY
#Benchmark commands that need to be run are below.
export REQUIRE_ENDPOINT=$(docker exec etcd netstat -lpna | grep \:2379 | grep tcp | grep LISTEN | tr -s ' ' | cut -d' ' -f4)
if [[ $REQUIRE_ENDPOINT =~ ":::" ]]; then
    echo "${green}etcd is listening on ${REQUIRE_ENDPOINT}, no need to pass --endpoints${reset}"
    echo ${green}'Benchmark commands to try out'${reset}'
benchmark --cert $ETCDCTL_CERT --key $ETCDCTL_KEY --cacert $ETCDCTL_CACERT --target-leader --conns=1 --clients=1 put --key-size=8 --sequential-keys --total=10000 --val-size=256 2> /dev/null
benchmark --cert $ETCDCTL_CERT --key $ETCDCTL_KEY --cacert $ETCDCTL_CACERT --target-leader  --conns=100 --clients=1000 put --key-size=8 --sequential-keys --total=100000 --val-size=256 2> /dev/null
benchmark --cert $ETCDCTL_CERT --key $ETCDCTL_KEY --cacert $ETCDCTL_CACERT --conns=100 --clients=1000 put --key-size=8 --sequential-keys --total=100000 --val-size=256 2> /dev/null
'${reset}
else
    echo "${green}etcd is only listening on ${REQUIRE_ENDPOINT}, we need to pass --endpoints${reset}"
    echo ${green}'Benchmark commands to try out'${reset}'
export REQUIRE_ENDPOINT=$(docker exec etcd netstat -lpna | grep \:2379 | grep tcp | grep LISTEN | tr -s "' '" | cut -d"' '" -f4)
benchmark --endpoints ${REQUIRE_ENDPOINT} --cert $ETCDCTL_CERT --key $ETCDCTL_KEY --cacert $ETCDCTL_CACERT --target-leader --conns=1 --clients=1 put --key-size=8 --sequential-keys --total=10000 --val-size=256 2> /dev/null
benchmark --endpoints ${REQUIRE_ENDPOINT} --cert $ETCDCTL_CERT --key $ETCDCTL_KEY --cacert $ETCDCTL_CACERT --target-leader  --conns=100 --clients=1000 put --key-size=8 --sequential-keys --total=100000 --val-size=256 2> /dev/null
benchmark --endpoints ${REQUIRE_ENDPOINT} --cert $ETCDCTL_CERT --key $ETCDCTL_KEY --cacert $ETCDCTL_CACERT --conns=100 --clients=1000 put --key-size=8 --sequential-keys --total=100000 --val-size=256 2> /dev/null
'${reset}
fi

#old benchmark comments that remove carriage return from variables, only needed when running inside of bash script
#benchmark --cert $ETCDCTL_CERT --key $ETCDCTL_KEY --cacert $ETCDCTL_CACERT --target-leader --conns=1 --clients=1 put --key-size=8 --sequential-keys --total=10000 --val-size=256
#benchmark --cert $ETCDCTL_CERT --key $ETCDCTL_KEY --cacert $ETCDCTL_CACERT --target-leader  --conns=100 --clients=1000 put --key-size=8 --sequential-keys --total=100000 --val-size=256
#benchmark --cert $ETCDCTL_CERT --key $ETCDCTL_KEY --cacert $ETCDCTL_CACERT --conns=100 --clients=1000 put --key-size=8 --sequential-keys --total=100000 --val-size=256
