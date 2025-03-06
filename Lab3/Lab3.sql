
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
            AND a.table_name NOT IN (SELECT table_name FROM all_tables WHERE owner = prod_schema_name)  -- Check child table not in prod_schema
            AND c.table_name NOT IN (SELECT table_name FROM all_tables WHERE owner = prod_schema_name)  -- Check parent table not in prod_schema
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
                AND a.table_name NOT IN (SELECT table_name FROM all_tables WHERE owner = prod_schema_name)  -- Check child table not in prod_schema
                AND c.table_name NOT IN (SELECT table_name FROM all_tables WHERE owner = prod_schema_name)  -- Check parent table not in prod_schema
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
