CREATE OR REPLACE FUNCTION build_dynamic_select_query(json_data IN CLOB) RETURN CLOB IS
    v_type         VARCHAR2(100);
    v_columns      JSON_ARRAY_T;
    v_tables       JSON_ARRAY_T;
    v_joins        JSON_ARRAY_T;
    v_filters      JSON_ARRAY_T;
    v_orders       JSON_ARRAY_T;
    v_group_by     JSON_ARRAY_T;
    v_result       CLOB;
    v_temp         VARCHAR2(4000);
    v_operator     VARCHAR2(20);
    v_value        VARCHAR2(4000);
    v_subquery     CLOB;
    v_filter_obj   JSON_OBJECT_T;
BEGIN
    v_result := '';

    v_type := JSON_VALUE(json_data, '$.queryType');

    IF v_type != 'SELECT' THEN
        RAISE_APPLICATION_ERROR(-20001, 'This function supports only SELECT queries.');
    END IF;

    v_result := v_result || v_type || ' ';

    v_temp := JSON_QUERY(json_data, '$.columns' RETURNING CLOB);
    IF v_temp IS NOT NULL THEN
        v_columns := JSON_ARRAY_T(v_temp);
        FOR i IN 0 .. v_columns.get_size - 1 LOOP
            IF i > 0 THEN
                v_result := v_result || ', ';
            END IF;
            v_result := v_result || v_columns.get_string(i);
        END LOOP;
        v_result := v_result || CHR(10);
    END IF;

    v_temp := JSON_QUERY(json_data, '$.tables' RETURNING CLOB);
    IF v_temp IS NOT NULL THEN
        v_tables := JSON_ARRAY_T(v_temp);
        v_result := v_result || 'FROM ';
        FOR i IN 0 .. v_tables.get_size - 1 LOOP
            IF i > 0 THEN
                v_result := v_result || ', ';
            END IF;
            v_result := v_result || v_tables.get_string(i);
        END LOOP;
        v_result := v_result || CHR(10);
    END IF;

    v_temp := JSON_QUERY(json_data, '$.joins' RETURNING CLOB);
    IF v_temp IS NOT NULL THEN
        v_joins := JSON_ARRAY_T(v_temp);
        FOR i IN 0 .. v_joins.get_size - 1 LOOP
            v_temp := JSON_VALUE(v_joins.get(i).to_string(), '$.type') || ' JOIN ' ||
                      JSON_VALUE(v_joins.get(i).to_string(), '$.table') || ' ON ' ||
                      JSON_VALUE(v_joins.get(i).to_string(), '$.on');
            v_result := v_result || v_temp || CHR(10);
        END LOOP;
    END IF;

    v_temp := JSON_QUERY(json_data, '$.filters' RETURNING CLOB);
    IF v_temp IS NOT NULL THEN
        v_filters := JSON_ARRAY_T(v_temp);
        IF v_filters.get_size > 0 THEN
            v_result := v_result || 'WHERE ';
            FOR i IN 0 .. v_filters.get_size - 1 LOOP
                IF i > 0 THEN
                    v_result := v_result || ' AND ';
                END IF;

                v_filter_obj := JSON_OBJECT_T(v_filters.get(i).to_string());
                v_operator := v_filter_obj.get_string('operator');
                v_value := v_filter_obj.get_string('value');

                IF v_filter_obj.has('subquery') THEN
                    v_subquery := JSON_QUERY(v_filters.get(i).to_string(), '$.subquery' RETURNING CLOB);
                    IF v_subquery IS NOT NULL THEN
                        v_temp := v_filter_obj.get_string('column') || ' ' ||
                                  v_operator || ' (' || build_dynamic_select_query(v_subquery) || ')';
                    END IF;

                ELSE
                    v_temp := v_filter_obj.get_string('column') || ' ' ||
                              v_operator || ' ' || v_value;
                END IF;

                v_result := v_result || v_temp;
            END LOOP;
        END IF;
    END IF;

    v_temp := JSON_QUERY(json_data, '$.groupBy' RETURNING CLOB);
    IF v_temp IS NOT NULL AND v_temp != '[]' THEN
        v_group_by := JSON_ARRAY_T(v_temp);
        IF v_group_by.get_size > 0 THEN
            v_result := v_result || CHR(10) || 'GROUP BY ';
            FOR i IN 0 .. v_group_by.get_size - 1 LOOP
                IF i > 0 THEN
                    v_result := v_result || ', ';
                END IF;
                v_result := v_result || v_group_by.get_string(i);
            END LOOP;
        END IF;
    END IF;

    v_temp := JSON_QUERY(json_data, '$.orderBy' RETURNING CLOB);
    IF v_temp IS NOT NULL AND v_temp != '[]' THEN
        v_orders := JSON_ARRAY_T(v_temp);
        IF v_orders.get_size > 0 THEN
            v_result := v_result || CHR(10) || 'ORDER BY ';
            FOR i IN 0 .. v_orders.get_size - 1 LOOP
                IF i > 0 THEN
                    v_result := v_result || ', ';
                END IF;
                v_temp := JSON_VALUE(v_orders.get(i).to_string(), '$.column') || ' ' ||
                          JSON_VALUE(v_orders.get(i).to_string(), '$.direction');
                v_result := v_result || v_temp;
            END LOOP;
        END IF;
    END IF;

    RETURN v_result;
