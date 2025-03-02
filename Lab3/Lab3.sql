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

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ТАБЛИЦ <--------------------');

    SELECT TABLE_NAME BULK COLLECT INTO v_tables 
    FROM ALL_TABLES WHERE OWNER = dev_schema_name AND TABLE_NAME NOT IN (SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = prod_schema_name);

    IF v_tables.COUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Таблицы, которые есть в DEV_SCHEMA, но отсутствуют в PROD_SCHEMA:');
        FOR i IN 1 .. v_tables.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || v_tables(i));
        END LOOP;
        v_table_differences := TRUE;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Все таблицы из DEV_SCHEMA присутствуют в PROD_SCHEMA.');
    END IF;

    SELECT TABLE_NAME BULK COLLECT INTO v_tables 
    FROM ALL_TABLES WHERE OWNER = prod_schema_name AND TABLE_NAME NOT IN (SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = dev_schema_name);

    IF v_tables.COUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Таблицы, которые есть в PROD_SCHEMA, но отсутствуют в DEV_SCHEMA:');
        FOR i IN 1 .. v_tables.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || v_tables(i));
        END LOOP;
        v_table_differences := TRUE;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Все таблицы из PROD_SCHEMA присутствуют в DEV_SCHEMA.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ТАБЛИЦ <--------------------');

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ СТРУКТУР ТАБЛИЦ <--------------------');

    FOR r_table IN (
        SELECT TABLE_NAME 
        FROM ALL_TABLES 
        WHERE OWNER = dev_schema_name
          AND TABLE_NAME IN (
              SELECT TABLE_NAME 
              FROM ALL_TABLES 
              WHERE OWNER = prod_schema_name
          )
    ) LOOP
        BEGIN
            v_has_differences := FALSE;

            FOR r_column IN (
                SELECT column_name 
                FROM ALL_TAB_COLUMNS
                WHERE OWNER = dev_schema_name 
                  AND table_name = r_table.TABLE_NAME
                MINUS
                SELECT column_name 
                FROM ALL_TAB_COLUMNS
                WHERE OWNER = prod_schema_name 
                  AND table_name = r_table.TABLE_NAME
            ) LOOP
                IF NOT v_has_differences THEN
                    DBMS_OUTPUT.PUT_LINE('Таблица ' || r_table.TABLE_NAME || ' в DEV_SCHEMA отличается от PROD_SCHEMA:');
                    v_has_differences := TRUE;
                    v_any_differences := TRUE;
                END IF;

                DBMS_OUTPUT.PUT_LINE('  - Столбец ' || r_column.column_name || ' есть в DEV_SCHEMA но отсутствует в PROD_SCHEMA.');
            END LOOP;

            FOR r_column IN (
                SELECT column_name 
                FROM ALL_TAB_COLUMNS
                WHERE OWNER = prod_schema_name 
                  AND table_name = r_table.TABLE_NAME
                MINUS
                SELECT column_name 
                FROM ALL_TAB_COLUMNS
                WHERE OWNER = dev_schema_name 
                  AND table_name = r_table.TABLE_NAME
            ) LOOP
                IF NOT v_has_differences THEN
                    DBMS_OUTPUT.PUT_LINE('Таблица ' || r_table.TABLE_NAME || ' в DEV_SCHEMA отличается от PROD_SCHEMA:');
                    v_has_differences := TRUE;
                    v_any_differences := TRUE;
                END IF;

                DBMS_OUTPUT.PUT_LINE('  - Столбец ' || r_column.column_name || ' есть в PROD_SCHEMA но отсутствует в DEV_SCHEMA.');
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
                    DBMS_OUTPUT.PUT_LINE('Таблица ' || r_table.TABLE_NAME || ' в DEV_SCHEMA отличается от PROD_SCHEMA:');
                    v_has_differences := TRUE;
                    v_any_differences := TRUE;
                END IF;

                DBMS_OUTPUT.PUT_LINE('  - Столбец ' || r_column.column_name || ' отличается.');
            END LOOP;
        END;
    END LOOP;

    IF NOT v_any_differences THEN
        DBMS_OUTPUT.PUT_LINE('Отличий в структуре таблиц между DEV_SCHEMA и PROD_SCHEMA не обнаружено.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ СТРУКТУР ТАБЛИЦ <--------------------');

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('--------------------> ПОРЯДОК СОЗДАНИЯ ТАБЛИЦ <--------------------');

    DECLARE
        TYPE table_dep_list IS TABLE OF VARCHAR2(30);
        v_independent_tables table_dep_list;
        v_dependent_tables table_dep_list;
        v_circular_tables table_dep_list := table_dep_list();
        v_temp_dependent_tables table_dep_list := table_dep_list();
        v_is_circular BOOLEAN;
    BEGIN
        SELECT table_name BULK COLLECT INTO v_independent_tables
        FROM all_tables
        WHERE owner = dev_schema_name
        AND table_name NOT IN (
            SELECT a.table_name
            FROM all_constraints a
            WHERE a.owner = dev_schema_name
                AND a.constraint_type = 'R'
        )
        AND table_name NOT IN (
            SELECT c.table_name
            FROM all_constraints c
            WHERE c.owner = dev_schema_name
                AND c.constraint_type = 'P'
        )
        AND table_name NOT IN (
            SELECT table_name
            FROM all_tables
            WHERE owner = prod_schema_name
        );

        SELECT table_name BULK COLLECT INTO v_dependent_tables
        FROM all_tables
        WHERE owner = dev_schema_name
        AND (
            table_name IN (
                SELECT a.table_name
                FROM all_constraints a
                WHERE a.owner = dev_schema_name
                    AND a.constraint_type = 'R'
            )
            OR table_name IN (
                SELECT c.table_name
                FROM all_constraints c
                WHERE c.owner = dev_schema_name
                    AND c.constraint_type = 'P'
            )
        )
        AND table_name NOT IN (
            SELECT table_name
            FROM all_tables
            WHERE owner = prod_schema_name
        );

        WITH cycle_detection AS (
            SELECT a.table_name AS child_table, c.table_name AS parent_table
            FROM all_constraints a
            JOIN all_constraints c ON a.r_constraint_name = c.constraint_name
            WHERE a.owner = dev_schema_name
            AND c.owner = dev_schema_name
            AND a.constraint_type = 'R'
        )
        SELECT DISTINCT child_table BULK COLLECT INTO v_circular_tables
        FROM cycle_detection d1
        WHERE EXISTS (
            SELECT 1 FROM cycle_detection d2
            WHERE d1.child_table = d2.parent_table 
            AND d1.parent_table = d2.child_table
        );

        IF v_circular_tables.COUNT > 0 THEN
            FOR i IN 1 .. v_dependent_tables.COUNT LOOP
                v_is_circular := FALSE;
                FOR j IN 1 .. v_circular_tables.COUNT LOOP
                    IF v_dependent_tables(i) = v_circular_tables(j) THEN
                        v_is_circular := TRUE;
                        EXIT;
                    END IF;
                END LOOP;

                IF NOT v_is_circular THEN
                    v_temp_dependent_tables.EXTEND;
                    v_temp_dependent_tables(v_temp_dependent_tables.COUNT) := v_dependent_tables(i);
                END IF;
            END LOOP;
            v_dependent_tables := v_temp_dependent_tables;
        END IF;

        IF v_independent_tables.COUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Таблицы без зависимостей (могут быть созданы в любом порядке):');
            FOR i IN 1 .. v_independent_tables.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE('  - ' || v_independent_tables(i));
            END LOOP;
        END IF;

        IF v_dependent_tables.COUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Таблицы с зависимостями (порядок создания важен):');
            FOR i IN 1 .. v_dependent_tables.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE('  - ' || v_dependent_tables(i));
            END LOOP;
        END IF;

        DECLARE
            TYPE cycle_pair IS RECORD (
                table1 VARCHAR2(30),
                table2 VARCHAR2(30)
            );
            TYPE cycle_list IS TABLE OF cycle_pair;
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
            SELECT child_table, parent_table
            BULK COLLECT INTO v_cycles
            FROM cycle_detection d1
            WHERE EXISTS (
                SELECT 1 FROM cycle_detection d2
                WHERE d1.child_table = d2.parent_table 
                AND d1.parent_table = d2.child_table
            );

            IF v_cycles.COUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE('Обнаруженные циклические зависимости:');
                FOR i IN 1 .. v_cycles.COUNT LOOP
                    DBMS_OUTPUT.PUT_LINE('  - ' || v_cycles(i).table1 || ' <-> ' || v_cycles(i).table2);
                END LOOP;
            END IF;
        END;
    END;

    DBMS_OUTPUT.PUT_LINE('--------------------> ПОРЯДОК СОЗДАНИЯ ТАБЛИЦ <--------------------');

    DBMS_OUTPUT.PUT_LINE('');
END;

SET SERVEROUTPUT ON;
