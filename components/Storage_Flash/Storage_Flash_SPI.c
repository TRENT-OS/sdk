/*
 * SPI Flash storage driver
 *
 * Copyright (C) 2020, HENSOLDT Cyber GmbH
 */

#include "OS_Error.h"
#include "OS_Dataport.h"

#include "LibDebug/Debug.h"
#include "LibUtil/BitConverter.h"

#include <platsupport/plat/spiflash.h>

#include "TimeServer.h"

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include <camkes.h>

static struct
{
    spiflash_t     spi_flash_ctx;
    OS_Dataport_t  port_storage;
    OS_Dataport_t  port_spi;
    bool           init_ok;
} ctx =
{
    .port_storage  = OS_DATAPORT_ASSIGN(storage_port),
    .port_spi      = OS_DATAPORT_ASSIGN(spi_port),
    .init_ok       = false,
};


//------------------------------------------------------------------------------
// callback from SPI library
static
__attribute__((__nonnull__))
int
impl_spiflash_spi_txrx(
    spiflash_t* spi,
    const uint8_t* tx_data,
    uint32_t tx_len,
    uint8_t* rx_data,
    uint32_t rx_len)
{
    if (tx_len > OS_Dataport_getSize(ctx.port_spi))
    {
        Debug_LOG_ERROR("tx_len %d too big for dataport", tx_len);
        return -1;
    }

    if (rx_len > OS_Dataport_getSize(ctx.port_spi))
    {
        Debug_LOG_ERROR("rx_len %d too big for dataport", rx_len);
        return -1;
    }

    // copy command into SPI driver data port
    memcpy(OS_Dataport_getBuf(ctx.port_spi), tx_data, tx_len);

    OS_Error_t ret = spi_rpc_txrx(tx_len, rx_len);
    if (OS_SUCCESS != ret)
    {
        Debug_LOG_ERROR("spi_interface_txrx() failed, code %d", ret);
        return -1;
    }

    memcpy(rx_data, OS_Dataport_getBuf(ctx.port_spi), rx_len);

    return 0;
}


//------------------------------------------------------------------------------
// callback from SPI library
static
__attribute__((__nonnull__))
void
impl_spiflash_spi_cs(
    spiflash_t* spi,
    uint8_t cs)
{
    OS_Error_t ret = spi_rpc_cs(cs);
    if (OS_SUCCESS != ret)
    {
        Debug_LOG_ERROR("spi_interface_cs() failed, code %d", ret);
        return;
    }

    return;
}


//------------------------------------------------------------------------------
// callback from SPI library
static
__attribute__((__nonnull__))
void
impl_spiflash_wait(
    spiflash_t* spi,
    uint32_t ms)
{
    // TimeServer.h provides this helper function, it contains the hard-coded
    // assumption that the RPC interface is "timeServer_rpc"
    TimeServer_sleep(TimeServer_PRECISION_MSEC, ms);
}


// //------------------------------------------------------------------------------
// static
// __attribute__((__unused__))
// void
// read_and_dump(
//     spiflash_t* spi_flash_ctx,
//     size_t  const offset,
//     size_t  const size)
// {
//     static uint8_t buffer[512];  // could pick any size here
//
//     size_t read_size = sizeof(buffer);
//     if (read_size > size)
//     {
//         read_size = size;
//     }
//     int ret = do_spi_flash_read(spi_flash_ctx, offset, read_size, buffer);
//     if (ret < 0)
//     {
//         Debug_LOG_ERROR(
//             "do_spi_flash_read() failed, offset %zu (0x%zx), size %zu, code %d",
//             offset, offset, read_size, ret);
//         return;
//     }
//
//     Debug_DUMP_INFO(buffer, read_size);
// }


