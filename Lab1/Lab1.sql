CREATE TABLE MyTable (
    id NUMBER PRIMARY KEY,
    val NUMBER
);


BEGIN
    FOR i IN 1..10000 LOOP
        INSERT INTO MyTable (id, val) VALUES (i, TRUNC(DBMS_RANDOM.VALUE(1, 10000)));
    END LOOP;
    COMMIT;
END;

CREATE OR REPLACE FUNCTION Check_Even_Odd
RETURN VARCHAR2 IS
    even_count NUMBER;
    odd_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO even_count FROM MyTable WHERE MOD(val, 2) = 0;
    SELECT COUNT(*) INTO odd_count FROM MyTable WHERE MOD(val, 2) = 1;
    
    IF even_count > odd_count THEN
        RETURN 'TRUE';
    ELSIF even_count < odd_count THEN
        RETURN 'FALSE';
    ELSE
        RETURN 'EQUAL';
    END IF;
END;

CREATE OR REPLACE FUNCTION Generate_Insert_Statement(p_id NUMBER)
RETURN VARCHAR2 IS
    v_val NUMBER;
    v_stmt VARCHAR2(500);
    v_max_id NUMBER;
BEGIN
    IF p_id < 0 THEN
        RETURN 'Ошибка: id не может быть отрицательным';
    END IF;

    BEGIN
        SELECT val INTO v_val
        FROM MyTable
        WHERE id = p_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'Ошибка: Запись с id = ' || p_id || ' не найдена';
        WHEN OTHERS THEN
            RETURN 'Ошибка: Произошла ошибка при запросе данных для id = ' || p_id;
    END;

    SELECT MAX(id) + 1 INTO v_max_id FROM MyTable;

    v_stmt := 'INSERT INTO MyTable (id, val) VALUES (' || v_max_id || ', ' || v_val || ');';

    RETURN v_stmt;
END;


CREATE OR REPLACE PROCEDURE Insert_MyTable(p_val NUMBER) IS
    v_new_id NUMBER;
BEGIN
    SELECT NVL(MAX(id), 0) + 1 INTO v_new_id FROM MyTable;
    INSERT INTO MyTable (id, val) VALUES (v_new_id, p_val);
    COMMIT;
END;
/


CREATE OR REPLACE PROCEDURE Update_MyTable(p_id NUMBER, p_val NUMBER) IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM MyTable WHERE id = p_id;

    IF v_count > 0 THEN
        UPDATE MyTable SET val = p_val WHERE id = p_id;
        COMMIT;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Нет записей с id - ' || p_id);
    END IF;
END;

CREATE OR REPLACE PROCEDURE Delete_MyTable(p_id NUMBER) IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM MyTable WHERE id = p_id;

    IF v_count > 0 THEN
        DELETE FROM MyTable WHERE id = p_id;
        COMMIT;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Нет записи с id - ' || p_id);
    END IF;
END;

CREATE OR REPLACE FUNCTION Calculate_Annual_Reward(monthly_salary NUMBER, annual_bonus_percent NUMBER)
RETURN NUMBER IS
    v_bonus_rate NUMBER;
BEGIN
    IF monthly_salary < 0 OR annual_bonus_percent < 0 THEN
        DBMS_OUTPUT.PUT_LINE('Значения не могут быть отрицательными');
    END IF;
    
    v_bonus_rate := annual_bonus_percent / 100;
    RETURN (1 + v_bonus_rate) * 12 * monthly_salary;
END;
