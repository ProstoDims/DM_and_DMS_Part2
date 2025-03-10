CREATE OR REPLACE FUNCTION build_dynamic_select_query(json_data IN CLOB) RETURN CLOB IS
    v_type         VARCHAR2(100);
    v_columns      JSON_ARRAY_T;
    v_tables       JSON_ARRAY_T;
    v_joins        JSON_ARRAY_T;
    v_filters      JSON_ARRAY_T;
    v_orders       JSON_ARRAY_T;
    v_result       CLOB;
    v_temp         VARCHAR2(4000);
    v_operator     VARCHAR2(20);
    v_value        VARCHAR2(4000);
    v_subquery     CLOB;
    v_filter_obj   JSON_OBJECT_T;
BEGIN
    v_result := '';

    v_type := JSON_VALUE(json_data, '$.queryType');
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
            v_result := v_result || CHR(10);
        END IF;
    END IF;

    v_temp := JSON_QUERY(json_data, '$.orderBy' RETURNING CLOB);
    IF v_temp IS NOT NULL AND v_temp != '[]' THEN
        v_orders := JSON_ARRAY_T(v_temp);
        IF v_orders.get_size > 0 THEN
            v_result := v_result || 'ORDER BY ';
            FOR i IN 0 .. v_orders.get_size - 1 LOOP
                IF i > 0 THEN
                    v_result := v_result || ', ';
                END IF;
                v_temp := JSON_VALUE(v_orders.get(i).to_string(), '$.column') || ' ' ||
                          JSON_VALUE(v_orders.get(i).to_string(), '$.direction');
                v_result := v_result || v_temp;
            END LOOP;
            v_result := v_result || CHR(10);
        END IF;
    END IF;

    v_result := v_result;

    RETURN v_result;
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
                            "value": "1700"
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
    }');

    DBMS_OUTPUT.PUT_LINE(result);
END;
/