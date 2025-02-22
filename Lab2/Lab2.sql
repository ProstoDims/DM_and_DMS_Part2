CREATE TABLE GROUPS (
    ID NUMBER PRIMARY KEY,
    NAME VARCHAR2(100),
    C_VAL NUMBER DEFAULT 0
);

CREATE TABLE STUDENTS (
    ID NUMBER PRIMARY KEY,
    NAME VARCHAR2(100),
    GROUP_ID NUMBER
);

CREATE SEQUENCE group_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE students_seq START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE TRIGGER groups_before_insert
BEFORE INSERT ON GROUPS
FOR EACH ROW
DECLARE
    v_count_name INTEGER;
BEGIN

    SELECT COUNT(*)
    INTO v_count_name
    FROM GROUPS
    WHERE NAME = :NEW.NAME;

    IF v_count_name > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Group name already exists');
    END IF;

    IF :NEW.ID IS NULL THEN
        SELECT group_seq.NEXTVAL INTO :NEW.ID FROM DUAL;
    ELSE
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count FROM GROUPS WHERE ID=:NEW.ID;
            IF v_count > 0 THEN
                SELECT group_seq.NEXTVAL INTO :NEW.ID FROM DUAL;
            ELSE
                NULL;
            END IF;
        END;
    END IF;
END;

CREATE OR REPLACE TRIGGER students_before_insert
BEFORE INSERT ON STUDENTS
FOR EACH ROW
DECLARE
    v_group_count NUMBER;
    v_trigger_disabled NUMBER;

BEGIN

    SELECT trigger_disabled INTO v_trigger_disabled FROM trigger_control WHERE trigger_name = 'students_before_insert';
    IF v_trigger_disabled = 1 THEN
        RETURN;
    END IF;

    IF :NEW.GROUP_ID IS NOT NULL THEN
        SELECT COUNT(*) INTO v_group_count FROM GROUPS WHERE GROUPS.ID = :NEW.GROUP_ID;
        IF v_group_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Group with id GROUP_ID not found');
        END IF;

    ELSE
        RAISE_APPLICATION_ERROR(-20001, 'Group Id is required');
    END IF;

    IF :NEW.ID IS NULL THEN
        SELECT students_seq.NEXTVAL INTO :NEW.ID FROM DUAL;
    ELSE
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count FROM STUDENTS WHERE ID=:NEW.ID;
            IF v_count > 0 THEN
                SELECT students_seq.NEXTVAL INTO :NEW.ID FROM DUAL;
            ELSE
                NULL;
            END IF;
        END;
    END IF;
END;

CREATE OR REPLACE TRIGGER groups_before_delete
AFTER DELETE ON GROUPS
FOR EACH ROW
BEGIN
    UPDATE trigger_control SET trigger_disabled = 1 WHERE trigger_name = 'update_c_val';
    DELETE FROM STUDENTS WHERE GROUP_ID = :OLD.ID;
    UPDATE trigger_control SET trigger_disabled = 0 WHERE trigger_name = 'update_c_val';
END;