END;
/

CREATE OR REPLACE FUNCTION get_dynamic_cursor_select(json_data IN CLOB) RETURN SYS_REFCURSOR IS
    v_query  CLOB;
    v_cursor SYS_REFCURSOR;
BEGIN
    v_query := build_dynamic_select_query(json_data);
    OPEN v_cursor FOR v_query;
    RETURN v_cursor;
END;
/

CREATE OR REPLACE FUNCTION build_dynamic_dml_query(json_data IN CLOB) RETURN CLOB IS
    v_type         VARCHAR2(100);
    v_table        VARCHAR2(100);
    v_columns      JSON_ARRAY_T;
    v_values       JSON_ARRAY_T;
    v_sets         JSON_ARRAY_T;
    v_filters      JSON_ARRAY_T;
    v_result       CLOB;
    v_temp         VARCHAR2(4000);
    v_operator     VARCHAR2(20);
    v_value        VARCHAR2(4000);
    v_subquery     CLOB;
    v_filter_obj   JSON_OBJECT_T;
BEGIN
    v_result := '';

    v_type := JSON_VALUE(json_data, '$.queryType');
    v_table := JSON_VALUE(json_data, '$.table');

    IF v_type IN ('INSERT', 'UPDATE', 'DELETE') THEN
        v_result := v_result || v_type || ' ';
    ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Unsupported DML query type: ' || v_type);
    END IF;

    IF v_type = 'INSERT' THEN
        v_result := v_result || 'INTO ' || v_table || ' ';

        v_temp := JSON_QUERY(json_data, '$.columns' RETURNING CLOB);
        IF v_temp IS NOT NULL THEN
            v_columns := JSON_ARRAY_T(v_temp);
            v_result := v_result || '(';
            FOR i IN 0 .. v_columns.get_size - 1 LOOP
                IF i > 0 THEN
                    v_result := v_result || ', ';
                END IF;
                v_result := v_result || v_columns.get_string(i);
            END LOOP;
            v_result := v_result || ') ';
        END IF;

        v_temp := JSON_QUERY(json_data, '$.values' RETURNING CLOB);
        IF v_temp IS NOT NULL THEN
            v_values := JSON_ARRAY_T(v_temp);
            v_result := v_result || 'VALUES (';
            FOR i IN 0 .. v_values.get_size - 1 LOOP
                IF i > 0 THEN
                    v_result := v_result || ', ';
                END IF;
                v_result := v_result || v_values.get_string(i);
            END LOOP;
            v_result := v_result || ')';
        END IF;

    ELSIF v_type = 'UPDATE' THEN
        v_result := v_result || v_table || ' ';

        v_temp := JSON_QUERY(json_data, '$.set' RETURNING CLOB);
        IF v_temp IS NOT NULL THEN
            v_sets := JSON_ARRAY_T(v_temp);
            v_result := v_result || 'SET ';
            FOR i IN 0 .. v_sets.get_size - 1 LOOP
                IF i > 0 THEN
                    v_result := v_result || ', ';
                END IF;
                v_temp := JSON_VALUE(v_sets.get(i).to_string(), '$.column') || ' = ' ||
                          JSON_VALUE(v_sets.get(i).to_string(), '$.value');
                v_result := v_result || v_temp;
            END LOOP;
        END IF;

    ELSIF v_type = 'DELETE' THEN
        v_result := v_result || 'FROM ' || v_table || ' ';
    END IF;

    v_temp := JSON_QUERY(json_data, '$.filters' RETURNING CLOB);
    IF v_temp IS NOT NULL THEN
        v_filters := JSON_ARRAY_T(v_temp);
        IF v_filters.get_size > 0 THEN
            v_result := v_result || ' WHERE ';
            FOR i IN 0 .. v_filters.get_size - 1 LOOP
                IF i > 0 THEN
                    v_result := v_result || ' AND ';
                END IF;

                v_filter_obj := JSON_OBJECT_T(v_filters.get(i).to_string());
                v_operator := v_filter_obj.get_string('operator');
                v_value := v_filter_obj.get_string('value');

                IF v_filter_obj.has('subquery') THEN
                    v_subquery := JSON_QUERY(v_filters.get(i).to_string(), '$.subquery' RETURNING CLOB);
                    IF v_subquery IS NOT NULL THEN
                        v_temp := v_filter_obj.get_string('column') || ' ' ||
                                  v_operator || ' (' || build_dynamic_select_query(v_subquery) || ')';
                    END IF;

                ELSE
                    v_temp := v_filter_obj.get_string('column') || ' ' ||
                              v_operator || ' ' || v_value;
                END IF;

                v_result := v_result || v_temp;
            END LOOP;
        END IF;
    END IF;

    RETURN v_result;
