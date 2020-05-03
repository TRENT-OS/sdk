/*
 *  UART
 *
 *  Copyright (C) 2020, Hensoldt Cyber GmbH
 */

#include "LibDebug/Debug.h"

#include <platsupport/chardev.h>
#include <platsupport/serial.h>
#include <platsupport/plat/serial.h>

#include <camkes.h>
#include <camkes/io.h>

#include <stdbool.h>


static struct {
    bool             isValid;
    ps_io_ops_t      io_ops;
    ps_chardevice_t  ps_cdev;
} ctx;


//------------------------------------------------------------------------------
void irq_handle(void)
{
    // this is called when an interrupt arrives. Notify the main loop of the
    // interrupt. This works, because the main loop is blocked in sem_wait()
    // and eventually it will ack the interrupt.
    int ret = sem_post();
    if (0 != ret)
    {
        Debug_LOG_ERROR("sem_post() error, code %d", ret);
    }
}


//------------------------------------------------------------------------------
// Interface UartDrv
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
void
UartDrv_write(
    size_t len)
{
    if (!ctx.isValid)
    {
        Debug_LOG_ERROR("UART not initialized");
        return;
    }

    ssize_t ret = ctx.ps_cdev.write(
                    &(ctx.ps_cdev),
                    inputDataPort,
                    len,
                    NULL,
                    NULL);
    if (ret != len)
    {
        Debug_LOG_ERROR("write error, could only write %zd of %zu bytes",
                        ret, len);
    }
}


//------------------------------------------------------------------------------
// CAmkES component
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
void post_init(void)
{
    Debug_LOG_INFO("initialize UART");

    ctx.isValid = false;

    int ret = camkes_io_ops( &(ctx.io_ops) );
    if (0 != ret)
    {
        Debug_LOG_ERROR("camkes_io_ops() failed, code %d", ret);
        return;
    }

    ps_chardevice_t* dev = ps_cdev_static_init(
                            &(ctx.io_ops),
                            &(ctx.ps_cdev),
                            regBase);
    if (dev != &(ctx.ps_cdev))
    {
        Debug_LOG_ERROR("ps_cdev_init() failed, code %p", dev);
        return;
    }

    // this is not a console, so we don't want that every CR (\n) is
    // automatically turned into CR LF (\r\n)
    ctx.ps_cdev.flags &= ~SERIAL_AUTO_CR;

    ctx.isValid = true;

    Debug_LOG_INFO("initialize UART ok");
}


//------------------------------------------------------------------------------
int run()
{
    if (!ctx.isValid)
    {
        Debug_LOG_ERROR("UART not initialized");
        return -1;
    }

    // The zynq7000 QEMU lacks hardware flow control. But RX interrupts work,
    // so there is no need use polling.
    //
    // Interrupt driven reading works as follows:
    //   Enable interrupts
    //     uart.Intrpt_en_reg0[TIMEOUT] = 1
    //     uart.Intrpt_en_reg0[RTRIG] = 1
    //   Loop
    //     Wait until interrupts: Rx trigger (RxFIFO filled) or timeout
    //     Check that uart.Chnl_int_sts_reg0 [RTRIG] == 1
    //       or uart.Chnl_int_sts_reg0 [TIMEOUT] == 1.
    //     Read data from the uart.TX_RX_FIFO0 register.
    //   repease as long a uart.Channel_sts_reg0[REMPTY] == 0
    //   Clear interrupt status

    for(;;)
    {
        // the ISR will release the semaphore when there is an interrupt
        int ret = sem_wait();
        if (0 != ret)
        {
            Debug_LOG_ERROR("sem_wait() error, code %d", ret);
            continue;
        }

        for(;;)
        {
            char c;
            ret = ctx.ps_cdev.read( &(ctx.ps_cdev), &c, 1, NULL, NULL);
            if (1 == ret)
            {
                // call upper layer to send char
                Output_takeByte(c);
                continue;
            }

            if (0 != ret)
            {
                Debug_LOG_ERROR("UART read error, code %d", ret);
            }
            break;
        }

        // ToDo: do we ack the interrupt here or in the ISR?
        ret = irq_acknowledge();
        if (0 != ret)
        {
            Debug_LOG_ERROR("irq_acknowledge() error, code %d", ret);
            continue;
        }
    }
}
