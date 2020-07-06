/* Copyright (C) 2020, HENSOLDT Cyber GmbH
 *
 * Driver for the Volatile Memory storage (RamDisk)
 */
#include "OS_Error.h"
#include "system_config.h"

#include <string.h>
#include <camkes.h>

static uint8_t storage[RAMDISK_SIZE_BYTES] = { 0u };


//------------------------------------------------------------------------------
static
bool
isOutsideOfTheStorage(
    size_t const offset,
    size_t const size)
{
    // Checking integer overflow.
    if ((offset + size) < offset)
    {
        return true;
    }

    return (RAMDISK_SIZE_BYTES <= (offset + size));
}


//------------------------------------------------------------------------------
OS_Error_t
storage_rpc_write(
    size_t  const offset,
    size_t  const size,
    size_t* const written)
{
    if (isOutsideOfTheStorage(offset, size))
    {
        *written = 0U;
        return OS_ERROR_INSUFFICIENT_SPACE;
    }

    if(NULL == storage)
    {
        return OS_ERROR_INVALID_STATE;
    }

    memcpy(&storage[offset], storage_port, size);
    *written = size;

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
OS_Error_t
storage_rpc_read(
    size_t  const offset,
    size_t  const size,
    size_t* const read)
{
    if (isOutsideOfTheStorage(offset, size))
    {
        *read = 0U;
        return OS_ERROR_OVERFLOW_DETECTED;
    }

    if(NULL == storage)
    {
        return OS_ERROR_INVALID_STATE;
    }

    memcpy(storage_port, &storage[offset], size);
    *read = size;

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
OS_Error_t
storage_rpc_erase(
    size_t  const offset,
    size_t  const size,
    size_t* const erased)
{
    if (isOutsideOfTheStorage(offset, size))
    {
        *erased = 0U;
        return OS_ERROR_OVERFLOW_DETECTED;
    }

    if(NULL == storage)
    {
        return OS_ERROR_INVALID_STATE;
    }

    memset(&storage[offset], 0xFF, size);
    *erased = size;

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
OS_Error_t
storage_rpc_getSize(
    size_t* const size)
{
    *size = RAMDISK_SIZE_BYTES;

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
OS_Error_t
storage_rpc_getState(
    uint32_t* flags)
{
    *flags = 0U;
    return OS_ERROR_NOT_SUPPORTED;
}
