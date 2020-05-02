/*
 *  Channel MUX
 *
 *  Copyright (C) 2020, Hensoldt Cyber GmbH
 */

#include "ChanMux/ChanMux.h"
#include "SeosError.h"
#include <camkes.h>

extern const ChanMux_config_t cfgChanMux;

//------------------------------------------------------------------------------
static ChanMux*
get_instance_ChanMux(void)
{
    // ToDo: actually, we need a mutex here to ensure all access and especially
    //       the creation is serialized. In the current implementation, the
    //       creation happens from the main thread before the interfaces are
    //       up and afterward we just try to get the instance, but never try to
    //       create it.

    // singleton
    static ChanMux* self = NULL;
    static ChanMux  theOne;

    if (NULL == self)
    {
        static const ChanMux_config_lower_t cfgChanMux_lower = {
            .port = CHANMUX_DATAPORT_ASSIGN(uart_port),
            .writer = uart_rpc_write,
        };

         // create a ChanMUX
        if (!ChanMux_ctor(&theOne, &cfgChanMux, &cfgChanMux_lower))
        {
            Debug_LOG_ERROR("ChanMux_ctor() failed");
            return NULL;
        }

        self = &theOne;
    }

    return self;
}


//==============================================================================
// CAmkES component
//==============================================================================

//---------------------------------------------------------------------------
// called before any other init function is called. Full runtime support is not
// available, e.g. interfaces cannot be expected to be accessible.
void pre_init(void)
{
    Debug_LOG_DEBUG("create ChanMUX instance");

    // ensure the instance is set up
    (void)get_instance_ChanMux();
}


//==============================================================================
// CAmkES Interface "chanMux_lower_rpc" (ChanMUX bottom)
//==============================================================================

//------------------------------------------------------------------------------
// function takeByte() of interface
void
chanMux_lower_rpc_takeByte(char byte)
{
    ChanMux_takeByte(
        get_instance_ChanMux(),
        byte);
}


//==============================================================================
// CAmkES Interface "ChanMuxDriverInf" (ChanMUX top)
//==============================================================================

// this is missing in camkes.h
extern unsigned int chanMux_rpc_get_sender_id(void);


//------------------------------------------------------------------------------
// function write() of interface
seos_err_t
chanMux_rpc_write(
    unsigned int  chanNum,
    size_t        len,
    size_t*       lenWritten)
{
    return ChanMux_write(
            get_instance_ChanMux(),
            chanMux_rpc_get_sender_id(),
            chanNum,
            len,
            lenWritten);
}


//------------------------------------------------------------------------------
// function read() of interface
seos_err_t
chanMux_rpc_read(
    unsigned int  chanNum,
    size_t        len,
    size_t*       lenRead)
{
    return ChanMux_read(
            get_instance_ChanMux(),
            chanMux_rpc_get_sender_id(),
            chanNum,
            len,
            lenRead);
}
