CREATE OR REPLACE PROCEDURE compare_schemes(
    dev_schema_name IN VARCHAR2,
    prod_schema_name IN VARCHAR2
) IS
    v_ddl_commands CLOB_LIST := CLOB_LIST();
    v_has_differences BOOLEAN := FALSE;
    v_table_differences BOOLEAN := FALSE;
    v_any_differences BOOLEAN := FALSE;
    v_has_circular_dependencies BOOLEAN := FALSE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ТАБЛИЦ <--------------------');
    v_table_differences := compare_tables(dev_schema_name, prod_schema_name, v_ddl_commands);
    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ТАБЛИЦ <--------------------');
    
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ СТРУКТУР ТАБЛИЦ <--------------------');
    v_has_differences := compare_table_structure(dev_schema_name, prod_schema_name, v_ddl_commands);
    add_constraints(dev_schema_name, prod_schema_name, v_ddl_commands);
    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ СТРУКТУР ТАБЛИЦ <--------------------');
        
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ПРОЦЕДУР И ФУНКЦИЙ <--------------------');
    compare_functions_and_procedures(dev_schema_name, prod_schema_name, v_ddl_commands);
    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ПРОЦЕДУР И ФУНКЦИЙ <--------------------');

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ИНДЕКСОВ <--------------------');
    compare_indexes(dev_schema_name, prod_schema_name, v_ddl_commands);
    DBMS_OUTPUT.PUT_LINE('--------------------> СРАВНЕНИЕ ИНДЕКСОВ <--------------------');

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('--------------------> ДДЛ КОМАНДЫ <--------------------');
    FOR i IN 1 .. v_ddl_commands.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(v_ddl_commands(i));
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('--------------------> ДДЛ КОМАНДЫ <--------------------');
    
END;






CREATE OR REPLACE FUNCTION compare_tables(
    dev_schema_name IN VARCHAR2,
    prod_schema_name IN VARCHAR2,
    v_ddl_commands IN OUT CLOB_LIST
) RETURN BOOLEAN IS
    TYPE table_list IS TABLE OF VARCHAR2(30);
    v_tables table_list;
    v_table_differences BOOLEAN := FALSE;

    PROCEDURE compare_and_generate_ddl(source_schema IN VARCHAR2, target_schema IN VARCHAR2, ddl_action IN VARCHAR2) IS
    BEGIN
        SELECT TABLE_NAME BULK COLLECT INTO v_tables
        FROM ALL_TABLES WHERE OWNER = source_schema
        AND TABLE_NAME NOT IN (SELECT TABLE_NAME FROM ALL_TABLES WHERE OWNER = target_schema);

        IF v_tables.COUNT > 0 THEN
            FOR i IN 1 .. v_tables.COUNT LOOP
                DBMS_OUTPUT.PUT_LINE('  - ' || v_tables(i));
                v_ddl_commands.EXTEND;
                IF ddl_action = 'CREATE' THEN
                    v_ddl_commands(v_ddl_commands.COUNT) := 'CREATE TABLE ' || target_schema || '.' || v_tables(i) || ' AS SELECT * FROM ' || source_schema || '.' || v_tables(i) || ' WHERE 1 = 0;';
                ELSIF ddl_action = 'DROP' THEN
                    v_ddl_commands(v_ddl_commands.COUNT) := 'DROP TABLE ' || target_schema || '.' || v_tables(i) || ';';
                END IF;
            END LOOP;
            v_table_differences := TRUE;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Все таблицы из ' || source_schema || ' присутствуют в ' || target_schema || '.');
        END IF;
    END compare_and_generate_ddl;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Таблицы, которые есть в DEV_SCHEMA, но отсутствуют в PROD_SCHEMA:');
    compare_and_generate_ddl(dev_schema_name, prod_schema_name, 'CREATE');
    DBMS_OUTPUT.PUT_LINE('Таблицы, которые есть в PROD_SCHEMA, но отсутствуют в DEV_SCHEMA:');
    compare_and_generate_ddl(prod_schema_name, dev_schema_name, 'DROP');

    RETURN v_table_differences;