// //------------------------------------------------------------------------------
// static
// OS_Error_t
// test_flash(
//     const size_t offset)
// {
//     OS_Error_t ret;
//     uint8_t test_data[16] = { 0, 1, 2, 3, 4, 5, 6, 7 };
//     uint8_t vfy_data[sizeof(test_data)];
//
//     uint64_t timestamp = timeServer_rpc_time();
//     BitConverter_putUint64BE(timestamp, &test_data[8]);
//     Debug_LOG_INFO("test flash offet=%zu, timestmap %" PRIu64, offset, timestamp);
//
//     ret = do_spi_flash_erase(&ctx.spi_flash_ctx, offset & ~(4096 - 1), 4096);
//     if (OS_SUCCESS != ret)
//     {
//         Debug_LOG_ERROR("do_spi_flash_erase() failed, code %d", ret);
//         return OS_ERROR_GENERIC;
//     }
//
//     ret = do_spi_flash_write(
//               &ctx.spi_flash_ctx,
//               offset,
//               sizeof(test_data),
//               test_data );
//     if (OS_SUCCESS != ret)
//     {
//         Debug_LOG_ERROR("do_spi_flash_write() failed, code %d", ret);
//         return OS_ERROR_GENERIC;
//     }
//
//     ret = do_spi_flash_read(
//               &ctx.spi_flash_ctx,
//               offset,
//               sizeof(test_data),
//               vfy_data );
//     if (OS_SUCCESS != ret)
//     {
//         Debug_LOG_ERROR("do_spi_flash_read() failed, code %d", ret);
//         return OS_ERROR_GENERIC;
//     }
//
//     int vfy = memcmp(vfy_data, test_data, sizeof(test_data));
//     if (0 != vfy)
//     {
//         Debug_LOG_ERROR("vfy data");
//         Debug_DUMP_INFO(vfy_data, sizeof(vfy_data));
//
//         return OS_ERROR_GENERIC;
//     }
//
//     uint64_t written = 0;
//     ret = do_erase_write_block(
//               &ctx.spi_flash_ctx,
//               offset,
//               sizeof(test_data),
//               test_data,
//               &written );
//     if (OS_SUCCESS != ret)
//     {
//         Debug_LOG_ERROR("do_erase_write_block() failed, code %d", ret);
//         return OS_ERROR_GENERIC;
//     }
//
//     ret = do_spi_flash_read(
//               &ctx.spi_flash_ctx,
//               offset,
//               sizeof(test_data),
//               vfy_data );
//     if (OS_SUCCESS != ret)
//     {
//         Debug_LOG_ERROR("do_spi_flash_read() failed, code %d", ret);
//         return OS_ERROR_GENERIC;
//     }
//
//     vfy = memcmp(vfy_data, test_data, sizeof(test_data));
//     if (0 != vfy)
//     {
//         Debug_LOG_ERROR("vfy data");
//         Debug_DUMP_INFO(vfy_data, sizeof(vfy_data));
//
//         return OS_ERROR_GENERIC;
//     }
//
//
//     return OS_SUCCESS;
//
// }


