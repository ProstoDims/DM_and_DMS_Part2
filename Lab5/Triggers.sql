CREATE OR REPLACE TRIGGER trg_update_group_students_count
AFTER INSERT OR UPDATE OR DELETE ON students
FOR EACH ROW
BEGIN
    UPDATE groups
    SET students_count = (
        SELECT COUNT(*)
        FROM students
        WHERE group_id = COALESCE(:NEW.group_id, :OLD.group_id)
    )
    WHERE id = COALESCE(:NEW.group_id, :OLD.group_id);
END;
/

CREATE OR REPLACE TRIGGER trg_update_faculty_students_count
AFTER INSERT OR UPDATE OR DELETE ON students
FOR EACH ROW
BEGIN
    UPDATE faculties
    SET students_count = (
        SELECT COUNT(s.id)
        FROM students s
        JOIN groups g ON s.group_id = g.id
        WHERE g.faculty_id = (
            SELECT faculty_id
            FROM groups
            WHERE id = COALESCE(:NEW.group_id, :OLD.group_id)
        )
    )
    WHERE id = (
        SELECT faculty_id
        FROM groups
        WHERE id = COALESCE(:NEW.group_id, :OLD.group_id)
    );
END;
/

CREATE OR REPLACE TRIGGER trg_update_faculty_groups_count
AFTER INSERT OR UPDATE OR DELETE ON groups
FOR EACH ROW
BEGIN
    UPDATE faculties
    SET groups_count = (
        SELECT COUNT(*)
        FROM groups
        WHERE faculty_id = COALESCE(:NEW.faculty_id, :OLD.faculty_id)
    )
    WHERE id = COALESCE(:NEW.faculty_id, :OLD.faculty_id);
END;
/