END compare_tables;





CREATE OR REPLACE FUNCTION compare_table_structure(
    dev_schema_name IN VARCHAR2,
    prod_schema_name IN VARCHAR2,
    v_ddl_commands IN OUT CLOB_LIST
) RETURN BOOLEAN IS
    v_has_differences BOOLEAN := FALSE;
    v_any_differences BOOLEAN := FALSE;

    PROCEDURE log_difference(table_name IN VARCHAR2, message IN VARCHAR2) IS
    BEGIN
        IF NOT v_has_differences THEN
            DBMS_OUTPUT.PUT_LINE('Таблица ' || table_name || ' в DEV_SCHEMA и PROD_SCHEMA отличается:');
            v_has_differences := TRUE;
            v_any_differences := TRUE;
        END IF;
        DBMS_OUTPUT.PUT_LINE('  - ' || message);
    END log_difference;

    PROCEDURE add_ddl_command(command IN VARCHAR2) IS
    BEGIN
        v_ddl_commands.EXTEND;
        v_ddl_commands(v_ddl_commands.COUNT) := command;
    END add_ddl_command;
BEGIN
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
        v_has_differences := FALSE;

        FOR r_column IN (
            SELECT column_name, data_type, data_length, 'ADD' as action
            FROM ALL_TAB_COLUMNS
            WHERE OWNER = dev_schema_name AND table_name = r_table.TABLE_NAME
            MINUS
            SELECT column_name, data_type, data_length, 'ADD'
            FROM ALL_TAB_COLUMNS
            WHERE OWNER = prod_schema_name AND table_name = r_table.TABLE_NAME

            UNION ALL

            SELECT column_name, NULL, NULL, 'DROP'
            FROM ALL_TAB_COLUMNS
            WHERE OWNER = prod_schema_name AND table_name = r_table.TABLE_NAME
            MINUS
            SELECT column_name, NULL, NULL, 'DROP'
            FROM ALL_TAB_COLUMNS
            WHERE OWNER = dev_schema_name AND table_name = r_table.TABLE_NAME

            UNION ALL

            SELECT dev.column_name, dev.data_type, dev.data_length, 'MODIFY'
            FROM ALL_TAB_COLUMNS dev
            JOIN ALL_TAB_COLUMNS prod ON dev.column_name = prod.column_name
            WHERE dev.OWNER = dev_schema_name
              AND prod.OWNER = prod_schema_name
              AND dev.table_name = r_table.TABLE_NAME
              AND prod.table_name = r_table.TABLE_NAME
              AND (dev.data_type != prod.data_type OR dev.data_length != prod.data_length)
        ) LOOP
            IF r_column.action = 'ADD' THEN
                log_difference(r_table.TABLE_NAME, 'Столбец ' || r_column.column_name || ' есть в DEV_SCHEMA но отсутствует в PROD_SCHEMA.');
                add_ddl_command('ALTER TABLE ' || prod_schema_name || '.' || r_table.TABLE_NAME ||
                                ' ADD ' || r_column.column_name || ' ' || r_column.data_type ||
                                '(' || r_column.data_length || ');');

            ELSIF r_column.action = 'DROP' THEN
                log_difference(r_table.TABLE_NAME, 'Столбец ' || r_column.column_name || ' есть в PROD_SCHEMA но отсутствует в DEV_SCHEMA.');
                add_ddl_command('ALTER TABLE ' || prod_schema_name || '.' || r_table.TABLE_NAME ||
                                ' DROP COLUMN ' || r_column.column_name || ';');

            ELSIF r_column.action = 'MODIFY' THEN
                log_difference(r_table.TABLE_NAME, 'Столбец ' || r_column.column_name || ' отличается.');
                add_ddl_command('ALTER TABLE ' || prod_schema_name || '.' || r_table.TABLE_NAME ||
                                ' MODIFY ' || r_column.column_name || ' ' || r_column.data_type ||
                                '(' || r_column.data_length || ');');
            END IF;
        END LOOP;
    END LOOP;

    IF NOT v_any_differences THEN
        DBMS_OUTPUT.PUT_LINE('Отличий в структуре таблиц между DEV_SCHEMA и PROD_SCHEMA не обнаружено.');
    END IF;

    RETURN v_any_differences;
