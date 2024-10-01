local constants = require "kong.constants"
local jwt_decoder = require "kong.plugins.jwt.jwt_parser"
local cjson = require "cjson.safe"

local zitadel_keys = require "kong.plugins.unique-jwt-auth.zitadel_keys"

local validate_issuer = require"kong.plugins.unique-jwt-auth.validate_issuers".validate_issuer

local fmt = string.format
local kong = kong
local type = type
local error = error
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local re_gmatch = ngx.re.gmatch

local priority_env_var = "UNIQUE_JWT_AUTH_PRIORITY"
local priority
if os.getenv(priority_env_var) then
    priority = tonumber(os.getenv(priority_env_var))
else
    priority = 1005
end
kong.log.info('UNIQUE_JWT_AUTH_PRIORITY: ' .. priority)

local UniqueJwtAuthHandler = {
    PRIORITY = priority,
    VERSION = "0.1.0"
}

-------------------------------------------------------------------------------
-- custom helper function of the extended plugin "unique-jwt-auth"
-- --> this is not contained in the official "jwt" pluging
-------------------------------------------------------------------------------
local function custom_helper_issuer_get_keys(well_known_endpoint)
    kong.log.debug('Getting public keys from token issuer')
    local keys, err = zitadel_keys.get_issuer_keys(well_known_endpoint)
    if err then
        return nil, err
    end

    kong.log.debug('Number of keys retrieved: ' .. table.getn(keys))
    kong.log.debug('Keys: ' .. cjson.encode(keys))

    return {
        keys = keys,
        updated_at = ngx.time()
    }
end

-------------------------------------------------------------------------------
-- custom zitadel specific extension for the plugin "unique-jwt-auth"
-- --> This is for one of the main benefits when using this plugin
--
-- This validates the token against the token issuer is the token is really
-- issued by this instance. The URL from inside the token from the "iss"
-- information is taken to connect with the token issuer instance.
-------------------------------------------------------------------------------
local function custom_validate_token_signature(conf, jwt, second_call)
    local issuer_cache_key = 'issuer_keys_' .. jwt.claims.iss

    local well_known_endpoint = zitadel_keys.get_wellknown_endpoint(conf.well_known_template, jwt.claims.iss)
    -- Retrieve public keys
    local public_keys, err = kong.cache:get(issuer_cache_key, nil, custom_helper_issuer_get_keys, well_known_endpoint)

    if not public_keys then
        if err then
            kong.log.err(err)
        end
        return kong.response.exit(403, {
            message = "Unable to get public key for issuer"
        })
    end

    -- Verify signatures
    for _, k in ipairs(public_keys.keys) do
        kong.log.debug('Verifying with key: ' .. cjson.encode(k))
        if jwt:verify_signature(k) then
            kong.log.debug('JWT signature verified')
            return nil
        end
    end

    -- -- We could not validate signature, try to get a new keyset?
    local since_last_update = ngx.time() - public_keys.updated_at
    if not second_call and since_last_update > conf.iss_key_grace_period then
        kong.log.debug('Could not validate signature. Keys updated last ' .. since_last_update .. ' seconds ago')
        -- can it be that the signature key of the issuer has changed ... ?
        -- invalidate the old keys in kong cache and do a current lookup to the signature keys
        -- of the token issuer
        kong.cache:invalidate_local(issuer_cache_key)
        return custom_validate_token_signature(conf, jwt, true)
    end

    return kong.response.exit(401, {
        message = "Invalid token signature"
    })
end

-------------------------------------------------------------------------------
-- Starting from here the "official" code of the community kong OSS version
-- plugin "jwt" is forked and in some places then extended with the special
-- logic from this plugin.
--
-- We use this ordering by intention that way .. if a new version of the
-- "jwt" plugin from kong is released .. these changes can me merged also
-- to this plugin here .... make the maintenance as easy as possible ...
--
-- This code is in sync with kong verion "3.3.0" jwt plugin as a baseline
-------------------------------------------------------------------------------

