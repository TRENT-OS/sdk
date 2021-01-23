/* Copyright (C) 2020, HENSOLDT Cyber GmbH */
#pragma once

#include "OS_Dataport.h"
#include "OS_Error.h"

#include <stdint.h>
#include "stdio.h"

typedef enum
{
    OS_Storage_StateFlag_MEDIUM_PRESENT = 0,
}
OS_Storage_StateFlag_e;

typedef struct
{
    OS_Error_t (*write)(off_t offset, size_t size, size_t* written);
    OS_Error_t (*read)(off_t offset, size_t size, size_t* read);
    OS_Error_t (*erase)(off_t offset, off_t size, off_t* erased);
    OS_Error_t (*getSize)(off_t* size);
    OS_Error_t (*getBlockSize)(size_t* blockSize);
    OS_Error_t (*getState)(uint32_t* flags);

    OS_Dataport_t dataport;
} if_OS_Storage_t;

#define IF_OS_STORAGE_ASSIGN(_rpc_, _port_)         \
{                                                   \
    .write          = _rpc_ ## _write,              \
    .read           = _rpc_ ## _read,               \
    .erase          = _rpc_ ## _erase,              \
    .getSize        = _rpc_ ## _getSize,            \
    .getBlockSize   = _rpc_ ## _getBlockSize,       \
    .getState       = _rpc_ ## _getState,           \
    .dataport       = OS_DATAPORT_ASSIGN(_port_)    \
}