END compare_table_structure;





CREATE OR REPLACE PROCEDURE add_constraints(
    dev_schema_name IN VARCHAR2,
    prod_schema_name IN VARCHAR2,
    v_ddl_commands IN OUT CLOB_LIST
) IS
    PROCEDURE add_command(command IN VARCHAR2) IS
    BEGIN
        v_ddl_commands.EXTEND;
        v_ddl_commands(v_ddl_commands.COUNT) := command;
    END add_command;
BEGIN
    FOR r_table IN (
        SELECT TABLE_NAME 
        FROM ALL_TABLES 
        WHERE OWNER = dev_schema_name
        AND TABLE_NAME NOT IN (
            SELECT TABLE_NAME 
            FROM ALL_TABLES 
            WHERE OWNER = prod_schema_name
        )
    ) LOOP
        FOR r_constraint IN (
            SELECT ac.constraint_name, acc.column_name,
                   CASE ac.constraint_type 
                       WHEN 'P' THEN 'PRIMARY KEY'
                       WHEN 'U' THEN 'UNIQUE'
                   END AS constraint_type,
                   NULL AS referenced_table,
                   NULL AS referenced_column
            FROM ALL_CONSTRAINTS ac
            JOIN ALL_CONS_COLUMNS acc ON ac.constraint_name = acc.constraint_name
            WHERE ac.OWNER = dev_schema_name
              AND ac.table_name = r_table.TABLE_NAME
              AND ac.constraint_type IN ('P', 'U')

            UNION ALL

            SELECT a.constraint_name, acc.column_name, 
                   'FOREIGN KEY' AS constraint_type,
                   c.table_name AS referenced_table,
                   c.column_name AS referenced_column
            FROM ALL_CONSTRAINTS a
            JOIN ALL_CONS_COLUMNS acc ON a.constraint_name = acc.constraint_name
            JOIN ALL_CONS_COLUMNS c ON a.r_constraint_name = c.constraint_name
            WHERE a.OWNER = dev_schema_name
              AND a.table_name = r_table.TABLE_NAME
              AND a.constraint_type = 'R'
        ) LOOP
            IF r_constraint.constraint_type = 'FOREIGN KEY' THEN
                add_command('ALTER TABLE ' || prod_schema_name || '.' || r_table.TABLE_NAME || 
                            ' ADD CONSTRAINT ' || r_constraint.constraint_name || 
                            ' FOREIGN KEY (' || r_constraint.column_name || 
                            ') REFERENCES ' || prod_schema_name || '.' || 
                            r_constraint.referenced_table || '(' || r_constraint.referenced_column || ');');
            ELSE
                add_command('ALTER TABLE ' || prod_schema_name || '.' || r_table.TABLE_NAME || 
                            ' ADD CONSTRAINT ' || r_constraint.constraint_name || 
                            ' ' || r_constraint.constraint_type || 
                            ' (' || r_constraint.column_name || ');');
            END IF;
        END LOOP;
    END LOOP;
END add_constraints;




CREATE OR REPLACE PROCEDURE get_plsql_procs_and_funcs(
  p_schema_name IN VARCHAR2, 
  p_object_name IN VARCHAR2, 
  p_code OUT VARCHAR2
) IS
  v_code VARCHAR2(32767);