END;
/

CREATE OR REPLACE FUNCTION execute_dynamic_dml_query(query IN CLOB) RETURN VARCHAR2 IS
RESULT CLOB;
BEGIN
    result := BUILD_DYNAMIC_DML_QUERY(query);
    EXECUTE IMMEDIATE result;
    COMMIT;
    RETURN 'DML query executed successfully';
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error: ' || SQLERRM;
END;
/

CREATE OR REPLACE FUNCTION generate_ddl_and_trigger(json_data IN CLOB) RETURN CLOB IS
    v_ddl_type    VARCHAR2(100);
    v_table_name  VARCHAR2(100);
    v_columns     JSON_ARRAY_T;
    v_primary_key VARCHAR2(100);
    v_ddl_query   CLOB;
    v_trigger_sql CLOB;
    v_temp        VARCHAR2(4000);
    v_result      CLOB;
BEGIN
    v_ddl_type := JSON_VALUE(json_data, '$.ddlType');
    v_table_name := JSON_VALUE(json_data, '$.tableName');

    IF v_ddl_type = 'CREATE' THEN
        v_columns := JSON_ARRAY_T(JSON_QUERY(json_data, '$.columns' RETURNING CLOB));
        v_ddl_query := 'CREATE TABLE ' || v_table_name || ' (';
        FOR i IN 0 .. v_columns.get_size - 1 LOOP
            IF i > 0 THEN
                v_ddl_query := v_ddl_query || ', ';
            END IF;
            v_temp := JSON_VALUE(v_columns.get(i).to_string(), '$.name') || ' ' ||
                      JSON_VALUE(v_columns.get(i).to_string(), '$.type');
            IF JSON_VALUE(v_columns.get(i).to_string(), '$.primaryKey') = 'true' THEN
                v_temp := v_temp || ' PRIMARY KEY';
                v_primary_key := JSON_VALUE(v_columns.get(i).to_string(), '$.name');
            END IF;
            v_ddl_query := v_ddl_query || v_temp;
        END LOOP;
        v_ddl_query := v_ddl_query || ')';

        v_ddl_query := v_ddl_query || CHR(10);
        IF v_primary_key IS NOT NULL THEN
            v_trigger_sql := 'CREATE SEQUENCE ' || v_table_name || '_seq START WITH 1 INCREMENT BY 1' || CHR(10) || CHR(10) ||
                             'CREATE OR REPLACE TRIGGER ' || v_table_name || '_trg ' || CHR(10) ||
                             'BEFORE INSERT ON ' || v_table_name || ' ' || CHR(10) ||
                             'FOR EACH ROW ' || CHR(10) ||
                             'BEGIN ' || CHR(10) ||
                             '    IF :NEW.' || v_primary_key || ' IS NULL THEN ' || CHR(10) ||
                             '        SELECT ' || v_table_name || '_seq.NEXTVAL INTO :NEW.' || v_primary_key || ' FROM DUAL; ' || CHR(10) ||
                             '    END IF; ' || CHR(10) ||
                             'END;';
        END IF;

        v_result := v_ddl_query || CHR(10) || v_trigger_sql;

    ELSIF v_ddl_type = 'DROP' THEN
        v_result := 'DROP TABLE ' || v_table_name || CHR(10) || CHR(10) ||
                    'DROP SEQUENCE ' || v_table_name || '_seq';
    ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Unsupported DDL type: ' || v_ddl_type);
    END IF;

    RETURN v_result;
