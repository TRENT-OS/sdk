/*
 *  NIC ChanMux Driver
 *
 *  Copyright (C) 2020, Hensoldt Cyber GmbH
 */

#include "LibDebug/Debug.h"
#include "SeosError.h"
#include "chanmux_nic_drv_api.h"
#include <camkes.h>
#include <limits.h>

static chanmux_nic_drv_config_t config;


//------------------------------------------------------------------------------
void
post_init(void)
{
    Debug_LOG_INFO("[NIC '%s'] %s()", get_instance_name(), __func__);

    // can't make this "static const" or even "static" because the data ports
    // are allocated at runtime
    chanmux_nic_drv_config_t my_config =
    {
        .chanmux =
        {
            .ctrl =
            {
                .id            = CFG_CHANMUX_CHANNEL_CRTL,
                .port =
                {
                    .buffer    = chanMux_port_ctrl,
                    .len       = PAGE_SIZE
                }
            },
            .data =
            {
                .id            = CFG_CHANMUX_CHANNEL_DATA,
                .port_read =
                {
                    .buffer    = chanMux_port_data_read,
                    .len       = PAGE_SIZE
                },
                .port_write = {
                    .buffer    = chanMux_port_data_write,
                    .len       = PAGE_SIZE
                }
            },
            .wait              = chanMux_event_hasData_wait
        },

        .network_stack =
        {
            .to = // driver -> network stack
            {
                .buffer        = nic_port_to,
                .len           = PAGE_SIZE
            },
            .from = // network stack -> driver
            {
                .buffer        = nic_port_from,
                .len           = PAGE_SIZE
            },
            .notify            = nic_event_hasData_emit
        },

        .nic_control_channel_mutex =
        {
            .lock    = mutex_ctrl_channel_lock,
            .unlock  = mutex_ctrl_channel_unlock
        }
    };

    config = my_config;

    seos_err_t ret = chanmux_nic_driver_init(&config);
    if (ret != SEOS_SUCCESS)
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

    seos_err_t ret = chanmux_nic_driver_run();
    if (ret != SEOS_SUCCESS)
    {
        Debug_LOG_FATAL("[NIC '%s'] chanmux_nic_driver_run() failed, error %d",
                        get_instance_name(), ret);
        return -1;
    }

    // actually, this is not supposed to return with SEOS_SUCCESS. We have to
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
seos_err_t
nic_rpc_tx_data(
    size_t* pLen)
{
    return chanmux_nic_driver_rpc_tx_data(pLen);
}


//------------------------------------------------------------------------------
seos_err_t
nic_rpc_get_mac(void)
{
    return chanmux_nic_driver_rpc_get_mac();
}