BEGIN
  v_code := '';

  FOR r IN (
    SELECT object_name, object_type
    FROM all_objects
    WHERE (object_type = 'FUNCTION' OR object_type = 'PROCEDURE')
    AND owner = UPPER(p_schema_name)
    AND object_name = UPPER(p_object_name)
  ) LOOP
    FOR proc_func IN (
      SELECT text AS text 
      FROM all_source
      WHERE owner = UPPER(p_schema_name)
      AND name = r.object_name
      ORDER BY line
    ) LOOP
      DECLARE
        v_text VARCHAR2(32767);
      BEGIN
        v_text := TRIM(TRIM(CHR(10) FROM proc_func.text)); 
        IF LENGTH(v_text) > 0 THEN
           v_text := REGEXP_REPLACE(v_text, '\s+', ' ');
           v_code := v_code || v_text || CHR(10);
        END IF;
      END;
    END LOOP;
  END LOOP;

  p_code := v_code;
END get_plsql_procs_and_funcs;



CREATE OR REPLACE PROCEDURE compare_functions_and_procedures(
    dev_schema_name IN VARCHAR2,
    prod_schema_name IN VARCHAR2,
    v_ddl_commands IN OUT CLOB_LIST
) IS
    v_dev_code CLOB; 
    v_prod_code CLOB; 
    v_has_diff BOOLEAN := FALSE;
