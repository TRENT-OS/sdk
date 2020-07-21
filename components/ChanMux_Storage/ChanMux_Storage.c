/* Copyright (C) 2020, HENSOLDT Cyber GmbH
 *
 * Driver for the generic storage
 *
 * This component will communicate with the chanmux for accessing the underlying
 * storage.
 */
#include "LibDebug/Debug.h"
#include "ChanMuxNvmDriver.h"

#include <inttypes.h>
#include <camkes.h>

static const ChanMuxClientConfig_t chanMuxClientConfig =
{
    .port  = CHANMUX_DATAPORT_ASSIGN(chanMux_chan_portRead,
                                     chanMux_chan_portWrite),
    .wait  = chanMux_chan_EventHasData_wait,
    .write = chanMux_Rpc_write,
    .read  = chanMux_Rpc_read
};

static ChanMuxNvmDriver chanMuxNvmDriver;
static Nvm* storage;

// Since signed offset (off_t) gets down casted to size_t, we need to verify
// the correctness of this cast i.e. 0 <= offset <= max_size_t.
static bool valueFitsIntoSize_t(off_t const offset)
{
    return (0 <= offset) && (offset <= SIZE_MAX);
}

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

    if (NULL == storage)
    {
        Debug_LOG_ERROR("Failed to get pointer to storage.");
        return;
    }
}

OS_Error_t
storage_rpc_write(
    off_t   const offset,
    size_t  const size,
    size_t* const written)
{
    if (!valueFitsIntoSize_t(offset))
    {
        Debug_LOG_ERROR(
            "%s: Offset our of range. offset = 0x%" PRIxMAX, __func__, offset);

        return OS_ERROR_INVALID_PARAMETER;
    }

    *written = storage->vtable->write(storage, offset, storage_port, size);
    return (size == *written) ? OS_SUCCESS : OS_ERROR_GENERIC;
}

OS_Error_t
storage_rpc_read(
    off_t   const offset,
    size_t  const size,
    size_t* const read)
{
    if (!valueFitsIntoSize_t(offset))
    {
        Debug_LOG_ERROR(
            "%s: Offset our of range. offset = 0x%" PRIxMAX, __func__, offset);

        return OS_ERROR_INVALID_PARAMETER;
    }

    *read = storage->vtable->read(storage, offset, storage_port, size);
    return (size == *read) ? OS_SUCCESS : OS_ERROR_GENERIC;
}

OS_Error_t
storage_rpc_erase(
    off_t  const offset,
    off_t  const size,
    off_t* const erased)
{
    if (!valueFitsIntoSize_t(offset) || !valueFitsIntoSize_t(size))
    {
        Debug_LOG_ERROR(
            "%s: `offset` or `size` out of range: "
            "offset = 0x%" PRIxMAX ", "
            "size = 0x%" PRIxMAX,
            __func__,
            offset,
            size);

        return OS_ERROR_INVALID_PARAMETER;
    }

    *erased = storage->vtable->erase(storage, offset, size);
    return (size == *erased) ? OS_SUCCESS : OS_ERROR_GENERIC;
}

OS_Error_t
storage_rpc_getSize(off_t* const size)
{
    const size_t sizePriorToCast = storage->vtable->getSize(storage);

    // -1 is reserved for a generic error on the ChanMux side.
    if (((size_t) -1) == sizePriorToCast)
    {
        Debug_LOG_ERROR("%s: Unexpected error.", __func__);
        return OS_ERROR_GENERIC;
    }

    *size = (off_t)sizePriorToCast;
    return OS_SUCCESS;
}

OS_Error_t
storage_rpc_getState(
    uint32_t* flags)
{
    *flags = 0U;
    return OS_ERROR_NOT_SUPPORTED;
}
