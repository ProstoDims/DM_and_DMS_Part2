CREATE USER admin_schema IDENTIFIED BY admin_password;
GRANT CONNECT, RESOURCE TO admin_schema;
GRANT SELECT ANY DICTIONARY TO admin_schema;
GRANT ALL PRIVILEGES TO ADMIN_SCHEMA;


ALTER SESSION SET CURRENT_SCHEMA = admin_schema;

CREATE OR REPLACE PROCEDURE compare_schemes(
    dev_schema_name IN VARCHAR2,
    prod_schema_name IN VARCHAR2
) IS
    TYPE table_list IS TABLE OF VARCHAR2(30);
    v_tables table_list;
    v_has_differences BOOLEAN := FALSE;
    v_table_differences BOOLEAN := FALSE;
    v_any_differences BOOLEAN := FALSE;
    v_has_circular_dependencies BOOLEAN := FALSE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('---------------> Comparing Tables Start <---------------');

    SELECT TABLE_NAME BULK COLLECT INTO v_tables FROM ALL_TABLES WHERE OWNER = dev_schema_name
    MINUS
    SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = prod_schema_name;

    IF v_tables.COUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Tables in DEV_SCHEMA but not in PROD_SCHEMA:');
        FOR i IN 1 .. v_tables.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || v_tables(i));
        END LOOP;
        v_table_differences := TRUE;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No tables in DEV_SCHEMA are missing in PROD_SCHEMA.');
    END IF;

    SELECT TABLE_NAME BULK COLLECT INTO v_tables FROM ALL_TABLES WHERE OWNER = prod_schema_name
    MINUS
    SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = dev_schema_name;

    IF v_tables.COUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Tables in PROD_SCHEMA but not in DEV_SCHEMA:');
        FOR i IN 1 .. v_tables.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || v_tables(i));
        END LOOP;
        v_table_differences := TRUE;
    ELSE
        DBMS_OUTPUT.PUT_LINE('No tables in PROD_SCHEMA are missing in DEV_SCHEMA.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('---------------> Comparing Tables End <---------------');


    DBMS_OUTPUT.PUT_LINE('');


    DBMS_OUTPUT.PUT_LINE('---------------> Comparing Tables Structure Start <---------------');

    FOR r_table IN (
        SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = dev_schema_name
        INTERSECT
        SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = prod_schema_name
    ) LOOP
        BEGIN
            v_has_differences := FALSE;

            FOR r_column IN (
                SELECT column_name FROM ALL_TAB_COLUMNS
                WHERE OWNER = dev_schema_name AND table_name = r_table.TABLE_NAME
                MINUS
                SELECT column_name FROM ALL_TAB_COLUMNS
                WHERE OWNER = prod_schema_name AND table_name = r_table.TABLE_NAME
            ) LOOP
                IF NOT v_has_differences THEN
                    DBMS_OUTPUT.PUT_LINE('Table ' || r_table.TABLE_NAME || ' has differences in DEV_SCHEMA and PROD_SCHEMA:');
                    v_has_differences := TRUE;
                    v_any_differences := TRUE;
                END IF;

                DBMS_OUTPUT.PUT_LINE('  - Column ' || r_column.column_name || ' exists in DEV_SCHEMA but not in PROD_SCHEMA.');
            END LOOP;

            FOR r_column IN (
                SELECT column_name FROM ALL_TAB_COLUMNS
                WHERE OWNER = prod_schema_name AND table_name = r_table.TABLE_NAME
                MINUS
                SELECT column_name FROM ALL_TAB_COLUMNS
                WHERE OWNER = dev_schema_name AND table_name = r_table.TABLE_NAME
            ) LOOP
                IF NOT v_has_differences THEN
                    DBMS_OUTPUT.PUT_LINE('Table ' || r_table.TABLE_NAME || ' has differences in DEV_SCHEMA and PROD_SCHEMA:');
                    v_has_differences := TRUE;
                    v_any_differences := TRUE;
                END IF;

                DBMS_OUTPUT.PUT_LINE('  - Column ' || r_column.column_name || ' exists in PROD_SCHEMA but not in DEV_SCHEMA.');
            END LOOP;

            FOR r_column IN (
                SELECT dev.column_name, dev.data_type, dev.data_length, dev.nullable
                FROM ALL_TAB_COLUMNS dev
                JOIN ALL_TAB_COLUMNS prod
                  ON dev.column_name = prod.column_name
                WHERE dev.OWNER = dev_schema_name
                  AND prod.OWNER = prod_schema_name
                  AND dev.table_name = r_table.TABLE_NAME
                  AND prod.table_name = r_table.TABLE_NAME
                  AND (dev.data_type != prod.data_type
                    OR dev.data_length != prod.data_length
                    OR dev.nullable != prod.nullable)
            ) LOOP
                IF NOT v_has_differences THEN
                    DBMS_OUTPUT.PUT_LINE('Table ' || r_table.TABLE_NAME || ' has differences in DEV_SCHEMA and PROD_SCHEMA:');
                    v_has_differences := TRUE;
                    v_any_differences := TRUE;
                END IF;

                DBMS_OUTPUT.PUT_LINE('  - Column ' || r_column.column_name || ' differs.');
            END LOOP;
        END;
    END LOOP;

    IF NOT v_any_differences THEN
        DBMS_OUTPUT.PUT_LINE('No differences found in table structures between DEV_SCHEMA and PROD_SCHEMA.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('---------------> Comparing Tables Structure End <---------------');


    DBMS_OUTPUT.PUT_LINE('');


    DBMS_OUTPUT.PUT_LINE('-----> Determining Table Creation Order Start <-----');

    BEGIN
        WITH table_dependencies AS (
            SELECT DISTINCT a.table_name AS child_table, c.table_name AS parent_table
            FROM all_constraints a
            JOIN all_constraints c ON a.r_constraint_name = c.constraint_name
            WHERE a.owner = dev_schema_name
              AND c.owner = dev_schema_name
              AND a.constraint_type = 'R'
        ),
        all_tables_list AS (
            SELECT table_name FROM all_tables WHERE owner = dev_schema_name
        ),
        ordered_tables AS (
            SELECT table_name FROM all_tables_list
            WHERE table_name NOT IN (SELECT child_table FROM table_dependencies)
            UNION ALL
            SELECT child_table FROM table_dependencies
            START WITH parent_table IN (SELECT table_name FROM all_tables_list WHERE table_name NOT IN (SELECT child_table FROM table_dependencies))
            CONNECT BY PRIOR child_table = parent_table
        )
        SELECT table_name BULK COLLECT INTO v_tables FROM ordered_tables;

        IF v_tables.COUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Order of table creation in DEV_SCHEMA (considering foreign keys):');
            FOR i IN 1 .. v_tables.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE('  - ' || v_tables(i));
            END LOOP;
        ELSE
            DBMS_OUTPUT.PUT_LINE('No foreign key dependencies found in DEV_SCHEMA. Tables can be created in any order.');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            v_has_circular_dependencies := TRUE;
            DBMS_OUTPUT.PUT_LINE('Error: Unable to determine table creation order.');
    END;

    DECLARE
        TYPE cycle_list IS TABLE OF VARCHAR2(4000);
        v_cycles cycle_list;
    BEGIN
        WITH cycle_detection AS (
            SELECT a.table_name AS child_table, c.table_name AS parent_table
            FROM all_constraints a
            JOIN all_constraints c ON a.r_constraint_name = c.constraint_name
            WHERE a.owner = dev_schema_name
              AND c.owner = dev_schema_name
              AND a.constraint_type = 'R'
        )
        SELECT DISTINCT child_table || ' <-> ' || parent_table
        BULK COLLECT INTO v_cycles
        FROM cycle_detection d1
        WHERE EXISTS (
            SELECT 1 FROM cycle_detection d2
            WHERE d1.child_table = d2.parent_table 
              AND d1.parent_table = d2.child_table
        );

        IF v_cycles.COUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Circular dependencies detected:');
            FOR i IN 1 .. v_cycles.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE('  - ' || v_cycles(i));
            END LOOP;
            v_has_circular_dependencies := TRUE;
        END IF;
    END;

    IF v_has_circular_dependencies THEN
        DBMS_OUTPUT.PUT_LINE('Warning: Circular dependencies detected in DEV_SCHEMA foreign keys.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('-----> Determining Table Creation Order End <-----');

    DBMS_OUTPUT.PUT_LINE('');
END;

SET SERVEROUTPUT ON;