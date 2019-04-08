
"This function may be unsafe: `safe_params` must outlive the `OraCommonCreateParams` generated by this function."
function OraCommonCreateParams(ctx::Context, safe_params::CommonCreateParams)

    function EmptyOraCommonCreateParams(ctx::Context)
        common_create_params_ref = Ref{OraCommonCreateParams}(OraCommonCreateParams(ORA_MODE_CREATE_DEFAULT, C_NULL, C_NULL, C_NULL, 0, C_NULL, 0))
        result = dpiContext_initCommonCreateParams(ctx.handle, common_create_params_ref)
        error_check(ctx, result)
        return common_create_params_ref[]
    end

    result = EmptyOraCommonCreateParams(ctx)

    if safe_params.create_mode != nothing
        result.create_mode = safe_params.create_mode
    end

    result.encoding = pointer(safe_params.encoding)
    result.nencoding = pointer(safe_params.nencoding)

    if safe_params.edition != nothing
        result.edition = pointer(safe_params.edition)
        result.edition_length = sizeof(safe_params.edition)
    end

    if safe_params.driver_name != nothing
        result.driver_name = pointer(safe_params.driver_name)
        result.driver_name_length = sizeof(safe_params.driver_name)
    end

    return result
end

"This function may be unsafe: `safe_params` must outlive the `OraConnCreateParams` generated by this function."
function OraConnCreateParams(ctx::Context, safe_params::ConnCreateParams)

    function EmptyOraConnCreateParams(ctx::Context)
        new_conn_create_params = OraConnCreateParams(ORA_MODE_AUTH_DEFAULT, C_NULL, 0, ORA_PURITY_DEFAULT, C_NULL, 0, C_NULL, 0, 0, C_NULL, C_NULL, C_NULL, 0, 0, C_NULL, 0, 0, C_NULL, 0, C_NULL, 0)
        conn_create_params_ref = Ref{OraConnCreateParams}(new_conn_create_params)
        result = dpiContext_initConnCreateParams(ctx.handle, conn_create_params_ref)
        error_check(ctx, result)
        return conn_create_params_ref[]
    end

    result = EmptyOraConnCreateParams(ctx)

    result.auth_mode = safe_params.auth_mode

    if safe_params.pool != nothing
        result.pool_handle = safe_params.pool.handle
    end

    return result
end

function Connection(ctx::Context, user::String, password::String, connect_string::String, common_params::CommonCreateParams, conn_create_params::ConnCreateParams)
    conn_handle_ref = Ref{Ptr{Cvoid}}()
    ora_common_params = OraCommonCreateParams(ctx, common_params)
    ora_conn_create_params = OraConnCreateParams(ctx, conn_create_params)
    result = dpiConn_create(ctx.handle, user, password, connect_string, Ref(ora_common_params), Ref(ora_conn_create_params), conn_handle_ref)
    error_check(ctx, result)
    return Connection(ctx, conn_handle_ref[], conn_create_params.pool)
end

function Connection(ctx::Context, user::String, password::String, connect_string::String;
        encoding::AbstractString=DEFAULT_CONNECTION_ENCODING,
        nencoding::AbstractString=DEFAULT_CONNECTION_NENCODING,
        create_mode::Union{Nothing, OraCreateMode}=nothing,
        edition::Union{Nothing, String}=nothing,
        driver_name::Union{Nothing, String}=nothing,
        auth_mode::OraAuthMode=ORA_MODE_AUTH_DEFAULT,
        pool::Union{Nothing, Pool}=nothing
    )

    common_params = CommonCreateParams(create_mode, encoding, nencoding, edition, driver_name)
    conn_create_params = ConnCreateParams(auth_mode, pool)

    return Connection(ctx, user, password, connect_string, common_params, conn_create_params)
end

function Connection(user::String, password::String, connect_string::String;
        encoding::AbstractString=DEFAULT_CONNECTION_ENCODING,
        nencoding::AbstractString=DEFAULT_CONNECTION_NENCODING,
        create_mode::Union{Nothing, OraCreateMode}=nothing,
        edition::Union{Nothing, String}=nothing,
        driver_name::Union{Nothing, String}=nothing,
        auth_mode::OraAuthMode=ORA_MODE_AUTH_DEFAULT,
        pool::Union{Nothing, Pool}=nothing
    )

    return Connection(Context(), user, password, connect_string,
                encoding=encoding,
                nencoding=nencoding,
                create_mode=create_mode,
                edition=edition,
                driver_name=driver_name,
                auth_mode=auth_mode,
                pool=pool
            )
end

function server_version(conn::Connection)
    release_string_ptr_ref = Ref{Ptr{UInt8}}()
    release_string_length_ref = Ref{UInt32}()
    version_info_ref = Ref{OraVersionInfo}()
    result = dpiConn_getServerVersion(conn.handle, release_string_ptr_ref, release_string_length_ref, version_info_ref)
    error_check(context(conn), result)

    release_string = unsafe_string(release_string_ptr_ref[], release_string_length_ref[])
    return (release_string, version_info_ref[])
end

function ping(conn::Connection)
    result = dpiConn_ping(conn.handle)
    error_check(context(conn), result)
    nothing
end

function startup_database(conn::Connection, startup_mode::OraStartupMode=ORA_MODE_STARTUP_DEFAULT)
    result = dpiConn_startupDatabase(conn.handle, startup_mode)
    error_check(context(conn), result)
    nothing
end

function shutdown_database(conn::Connection, shutdown_mode::OraShutdownMode=ORA_MODE_SHUTDOWN_DEFAULT)
    result = dpiConn_shutdownDatabase(conn.handle, shutdown_mode)
    error_check(context(conn), result)
    nothing
end

function commit(conn::Connection)
    result = dpiConn_commit(conn.handle)
    error_check(context(conn), result)
    nothing
end

function rollback(conn::Connection)
    result = dpiConn_rollback(conn.handle)
    error_check(context(conn), result)
    nothing
end

function close(conn::Connection; close_mode::OraConnCloseMode=ORA_MODE_CONN_CLOSE_DEFAULT, tag::String="")
    result = dpiConn_close(conn.handle, close_mode=close_mode, tag=tag)
    error_check(context(conn), result)
    conn.pool = nothing
    nothing
end

function current_schema(conn::Connection) :: Union{Missing, String}
    value_char_array_ref = Ref{Ptr{UInt8}}()
    value_length_ref = Ref{UInt32}()
    result = dpiConn_getCurrentSchema(conn.handle, value_char_array_ref, value_length_ref)
    error_check(context(conn), result)
    if value_char_array_ref[] == C_NULL
        return missing
    else
        return unsafe_string(value_char_array_ref[], value_length_ref[])
    end
end

function stmt_cache_size(conn::Connection) :: UInt32
    cache_size_ref = Ref{UInt32}()
    result = dpiConn_getStmtCacheSize(conn.handle, cache_size_ref)
    error_check(context(conn), result)
    return cache_size_ref[]
end

function stmt_cache_size!(conn::Connection, cache_size::Integer)
    result = dpiConn_setStmtCacheSize(conn.handle, UInt32(cache_size))
    error_check(context(conn), result)
end