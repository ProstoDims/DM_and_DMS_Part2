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
    TYPE ddl_list IS TABLE OF VARCHAR2(4000);
    
    v_tables table_list;
    v_ddl_commands ddl_list := ddl_list();
    v_has_differences BOOLEAN := FALSE;
    v_table_differences BOOLEAN := FALSE;
    v_any_differences BOOLEAN := FALSE;
    v_has_circular_dependencies BOOLEAN := FALSE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ТАБЛИЦ <--------------------');

    SELECT TABLE_NAME BULK COLLECT INTO v_tables 
    FROM ALL_TABLES 
    WHERE OWNER = dev_schema_name
      AND TABLE_NAME NOT IN (
          SELECT TABLE_NAME 
          FROM ALL_TABLES 
          WHERE OWNER = prod_schema_name
      );

    IF v_tables.COUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Таблицы, которые есть в DEV_SCHEMA, но отсутствуют в PROD_SCHEMA:');
        FOR i IN 1 .. v_tables.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || v_tables(i));
            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := 'CREATE TABLE ' || prod_schema_name || '.' || v_tables(i) || ' AS SELECT * FROM ' || dev_schema_name || '.' || v_tables(i) || ' WHERE 1 = 0;';
        END LOOP;
        v_table_differences := TRUE;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Все таблицы из DEV_SCHEMA присутствуют в PROD_SCHEMA.');
    END IF;

    SELECT TABLE_NAME BULK COLLECT INTO v_tables 
    FROM ALL_TABLES 
    WHERE OWNER = prod_schema_name
      AND TABLE_NAME NOT IN (
          SELECT TABLE_NAME 
          FROM ALL_TABLES 
          WHERE OWNER = dev_schema_name
      );

    IF v_tables.COUNT > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Таблицы, которые есть в PROD_SCHEMA, но отсутствуют в DEV_SCHEMA:');
        FOR i IN 1 .. v_tables.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('  - ' || v_tables(i));
            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := 'DROP TABLE ' || prod_schema_name || '.' || v_tables(i) || ';';
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
                SELECT column_name, data_type, data_length
                FROM ALL_TAB_COLUMNS
                WHERE OWNER = dev_schema_name 
                  AND table_name = r_table.TABLE_NAME
                MINUS
                SELECT column_name, data_type, data_length
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
                v_ddl_commands.EXTEND;
                v_ddl_commands(v_ddl_commands.COUNT) := 'ALTER TABLE ' || prod_schema_name || '.' || r_table.TABLE_NAME || ' ADD ' || r_column.column_name || ' ' || r_column.data_type || '(' || r_column.data_length || ');';
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
                v_ddl_commands.EXTEND;
                v_ddl_commands(v_ddl_commands.COUNT) := 'ALTER TABLE ' || prod_schema_name || '.' || r_table.TABLE_NAME || ' DROP COLUMN ' || r_column.column_name || ';';
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
                v_ddl_commands.EXTEND;
                v_ddl_commands(v_ddl_commands.COUNT) := 'ALTER TABLE ' || prod_schema_name || '.' || r_table.TABLE_NAME || ' MODIFY ' || r_column.column_name || ' ' || r_column.data_type || '(' || r_column.data_length || ');';
            END LOOP;
        END;
    END LOOP;

    IF NOT v_any_differences THEN
        DBMS_OUTPUT.PUT_LINE('Отличий в структуре таблиц между DEV_SCHEMA и PROD_SCHEMA не обнаружено.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ СТРУКТУР ТАБЛИЦ <--------------------');

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ПРОЦЕДУР И ФУНКЦИЙ <--------------------');

    DECLARE
        v_has_proc_func_differences BOOLEAN := FALSE;
        v_object_ddl CLOB;
    BEGIN
        FOR r_object IN (
            SELECT OBJECT_NAME, OBJECT_TYPE
            FROM ALL_OBJECTS
            WHERE OWNER = dev_schema_name
            AND OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION')
            AND OBJECT_NAME NOT IN (
                SELECT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OWNER = prod_schema_name
                    AND OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION')
            )
        ) LOOP
            IF NOT v_has_proc_func_differences THEN
                v_has_proc_func_differences := TRUE;
            END IF;
            DBMS_OUTPUT.PUT_LINE('Объект ' || r_object.OBJECT_TYPE || ' ' || r_object.OBJECT_NAME || ' есть в DEV_SCHEMA, но отсутствует в PROD_SCHEMA.');

            BEGIN
                SELECT DBMS_METADATA.GET_DDL(r_object.OBJECT_TYPE, r_object.OBJECT_NAME, dev_schema_name)
                INTO v_object_ddl
                FROM DUAL;
            EXCEPTION
                WHEN OTHERS THEN
                    v_object_ddl := '-- Не удалось извлечь DDL для объекта ' || r_object.OBJECT_NAME;
            END;

            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := v_object_ddl;
        END LOOP;

        FOR r_object IN (
            SELECT OBJECT_NAME, OBJECT_TYPE
            FROM ALL_OBJECTS
            WHERE OWNER = prod_schema_name
            AND OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION')
            AND OBJECT_NAME NOT IN (
                SELECT OBJECT_NAME
                FROM ALL_OBJECTS
                WHERE OWNER = dev_schema_name
                    AND OBJECT_TYPE IN ('PROCEDURE', 'FUNCTION')
            )
        ) LOOP
            IF NOT v_has_proc_func_differences THEN
                v_has_proc_func_differences := TRUE;
            END IF;
            DBMS_OUTPUT.PUT_LINE('Объект ' || r_object.OBJECT_TYPE || ' ' || r_object.OBJECT_NAME || ' есть в PROD_SCHEMA, но отсутствует в DEV_SCHEMA.');
            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := 'DROP ' || r_object.OBJECT_TYPE || ' ' || prod_schema_name || '.' || r_object.OBJECT_NAME || ';';
        END LOOP;

        IF NOT v_has_proc_func_differences THEN
            DBMS_OUTPUT.PUT_LINE('Отличий в процедурах и функциях между DEV_SCHEMA и PROD_SCHEMA не обнаружено.');
        END IF;
    END;

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ПРОЦЕДУР И ФУНКЦИЙ <--------------------');

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ИНДЕКСОВ <--------------------');

    DECLARE
        v_has_index_differences BOOLEAN := FALSE;
    BEGIN
        FOR r_index IN (
            SELECT i.INDEX_NAME, i.TABLE_NAME, LISTAGG(c.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY c.COLUMN_POSITION) AS COLUMN_LIST
            FROM ALL_INDEXES i
            JOIN ALL_IND_COLUMNS c ON i.INDEX_NAME = c.INDEX_NAME AND i.TABLE_NAME = c.TABLE_NAME AND i.OWNER = c.INDEX_OWNER
            WHERE i.OWNER = dev_schema_name
            AND i.TABLE_NAME IN (
                SELECT TABLE_NAME
                FROM ALL_TABLES
                WHERE OWNER = prod_schema_name
            )
            AND i.INDEX_NAME NOT IN (
                SELECT INDEX_NAME
                FROM ALL_INDEXES
                WHERE OWNER = prod_schema_name
            )
            GROUP BY i.INDEX_NAME, i.TABLE_NAME
        ) LOOP
            IF NOT v_has_index_differences THEN
                v_has_index_differences := TRUE;
            END IF;
            DBMS_OUTPUT.PUT_LINE('Индекс ' || r_index.INDEX_NAME || ' есть в DEV_SCHEMA, но отсутствует в PROD_SCHEMA.');
            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := 'CREATE INDEX ' || prod_schema_name || '.' || r_index.INDEX_NAME || ' ON ' || prod_schema_name || '.' || r_index.TABLE_NAME || '(' || r_index.COLUMN_LIST || ');';
        END LOOP;

        FOR r_index IN (
            SELECT i.INDEX_NAME, i.TABLE_NAME, LISTAGG(c.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY c.COLUMN_POSITION) AS COLUMN_LIST
            FROM ALL_INDEXES i
            JOIN ALL_IND_COLUMNS c ON i.INDEX_NAME = c.INDEX_NAME AND i.TABLE_NAME = c.TABLE_NAME AND i.OWNER = c.INDEX_OWNER
            WHERE i.OWNER = prod_schema_name
            AND i.TABLE_NAME IN (
                SELECT TABLE_NAME
                FROM ALL_TABLES
                WHERE OWNER = dev_schema_name
            )
            AND i.INDEX_NAME NOT IN (
                SELECT INDEX_NAME
                FROM ALL_INDEXES
                WHERE OWNER = dev_schema_name
            )
            GROUP BY i.INDEX_NAME, i.TABLE_NAME
        ) LOOP
            IF NOT v_has_index_differences THEN
                v_has_index_differences := TRUE;
            END IF;
            DBMS_OUTPUT.PUT_LINE('Индекс ' || r_index.INDEX_NAME || ' есть в PROD_SCHEMA, но отсутствует в DEV_SCHEMA.');
            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := 'DROP INDEX ' || prod_schema_name || '.' || r_index.INDEX_NAME || ';';
        END LOOP;

        IF NOT v_has_index_differences THEN
            DBMS_OUTPUT.PUT_LINE('Отличий в индексах между DEV_SCHEMA и PROD_SCHEMA не обнаружено.');
        END IF;
    END;

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ИНДЕКСОВ <--------------------');

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ПАКЕТОВ <--------------------');

    DECLARE
        v_has_package_differences BOOLEAN := FALSE;
    BEGIN
        FOR r_package IN (
            SELECT OBJECT_NAME
            FROM ALL_OBJECTS
            WHERE OWNER = dev_schema_name
              AND OBJECT_TYPE = 'PACKAGE'
              AND OBJECT_NAME NOT IN (
                  SELECT OBJECT_NAME
                  FROM ALL_OBJECTS
                  WHERE OWNER = prod_schema_name
                    AND OBJECT_TYPE = 'PACKAGE'
              )
        ) LOOP
            IF NOT v_has_package_differences THEN
                v_has_package_differences := TRUE;
            END IF;
            DBMS_OUTPUT.PUT_LINE('Пакет ' || r_package.OBJECT_NAME || ' есть в DEV_SCHEMA, но отсутствует в PROD_SCHEMA.');
            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := 'CREATE OR REPLACE PACKAGE ' || prod_schema_name || '.' || r_package.OBJECT_NAME || ' AS <код_пакета>;';
        END LOOP;

        FOR r_package IN (
            SELECT OBJECT_NAME
            FROM ALL_OBJECTS
            WHERE OWNER = prod_schema_name
              AND OBJECT_TYPE = 'PACKAGE'
              AND OBJECT_NAME NOT IN (
                  SELECT OBJECT_NAME
                  FROM ALL_OBJECTS
                  WHERE OWNER = dev_schema_name
                    AND OBJECT_TYPE = 'PACKAGE'
              )
        ) LOOP
            IF NOT v_has_package_differences THEN
                v_has_package_differences := TRUE;
            END IF;
            DBMS_OUTPUT.PUT_LINE('Пакет ' || r_package.OBJECT_NAME || ' есть в PROD_SCHEMA, но отсутствует в DEV_SCHEMA.');
            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := 'DROP PACKAGE ' || prod_schema_name || '.' || r_package.OBJECT_NAME || ';';
        END LOOP;

        IF NOT v_has_package_differences THEN
            DBMS_OUTPUT.PUT_LINE('Отличий в пакетах между DEV_SCHEMA и PROD_SCHEMA не обнаружено.');
        END IF;
    END;

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ПАКЕТОВ <--------------------');

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

    DBMS_OUTPUT.PUT_LINE('--------------------> DDL-СКРИПТ ДЛЯ ОБНОВЛЕНИЯ <--------------------');
    IF v_ddl_commands.COUNT > 0 THEN
        FOR i IN 1 .. v_ddl_commands.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE(v_ddl_commands(i));
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE('DDL-скрипт не требуется: отличий между схемами не обнаружено.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('--------------------> DDL-СКРИПТ ДЛЯ ОБНОВЛЕНИЯ <--------------------');

    DBMS_OUTPUT.PUT_LINE('');
END;

SET SERVEROUTPUT ON;
