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
    v_has_differences BOOLEAN := FALSE; 
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


    DBMS_OUTPUT.PUT_LINE('');


    DBMS_OUTPUT.PUT_LINE('-----> Comparing Tables Structure Start <-----');

    FOR r_table IN (SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = dev_schema_name) LOOP
        BEGIN
            SELECT 1 INTO v_dll FROM ALL_TABLES 
            WHERE OWNER = prod_schema_name AND TABLE_NAME = r_table.table_name;

            v_has_differences := FALSE;

            FOR r_column IN (
                SELECT column_name, data_type, data_length, nullable FROM ALL_TAB_COLUMNS
                WHERE OWNER = UPPER(dev_schema_name) AND table_name = r_table.table_name
                MINUS
                SELECT column_name, data_type, data_length, nullable FROM ALL_TAB_COLUMNS
                WHERE OWNER = UPPER(prod_schema_name) AND table_name = r_table.table_name
            ) LOOP
                IF NOT v_has_differences THEN
                    DBMS_OUTPUT.PUT_LINE('Table ' || r_table.table_name || ' has different structure in DEV_SCHEMA and PROD_SCHEMA.');
                    v_has_differences := TRUE;
                END IF;

                DBMS_OUTPUT.PUT_LINE('  - Column ' || r_column.column_name || ' differs.');
            END LOOP;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('-----> Comparing Tables Structure End <-----');


    DBMS_OUTPUT.PUT_LINE('');


END;

SET SERVEROUTPUT ON;
