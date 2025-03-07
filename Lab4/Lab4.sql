CREATE OR REPLACE FUNCTION generate_sql_from_json(json_data IN CLOB) RETURN SYS_REFCURSOR IS
    v_query_type VARCHAR2(50);
    v_columns    VARCHAR2(1000);
    v_tables     VARCHAR2(1000);
    v_joins      VARCHAR2(1000);
    v_filters    VARCHAR2(1000);
    v_order_by   VARCHAR2(1000);

    v_sql_query VARCHAR2(4000);

    v_cursor SYS_REFCURSOR;

    FUNCTION generate_subquery(subquery_data IN CLOB) RETURN VARCHAR2 IS
        v_subquery CLOB;
    BEGIN
        v_subquery := generate_sql_from_json(subquery_data);
        RETURN v_subquery;
    END;

BEGIN
    SELECT 
        JSON_VALUE(json_data, '$.queryType'),
        JSON_QUERY(json_data, '$.columns' WITH ARRAY WRAPPER),
        JSON_VALUE(json_data, '$.tables[0]'),
        JSON_QUERY(json_data, '$.joins' WITH ARRAY WRAPPER),
        JSON_QUERY(json_data, '$.filters' WITH ARRAY WRAPPER),
        JSON_QUERY(json_data, '$.orderBy' WITH ARRAY WRAPPER)
    INTO
        v_query_type,
        v_columns,
        v_tables,
        v_joins,
        v_filters,
        v_order_by
    FROM DUAL;

    IF v_query_type = 'SELECT' THEN
        v_columns := REPLACE(REPLACE(v_columns, '[', ''), ']', '');
        v_joins := REPLACE(REPLACE(v_joins, '[', ''), ']', '');
        v_filters := REPLACE(REPLACE(v_filters, '[', ''), ']', '');
        v_order_by := REPLACE(REPLACE(v_order_by, '[', ''), ']', '');

        v_sql_query := 'SELECT ' || v_columns || ' FROM ' || v_tables;

        IF v_joins IS NOT NULL THEN
            FOR r IN (
                SELECT jt.type, jt.table, jt.on
                FROM JSON_TABLE(
                    v_joins,
                    '$[*]'
                    COLUMNS (
                        type VARCHAR2(20) PATH '$.type',
                        table VARCHAR2(50) PATH '$.table',
                        on VARCHAR2(200) PATH '$.on'
                    )
                ) jt
            LOOP
                v_sql_query := v_sql_query || ' ' || r.type || ' JOIN ' || r.table || ' ON ' || r.on;
            END LOOP;
        END IF;

        IF v_filters IS NOT NULL THEN
            FOR f IN (
                SELECT jf.column, jf.operator, jf.value, jf.subquery
                FROM JSON_TABLE(
                    v_filters,
                    '$[*]'
                    COLUMNS (
                        column VARCHAR2(100) PATH '$.column',
                        operator VARCHAR2(20) PATH '$.operator',
                        value VARCHAR2(200) PATH '$.value',
                        subquery CLOB PATH '$.subquery'
                    )
                ) jf
            LOOP
                IF f.subquery IS NOT NULL THEN
                    v_sql_query := v_sql_query || ' ' || f.column || ' ' || f.operator || ' (' || generate_subquery(f.subquery) || ')';
                ELSE
                    v_sql_query := v_sql_query || ' ' || f.column || ' ' || f.operator || ' ' || f.value;
                END IF;
            END LOOP;
        END IF;

        IF v_order_by IS NOT NULL THEN
            v_sql_query := v_sql_query || ' ORDER BY ' || v_order_by;
        END IF;
    END IF;

    OPEN v_cursor FOR v_sql_query;

    RETURN v_cursor;
END;


DECLARE
    v_json_data CLOB;
    v_cursor SYS_REFCURSOR;
    v_employee_id employees.employee_id%TYPE;
    v_first_name employees.first_name%TYPE;
    v_department_name departments.department_name%TYPE;
    v_city locations.city%TYPE;
BEGIN
    v_json_data := '{
        "queryType": "SELECT",
        "columns": ["employees.employee_id", "employees.first_name", "departments.department_name", "locations.city"],
        "tables": ["employees"],
        "joins": [
            {
                "type": "INNER",
                "table": "departments",
                "on": "employees.department_id = departments.department_id"
            },
            {
                "type": "LEFT",
                "table": "locations",
                "on": "departments.location_id = locations.location_id"
            }
        ],
        "filters": [
            {
                "column": "employees.department_id",
                "operator": "=",
                "value": 10
            }
        ],
        "orderBy": [
            {
                "column": "employees.last_name",
                "direction": "ASC"
            }
        ]
    }';

    v_cursor := generate_sql_from_json(v_json_data);

    LOOP
        FETCH v_cursor INTO v_employee_id, v_first_name, v_department_name, v_city;
        EXIT WHEN v_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            'Employee ID: ' || v_employee_id || ', ' ||
            'First Name: ' || v_first_name || ', ' ||
            'Department: ' || v_department_name || ', ' ||
            'City: ' || v_city
        );
    END LOOP;

    CLOSE v_cursor;
END;


DECLARE
    v_json_data CLOB;
    v_cursor SYS_REFCURSOR;
    v_employee_id employees.employee_id%TYPE;
    v_first_name employees.first_name%TYPE;
    v_department_name departments.department_name%TYPE;
    v_city locations.city%TYPE;
BEGIN
    v_json_data := '{
        "queryType": "SELECT",
        "columns": ["employees.employee_id", "employees.first_name"],
        "tables": ["employees"],
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
                            "column": "departments.location_id",
                            "operator": "=",
                            "value": 1
                        }
                    ]
                }
            }
        ]
    }';

    v_cursor := generate_sql_from_json(v_json_data);

    LOOP
        FETCH v_cursor INTO v_employee_id, v_first_name;
        EXIT WHEN v_cursor%NOTFOUND;

        DBMS_OUTPUT.PUT_LINE(
            'Employee ID: ' || v_employee_id || ', ' ||
            'First Name: ' || v_first_name
        );
    END LOOP;

    CLOSE v_cursor;
END;