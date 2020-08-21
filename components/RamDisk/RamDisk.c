/* Copyright (C) 2020, HENSOLDT Cyber GmbH
 *
 * Driver for the Volatile Memory storage (RAM Disk)
 */
#include "OS_Error.h"
#include "OS_Dataport.h"

#include "LibUtil/RleCompressor.h"
#include "LibDebug/Debug.h"

#include "system_config.h"

#include <stdint.h>
#include <string.h>
#include <camkes.h>

static uint8_t storage[RAMDISK_SIZE_BYTES] = { 0u };

static struct
{
    bool          init_ok;
    OS_Dataport_t port_storage;

} ctx =
{
    .init_ok       = false,
    .port_storage  = OS_DATAPORT_ASSIGN(storage_port),
};

// The RamDisk can be linked with
extern uint8_t __attribute__((weak)) RAMDISK_IMAGE[];
extern size_t  __attribute__((weak)) RAMDISK_IMAGE_SIZE;

//------------------------------------------------------------------------------
/**
 * @brief   Checks if given parameters are pointing to the valid area of the
 *          storage.
 *
 * Depending on the context "size" is the `size_t` or `off_t`. If "size" refers
 * to a buffer in memory, then it's `size_t`. If size refers to an area on a
 * storage medium, then this can exceed `size_t`, because storage size is not
 * bound to architectural memory limits. So if we check if it is a valid storage
 * area and this is called from erase(), where no buffer is involved, size can
 * be off_t also.
 *
 * As a consequence, this function should use `off_t` for size to answer the
 * question if this is a valid storage are.
 *
 * The problem is that signed interger overflow is undefined in C, so we try to
 * work around this.
 *
 * Furthermore, it seems there is no MAX_OFF_T define (which is a bit odd
 * actually). Using "((off_t)(-1)) >> 1" does not work, as right shift of a
 * negative signed number has implementation-defined behaviour, which means that
 * the compiler will do something sensible, but in a platform-dependent manner
 * i.e. the compiler documentation is supposed to tell you what.
 */
static
bool
isValidStorageArea(
    off_t const offset,
    off_t const size    /* Argument is of type `off_t` on purpose so that the
                            arbitrary large storage can be verified. */)
{
    // Casting to the biggest possible integer for overflow detection purposes.
    uintmax_t const end = (uintmax_t)offset + (uintmax_t)size;

    // Checking integer overflow first. The end index is not part of the area,
    // but we allow offset = end with size = 0 here.
    //
    // We also do not accept negative offsets and sizes (`off_t` is signed).
    return ((offset >= 0)
            && (size >= 0)
            && (end >= offset)
            && (end <= sizeof(storage)));
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "written"
// never points to NULL.
OS_Error_t
NONNULL_ALL
storage_rpc_write(
    off_t   const offset,
    size_t  const size,
    size_t* const written)
{
    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    size_t dataport_size = OS_Dataport_getSize(ctx.port_storage);
    if (size > dataport_size)
    {
        // The client did a bogus request, it knows the data port size but
        // sends more data.
        Debug_LOG_ERROR(
            "size %zu exceeds dataport size %zu",
            size,
            dataport_size);

        return OS_ERROR_INVALID_PARAMETER;
    }

    if (!isValidStorageArea(offset, size))
    {
        *written = 0U;
        return OS_ERROR_OUT_OF_BOUNDS;
    }

    memcpy(&storage[offset], OS_Dataport_getBuf(ctx.port_storage), size);
    *written = size;

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "read" never
// points to NULL.
OS_Error_t
NONNULL_ALL
storage_rpc_read(
    off_t   const offset,
    size_t  const size,
    size_t* const read)
{
    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    size_t dataport_size = OS_Dataport_getSize(ctx.port_storage);
    if (size > dataport_size)
    {
        // The client did a bogus request, it knows the data port size but
        // asks for too much data.
        Debug_LOG_ERROR(
            "size %zu exceeds dataport size %zu",
            size,
            dataport_size);

        return OS_ERROR_INVALID_PARAMETER;
    }

    if (!isValidStorageArea(offset, size))
    {
        *read = 0U;
        return OS_ERROR_OUT_OF_BOUNDS;
    }

    memcpy(OS_Dataport_getBuf(ctx.port_storage), &storage[offset], size);
    *read = size;

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "erased" never
// points to NULL.
OS_Error_t
NONNULL_ALL
storage_rpc_erase(
    off_t  const offset,
    off_t  const size,
    off_t* const erased)
{
    *erased = 0;

    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    if (!isValidStorageArea(offset, size))
    {
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
    off_t* const size)
{
    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

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
    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    *flags = 0U;
    return OS_ERROR_NOT_SUPPORTED;
}

//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "blockSize"
// never points to NULL.
OS_Error_t
NONNULL_ALL
storage_rpc_getBlockSize(
    size_t* const blockSize)
{
    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    *blockSize = 1;
    return OS_SUCCESS;
}

//------------------------------------------------------------------------------
// RamDisk can be linked with an IMAGE, which we decompress here into the
// storage space
void
post_init(void)
{
    size_t sz = 0;
    size_t diskSz = sizeof(storage);
    uint8_t* ptr = storage;

    Debug_LOG_INFO("RamDisk has size of %zu bytes", diskSz);

    if (RAMDISK_IMAGE && RAMDISK_IMAGE_SIZE)
    {
        Debug_LOG_INFO("RamDisk is linked with image of %zu bytes",
                       RAMDISK_IMAGE_SIZE);
        OS_Error_t  err;
        if ((err = RleCompressor_decompress(RAMDISK_IMAGE_SIZE,
                                            RAMDISK_IMAGE,
                                            diskSz,
                                            &sz,
                                            &ptr)) != OS_SUCCESS)
        {
            Debug_LOG_ERROR("RleCompressor_decompress() failed with %i", err);
            return;
        }
        Debug_LOG_INFO("RamDisk initialized with %zu byte from predefined image", sz);
    }

    ctx.init_ok = true;
}