END;
/


CREATE OR REPLACE FUNCTION execute_dynamic_ddl_query(query IN CLOB) RETURN VARCHAR2 IS
    result CLOB;
    v_sql_part VARCHAR2(4000);
    v_pos_start PLS_INTEGER := 1;
    v_pos_end PLS_INTEGER;
BEGIN
    result := generate_ddl_and_trigger(query);
    LOOP
        v_pos_end := INSTR(result, CHR(10) || CHR(10), v_pos_start);

        IF v_pos_end = 0 THEN
            v_sql_part := SUBSTR(result, v_pos_start);
        ELSE
            v_sql_part := SUBSTR(result, v_pos_start, v_pos_end - v_pos_start);
        END IF;

        v_sql_part := TRIM(v_sql_part);

        IF v_sql_part IS NOT NULL THEN
            BEGIN
                EXECUTE IMMEDIATE v_sql_part;
                COMMIT;
            END;
        END IF;

        EXIT WHEN v_pos_end = 0;

        v_pos_start := v_pos_end + 2;
    END LOOP;

    RETURN 'DDL query executed successfully';
EXCEPTION
    WHEN OTHERS THEN
        RETURN 'Error: ' || SQLERRM;
END;
/

DECLARE
    result CLOB;
    v_json    CLOB;
    v_cursor  SYS_REFCURSOR;
    v_employee_id employees.employee_id%TYPE;
    v_first_name  employees.first_name%TYPE;
BEGIN
    v_json := '{
        "queryType": "SELECT",
        "columns": ["employees.employee_id", "employees.first_name"],
        "tables": ["employees"],
        "joins": [
            {
                "type": "INNER",
                "table": "departments",
                "on": "employees.department_id = departments.department_id"
            }
        ],
        "filters": [
            {
                "column": "employees.department_id",
                "operator": "IN",
                "subquery": {
                    "queryType": "SELECT",
                    "columns": ["department_id"],
                    "tables": ["departments"],
                    "filters": [
                        {
                            "column": "location_id",
                            "operator": "=",
                            "value": "1"
                        }
                    ],
                    "orderBy": []
                }
            },
            {
                "column": "employees.salary",
                "operator": ">",
                "value": "5000"
            }
        ],
        "orderBy": [
            {
                "column": "employees.last_name",
                "direction": "ASC"
            }
        ]
    }';

     v_cursor := get_dynamic_cursor_select(v_json);

    LOOP
        FETCH v_cursor INTO v_employee_id, v_first_name;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('Employee ID: ' || v_employee_id || ', First Name: ' || v_first_name);
    END LOOP;

    CLOSE v_cursor;