CREATE SEQUENCE students_log_seq START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE TABLE STUDENTS_LOG (
    LOG_ID NUMBER PRIMARY KEY,
    ACTION_TYPE VARCHAR2(10),
    GROUP_NAME VARCHAR2(100);
    STUDENT_ID NUMBER,
    NAME VARCHAR2(100),
    GROUP_ID NUMBER,
    OLD_NAME VARCHAR2(100),
    OLD_GROUP_ID NUMBER,
    TIMESTAMP TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE OR REPLACE TRIGGER students_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON STUDENTS
FOR EACH ROW
DECLARE
    v_action_type VARCHAR2(10);
    v_trigger_disabled NUMBER;
    v_group_name VARCHAR2(100);
BEGIN
    SELECT trigger_disabled INTO v_trigger_disabled FROM trigger_control WHERE trigger_name = 'students_audit_trigger';

    IF v_trigger_disabled = 1 THEN
        RETURN;
    END IF;

    BEGIN
        IF INSERTING OR UPDATING THEN
            SELECT NAME INTO v_group_name
            FROM GROUPS
            WHERE ID = :NEW.GROUP_ID;
        ELSIF DELETING THEN
            BEGIN
            SELECT GROUP_NAME INTO v_group_name
            FROM (
                SELECT GROUP_NAME
                FROM STUDENTS_LOG
                WHERE STUDENT_ID = :OLD.ID
                ORDER BY LOG_ID DESC
            )
            WHERE ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_group_name := NULL; 
            END;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_group_name := NULL; 
    END;

    IF INSERTING THEN
        v_action_type := 'INSERT';
        INSERT INTO STUDENTS_LOG (LOG_ID, ACTION_TYPE, STUDENT_ID, NAME, GROUP_ID, GROUP_NAME, TIMESTAMP)
        VALUES (students_log_seq.NEXTVAL, v_action_type, :NEW.ID, :NEW.NAME, :NEW.GROUP_ID, v_group_name, SYSTIMESTAMP);
    ELSIF UPDATING THEN
        v_action_type := 'UPDATE';
        INSERT INTO STUDENTS_LOG (LOG_ID, ACTION_TYPE, STUDENT_ID, NAME, GROUP_ID, GROUP_NAME, OLD_NAME, OLD_GROUP_ID, TIMESTAMP)
        VALUES (students_log_seq.NEXTVAL, v_action_type, :NEW.ID, :NEW.NAME, :NEW.GROUP_ID, v_group_name, :OLD.NAME, :OLD.GROUP_ID, SYSTIMESTAMP);
    ELSIF DELETING THEN
        v_action_type := 'DELETE';
        INSERT INTO STUDENTS_LOG (LOG_ID, ACTION_TYPE, STUDENT_ID, NAME, GROUP_ID, GROUP_NAME, OLD_NAME, OLD_GROUP_ID, TIMESTAMP)
        VALUES (students_log_seq.NEXTVAL, v_action_type, :OLD.ID, :OLD.NAME, :OLD.GROUP_ID, v_group_name, :OLD.NAME, :OLD.GROUP_ID, SYSTIMESTAMP);
    END IF;
END;


CREATE OR REPLACE TRIGGER update_c_val
AFTER INSERT OR DELETE OR UPDATE ON STUDENTS
DECLARE
    v_count NUMBER;
    v_trigger_disabled NUMBER;
BEGIN
    SELECT trigger_disabled INTO v_trigger_disabled FROM trigger_control WHERE trigger_name = 'update_c_val';
    IF v_trigger_disabled = 1 THEN
        RETURN;
    END IF;

    FOR rec IN (SELECT GROUP_ID FROM STUDENTS GROUP BY GROUP_ID) LOOP
        SELECT COUNT(*) INTO v_count
        FROM STUDENTS
        WHERE GROUP_ID = rec.GROUP_ID;

        UPDATE GROUPS
        SET C_VAL = v_count
        WHERE ID = rec.GROUP_ID;
    END LOOP;
END;

CREATE OR REPLACE PROCEDURE restore_students(
    p_log_id IN NUMBER
) IS
    v_group_id NUMBER;
BEGIN
    UPDATE trigger_control SET trigger_disabled = 1 WHERE TRIGGER_NAME = 'students_audit_trigger';
    UPDATE trigger_control SET trigger_disabled = 1 WHERE TRIGGER_NAME = 'students_before_insert';
    DELETE FROM STUDENTS;

    FOR rec IN (
        SELECT * 
        FROM STUDENTS_LOG
        WHERE LOG_ID <= p_log_id
        ORDER BY LOG_ID ASC 
    ) LOOP
        BEGIN
            SELECT ID INTO v_group_id
            FROM GROUPS
            WHERE NAME = rec.GROUP_NAME;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_group_id := group_seq.NEXTVAL;
                INSERT INTO GROUPS (ID, NAME)
                VALUES (v_group_id, rec.GROUP_NAME);
        END;

        IF rec.ACTION_TYPE = 'INSERT' THEN
            INSERT INTO STUDENTS (ID, NAME, GROUP_ID)
            VALUES (rec.STUDENT_ID, rec.NAME, v_group_id);
        ELSIF rec.ACTION_TYPE = 'DELETE' THEN
            DELETE FROM STUDENTS WHERE ID = rec.STUDENT_ID;
        ELSIF rec.ACTION_TYPE = 'UPDATE' THEN
            UPDATE STUDENTS
            SET NAME = rec.NAME, GROUP_ID = v_group_id
            WHERE ID = rec.STUDENT_ID;
        END IF;
    END LOOP;

    COMMIT;

    UPDATE trigger_control SET trigger_disabled = 0 WHERE TRIGGER_NAME = 'students_audit_trigger';
    UPDATE trigger_control SET trigger_disabled = 0 WHERE TRIGGER_NAME = 'students_before_insert';
END;

CREATE TABLE trigger_control (
    trigger_name VARCHAR2(100) PRIMARY KEY,
    trigger_disabled NUMBER(1) DEFAULT 0
);

INSERT INTO trigger_control (trigger_name, trigger_disabled) VALUES ('update_c_val', 0);
INSERT INTO trigger_control (trigger_name, trigger_disabled) VALUES ('students_audit_trigger', 0);
INSERT INTO trigger_control (trigger_name, trigger_disabled) VALUES ('students_before_insert', 0);