--- Retrieve a JWT in a request.
-- Checks for the JWT in URI parameters, then in cookies, and finally
-- in the configured header_names (defaults to `[Authorization]`).
-- @param conf Plugin configuration
-- @return token JWT token contained in request (can be a table) or nil
-- @return err
local function retrieve_tokens(conf)
    local token_set = {}
    local args = kong.request.get_query()
    for _, v in ipairs(conf.uri_param_names) do
        local token = args[v] -- can be a table
        if token then
            if type(token) == "table" then
                for _, t in ipairs(token) do
                    if t ~= "" then
                        token_set[t] = true
                    end
                end

            elseif token ~= "" then
                token_set[token] = true
            end
        end
    end

    local var = ngx.var
    for _, v in ipairs(conf.cookie_names) do
        local cookie = var["cookie_" .. v]
        if cookie and cookie ~= "" then
            token_set[cookie] = true
        end
    end

    local request_headers = kong.request.get_headers()
    for _, v in ipairs(conf.header_names) do
        local token_header = request_headers[v]
        if token_header then
            if type(token_header) == "table" then
                token_header = token_header[1]
            end
            local iterator, iter_err = re_gmatch(token_header, "\\s*[Bb]earer\\s+(.+)", "jo")
            if not iterator then
                kong.log.err(iter_err)
                break
            end

            local m, err = iterator()
            if err then
                kong.log.err(err)
                break
            end

            if m and #m > 0 then
                if m[1] ~= "" then
                    token_set[m[1]] = true
                end
            end
        end
    end

    local tokens_n = 0
    local tokens = {}
    for token, _ in pairs(token_set) do
        tokens_n = tokens_n + 1
        tokens[tokens_n] = token
    end

    if tokens_n == 0 then
        return nil
    end

    if tokens_n == 1 then
        return tokens[1]
    end

    return tokens
end

local function set_consumer(consumer, credential, token)
    -- TODO: implement
end

local function do_authentication(conf)
    local token, err = retrieve_tokens(conf)
    if err then
        kong.log.err(err)
        return kong.response.exit(500, {
            message = "An unexpected error occurred"
        })
    end

    local token_type = type(token)
    if token_type ~= "string" then
        if token_type == "nil" then
            return false, {
                status = 401,
                message = "Unauthorized"
            }
        elseif token_type == "table" then
            return false, {
                status = 401,
                message = "Multiple tokens provided"
            }
        else
            return false, {
                status = 401,
                message = "Unrecognizable token"
            }
        end
    end

    -- Decode token to find out who the consumer is
    local jwt, err = jwt_decoder:new(token)
    if err then
        return false, {
            status = 401,
            message = "Bad token; " .. tostring(err)
        }
    end

    local claims = jwt.claims
    local header = jwt.header

    kong.log.debug("claims: " .. cjson.encode(claims))
    kong.log.debug("header: " .. cjson.encode(header))

    -- Verify that the issuer is allowed
    if not validate_issuer(conf.allowed_iss, jwt.claims) then
        return false, {
            status = 401,
            message = "Token issuer not allowed"
        }
    end

    local algorithm = conf.algorithm

    -- Verify "alg"
    if jwt.header.alg ~= algorithm then
        return false, {
            status = 403,
            message = "Invalid algorithm"
        }
    end

    -- Now verify the JWT signature
    err = custom_validate_token_signature(conf, jwt)
    if err ~= nil then
        return false, err
    end

    return true
end

local function set_anonymous_consumer(anonymous)
    local consumer_cache_key = kong.db.consumers:cache_key(anonymous)
    local consumer, err = kong.cache:get(consumer_cache_key, nil, kong.client.load_consumer, anonymous, true)
    if err then
        return error(err)
    end

    set_consumer(consumer)
end

--- When conf.anonymous is enabled we are in "logical OR" authentication flow.
--- Meaning - either anonymous consumer is enabled or there are multiple auth plugins
--- and we need to passthrough on failed authentication.
local function logical_OR_authentication(conf)
    if kong.client.get_credential() then
        -- we're already authenticated and in "logical OR" between auth methods -- early exit
        return
    end

    local ok, _ = do_authentication(conf)
    if not ok then
        set_anonymous_consumer(conf.anonymous)
    end
end

--- When conf.anonymous is not set we are in "logical AND" authentication flow.
--- Meaning - if this authentication fails the request should not be authorized
--- even though other auth plugins might have successfully authorized user.
local function logical_AND_authentication(conf)
    local ok, err = do_authentication(conf)
    if not ok then
        return kong.response.exit(err.status, err.errors or {
            message = err.message
        }, err.headers)
    end
end

function UniqueJwtAuthHandler:access(conf)
    kong.log.info("UniqueJwtAuthHandler:access")
    -- check if preflight request and whether it should be authenticated
    if not conf.run_on_preflight and kong.request.get_method() == "OPTIONS" then
        return
    end

    if conf.anonymous then
        return logical_OR_authentication(conf)
    else
        return logical_AND_authentication(conf)
    end
end

return UniqueJwtAuthHandler
