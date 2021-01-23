/* Copyright (C) 2020, HENSOLDT Cyber GmbH */
#pragma once

#include "OS_Dataport.h"
#include "OS_Error.h"

#include <stdint.h>

typedef struct
{
    size_t (*read)(const size_t len);
    OS_Dataport_t dataport;
} if_OS_Entropy_t;

#define IF_OS_ENTROPY_ASSIGN(_rpc_, _port_)     \
{                                               \
    .read     = _rpc_ ## _read,                 \
    .dataport = OS_DATAPORT_ASSIGN(_port_)      \
}
