CREATE OR REPLACE TRIGGER trg_update_group_students_count
FOR INSERT OR UPDATE OR DELETE ON students
COMPOUND TRIGGER
    v_group_id NUMBER;
    v_is_enabled NUMBER;

    BEFORE EACH ROW IS
    BEGIN
        SELECT is_enabled INTO v_is_enabled
        FROM triggers_state
        WHERE trigger_name = 'trg_update_group_students_count';

        IF v_is_enabled = 1 THEN
            v_group_id := :NEW.group_id;

            UPDATE triggers_state
            SET is_enabled = 0
            WHERE trigger_name IN ('trg_update_specialty_groups_count', 'trg_update_faculty_specialties_count');
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF v_is_enabled = 1 THEN
            UPDATE groups
            SET students_count = (
                SELECT COUNT(*)
                FROM students
                WHERE group_id = v_group_id
            )
            WHERE id = v_group_id;

            UPDATE triggers_state
            SET is_enabled = 1
            WHERE trigger_name IN ('trg_update_specialty_groups_count', 'trg_update_faculty_specialties_count');
        END IF;
    END AFTER STATEMENT;

END trg_update_group_students_count;
/


CREATE OR REPLACE TRIGGER trg_update_specialty_groups_count
FOR INSERT OR UPDATE OR DELETE ON groups
COMPOUND TRIGGER
    v_specialty_id NUMBER;
    v_is_enabled NUMBER;

    BEFORE EACH ROW IS
    BEGIN
        SELECT is_enabled INTO v_is_enabled
        FROM triggers_state
        WHERE trigger_name = 'trg_update_specialty_groups_count';

        IF v_is_enabled = 1 THEN
            v_specialty_id := :NEW.specialty_id;

            UPDATE triggers_state
            SET is_enabled = 0
            WHERE trigger_name = 'trg_update_faculty_specialties_count';
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF v_is_enabled = 1 THEN
            UPDATE specialties
            SET groups_count = (
                SELECT COUNT(*)
                FROM groups
                WHERE specialty_id = v_specialty_id
            )
            WHERE id = v_specialty_id;

            UPDATE triggers_state
            SET is_enabled = 1
            WHERE trigger_name = 'trg_update_faculty_specialties_count';
        END IF;
    END AFTER STATEMENT;

END trg_update_specialty_groups_count;
/


CREATE OR REPLACE TRIGGER trg_update_faculty_specialties_count
FOR INSERT OR UPDATE OR DELETE ON specialties
COMPOUND TRIGGER
    v_faculty_id NUMBER;
    v_is_enabled NUMBER;

    BEFORE EACH ROW IS
    BEGIN
        SELECT is_enabled INTO v_is_enabled
        FROM triggers_state
        WHERE trigger_name = 'trg_update_faculty_specialties_count';

        IF v_is_enabled = 1 THEN
            v_faculty_id := :NEW.faculty_id;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF v_is_enabled = 1 THEN
            UPDATE faculties
            SET specialties_count = (
                SELECT COUNT(*)
                FROM specialties
                WHERE faculty_id = v_faculty_id
            )
            WHERE id = v_faculty_id;
        END IF;
    END AFTER STATEMENT;

END trg_update_faculty_specialties_count;
/


DROP TRIGGER trg_update_group_students_count;
DROP TRIGGER trg_update_specialty_groups_count;
DROP TRIGGER trg_update_faculty_specialties_count;


CREATE OR REPLACE TRIGGER faculties_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON faculties
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO faculties_log (action_type, faculty_id, new_name, new_abbreviation, new_specialties_count)
        VALUES ('INSERT', :NEW.id, :NEW.name, :NEW.abbreviation, :NEW.specialties_count);
    ELSIF UPDATING THEN
        INSERT INTO faculties_log (action_type, faculty_id, old_name, new_name, old_abbreviation, new_abbreviation, old_specialties_count, new_specialties_count)
        VALUES ('UPDATE', :NEW.id, :OLD.name, :NEW.name, :OLD.abbreviation, :NEW.abbreviation, :OLD.specialties_count, :NEW.specialties_count);
    ELSIF DELETING THEN
        INSERT INTO faculties_log (action_type, faculty_id, old_name, old_abbreviation, old_specialties_count)
        VALUES ('DELETE', :OLD.id, :OLD.name, :OLD.abbreviation, :OLD.specialties_count);
    END IF;
END;
/


CREATE OR REPLACE TRIGGER specialties_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON specialties
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO specialties_log (action_type, specialty_id, new_name, new_abbreviation, new_faculty_id, new_groups_count)
        VALUES ('INSERT', :NEW.id, :NEW.name, :NEW.abbreviation, :NEW.faculty_id, :NEW.groups_count);
    ELSIF UPDATING THEN
        INSERT INTO specialties_log (action_type, specialty_id, old_name, new_name, old_abbreviation, new_abbreviation, old_faculty_id, new_faculty_id, old_groups_count, new_groups_count)
        VALUES ('UPDATE', :NEW.id, :OLD.name, :NEW.name, :OLD.abbreviation, :NEW.abbreviation, :OLD.faculty_id, :NEW.faculty_id, :OLD.groups_count, :NEW.groups_count);
    ELSIF DELETING THEN
        INSERT INTO specialties_log (action_type, specialty_id, old_name, old_abbreviation, old_faculty_id, old_groups_count)
        VALUES ('DELETE', :OLD.id, :OLD.name, :OLD.abbreviation, :OLD.faculty_id, :OLD.groups_count);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER groups_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON groups
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO groups_log (action_type, group_id, new_name, new_specialty_id, new_students_count)
        VALUES ('INSERT', :NEW.id, :NEW.name, :NEW.specialty_id, :NEW.students_count);
    ELSIF UPDATING THEN
        INSERT INTO groups_log (action_type, group_id, old_name, new_name, old_specialty_id, new_specialty_id, old_students_count, new_students_count)
        VALUES ('UPDATE', :NEW.id, :OLD.name, :NEW.name, :OLD.specialty_id, :NEW.specialty_id, :OLD.students_count, :NEW.students_count);
    ELSIF DELETING THEN
        INSERT INTO groups_log (action_type, group_id, old_name, old_specialty_id, old_students_count)
        VALUES ('DELETE', :OLD.id, :OLD.name, :OLD.specialty_id, :OLD.students_count);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER students_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON students
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO students_log (action_type, student_id, new_first_name, new_last_name, new_group_id)
        VALUES ('INSERT', :NEW.id, :NEW.first_name, :NEW.last_name, :NEW.group_id);
    ELSIF UPDATING THEN
        INSERT INTO students_log (action_type, student_id, old_first_name, new_first_name, old_last_name, new_last_name, old_group_id, new_group_id)
        VALUES ('UPDATE', :NEW.id, :OLD.first_name, :NEW.first_name, :OLD.last_name, :NEW.last_name, :OLD.group_id, :NEW.group_id);
    ELSIF DELETING THEN
        INSERT INTO students_log (action_type, student_id, old_first_name, old_last_name, old_group_id)
        VALUES ('DELETE', :OLD.id, :OLD.first_name, :OLD.last_name, :OLD.group_id);
    END IF;
END;
/


DROP TRIGGER faculties_audit_trigger;
DROP TRIGGER specialties_audit_trigger;
DROP TRIGGER groups_audit_trigger;
DROP TRIGGER students_audit_trigger;
