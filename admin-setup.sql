-- Run these to test this script from a fresh slate
-- USE ROLE accountadmin;
-- drop database if exists sf_ai_demo;
-- drop database if exists snowflake_intelligence;
-- drop warehouse if exists Snow_Intelligence_demo_wh;
-- drop role if exists SF_Intelligence_Demo;

-- ========================================================================
-- STEP 1: Create Snowflake Objects
-- ========================================================================
USE ROLE accountadmin;

-- Enable Snowflake Intelligence by creating the Config DB & Schema
CREATE DATABASE IF NOT EXISTS snowflake_intelligence;
CREATE SCHEMA IF NOT EXISTS snowflake_intelligence.agents;

-- Allow anyone to see the agents in this schema
GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE PUBLIC;


create or replace role SF_Intelligence_Demo;
SET current_user_name = CURRENT_USER();

-- Step 2: Use the variable to grant the role
GRANT ROLE SF_Intelligence_Demo TO USER IDENTIFIER($current_user_name);
GRANT CREATE DATABASE ON ACCOUNT TO ROLE SF_Intelligence_Demo;

-- Create a dedicated warehouse for the demo with auto-suspend/resume
CREATE OR REPLACE WAREHOUSE Snow_Intelligence_demo_wh 
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;


-- Grant usage on warehouse to admin role
GRANT USAGE ON WAREHOUSE SNOW_INTELLIGENCE_DEMO_WH TO ROLE SF_Intelligence_Demo;

-- Alter current user's default role and warehouse to the ones used here
ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_ROLE = SF_Intelligence_Demo;
ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_WAREHOUSE = Snow_Intelligence_demo_wh;


-- Switch to SF_Intelligence_Demo role to create demo objects
use role SF_Intelligence_Demo;

-- Create database and schema
CREATE OR REPLACE DATABASE SF_AI_DEMO;
USE DATABASE SF_AI_DEMO;

CREATE SCHEMA IF NOT EXISTS DEMO_SCHEMA;
USE SCHEMA DEMO_SCHEMA;

-- Create file format for CSV files
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    ESCAPE = 'NONE'
    ESCAPE_UNENCLOSED_FIELD = '\134'
    DATE_FORMAT = 'YYYY-MM-DD'
    TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'
    NULL_IF = ('NULL', 'null', '', 'N/A', 'n/a');

    
-- ========================================================================
-- STEP 2: Create Git API integration and clone repo
-- ========================================================================
use role accountadmin;
-- Create API Integration for GitHub (public repository access)
CREATE OR REPLACE API INTEGRATION git_api_integration
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/justindelisi-phdata')
    ENABLED = TRUE;


GRANT USAGE ON INTEGRATION GIT_API_INTEGRATION TO ROLE SF_Intelligence_Demo;


use role SF_Intelligence_Demo;
-- Create Git repository integration for the public demo repository
CREATE OR REPLACE GIT REPOSITORY SF_AI_DEMO_REPO
    API_INTEGRATION = git_api_integration
    ORIGIN = 'https://github.com/justindelisi-phdata/snowflake_intelligence_hol.git';

-- Create internal stage for copied data files
CREATE OR REPLACE STAGE INTERNAL_DATA_STAGE
    FILE_FORMAT = CSV_FORMAT
    COMMENT = 'Internal stage for copied demo data files'
    DIRECTORY = ( ENABLE = TRUE)
    ENCRYPTION = (   TYPE = 'SNOWFLAKE_SSE');

ALTER GIT REPOSITORY SF_AI_DEMO_REPO FETCH;

-- ========================================================================
-- STEP 3: Load data into internal stage
-- ========================================================================
COPY FILES
INTO @INTERNAL_DATA_STAGE/structured_data/
FROM @SF_AI_DEMO_REPO/branches/"feat/semantic-modeling-lab"/structured_data/;

COPY FILES
INTO @INTERNAL_DATA_STAGE/unstructured_docs/
FROM @SF_AI_DEMO_REPO/branches/"feat/semantic-modeling-lab"/source_pdfs/;

-- Verify files were copied
LS @INTERNAL_DATA_STAGE;
ALTER STAGE INTERNAL_DATA_STAGE refresh;


-- ========================================================================
-- STEP 4: Configure Snowflake Intelligence
-- ========================================================================
-- Switch to accountadmin for integration creation
USE ROLE accountadmin;

-- Grant necessary privileges on database and schema
GRANT ALL PRIVILEGES ON DATABASE SF_AI_DEMO TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON SCHEMA SF_AI_DEMO.DEMO_SCHEMA TO ROLE ACCOUNTADMIN;
-- GRANT USAGE ON NETWORK RULE snowflake_intelligence_webaccessrule TO ROLE accountadmin;

USE SCHEMA SF_AI_DEMO.DEMO_SCHEMA;

GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE SF_Intelligence_Demo;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE SF_Intelligence_Demo;
GRANT CREATE AGENT ON SCHEMA snowflake_intelligence.agents TO ROLE SF_Intelligence_Demo;


