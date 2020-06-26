/* Copyright (C) 2020, HENSOLDT Cyber GmbH
 *
 * Driver for the generic storage
 *
 * This component will communicate with the chanmux for accessing the underlying
 * storage.
 */
#include "LibDebug/Debug.h"
#include "ChanMuxNvmDriver.h"

#include <camkes.h>

static const ChanMuxClientConfig_t chanMuxClientConfig = {
    .port  = CHANMUX_DATAPORT_ASSIGN(chanMux_chan_portRead,
                                     chanMux_chan_portWrite),
    .wait  = chanMux_chan_EventHasData_wait,
    .write = chanMux_Rpc_write,
    .read  = chanMux_Rpc_read
};

static ChanMuxNvmDriver chanMuxNvmDriver;
static Nvm* storage;

void storage_rpc__init(void)
{
    if (!ChanMuxNvmDriver_ctor(
            &chanMuxNvmDriver,
            &chanMuxClientConfig))
    {
        Debug_LOG_ERROR("Failed to construct ChanMuxNvmDriver");
        return;
    }

    storage = ChanMuxNvmDriver_get_nvm(&chanMuxNvmDriver);

    if(NULL == storage)
    {
        Debug_LOG_ERROR("Failed to get pointer to storage.");
        return;
    }
}

OS_Error_t
storage_rpc_write(
    size_t  const offset,
    size_t  const size,
    size_t* const written)
{
    *written = storage->vtable->write(storage, offset, storage_port, size);
    return (size == *written) ? OS_SUCCESS : OS_ERROR_GENERIC;
}

OS_Error_t
storage_rpc_read(
    size_t  const offset,
    size_t  const size,
    size_t* const read)
{
    *read = storage->vtable->read(storage, offset, storage_port, size);
    return (size == *read) ? OS_SUCCESS : OS_ERROR_GENERIC;
}

OS_Error_t
storage_rpc_erase(
    size_t  const offset,
    size_t  const size,
    size_t* const erased)
{
    *erased = storage->vtable->erase(storage, offset, size);
    return (size == *erased) ? OS_SUCCESS : OS_ERROR_GENERIC;
}

OS_Error_t
storage_rpc_getSize(size_t* const size)
{
    *size = storage->vtable->getSize(storage);

    if(((size_t)-1) == *size)
    {
        return OS_ERROR_GENERIC;
    }

    return OS_SUCCESS;
}

OS_Error_t
storage_rpc_getState(
    uint32_t* flags)
{
    *flags = 0U;
    return OS_ERROR_NOT_SUPPORTED;
}
