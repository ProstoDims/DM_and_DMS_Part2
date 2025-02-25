CREATE USER admin_schema IDENTIFIED BY admin_password;
GRANT CONNECT, RESOURCE TO admin_schema;
GRANT SELECT ANY DICTIONARY TO admin_schema;
GRANT ALL PRIVILEGES TO ADMIN_SCHEMA;

ALTER SESSION SET CURRENT_SCHEMA = admin_schema;

CREATE OR REPLACE PROCEDURE compare_schemes(
    dev_schema_name IN VARCHAR2,
    prod_schema_name IN VARCHAR2
) IS
    v_dll VARCHAR2(4000);
BEGIN

    DBMS_OUTPUT.PUT_LINE('-----> Comparing Tables Start <-----');
    FOR r_table IN(
        SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = dev_schema_name
        MINUS
        SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = prod_schema_name
    ) LOOP
    DBMS_OUTPUT.PUT_LINE('Table ' || r_table.table_name || ' exists in DEV_SCHEMA but not in PROD_SCHEMA');
    END LOOP;
    FOR r_table IN(
        SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = prod_schema_name
        MINUS
        SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = dev_schema_name
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('Table ' || r_table.table_name || ' exists in PROD_SCHEMA but not in DEV_SCHEMA');
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('-----> Comparing Tables End <-----');

END;

SET SERVEROUTPUT ON;
