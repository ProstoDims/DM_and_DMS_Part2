CREATE OR REPLACE FUNCTION generate_sql_from_json(json_data IN CLOB) RETURN SYS_REFCURSOR IS
    v_query_type VARCHAR2(50);
    v_table      VARCHAR2(100);
    v_columns    VARCHAR2(1000);
    v_values     VARCHAR2(1000);
    v_set        VARCHAR2(1000);
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
        JSON_VALUE(json_data, '$.table'),
        JSON_QUERY(json_data, '$.columns' WITH ARRAY WRAPPER),
        JSON_QUERY(json_data, '$.values' WITH ARRAY WRAPPER),
        JSON_QUERY(json_data, '$.set' WITH ARRAY WRAPPER),
        JSON_QUERY(json_data, '$.filters' WITH ARRAY WRAPPER),
        JSON_QUERY(json_data, '$.orderBy' WITH ARRAY WRAPPER)
    INTO
        v_query_type,
        v_table,
        v_columns,
        v_values,
        v_set,
        v_filters,
        v_order_by
    FROM DUAL;

    CASE v_query_type
        WHEN 'SELECT' THEN
            v_sql_query := 'SELECT ' || v_columns || ' FROM ' || v_table;

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

        WHEN 'INSERT' THEN
            v_sql_query := 'INSERT INTO ' || v_table || ' (' || v_columns || ') VALUES (';

            FOR r IN (
                SELECT jv.key, jv.value
                FROM JSON_TABLE(
                    v_values,
                    '$[*]'
                    COLUMNS (
                        key VARCHAR2(100) PATH '$.key',
                        value VARCHAR2(200) PATH '$.value'
                    )
                ) jv
            LOOP
                IF JSON_EXISTS(jv.value, '$.subquery') THEN
                    v_sql_query := v_sql_query || '(' || generate_subquery(jv.value) || ')';
                ELSE
                    v_sql_query := v_sql_query || jv.value;
                END IF;
            END LOOP;

            v_sql_query := v_sql_query || ')';

        WHEN 'UPDATE' THEN
            v_sql_query := 'UPDATE ' || v_table || ' SET ' || v_set;

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

        WHEN 'DELETE' THEN
            v_sql_query := 'DELETE FROM ' || v_table;

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

        ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Unsupported query type: ' || v_query_type);
    END CASE;

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

DECLARE
    v_json_data CLOB;
    v_cursor SYS_REFCURSOR;
BEGIN
    v_json_data := '{
        "queryType": "UPDATE",
        "table": "employees",
        "set": {
            "first_name": "Robert"
        },
        "filters": [
            {
                "column": "department_id",
                "operator": "IN",
                "subquery": {
                    "queryType": "SELECT",
                    "columns": ["department_id"],
                    "tables": ["departments"],
                    "filters": [
                        {
                            "column": "location_id",
                            "operator": "=",
                            "value": 1
                        }
                    ]
                }
            }
        ]
    }';

    v_cursor := generate_sql_from_json(v_json_data);

    DBMS_OUTPUT.PUT_LINE('Rows updated successfully.');
END;


DECLARE
    v_json_data CLOB;
    v_cursor SYS_REFCURSOR;
BEGIN
    v_json_data := '{
        "queryType": "DELETE",
        "table": "employees",
        "filters": [
            {
                "column": "department_id",
                "operator": "IN",
                "subquery": {
                    "queryType": "SELECT",
                    "columns": ["department_id"],
                    "tables": ["departments"],
                    "filters": [
                        {
                            "column": "location_id",
                            "operator": "=",
                            "value": 1
                        }
                    ]
                }
            }
        ]
    }';

    v_cursor := generate_sql_from_json(v_json_data);

    DBMS_OUTPUT.PUT_LINE('Rows deleted successfully.');
END;

DECLARE
    v_json_data CLOB;
    v_cursor SYS_REFCURSOR;
BEGIN
    v_json_data := '{
        "queryType": "INSERT",
        "table": "employees",
        "columns": ["employee_id", "first_name", "last_name", "department_id"],
        "values": {
            "employee_id": 5,
            "first_name": "Alice",
            "last_name": "Brown",
            "department_id": {
                "subquery": {
                    "queryType": "SELECT",
                    "columns": ["department_id"],
                    "tables": ["departments"],
                    "filters": [
                        {
                            "column": "location_id",
                            "operator": "=",
                            "value": 1
                        }
                    ]
                }
            }
        }
    }';

    v_cursor := generate_sql_from_json(v_json_data);

    DBMS_OUTPUT.PUT_LINE('Row inserted successfully.');
END;