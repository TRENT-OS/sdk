/*
 * SPI driver
 *
 * Copyright (C) 2020, HENSOLDT Cyber GmbH
 */

#include "OS_Error.h"
#include "OS_Dataport.h"

#include "LibDebug/Debug.h"
#include <platsupport/plat/spi.h>
#include <platsupport/plat/spiflash.h>

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include <camkes.h>


static bool init_ok = false;

// wrap CAmkES variables
static OS_Dataport_t spi_dataport = OS_DATAPORT_ASSIGN(spi_port);

// our data port is 4096 byte, 16 byte are for SPI protocol overhead
static uint8_t rx_buffer[4096 + 16];

//------------------------------------------------------------------------------
void
post_init(void)
{
    Debug_LOG_INFO("SPI init");

    if (!bcm2837_spi_begin(regBase))
    {
        Debug_LOG_ERROR("bcm2837_spi_begin() failed");
        return;
    }

    bcm2837_spi_setBitOrder(BCM2837_SPI_BIT_ORDER_MSBFIRST);
    bcm2837_spi_setDataMode(BCM2837_SPI_MODE0);
    bcm2837_spi_setClockDivider(BCM2837_SPI_CLOCK_DIVIDER_8);
    bcm2837_spi_chipSelect(BCM2837_SPI_CS0);
    bcm2837_spi_setChipSelectPolarity(BCM2837_SPI_CS0, LOW);

    init_ok = true;

    Debug_LOG_INFO("SPI init ok");
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler.
OS_Error_t
spi_rpc_txrx(
    size_t tx_len,
    size_t rx_len)
{
    if (!init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    if (tx_len > OS_Dataport_getSize(spi_dataport))
    {
        Debug_LOG_ERROR("tx_len %d too big for dataport", tx_len);
        return OS_ERROR_INVALID_PARAMETER;
    }

    if (rx_len > OS_Dataport_getSize(spi_dataport))
    {
        Debug_LOG_ERROR("rx_len %d too big for dataport", rx_len);
        return OS_ERROR_INVALID_PARAMETER;
    }

    if (tx_len + rx_len < tx_len)
    {
        Debug_LOG_ERROR("overflow, tx_len=%zu, rx_len=%zu", tx_len, rx_len);
        return OS_ERROR_INVALID_PARAMETER;

    }

    if (tx_len + rx_len > sizeof(rx_buffer))
    {
        Debug_LOG_ERROR("rx_buffer (%zu) too small for tx_len=%zu, rx_len=%zu",
                        sizeof(rx_buffer),
                        tx_len, rx_len);
        return OS_ERROR_INVALID_PARAMETER;
    }

    if (0 == tx_len)
    {
        Debug_LOG_ERROR("tx_len is 0!");
        return OS_ERROR_INVALID_PARAMETER;
    }

    bcm2837_spi_transfernb(
        OS_Dataport_getBuf(spi_dataport),
        (char*)rx_buffer,
        tx_len + rx_len);

    memcpy(OS_Dataport_getBuf(spi_dataport), &rx_buffer[tx_len], rx_len);

    return OS_SUCCESS;
}


//------------------------------------------------------------------------------
// This is a CAmkES RPC interface handler.
OS_Error_t
spi_rpc_cs(
    unsigned int cs)
{
    if (!init_ok)
    {
        Debug_LOG_ERROR("initialization failed, fail call %s()", __func__);
        return OS_ERROR_INVALID_STATE;
    }

    bcm2837_spi_chipSelect(cs ? BCM2837_SPI_CS0 : BCM2837_SPI_CS2);

    return OS_SUCCESS;
}
