USE ROLE ACCOUNTADMIN;
--create warehouse for openflow usage
CREATE WAREHOUSE SANDBOX_WH;

--Create openflow admin user
CREATE ROLE IF NOT EXISTS OPENFLOW_ADMIN;

--Grant role to user
GRANT CREATE ROLE ON ACCOUNT TO ROLE OPENFLOW_ADMIN;
GRANT ROLE OPENFLOW_ADMIN TO USER USER;

--set default role for user
ALTER USER USER SET DEFAULT_ROLE = USER;
ALTER USER USER SET DEFAULT_SECONDARY_ROLES = ('ALL');

--grant required privileges
GRANT CREATE OPENFLOW DATA PLANE INTEGRATION ON ACCOUNT TO ROLE OPENFLOW_ADMIN;
GRANT CREATE OPENFLOW RUNTIME INTEGRATION ON ACCOUNT TO ROLE OPENFLOW_ADMIN;
GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE OPENFLOW_ADMIN;

--enable BCR Bundle to ensure connectivity
call SYSTEM$ENABLE_BEHAVIOR_CHANGE_BUNDLE('2025_06');

--Create a role to manage the connector and the associated data and
--grant it to that user
USE ROLE SECURITYADMIN;
CREATE ROLE BOX_OPENFLOW_ADMIN_ROLE;

GRANT ROLE BOX_OPENFLOW_ADMIN_ROLE TO USER USER;

--Grant usage on the database to be used to the newly created role
USE ROLE SYSADMIN;
GRANT USAGE ON DATABASE DEFAULT_DATABASE TO ROLE BOX_OPENFLOW_ADMIN_ROLE;

--Grant the necessary privileges on the schema to be used for the connector admin role
USE DATABASE DEFAULT_DATABASE;
GRANT USAGE ON SCHEMA DEFAULT_SCHEMA TO ROLE BOX_OPENFLOW_ADMIN_ROLE;
GRANT CREATE TABLE, CREATE DYNAMIC TABLE, CREATE STAGE, CREATE SEQUENCE ON SCHEMA DEFAULT_SCHEMA TO ROLE BOX_OPENFLOW_ADMIN_ROLE;


--Grant the appropriate privileges to the connector admin role. Adjust the size according to your needs.
GRANT USAGE, OPERATE ON WAREHOUSE SANDBOX_WH TO ROLE BOX_OPENFLOW_ADMIN_ROLE;

USE ROLE ACCOUNTADMIN;

--create network rule for box connectivity
CREATE OR REPLACE NETWORK RULE box_connectivity_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = (
    -- Core Box domains
    '*.box.com:443',
    '*.app.box.com:443',
    '*.ent.box.com:443',
    '*.box.net:443',
    '*.boxcdn.net:443',
    '*.boxcloud.com:443',
    '*.services.box.com:443',
    'api.box.com:443',
    'app.box.com:443',
    'upload.box.com:443',
    'dl.boxcloud.com:443',
    'account.box.com:443'
  );

SHOW NETWORK RULES LIKE 'box_%';

--create external access integration for box using network rule
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION box_eai
  ALLOWED_NETWORK_RULES = (
    box_connectivity_rule
  )
  ENABLED = TRUE
  COMMENT = 'External Access Integration for Box.com connectivity';

--grant external access integration to openflow roles
GRANT USAGE ON INTEGRATION box_eai TO ROLE BOX_OPENFLOW_ADMIN_ROLE;
GRANT USAGE ON INTEGRATION box_eai TO ROLE OPENFLOW_ADMIN;

SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'box_eai';

--list documents uploaded from box
list @DEFAULT_DATABASE.DEFAULT_SCHEMA.DOCUMENTS;


-- 1. Enable directory table support
ALTER STAGE DEFAULT_DATABASE.DEFAULT_SCHEMA.DOCUMENTS SET DIRECTORY = (ENABLE = TRUE);

-- 2. Refresh the directory metadata so it captures the files
ALTER STAGE DEFAULT_DATABASE.DEFAULT_SCHEMA.DOCUMENTS REFRESH;
CREATE OR REPLACE TABLE DEFAULT_DATABASE.DEFAULT_SCHEMA.parsed_content AS 
SELECT 
    relative_path, 
    BUILD_STAGE_FILE_URL('@DEFAULT_DATABASE.DEFAULT_SCHEMA.DOCUMENTS', relative_path) as file_url,
    TO_FILE(BUILD_STAGE_FILE_URL('@DEFAULT_DATABASE.DEFAULT_SCHEMA.DOCUMENTS', relative_path)) file_object,
    SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
        @DEFAULT_DATABASE.DEFAULT_SCHEMA.DOCUMENTS,
        relative_path,
        {'mode':'LAYOUT'}
    ):content::string as Content
FROM directory(@DEFAULT_DATABASE.DEFAULT_SCHEMA.DOCUMENTS) 
WHERE relative_path ILIKE '%.pdf';


select * from DEFAULT_DATABASE.DEFAULT_SCHEMA.parsed_content;