END;
/

DECLARE
    result CLOB;
    v_json    CLOB;
    v_cursor  SYS_REFCURSOR;
    v_department_id departments.department_id%TYPE;
    v_employee_count NUMBER;
BEGIN
    v_json := '{
        "queryType": "SELECT",
        "columns": ["employees.department_id", "COUNT(employees.employee_id) AS employee_count"],
        "tables": ["employees"],
        "joins": [
            {
                "type": "INNER",
                "table": "departments",
                "on": "employees.department_id = departments.department_id"
            }
        ],
        "filters": [
            {
                "column": "employees.salary",
                "operator": ">",
                "value": "5000"
            }
        ],
        "groupBy": ["employees.department_id"],
        "orderBy": [
            {
                "column": "employee_count",
                "direction": "DESC"
            }
        ]
    }';

    v_cursor := get_dynamic_cursor_select(v_json);

    LOOP
        FETCH v_cursor INTO v_department_id, v_employee_count;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('Department ID: ' || v_department_id || ', Employee Count: ' || v_employee_count);
    END LOOP;

    CLOSE v_cursor;
END;
/

DECLARE
    v_json CLOB;
    v_query CLOB;
BEGIN
    v_json := '{
        "queryType": "INSERT",
        "table": "employees",
        "columns": ["employee_id", "first_name", "last_name", "department_id", "salary"],
        "values": ["10", "''John''", "''Doe''", "10","1000"]
    }';
    
    v_query := EXECUTE_DYNAMIC_DML_QUERY(v_json);
    DBMS_OUTPUT.PUT_LINE(v_query);
END;
/



DECLARE
    v_json CLOB;
    v_query CLOB;
BEGIN
    v_json := '{
        "queryType": "UPDATE",
        "table": "employees",
        "set": [
            {"column": "first_name", "value": "''Jane''"},
            {"column": "last_name", "value": "''Smith''"}
        ],
        "filters": [
            {"column": "employee_id", "operator": "=", "value": "10"}
        ]
    }';
    
    v_query := EXECUTE_DYNAMIC_DML_QUERY(v_json);
    
    DBMS_OUTPUT.PUT_LINE(v_query);
END;
/

DECLARE
    v_json CLOB;
    v_query CLOB;
BEGIN
    v_json := '{
        "queryType": "DELETE",
        "table": "employees",
        "filters": [
            {"column": "employee_id", "operator": "=", "value": "10"}
        ]
    }';
    
    v_query := EXECUTE_DYNAMIC_DML_QUERY(v_json);
    
    DBMS_OUTPUT.PUT_LINE(v_query);
END;
/

DECLARE
    v_json       CLOB;
    v_result     VARCHAR2(4000);
BEGIN
    v_json := '{
        "ddlType": "CREATE",
        "tableName": "employees1",
        "columns": [
            {"name": "employee_id", "type": "NUMBER", "primaryKey": "true"},
            {"name": "first_name", "type": "VARCHAR2(100)"},
            {"name": "last_name", "type": "VARCHAR2(100)"},
            {"name": "department_id", "type": "NUMBER"}
        ]
    }';

    v_result := execute_dynamic_ddl_query(v_json);
    DBMS_OUTPUT.PUT_LINE(v_result);
END;
/

DECLARE
    v_json       CLOB;
    v_result     VARCHAR2(4000);
BEGIN
    v_json := '{
        "ddlType": "DROP",
        "tableName": "employees1"
    }';

    v_result := execute_dynamic_ddl_query(v_json);
    DBMS_OUTPUT.PUT_LINE(v_result);
END;
/


GRANT CREATE SEQUENCE TO SYSTEM;
GRANT CREATE TRIGGER TO SYSTEM;
