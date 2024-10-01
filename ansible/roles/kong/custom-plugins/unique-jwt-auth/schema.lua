local typedefs = require "kong.db.schema.typedefs"

local PLUGIN_NAME = "unique-jwt-auth"

local schema = {
    name = PLUGIN_NAME,
    fields = {{
        -- this plugin will only be applied to Services or Routes
        consumer = typedefs.no_consumer
    }, {
        -- this plugin will only run within Nginx HTTP module
        protocols = typedefs.protocols_http
    }, {
        config = {
            type = "record",
            fields = {{
                uri_param_names = {
                    -- description = "A list of querystring parameters that Kong will inspect to retrieve JWTs.",
                    type = "set",
                    elements = {
                        type = "string"
                    },
                    default = {"jwt"}
                }
            }, {
                cookie_names = {
                    -- description = "A list of cookie names that Kong will inspect to retrieve JWTs.",
                    type = "set",
                    elements = {
                        type = "string"
                    },
                    default = {}
                }
            }, {
                header_names = {
                    -- description = "A list of HTTP header names that Kong will inspect to retrieve JWTs.",
                    type = "set",
                    elements = {
                        type = "string"
                    },
                    default = {"authorization"}
                }
            }, {
                anonymous = {
                    -- description = "An optional string (consumer UUID or username) value to use as an �anonymous� consumer if authentication fails.",
                    type = "string"
                }
            }, {
                run_on_preflight = {
                    -- description = "A boolean value that indicates whether the plugin should run (and try to authenticate) on OPTIONS preflight requests. If set to false, then OPTIONS requests will always be allowed.",
                    type = "boolean",
                    required = true,
                    default = true
                }
            }, {
                algorithm = {
                    type = "string",
                    required = true,
                    default = "RS256"
                }
            }, {
                allowed_iss = {
                    type = "set",
                    elements = {
                        type = "string"
                    },
                    required = true
                }
            }, {
                iss_key_grace_period = {
                    type = "number",
                    default = 10,
                    between = {1, 60}
                }
            }, {
                well_known_template = {
                    type = "string",
                    default = "%s/.well-known/openid-configuration"
                }
            }}
        }
    }}
}

return schema
