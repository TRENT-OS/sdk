/*
 * System configurations
 *
 * Copyright (C) 2021, HENSOLDT Cyber GmbH
 */

#pragma once


//-----------------------------------------------------------------------------
// Debug
//-----------------------------------------------------------------------------

#define Debug_Config_STANDARD_ASSERT
#define Debug_Config_ASSERT_SELF_PTR

#define Debug_Config_LOG_LEVEL              Debug_LOG_LEVEL_NONE

//-----------------------------------------------------------------------------
// Memory
//-----------------------------------------------------------------------------

// Use the stdlib alloc
#define Memory_Config_USE_STDLIB_ALLOC
