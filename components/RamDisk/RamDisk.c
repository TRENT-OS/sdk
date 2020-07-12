/* Copyright (C) 2020, HENSOLDT Cyber GmbH
 *
 * Driver for the Volatile Memory storage (RAM Disk)
 */
#include "OS_Error.h"
#include "system_config.h"

#include <stdint.h>
#include <string.h>
#include <camkes.h>

static uint8_t storage[RAMDISK_SIZE_BYTES] = { 0u };


//------------------------------------------------------------------------------
static
bool
isValidStorageArea(
    size_t const offset,
    size_t const size)
{
    size_t const end = offset + size;
    // Checking integer overflow first. The end index is not part of the area,
    // but we allow offset = end with size = 0 here
    return ( (end >= offset) && (end <= sizeof(storage)) );
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "written"
// never points to NULL.
OS_Error_t
NONNULL_ALL
storage_rpc_write(
    size_t  const offset,
    size_t  const size,
    size_t* const written)
{
    if (!isValidStorageArea(offset, size))
    {
        *written = 0U;
        return OS_ERROR_OUT_OF_BOUNDS;
    }

    memcpy(&storage[offset], storage_port, size);
    *written = size;

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "read" never
// points to NULL.
OS_Error_t
NONNULL_ALL
storage_rpc_read(
    size_t  const offset,
    size_t  const size,
    size_t* const read)
{
    if (!isValidStorageArea(offset, size))
    {
        *read = 0U;
        return OS_ERROR_OUT_OF_BOUNDS;
    }

    memcpy(storage_port, &storage[offset], size);
    *read = size;

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "erased" never
// points to NULL.
OS_Error_t
NONNULL_ALL
storage_rpc_erase(
    size_t  const offset,
    size_t  const size,
    size_t* const erased)
{
    if (!isValidStorageArea(offset, size))
    {
        *erased = 0U;
        return OS_ERROR_OUT_OF_BOUNDS;
    }

    // Erase for a RAM-Disk does not really make sense. It's a command that
    // comes handy in two cases when dealing with storage hardware:
    //
    // * Flash/EEPROM based storage usually does not support random writing,
    //   but bits can only be toggled in one direction, e.g. 1 -> 0. Toggling
    //   bits in the other direction does not work, the whole sector must be
    //   "reloaded" instead ( 0 -> 1). Thus erase is usually valid on full
    //   sectors only.
    //
    // * The trim() command was introduced with SSDs. It tells the disk that a
    //   certain area is no longer in use and the data there can be discarded.
    //   It leaves more room for optimization if further wiping details are
    //   then left to the SSD's controller instead of explicitly writing
    //   anything (e.g. zeros) there. Reading from wiped space my return
    //   deterministic data (e.g. zeros) or not, details depend on the SSD.
    //
    // Instead of returning OS_ERROR_NOT_IMPLEMENTED or OS_ERROR_NOT_SUPPORTED
    // here, we implement erase() as writing all bits to 1, which mimics a
    // classic EEPROM behavior.
    memset(&storage[offset], 0xFF, size);
    *erased = size;

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "size" never
// points to NULL.
OS_Error_t
NONNULL_ALL
storage_rpc_getSize(
    size_t* const size)
{
    *size = sizeof(storage);

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "flags" never
// points to NULL.
OS_Error_t
NONNULL_ALL
storage_rpc_getState(
    uint32_t* flags)
{
    *flags = 0U;
    return OS_ERROR_NOT_SUPPORTED;
}