BEGIN
    FOR dev_only IN (
        SELECT object_name, object_type
        FROM all_objects
        WHERE (object_type = 'FUNCTION' OR object_type = 'PROCEDURE')
        AND owner = UPPER(dev_schema_name)
        AND object_name NOT IN (
            SELECT object_name
            FROM all_objects
            WHERE (object_type = 'FUNCTION' OR object_type = 'PROCEDURE')
            AND owner = UPPER(prod_schema_name)
        )
    ) LOOP
        IF NOT v_has_diff THEN
            DBMS_OUTPUT.PUT_LINE('Функции и процедуры, которые есть в ' || UPPER(dev_schema_name) || ', но отсутствуют в ' || UPPER(prod_schema_name) || ':');
            v_has_diff := TRUE;
        END IF;

        get_plsql_procs_and_funcs(dev_schema_name, dev_only.object_name, v_dev_code);

        IF v_dev_code LIKE 'PROCEDURE%' THEN
            v_dev_code := SUBSTR(v_dev_code, INSTR(v_dev_code, 'IS') + 2); 
        ELSIF v_dev_code LIKE 'FUNCTION%' THEN
            v_dev_code := SUBSTR(v_dev_code, INSTR(v_dev_code, 'IS') + 2);  
        END IF;

        v_ddl_commands.EXTEND;
        v_ddl_commands(v_ddl_commands.COUNT) := '';  
        v_ddl_commands.EXTEND;
        v_ddl_commands(v_ddl_commands.COUNT) := '';  
        v_ddl_commands.EXTEND;
        v_ddl_commands(v_ddl_commands.COUNT) := 'CREATE OR REPLACE ' || dev_only.object_type || ' ' || prod_schema_name || '.' || dev_only.object_name || ' AS ' || v_dev_code;

        DBMS_OUTPUT.PUT_LINE('  - ' || dev_only.object_name);
    END LOOP;


    FOR prod_only IN (
        SELECT object_name, object_type
        FROM all_objects
        WHERE (object_type = 'FUNCTION' OR object_type = 'PROCEDURE')
        AND owner = UPPER(prod_schema_name)
        AND object_name NOT IN (
            SELECT object_name
            FROM all_objects
            WHERE (object_type = 'FUNCTION' OR object_type = 'PROCEDURE')
            AND owner = UPPER(dev_schema_name)
        )
    ) LOOP
        IF NOT v_has_diff THEN
            DBMS_OUTPUT.PUT_LINE('Функции и процедуры, которые есть в ' || UPPER(prod_schema_name) || ', но отсутствуют в ' || UPPER(dev_schema_name) || ':');
            v_has_diff := TRUE;
        END IF;

        v_ddl_commands.EXTEND;
        v_ddl_commands(v_ddl_commands.COUNT) := '';
        v_ddl_commands.EXTEND;
        v_ddl_commands(v_ddl_commands.COUNT) := '';
        v_ddl_commands.EXTEND;
        v_ddl_commands(v_ddl_commands.COUNT) := 'DROP ' || prod_only.object_type || ' ' || prod_schema_name || '.' || prod_only.object_name;

        DBMS_OUTPUT.PUT_LINE('  - ' || prod_only.object_name);
    END LOOP;


   FOR common_obj IN (
        SELECT dev.object_name, dev.object_type
        FROM all_objects dev
        JOIN all_objects prod
        ON dev.object_name = prod.object_name
        AND dev.object_type = prod.object_type
        WHERE (dev.object_type = 'FUNCTION' OR dev.object_type = 'PROCEDURE')
        AND dev.owner = UPPER(dev_schema_name)
        AND prod.owner = UPPER(prod_schema_name)
    ) LOOP
        get_plsql_procs_and_funcs(dev_schema_name, common_obj.object_name, v_dev_code);
        get_plsql_procs_and_funcs(prod_schema_name, common_obj.object_name, v_prod_code);

        IF v_dev_code <> v_prod_code THEN
            IF NOT v_has_diff THEN
                DBMS_OUTPUT.PUT_LINE('Функции и процедуры, которые отличаются между ' || UPPER(dev_schema_name) || ' и ' || UPPER(prod_schema_name) || ':');
                v_has_diff := TRUE;
            END IF;

            IF v_dev_code LIKE 'PROCEDURE%' OR v_dev_code LIKE 'FUNCTION%' THEN
                IF INSTR(v_dev_code, 'IS') > 0 THEN
                    v_dev_code := SUBSTR(v_dev_code, INSTR(v_dev_code, 'IS') + 2);
                ELSIF INSTR(v_dev_code, 'AS') > 0 THEN
                    v_dev_code := SUBSTR(v_dev_code, INSTR(v_dev_code, 'AS') + 2);
                END IF;
            END IF;

            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := '';
            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := ''; 
            v_ddl_commands.EXTEND;
            v_ddl_commands(v_ddl_commands.COUNT) := 'CREATE OR REPLACE ' || common_obj.object_type || ' ' || prod_schema_name || '.' || common_obj.object_name || ' AS ' || v_dev_code;

            DBMS_OUTPUT.PUT_LINE('  - ' || common_obj.object_name);
        END IF;
    END LOOP;


    IF NOT v_has_diff THEN
        DBMS_OUTPUT.PUT_LINE('Функции и процедуры в схемах ' || UPPER(dev_schema_name) || ' и ' || UPPER(prod_schema_name) || ' совпадают.');
    END IF;
END compare_functions_and_procedures;



CREATE OR REPLACE PROCEDURE compare_indexes(
    dev_schema_name IN VARCHAR2,
    prod_schema_name IN VARCHAR2,
    ddl_commands IN OUT CLOB_LIST
) IS
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
        ddl_commands.EXTEND;
        ddl_commands(ddl_commands.COUNT) := 'CREATE INDEX ' || prod_schema_name || '.' || r_index.INDEX_NAME || ' ON ' || prod_schema_name || '.' || r_index.TABLE_NAME || '(' || r_index.COLUMN_LIST || ');';
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
        ddl_commands.EXTEND;
        ddl_commands(ddl_commands.COUNT) := 'DROP INDEX ' || prod_schema_name || '.' || r_index.INDEX_NAME || ';';
    END LOOP;

    IF NOT v_has_index_differences THEN
        DBMS_OUTPUT.PUT_LINE('Отличий в индексах между DEV_SCHEMA и PROD_SCHEMA не обнаружено.');
    END IF;
END compare_indexes;



CREATE OR REPLACE TYPE CLOB_LIST AS TABLE OF CLOB;



