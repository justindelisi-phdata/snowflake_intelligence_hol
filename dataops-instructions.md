# <h0blue>{{ getenv("EVENT_NAME","[unknown event]") }}</h0blue> <h0black> | Hands on lab</h0black>

##<h1sub> Why are we here? </h1sub>

To learn about Snowflake, with a hands on approach.

## <h1sub>The lab environment</h1sub>

A complete lab environment has been built for you automatically. This includes:

- **Snowflake Account**: {{ getenv("DATAOPS_SNOWFLAKE_ACCOUNT","[unknown]") }}
- **User**: {{ getenv("EVENT_USER_NAME","[unknown]") }}
- **Snowflake Virtual Warehouse**: {{ getenv("EVENT_WAREHOUSE","[unknown]") }}
- **Snowflake Database**: {{ getenv("DATAOPS_DATABASE","[unknown]") }}
- **Schema**: {{ getenv("EVENT_SCHEMA","[unknown]") }}

!!! warning "This lab environment will disappear!"

    This event is due to end at {{ getenv("EVENT_DECOMMISSION_DATETIME","[unknown time]") }}, at which point access will be restricted, and accounts will be removed.

## <h1sub>Structure of the session</h1sub>

This walkthrough contains everything you need. We will also demonstrate a number of the key steps live.

### <h1sub>Getting started</h1sub>

1 [Logging in and ready to build](step1.md)