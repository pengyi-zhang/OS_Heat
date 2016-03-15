#!/bin/bash

cleanup=false
prefix="qvpc-di"
n_cards=6

shopt -s extglob

function usage {
	echo "This is the function to auto create config disk for each qvpc-di card"

    echo "-h	help"
	echo "-s	number of slots"
	echo "-n	name prefix"
    
    exit 0
}

function delete_glance_img {
    local img_name=$1
    glance image-list | grep  ${img_name} | cut -d'|' -f2 | xargs glance image-delete
}

function write_param_cfg {
    local card_slot=$1
    local card_type=""
    local param_file_name="staros_param.cfg"

    if [ ${card_slot} -lt 3 ]; then
        card_type="CFC"
    else
        card_type="SFC"
    fi
    echo "CARDSLOT=${slot}"         >${param_file_name}
    echo "CARDTYPE=${card_type}"   >>${param_file_name}
    echo "CPUID=0"                 >>${param_file_name}

    local img_name="${prefix}_${card_type}_${card_slot}"

    genisoimage -l -o /tmp/${img_name}.iso staros_param.cfg &>/dev/null
    if [ $? -ne 0 ]; then
        echo "image creation fail for ${img_name}"
    fi
    
    if glance image-list | grep ${img_name} >/dev/null; then
        echo "found ${img_name} already in glance, deleting duplication"
        delete_glance_img ${img_name}   
    fi

    glance image-create --name ${img_name} --disk-format iso --container-format bare --file /tmp/${img_name}.iso --property='hw_disk_bus=ide' --progress
    if [ $? -ne 0 ]; then
        echo "image creation fail for ${img_name}"
    fi

    rm ${param_file_name}
    
    if ${cleanup}; then
        rm ${img_name}.iso
    fi
}

function create_cfg {
    local slot=$1
    case $slot in
    1)  echo "createing cfg disk for CF_${slot}"
        write_param_cfg 1
        ;;
    2)  echo "createing cfg disk for CF_${slot}"
        write_param_cfg 2
        ;;
    +([0-9])    )
        echo "createing cfg disk for SF_${slot}"
        write_param_cfg ${slot}
        ;;
    *)  echo "Invalid slot number passed in"
        return 1
        ;;
    esac
    
}


while getopts ":hcn:s:" opt; do
    case $opt in
    h) 
        usage
        ;;
    s)
        n_cards=${OPTARG}
        ;;
	n)
        prefix=${OPTARG}
        ;;
    c)
        cleanup=true
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1  
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done

function create_all_imgs {
    for slot in $(seq 1 ${n_cards}); do
        create_cfg ${slot}
    done
}
create_all_imgs
