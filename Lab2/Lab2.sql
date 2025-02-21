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
BEGIN

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
BEFORE DELETE ON GROUPS
FOR EACH ROW
BEGIN
    DELETE FROM STUDENTS WHERE GROUP_ID = :OLD.ID;
END;