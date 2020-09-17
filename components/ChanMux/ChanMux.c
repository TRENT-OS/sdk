/*
 *  Channel MUX
 *
 *  Copyright (C) 2020, Hensoldt Cyber GmbH
 */

#include "ChanMux/ChanMux.h"
#include "OS_Dataport.h"
#include "LibIO/FifoDataport.h"

#include <camkes.h>

extern const ChanMux_Config_t cfgChanMux;


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
        static const ChanMux_ConfigLowerChan_t cfgChanMux_lower =
        {
            .port = OS_DATAPORT_ASSIGN(UnderlyingChan_inputDataport),
            .writer = UnderlyingChan_Rpc_write,
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
// CAmkES Interface "ChanMuxDriverInf" (ChanMUX top)
//==============================================================================

// this is missing in camkes.h
extern unsigned int ChanMuxRpc_get_sender_id(void);


//------------------------------------------------------------------------------
// function write() of interface
OS_Error_t
ChanMuxRpc_write(
    unsigned int  chanNum,
    size_t        len,
    size_t*       lenWritten)
{
    return ChanMux_write(
               get_instance_ChanMux(),
               ChanMuxRpc_get_sender_id(),
               chanNum,
               len,
               lenWritten);
}


//------------------------------------------------------------------------------
// function read() of interface
OS_Error_t
ChanMuxRpc_read(
    unsigned int  chanNum,
    size_t        len,
    size_t*       lenRead)
{
    return ChanMux_read(
               get_instance_ChanMux(),
               ChanMuxRpc_get_sender_id(),
               chanNum,
               len,
               lenRead);
}


//==============================================================================
// CAmkES component
//==============================================================================

//---------------------------------------------------------------------------
// called before any other init function is called. Full runtime support is not
// available, e.g. interfaces cannot be expected to be accessible.
void pre_init(void)
{
    Debug_LOG_DEBUG("[%s] %s", get_instance_name(), __func__);

    Debug_LOG_DEBUG("create ChanMUX instance");

    // ensure the instance is set up
    (void)get_instance_ChanMux();
}

/**
 * @brief loads bytes from the underlying FIFO into the internal one
 *
 * @param fifo the internal FIFO
 * @param underlyingFifo the underlying FIFO
 *
 * @return processing_boost, by default we prefer reading data from the dataport
 * FIFO over processing the data. This ensures the dataport FIFO has space for
 * new data. However, when out FIFO is full, we prefer processing data
 * over reading more data from the underlying FIFO. This return value
 * defines, how much data bytes we should process in a row now, before looking
 * at the underlying FIFO again.
 */
static size_t
loadInternalFifo(
    CharFifo* fifo,
    FifoDataport* underlyingFifo)
{
    size_t processing_boost = 0;

    // try to read new data to drain the lower FIFO as quickly as possible
    for (;;)
    {
        size_t avail = FifoDataport_getAmountConsecutives(underlyingFifo);
        if (0 == avail)
        {
            break;
        }

        char const* buf_port = FifoDataport_getFirst(underlyingFifo);
        assert( NULL != buf_port );

        // copy from dataport to internal fifo
        size_t copied = 0;
        do
        {
            if (!CharFifo_push(fifo, &buf_port[copied]))
            {
                break;
            }
            copied++;
        }
        while (copied < avail);
        FifoDataport_remove(underlyingFifo, copied);

        // if our internal FIFO is more than 75% filled, give processing
        // of data a boost
        const size_t watermark = (CharFifo_getCapacity(fifo) / 4) * 3;
        const size_t used = CharFifo_getSize(fifo);
        if (used > watermark)
        {
            processing_boost = used - watermark;
            if (copied < avail)
            {
                Debug_LOG_DEBUG("avail %zu, copied %zu, boost %zu",
                                avail, copied, processing_boost);
            }
            break;
        }
    }
    return processing_boost;
}

/**
 * @brief waits for new data event from the underlying layer and then executes
 *  loadInternalFifo() which provides the bytes to be processed into the
 *  internal FIFO. Finally it does process the bytes with ChanMux_takeByte() and
 *  consume them from the internal FIFO
 *
 * @param fifo the internal FIFO
 * @param underlyingFifo the underlying FIFO
 *
 * @return true if successful
 */
static bool
extractAndProcessData(
    CharFifo* fifo,
    FifoDataport* underlyingFifo,
    volatile char* fifoOverflow)
{
    // if there is no data in the FIFO then wait for new data
    if (CharFifo_isEmpty(fifo) && FifoDataport_isEmpty(underlyingFifo))
    {
        // no new data will arrive if there was an overflow
        if (0 != *fifoOverflow)
        {
            Debug_LOG_ERROR("dataport FIFO overflow detected");
            // ToDo: clear overflow, reset ChanMux engine and continue
            return false;
        }

        // block waiting for an event. Such an event indicates either
        // new data or a state change that needs attention.
        UnderlyingChan_EventHasData_wait();
    }

    size_t processing_boost = loadInternalFifo(fifo, underlyingFifo);

    // get data to process from our internal FIFO
    do
    {
        char const* char_container = CharFifo_getFirst(fifo);
        if (NULL == char_container)
        {
            break; // FIFO is empty
        }

        ChanMux_takeByte(get_instance_ChanMux(), *char_container);
        CharFifo_pop(fifo);

    }
    while (0 < processing_boost--);

    return true;
}

//------------------------------------------------------------------------------
int run()
{
    Debug_LOG_DEBUG("[%s] %s", get_instance_name(), __func__);

    OS_Dataport_t out_dp = OS_DATAPORT_ASSIGN(UnderlyingChan_outputFifoDataport);

    // the last byte of the dataport holds an overflow flag
    volatile char* fifoOverflow = (volatile char*)(
                                      (uintptr_t)OS_Dataport_getBuf(out_dp)
                                      + OS_Dataport_getSize(out_dp) - 1 );


    FifoDataport* underlyingFifo = (FifoDataport*)OS_Dataport_getBuf(out_dp);

    static char fifo_buffer[2048]; // value found from testing
    CharFifo fifo;
    if (!CharFifo_ctor(&fifo, fifo_buffer, sizeof(fifo_buffer)))
    {
        Debug_LOG_ERROR("CharFifo_ctor() failed");
        return -1;
    }

    for (;;)
    {
        if (!extractAndProcessData(&fifo, underlyingFifo, fifoOverflow))
        {
            Debug_LOG_ERROR("[%s] extractAndProcessData() failed",
                            get_instance_name());
            return -1;
        }
    } // for (;;) main loop
}
