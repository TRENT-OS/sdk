/* Copyright (C) 2020-2021, HENSOLDT Cyber GmbH */
#pragma once

typedef enum
{
    //--------------------------------------------------------------------------
    // space reserved for custom error codes range
    //--------------------------------------------------------------------------
    __START_OS_ERROR_CODES_CUSTOM = -1000000,
    // OS_ERROR_CUSTOM_FOO = -999999
    // ...
    // OS_ERROR_CUSTOM_BAR = -100001
    __END_OS_ERROR_CODES_CUSTOM = -100000,

    //--------------------------------------------------------------------------
    // Network specific error codes
    //--------------------------------------------------------------------------
    /// @cond OS_ERROR_HELPER_DEFINES
    __START_OS_ERROR_CODES_NETWORK = -1318,
    /// @endcond
    //--------------------------------------
    OS_ERROR_NETWORK_NO_SUPPORT,            /**< no network support */
    OS_ERROR_NETWORK_OP_NO_SUPPORT,         /**< operation not supported */
    OS_ERROR_NETWORK_DOWN,                  /**< network stack is down */
    OS_ERROR_NETWORK_UNREACHABLE,           /**< network is unreachable */
    OS_ERROR_NETWORK_NO_ROUTE,              /**< no route to host or network */

    OS_ERROR_NETWORK_PROTO,                 /**< protocol error */
    OS_ERROR_NETWORK_PROTO_NO_SUPPORT,      /**< protocol not supported */
    OS_ERROR_NETWORK_PROTO_OPT_NO_SUPPORT,  /**< protocol option not supported */

    OS_ERROR_NETWORK_ADDR_IN_USE,           /**< address already in use */
    OS_ERROR_NETWORK_ADDR_NOT_AVAILABLE,    /**< address not available */

    OS_ERROR_NETWORK_CONN_RESET,            /**< connection reset */
    OS_ERROR_NETWORK_CONN_ALREADY_BOUND,    /**< already connected */
    OS_ERROR_NETWORK_CONN_NONE,             /**< no connection */
    OS_ERROR_NETWORK_CONN_SHUTDOWN,         /**< connection shutdown */
    OS_ERROR_NETWORK_CONN_REFUSED,          /**< connection refused */

    OS_ERROR_NETWORK_HOST_DOWN,             /**< host is down */
    OS_ERROR_NETWORK_HOST_UNREACHABLE,      /**< host is unreachable */

    /// @cond OS_ERROR_HELPER_DEFINES
    __END_OS_ERROR_CODES_NETWORK,                   /**< -1300 */
    /// @endcond

    //--------------------------------------------------------------------------
    // Device specific error codes
    //--------------------------------------------------------------------------
    /// @cond OS_ERROR_HELPER_DEFINES
    __START_OS_ERROR_CODES_DEVICE = -1204,
    /// @endcond

    /**
     * @brief   The device is present, but it can't be used.
     *
     * The difference to OS_ERROR_DEVICE_NOT_READY is, that this is intended for
     * permanent conditions, where the user should be prompted to connect the
     * valid device.
     */
    OS_ERROR_DEVICE_INVALID,

    /**
     * @brief   The device is not present.
     */
    OS_ERROR_DEVICE_NOT_PRESENT,

    /**
     * @brief   The device is present, but temporarily not accessible.
     *
     * Please retry some time soon, or wait for the ready event.
     */
    OS_ERROR_DEVICE_BUSY,

    /// @cond OS_ERROR_HELPER_DEFINES
    __END_OS_ERROR_CODES_DEVICE,                   /**< -1200 */
    /// @endcond

    //--------------------------------------------------------------------------
    // File System specific error codes
    //--------------------------------------------------------------------------
    /// @cond OS_ERROR_HELPER_DEFINES
    __START_OS_ERROR_CODES_FS = -1124,
    /// @endcond
    //----------------------------------------
    OS_ERROR_FS_NO_FREE_HANDLE,                /**< failed cause no free handle */
    OS_ERROR_FS_DELETE_HANDLE,                 /**< failed due to delete handle */
    OS_ERROR_FS_NO_DISK,                       /**< disk doesn't exist */
    OS_ERROR_FS_INIT,                          /**< failed to init */
    OS_ERROR_FS_REGISTER,                      /**< failed to register low level functions */
    OS_ERROR_FS_CREATE_FS,                     /**< failed to create filesystem */
    OS_ERROR_FS_FORMAT_FS,                     /**< failed to format filesystem */
    OS_ERROR_FS_PARTITION_READ,                /**< partiton read throws an error */
    OS_ERROR_FS_OPEN,                          /**< failed to open */
    OS_ERROR_FS_CLOSE,                         /**< failed to close */
    OS_ERROR_FS_MOUNT,                         /**< failed to mount */
    OS_ERROR_FS_UNMOUNT,                       /**< failed to unmount */
    OS_ERROR_FS_FILE_NOT_FOUND,                /**< file is missing (if FS_O_CREATE has not been passed) */
    OS_ERROR_FS_OPERATION_DENIED,              /**< partition was opened in read-only mode */
    OS_ERROR_FS_INSUFFICIENT_STORAGE_CAPACITY, /**< less space or file to big */
    OS_ERROR_FS_STRUCTURE,                     /**< failed to get internal structure */
    OS_ERROR_FS_RESOLVE_HANDLE,                /**< failed to resolve handle */
    OS_ERROR_FS_DELETE_RESOLVE_HANDLE,         /**< failed to delete resolve handle */
    OS_ERROR_FS_LIB,                           /**< error from lib */
    OS_ERROR_FS_DATABUFFER_OVERLOW,            /**< databuffer is too small */
    OS_ERROR_FS_INVALID_PARTITION_MODE,        /**< partition access mode is invalid */
    OS_ERROR_FS_PARTITION_NOT_READY,           /**< partition not ready */
    OS_ERROR_FS_INVALID_FILESYSTEM,            /**< no valid filesystem */
    //----------------------------------------
    /// @cond OS_ERROR_HELPER_DEFINES
    __END_OS_ERROR_CODES_FS,                   /**< -1100 */
    /// @endcond

    //--------------------------------------------------------------------------
    // Configuration Server specific error codes
    //--------------------------------------------------------------------------
    /// @cond OS_ERROR_HELPER_DEFINES
    __START_OS_ERROR_CODES_CONFIG = -1004,
    /// @endcond
    //----------------------------------------
    OS_ERROR_CONFIG_DOMAIN_NOT_FOUND,          /**< configuration domain not found */
    OS_ERROR_CONFIG_PARAMETER_NOT_FOUND,       /**< configuration parameter not found */
    OS_ERROR_CONFIG_TYPE_MISMATCH,             /**< configuration parameter type mismatch */
    //----------------------------------------
    /// @cond OS_ERROR_HELPER_DEFINES
    __END_OS_ERROR_CODES_CONFIG,              /**< -1000 */
    /// @endcond

    //--------------------------------------------------------------------------
    // General error codes
    //--------------------------------------------------------------------------
    /// @cond OS_ERROR_HELPER_DEFINES
    __START_OS_ERROR_CODES_GENERIC = -27,
    /// @endcond
    //----------------------------------------
    OS_ERROR_IN_PROGRESS,                      /**< operation in progress */
    OS_ERROR_TIMEOUT,                          /**< operation timeout */
    OS_ERROR_IO,                               /**< generic IO error */
    OS_ERROR_EXISTS,                           /**< alredy exists */
    OS_ERROR_BUFFER_FULL,                      /**< buffer is full */
    OS_ERROR_BUFFER_EMPTY,                     /**< buffer is empty */
    OS_ERROR_NO_DATA,                          /**< no data available to fullfill the request */
    OS_ERROR_NOT_INITIALIZED,                  /**< not initialized */
    OS_ERROR_TRY_AGAIN,                        /**< caller should retry operation */
    OS_ERROR_WOULD_BLOCK,                      /**< operation would block */
    OS_ERROR_OUT_OF_BOUNDS,                    /**< operation violated boundaries */
    OS_ERROR_CONNECTION_CLOSED,                /**< connection closed */
    OS_ERROR_OVERFLOW_DETECTED,                /**< overflow detected */
    OS_ERROR_INSUFFICIENT_SPACE,               /**< insufficient space */
    OS_ERROR_BUFFER_TOO_SMALL,                 /**< buffer too small */
    OS_ERROR_ABORTED,                          /**< operation aborted */
    OS_ERROR_OPERATION_DENIED,                 /**< operation denied */
    OS_ERROR_ACCESS_DENIED,                    /**< access denied */
    OS_ERROR_NOT_FOUND,                        /**< not found */
    OS_ERROR_INVALID_HANDLE,                   /**< invalid handle */
    OS_ERROR_INVALID_NAME,                     /**< invalid name */
    OS_ERROR_INVALID_PARAMETER,                /**< invalid parameter */
    OS_ERROR_INVALID_STATE,                    /**< invalid state */
    OS_ERROR_NOT_SUPPORTED,                    /**< not supported */
    OS_ERROR_NOT_IMPLEMENTED,                  /**< not implemented */
    OS_ERROR_GENERIC,                          /**< general error, not further details available */

    //----------------------------------------
    OS_SUCCESS                                 /**< operation successful */
}
OS_Error_t;
