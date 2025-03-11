CREATE OR REPLACE TRIGGER trg_update_group_students_count
FOR INSERT OR UPDATE OR DELETE ON students
COMPOUND TRIGGER
    v_group_id NUMBER;

    BEFORE EACH ROW IS
    BEGIN
        v_group_id := :NEW.group_id;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        UPDATE groups
        SET students_count = (
            SELECT COUNT(*)
            FROM students
            WHERE group_id = v_group_id
        )
        WHERE id = v_group_id;
    END AFTER STATEMENT;

END trg_update_group_students_count;
/

CREATE OR REPLACE TRIGGER trg_update_specialty_groups_count
FOR INSERT OR UPDATE OR DELETE ON groups
COMPOUND TRIGGER
    v_specialty_id NUMBER;

    BEFORE EACH ROW IS
    BEGIN
        v_specialty_id := :NEW.specialty_id;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        UPDATE specialties
        SET groups_count = (
            SELECT COUNT(*)
            FROM groups
            WHERE specialty_id = v_specialty_id
        )
        WHERE id = v_specialty_id;
    END AFTER STATEMENT;

END trg_update_specialty_groups_count;
/

CREATE OR REPLACE TRIGGER trg_update_faculty_specialties_count
FOR INSERT OR UPDATE OR DELETE ON specialties
COMPOUND TRIGGER
    v_faculty_id NUMBER;

    BEFORE EACH ROW IS
    BEGIN
        v_faculty_id := :NEW.faculty_id;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        UPDATE faculties
        SET specialties_count = (
            SELECT COUNT(*)
            FROM specialties
            WHERE faculty_id = v_faculty_id
        )
        WHERE id = v_faculty_id;
    END AFTER STATEMENT;

END trg_update_faculty_specialties_count;
/

DROP TRIGGER trg_update_group_students_count;
DROP TRIGGER trg_update_specialty_groups_count;
DROP TRIGGER trg_update_faculty_specialties_count;