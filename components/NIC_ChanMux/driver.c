/*
 *  NIC ChanMux Driver
 *
 *  Copyright (C) 2020, Hensoldt Cyber GmbH
 */

#include "LibDebug/Debug.h"
#include "OS_Error.h"
#include "OS_Dataport.h"
#include "chanmux_nic_drv_api.h"
#include <camkes.h>
#include <limits.h>


//------------------------------------------------------------------------------
void
post_init(void)
{
    Debug_LOG_INFO("[NIC '%s'] %s()", get_instance_name(), __func__);

    static const chanmux_nic_drv_config_t config =
    {
        .chanmux =
        {
            .ctrl =
            {
                .id         = CFG_CHANMUX_CHANNEL_CRTL,
                .func = {
                    .read   = chanMux_Rpc_read,
                    .write  = chanMux_Rpc_write
                },
                .port       = CHANMUX_DATAPORT_ASSIGN(
                    chanMux_ctrl_portRead,
                    chanMux_ctrl_portWrite),
                .wait       = chanMux_ctrl_EventHasData_wait
            },
            .data =
            {
                .id         = CFG_CHANMUX_CHANNEL_DATA,
                .func = {
                    .read   = chanMux_Rpc_read,
                    .write  = chanMux_Rpc_write
                },
                .port       = CHANMUX_DATAPORT_ASSIGN(
                    chanMux_data_portRead,
                    chanMux_data_portWrite),
                .wait       = chanMux_data_EventHasData_wait
            },
        },

        .network_stack =
        {
            // driver -> network stack
            .to             = OS_DATAPORT_ASSIGN(nic_port_to),
            // network stack -> driver
            .from           = OS_DATAPORT_ASSIGN(nic_port_from),
            .notify         = nic_event_hasData_emit
        },

        .nic_control_channel_mutex =
        {
            .lock           = mutex_ctrl_channel_lock,
            .unlock         = mutex_ctrl_channel_unlock
        }
    };

    Debug_LOG_INFO("[NIC '%s'] starting driver", get_instance_name());


    OS_Error_t ret = chanmux_nic_driver_init(&config);
    if (ret != OS_SUCCESS)
    {
        Debug_LOG_FATAL("[NIC '%s'] chanmux_nic_driver_init() failed, error %d",
                        get_instance_name(), ret);
    }
}



//------------------------------------------------------------------------------
int
run(void)
{
    Debug_LOG_INFO("[NIC '%s'] %s()", get_instance_name(), __func__);

    OS_Error_t ret = chanmux_nic_driver_run();
    if (ret != OS_SUCCESS)
    {
        Debug_LOG_FATAL("[NIC '%s'] chanmux_nic_driver_run() failed, error %d",
                        get_instance_name(), ret);
        return -1;
    }

    // actually, this is not supposed to return with OS_SUCCESS. We have to
    // assume this is a graceful shutdown for some reason
    Debug_LOG_WARNING("[NIC '%s'] graceful termination", get_instance_name());

    return 0;
}


//------------------------------------------------------------------------------
// CAmkES RPC API
//
// the prefix "nic_driver" is RPC connector name, the rest comes from the
// interface definition
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
OS_Error_t
nic_rpc_tx_data(
    size_t* pLen)
{
    return chanmux_nic_driver_rpc_tx_data(pLen);
}


//------------------------------------------------------------------------------
OS_Error_t
nic_rpc_get_mac(void)
{
    return chanmux_nic_driver_rpc_get_mac();
}
