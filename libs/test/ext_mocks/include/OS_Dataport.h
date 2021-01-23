/* Copyright (C) 2020, HENSOLDT Cyber GmbH */
#pragma once

#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct
{
    void**  io;
    size_t  size;
} OS_Dataport_t;

// Access the dataport
static __attribute__((unused)) void*
OS_Dataport_getBuf(
    const OS_Dataport_t dp)
{
    return *(dp.io);
}
static __attribute__((unused)) size_t
OS_Dataport_getSize(
    const OS_Dataport_t dp)
{
    return dp.size;
}

// Assign the dataport
#define OS_DATAPORT_ASSIGN(p) { \
    .io   = (void**)( &(p) ),   \
    .size = sizeof( *(p) )      \
}
#define OS_DATAPORT_NONE {  \
    .io   = NULL,           \
    .size = 0               \
}

/*
 * Ideally, we would like to include <camkes/dataport.h> but it is not available
 * for non-CAmkES builds; so we derive the size in the same way it is done in the
 * actual dataport definition.
 *
 * NOTE: The following are copied from sel4_util_libs/libutils...
 */
#ifndef PAGE_SIZE_4K
#   define BIT(n) (1ul<<(n))
#   define SIZE_BITS_TO_BYTES(size_bits) (BIT(size_bits))
#   define PAGE_BITS_4K 12
#   define PAGE_SIZE_4K (SIZE_BITS_TO_BYTES(PAGE_BITS_4K))
#endif
#define OS_DATAPORT_DEFAULT_SIZE PAGE_SIZE_4K

// Fake dataport to be used on the host
typedef uint8_t FakeDataport_t[PAGE_SIZE_4K];
