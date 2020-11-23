/*
 *  NIC Dummy Driver
 *
 *  Copyright (C) 2020, Hensoldt Cyber GmbH
 */

#include "OS_Error.h"
#include "OS_Dataport.h"

#include "LibDebug/Debug.h"

#include <string.h>

#include <camkes.h>

static OS_Dataport_t port = OS_DATAPORT_ASSIGN(nic_port_to);

OS_Error_t
nic_rpc_rx_data(
    size_t* pLen,
    size_t* framesRemaining)
{
    return OS_ERROR_NOT_IMPLEMENTED;
}

OS_Error_t
nic_rpc_tx_data(
    size_t* pLen)
{
    Debug_LOG_TRACE("[NIC '%s'] %s()", get_instance_name(), __func__);
    return OS_SUCCESS;
}

OS_Error_t
nic_rpc_get_mac_address(void)
{
    static const uint8_t mac[6] =
    {
        0x00, 0x11, 0x22, 0x33, 0x44, 0x55
    };

    Debug_LOG_TRACE("[NIC '%s'] %s()", get_instance_name(), __func__);

    // Copy a dummy MAC
    memcpy(OS_Dataport_getBuf(port), mac, sizeof(mac));

    return OS_SUCCESS;
}
