/* Copyright (C) 2020, HENSOLDT Cyber GmbH
 *
 * Driver for the Volatile Memory storage (RamDisk)
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
    // Instead of returning  OS_ERROR_NOT_IMPLEMENTED or OS_ERROR_NOT_SUPPORTED
    // here, we implement erase() as writing all bits to 1, which mimics a
    // classic EEPROM behavior.
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