-- STEP 5: Load data
USE SF_AI_DEMO.DEMO_SCHEMA;

-- Vendor Dimension
CREATE OR REPLACE TABLE vendor_dim (
    vendor_key INT PRIMARY KEY,
    vendor_name VARCHAR(200) NOT NULL,
    vertical VARCHAR(50) NOT NULL,
    address VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(10),
    zip VARCHAR(20)
);

-- Customer Dimension
CREATE OR REPLACE TABLE customer_dim (
    customer_key INT PRIMARY KEY,
    customer_name VARCHAR(200) NOT NULL,
    industry VARCHAR(100),
    vertical VARCHAR(50),
    address VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(10),
    zip VARCHAR(20)
);

-- Account Dimension
CREATE OR REPLACE TABLE account_dim (
    account_key INT PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL,
    account_type VARCHAR(50)
);


CREATE OR REPLACE TABLE product_dim (
    product_key INT PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    category_key INT NOT NULL,
    category_name VARCHAR(100),
    vertical VARCHAR(50)
);

-- Product Category Dimension
CREATE OR REPLACE TABLE product_category_dim (
    category_key INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    vertical VARCHAR(50) NOT NULL
);

-- Department Dimension
CREATE OR REPLACE TABLE department_dim (
    department_key INT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL
);

-- Campaign Dimension (Marketing)
CREATE OR REPLACE TABLE campaign_dim (
    campaign_key INT PRIMARY KEY,
    campaign_name VARCHAR(300) NOT NULL,
    objective VARCHAR(100)
);

-- Channel Dimension (Marketing)
CREATE OR REPLACE TABLE channel_dim (
    channel_key INT PRIMARY KEY,
    channel_name VARCHAR(100) NOT NULL
);

-- Region Dimension
CREATE OR REPLACE TABLE region_dim (
    region_key INT PRIMARY KEY,
    region_name VARCHAR(100) NOT NULL
);

-- Sales Rep Dimension
CREATE OR REPLACE TABLE sales_rep_dim (
    sales_rep_key INT PRIMARY KEY,
    rep_name VARCHAR(200) NOT NULL,
    hire_date DATE
);
    
-- Finance Transactions Fact Table
CREATE OR REPLACE TABLE finance_transactions (
    transaction_id INT PRIMARY KEY,
    date DATE NOT NULL,
    account_key INT NOT NULL,
    department_key INT NOT NULL,
    vendor_key INT NOT NULL,
    product_key INT NOT NULL,
    customer_key INT NOT NULL,
    amount DECIMAL(12,2) NOT NULL
);

CREATE OR REPLACE TABLE sales_fact (
    sale_id INT PRIMARY KEY,
    date DATE NOT NULL,
    customer_key INT NOT NULL,
    product_key INT NOT NULL,
    sales_rep_key INT NOT NULL,
    region_key INT NOT NULL,
    vendor_key INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    units INT NOT NULL
);

-- Marketing Campaign Fact Table
-- CREATE OR REPLACE TABLE marketing_campaign_fact (
--     campaign_fact_id INT PRIMARY KEY,
--     date DATE NOT NULL,
--     campaign_key INT NOT NULL,
--     product_key INT NOT NULL,
--     channel_key INT NOT NULL,
--     region_key INT NOT NULL,
--     spend DECIMAL(10,2) NOT NULL,
--     leads_generated INT NOT NULL,
--     impressions INT NOT NULL
-- );

-- Load Product Dimension
COPY INTO product_dim
FROM @INTERNAL_DATA_STAGE/structured_data/product_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Product Category Dimension
COPY INTO product_category_dim
FROM @INTERNAL_DATA_STAGE/structured_data/product_category_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Vendor Dimension
COPY INTO vendor_dim
FROM @INTERNAL_DATA_STAGE/structured_data/vendor_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Customer Dimension
COPY INTO customer_dim
FROM @INTERNAL_DATA_STAGE/structured_data/customer_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Account Dimension
COPY INTO account_dim
FROM @INTERNAL_DATA_STAGE/structured_data/account_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Department Dimension
COPY INTO department_dim
FROM @INTERNAL_DATA_STAGE/structured_data/department_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Sales Rep Dimension
COPY INTO sales_rep_dim
FROM @INTERNAL_DATA_STAGE/structured_data/sales_rep_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Campaign Dimension
COPY INTO campaign_dim
FROM @INTERNAL_DATA_STAGE/structured_data/campaign_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Region Dimension
COPY INTO region_dim
FROM @INTERNAL_DATA_STAGE/structured_data/region_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Channel Dimension
COPY INTO channel_dim
FROM @INTERNAL_DATA_STAGE/structured_data/channel_dim.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Finance Transactions
COPY INTO finance_transactions
FROM @INTERNAL_DATA_STAGE/structured_data/finance_transactions.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Load Sales Fact
COPY INTO sales_fact
FROM @INTERNAL_DATA_STAGE/structured_data/sales_fact.csv
FILE_FORMAT = CSV_FORMAT
ON_ERROR = 'CONTINUE';

