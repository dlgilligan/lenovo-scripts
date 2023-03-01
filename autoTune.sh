#!/bin/bash
# Daniel Gilligan - 2/24/2023
# Intended for use on RHEL 8.6

# -B : Option for Broadcom Adapters
# -h : should display option information
# -s XX : Uses ethtool to switch to XX link speed
# -m XXXX : uses ifconfig to switch to MTU XXXX for the ports

clear

broadcom=(false)
helper_var=(false)
speed=(false)
mtu=(false)

function helper() {
    echo "usage: $0 [-B/-h/-s/-m] {args} <interface1> <interface2>"
    echo "-B : Further tunes TCP Stack for Broadcom Adapter"
    echo "-s XX : Switches link speed to XX Mb/s"
    echo "-m XXX : Switches MTU to XXX across all interfaces"
    exit 1
}

function usage () {
    echo "usage: $0 [-B/-h/-s/-m] {args} <interface1> <interface2>"
    exit 1
}

# Deal with Options and get them out of command line
while getopts "Bhs:m:" opt; do
    case $opt in
        B) 
            broadcom=(true)
        ;;
        h) 
            helper_var=(true)
        ;;
        s) 
            speed=(true)
            speed_arg="$OPTARG"
        ;;
        m) 
            mtu=(true)
            mtu_arg="$OPTARG"
        ;;
        *)
            break
    esac
done

shift $((OPTIND-1))


# Deals with misinput or simple input
if (($speed) && [ -z "${speed_arg}" ]) || (($mtu) && [ -z "${mtu_arg}" ])); then 
    echo "-s and -m must have some argument"
    exit 1
fi

if $helper_var; then
    helper # FUNC
fi

if [ -z "$1" ] || [ -z "$2" ]; then
    usage # FUNC
fi


function setup() {
    systemctl stop NetworkManager.service
    systemctl stop firewalld.service
    echo 0 > /proc/sys/net/ipv4/ip_forward

    service irqbalance stop
}

function tune_interfaces() {
    ifconfig $interface1 up
    ifconfig $interface2 up

    ethtool -L $interface1 combined 4
    ethtool -L $interface2 combined 4

    ethtool -G $interface1 rx $rx_ring_param tx $tx_ring_param
    ethtool -G $interface2 rx $rx_ring_param tx $tx_ring_param

    ethtool -A $interface1 rx off tx off
    ethtool -A $interface2 rx off tx off
}

function irq_affinity() {
    /networking/netperf-2.7.0/set_irq_affinity_cpulist.sh ${irq_low}-${irq_high_a1} ${interface1}
    /networking/netperf-2.7.0/set_irq_affinity_cpulist.sh ${irq_low_a2}-${irq_high} ${interface2}
}

function tune_stack() {

    # Sysctl calls silenced with -q option since this section is standard and rarely throws errors
    sysctl -wq net.ipv4.tcp_mem="16777216    16777216    16777216"
    sysctl -wq net.ipv4.tcp_wmem="4096   65536   16777216"
    sysctl -wq net.ipv4.tcp_rmem="4096   87380   16777216"
    sysctl -wq net.core.wmem_max=16777216
    sysctl -wq net.core.rmem_max=16777216
    sysctl -wq net.core.wmem_default=16777216
    sysctl -wq net.core.rmem_default=16777216
    sysctl -wq net.core.optmem_max=16777216
    sysctl -wq net.ipv4.tcp_low_latency=1
    sysctl -wq net.ipv4.tcp_timestamps=0
    sysctl -wq net.ipv4.tcp_sack=1
    sysctl -wq net.ipv4.tcp_window_scaling=0
    sysctl -wq net.ipv4.tcp_adv_win_scale=1

    #Broadcom Recommendation
    if $broadcom; then 
        sysctl -wq net.ipv4.tcp_limit_output_bytes=262146
    fi

    pkill netserver
    echo ""
    /networking/netperf-2.7.0/MLK/netserver

    #./iperf3 -s

}

function speed() {
    ifconfig $interface1 down
    ifconfig $interface2 down

    ethtool -s $interface1 autoneg off speed $speed_arg duplex full
    ethtool -s $interface2 autoneg off speed $speed_arg duplex full

    ifconfig $interface1 up
    ifconfig $interface2 up
}

function mtu () {
    ifconfig $interface1 mtu $mtu_arg
    ifconfig $interface2 mtu $mtu_arg
}

######################## MAIN PROGRAM ########################
setup # FUNC

interface1=$1
interface2=$2

irq_high=$(cat /sys/class/net/${interface1}/device/local_cpulist | grep -m 1 -oP '(\d+)[^-]*$') 
irq_low=$(cat /sys/class/net/${interface1}/device/local_cpulist | grep -m 1 -oP '(\d+)(?=-)')
irq_inc=$((${irq_high}-${irq_low})) # MATH
irq_inc=$((${irq_inc}/2)) # MATH
irq_inc=$(($irq_inc-1)) # MATH
irq_high_a1=$((${irq_low}+${irq_inc})) # MATH
irq_low_a2=$((${irq_high}-${irq_inc})) # MATH

#Extract RX Hardware Max
rx_ring_param=$(ethtool -g ${interface1} | grep -m 1 -oP '(?<=RX:).*' | xargs)
#Extract TX Hardware Max
tx_ring_param=$(ethtool -g ${interface1} | grep -m 1 -oP '(?<=TX:).*' | xargs)

tune_interfaces # FUNC
irq_affinity # FUNC
tune_stack # FUNC

if $speed; then
    speed # FUNC
fi

if $mtu; then
    mtu # FUNC
fi

# Verify or display tunings
echo ""
echo "####################VALUES####################"
# Interface 1
echo "INTERFACE 1:"
ethtool $interface1 | grep "Speed"
ifconfig $interface1 | grep $interface1
echo "##############################################"
# Interface 2
echo "INTERFACE 2:"
ethtool $interface2 | grep "Speed"
ifconfig $interface2 | grep $interface2
echo "##############################################"
