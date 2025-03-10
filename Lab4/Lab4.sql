CREATE OR REPLACE FUNCTION build_dynamic_select_query(json_data IN CLOB) RETURN CLOB IS
 v_type VARCHAR2(100);
 v_columns JSON_ARRAY_T;
 v_tables JSON_ARRAY_T;
 v_result VARCHAR2(4000);
BEGIN
    v_type := JSON_VALUE(json_data, '$.queryType');
    v_result := v_result || v_type || ' ';

    v_columns := JSON_ARRAY_T(JSON_QUERY(json_data, '$.columns'));
    FOR i in 0 .. v_columns.get_size - 1 LOOP
        v_result := v_result || v_columns.get_string(i) || ' ';
    END LOOP;

    v_tables := JSON_ARRAY_T(JSON_QUERY(json_data, '$.tables'));
    v_result := v_result || 'FROM';
    FOR i in 0 .. v_tables.get_size - 1 LOOP
        v_result := v_result || ' ' || v_tables.get_string(i);
    END LOOP;
    v_result := v_result || ';';

    

    DBMS_OUTPUT.PUT_LINE(v_result);
    RETURN json_data;
END;
/

DECLARE
 result CLOB;
BEGIN
    result := build_dynamic_select_query('{
        "queryType": "SELECT",
        "columns": ["employee_id", "first_name"],
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
    }');
END;
/