//------------------------------------------------------------------------------
void post_init(void)
{
    Debug_LOG_INFO("SPI-Flash init");

    // setting of the W25Q64 Flash with 8 MiByte storage space
    static const spiflash_config_t config =
    {
        .sz = 1024 * 1024 * 8,                  // 8 MiByte flash
        .page_sz = 256,                         // 256 byte pages
        .addr_sz = 3,                           // 3 byte SPI addressing
        .addr_dummy_sz = 0,                     // using single line data, not quad
        .addr_endian = SPIFLASH_ENDIANNESS_BIG, // big endianess on addressing
        .sr_write_ms = 15,                      // write delay (typical 10 ms, max 15 ms)
        .page_program_ms = 3,                   // page programming takes typical 0.8 ms, max 3 ms
        .block_erase_4_ms = 300,                // 4k block erase takes typical 45 ms, max 300 ms
        .block_erase_8_ms = 0,                  // 8k block erase is not supported
        .block_erase_16_ms = 0,                 // 16k block erase is not supported
        .block_erase_32_ms = 800,               // 32k block erase takes typical 120 ms, max 800 ms
        .block_erase_64_ms = 1000,              // 64k block erase takes typical 150 ms, max 1000 ms
        .chip_erase_ms = 6000                   // chip erase takes typical 2 sec, max 6 sec
    };

    static const spiflash_cmd_tbl_t cmds = SPIFLASH_CMD_TBL_STANDARD;

    static const spiflash_hal_t hal =
    {
        ._spiflash_spi_txrx  = impl_spiflash_spi_txrx,
        ._spiflash_spi_cs    = impl_spiflash_spi_cs,
        ._spiflash_wait      = impl_spiflash_wait,
    };

    SPIFLASH_init(
        &ctx.spi_flash_ctx,
        &config,
        &cmds,
        &hal,
        NULL, // asynchronous callback
        SPIFLASH_SYNCHRONOUS,
        NULL); // user data

    if ( (NULL == ctx.spi_flash_ctx.cfg) ||
         (NULL == ctx.spi_flash_ctx.cmd_tbl) ||
         (NULL == ctx.spi_flash_ctx.hal) )
    {
        Debug_LOG_ERROR("SPIFLASH_init() failed");
        return;
    }

    ctx.init_ok = true;

    Debug_LOG_INFO("SPI-Flash init ok");
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "written"
// never points to NULL.
OS_Error_t
__attribute__((__nonnull__))
storage_rpc_write(
    size_t  offset,
    size_t  size,
    size_t* written)
{
    // set defaults
    *written = 0;

    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    size_t dataport_size = OS_Dataport_getSize(ctx.port_storage);
    if (size > dataport_size)
    {
        // the client did a bogus request, it knows the data port size and
        // never ask for more data
        Debug_LOG_ERROR(
            "size %zu exceeds dataport size %zu",
            size,
            dataport_size );

        return OS_ERROR_INVALID_PARAMETER;
    }

    const void* buffer = OS_Dataport_getBuf(ctx.port_storage);

    // max one page (size must be of the form 2^n) can be written at once,
    // worst case is that the buffer starts and end within a page:
    //
    //    Buffer:         |------buffer-----|
    //    Pages:  ...|--------|--------|--------|...

    const size_t page_size = ctx.spi_flash_ctx.cfg->page_sz;
    const size_t page_len_mask = page_size - 1; // work for 2^n values only
    size_t offset_in_page = offset & page_len_mask;

    size_t size_left = size;
    while (size_left > 0)
    {
        const size_t size_in_page = page_size - offset_in_page;
        size_t write_len = (size_in_page < size_left) ? size_in_page : size_left;

        const size_t size_already_written = size - size_left;
        const size_t offs = offset + size_already_written;
        void* buf = (void*)((uintptr_t)buffer + size_already_written);

        int ret = SPIFLASH_write(&(ctx.spi_flash_ctx), offs, write_len, buf);
        if (ret < 0)
        {
            Debug_LOG_ERROR(
                "SPIFLASH_write() failed, offset %zu (0x%zx) write_len %zu, code %d",
                offs, offs, write_len, ret);
            return OS_ERROR_GENERIC;
        }

        // we can't write more then what is left to write
        assert( size_left >= write_len);
        size_left -= write_len;

        *written = size_already_written + write_len;

        // move to next page
        offset_in_page = 0;

    } // end while (size_left > 0)

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "read"
// never points to NULL.
OS_Error_t
__attribute__((__nonnull__))
storage_rpc_read(
    size_t  offset,
    size_t  size,
    size_t* read)
{
    // set defaults
    *read = 0;

    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    size_t dataport_size = OS_Dataport_getSize(ctx.port_storage);
    if (size > dataport_size)
    {
        // the client did a bogus request, it knows the data port size and
        // never ask for more data
        Debug_LOG_ERROR(
            "size %zu exceeds dataport size %zu",
            size,
            dataport_size );

        return OS_ERROR_INVALID_PARAMETER;
    }

    void* buffer = OS_Dataport_getBuf(ctx.port_storage);
    {
        // The data port size of the SPI driver limits how much data we can read at
        // once. An SPI read command has 1 command byte and 3 address bytes, so
        // reserving 4 byte should be sufficient. Use 8 to play safe.
        const size_t max_len = OS_Dataport_getSize(ctx.port_spi) - 8;

        size_t size_left = size;
        while (size_left > 0)
        {
            const size_t read_len = (max_len < size_left) ? max_len : size_left;

            const size_t size_already_read = size - size_left;
            const size_t offs = offset + size_already_read;
            void* buf = (void*)((uintptr_t)buffer + size_already_read);

            int ret = SPIFLASH_read(&(ctx.spi_flash_ctx), offs, read_len, buf);
            if (ret < 0)
            {
                Debug_LOG_ERROR(
                    "SPIFLASH_read() offset %zu (0x%zx) read_len %zu failed, code %d",
                    offs, offs, read_len, ret);
                return OS_ERROR_GENERIC;
            }

            // we can't write more then what is left to write
            assert( size_left >= read_len);
            size_left -= read_len;

            *read = size_already_read + read_len;
        }

        return OS_SUCCESS;
    }
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "erased"
// never points to NULL.
OS_Error_t
__attribute__((__nonnull__))
storage_rpc_erase(
    size_t  offset,
    size_t  size,
    size_t* erased)
{
    // set defaults
    *erased = 0;

    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    int ret = SPIFLASH_erase(&(ctx.spi_flash_ctx), offset, size);
    if (ret < 0)
    {
        Debug_LOG_ERROR(
            "SPIFLASH_erase() failed, offset %zu (0x%zx), size %zu, code %d",
            offset, offset, size, ret);
        return OS_ERROR_GENERIC;
    }

    *erased = size;
    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "size"
// never points to NULL.
OS_Error_t
__attribute__((__nonnull__))
storage_rpc_getSize(
    size_t* size)
{
    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    *size = ctx.spi_flash_ctx.cfg->sz;

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler. It's guaranteed that "flags"
// never points to NULL.
OS_Error_t
__attribute__((__nonnull__))
storage_rpc_getState(
    uint32_t* flags)
{
    if (!ctx.init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    *flags = 0U;
    return OS_SUCCESS;
}
