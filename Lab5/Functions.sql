CREATE OR REPLACE PACKAGE rollback_pkg AS
    PROCEDURE rollback_changes(p_timestamp TIMESTAMP);

    PROCEDURE rollback_changes(p_milliseconds NUMBER);
END rollback_pkg;
/

CREATE OR REPLACE PACKAGE BODY rollback_pkg AS
    PROCEDURE perform_rollback(p_timestamp TIMESTAMP) IS
    BEGIN
        UPDATE triggers_state SET is_enabled = 0;
        DBMS_OUTPUT.PUT_LINE(p_timestamp);
        FOR rec IN (
            SELECT * FROM students_log
            WHERE timestamp > p_timestamp
            ORDER BY timestamp DESC
        ) LOOP
            IF rec.action_type = 'INSERT' THEN
                DELETE FROM students WHERE id = rec.student_id;
            ELSIF rec.action_type = 'UPDATE' THEN
                UPDATE students
                SET first_name = rec.old_first_name,
                    last_name = rec.old_last_name,
                    group_id = rec.old_group_id
                WHERE id = rec.student_id;
            ELSIF rec.action_type = 'DELETE' THEN
                INSERT INTO students (id, first_name, last_name, group_id, created_at)
                VALUES (rec.student_id, rec.old_first_name, rec.old_last_name, rec.old_group_id, rec.timestamp);
            END IF;

            DELETE FROM students_log WHERE log_id = rec.log_id;
        END LOOP;

        FOR rec IN (
            SELECT * FROM groups_log
            WHERE timestamp > p_timestamp
            ORDER BY timestamp DESC
        ) LOOP
            IF rec.action_type = 'INSERT' THEN
                DELETE FROM groups WHERE id = rec.group_id;
            ELSIF rec.action_type = 'UPDATE' THEN
                UPDATE groups
                SET name = rec.old_name,
                    specialty_id = rec.old_specialty_id,
                    students_count = rec.old_students_count
                WHERE id = rec.group_id;
            ELSIF rec.action_type = 'DELETE' THEN
                INSERT INTO groups (id, name, specialty_id, students_count, created_at)
                VALUES (rec.group_id, rec.old_name, rec.old_specialty_id, rec.old_students_count, rec.timestamp);
            END IF;

            DELETE FROM groups_log WHERE log_id = rec.log_id;
        END LOOP;

        FOR rec IN (
            SELECT * FROM specialties_log
            WHERE timestamp > p_timestamp
            ORDER BY timestamp DESC
        ) LOOP
            IF rec.action_type = 'INSERT' THEN
                DELETE FROM specialties WHERE id = rec.specialty_id;
            ELSIF rec.action_type = 'UPDATE' THEN
                UPDATE specialties
                SET name = rec.old_name,
                    abbreviation = rec.old_abbreviation,
                    faculty_id = rec.old_faculty_id,
                    groups_count = rec.old_groups_count
                WHERE id = rec.specialty_id;
            ELSIF rec.action_type = 'DELETE' THEN
                INSERT INTO specialties (id, name, abbreviation, faculty_id, groups_count, created_at)
                VALUES (rec.specialty_id, rec.old_name, rec.old_abbreviation, rec.old_faculty_id, rec.old_groups_count, rec.timestamp);
            END IF;

            DELETE FROM specialties_log WHERE log_id = rec.log_id;
        END LOOP;

        FOR rec IN (
            SELECT * FROM faculties_log
            WHERE timestamp > p_timestamp
            ORDER BY timestamp DESC
        ) LOOP
            IF rec.action_type = 'INSERT' THEN
                DELETE FROM faculties WHERE id = rec.faculty_id;
            ELSIF rec.action_type = 'UPDATE' THEN
                UPDATE faculties
                SET name = rec.old_name,
                    abbreviation = rec.old_abbreviation,
                    specialties_count = rec.old_specialties_count
                WHERE id = rec.faculty_id;
            ELSIF rec.action_type = 'DELETE' THEN
                INSERT INTO faculties (id, name, abbreviation, specialties_count, created_at)
                VALUES (rec.faculty_id, rec.old_name, rec.old_abbreviation, rec.old_specialties_count, rec.timestamp);
            END IF;

            DELETE FROM faculties_log WHERE log_id = rec.log_id;
        END LOOP;

        UPDATE triggers_state SET is_enabled = 1;
    END perform_rollback;

    PROCEDURE rollback_changes(p_timestamp TIMESTAMP) IS
    BEGIN
        perform_rollback(p_timestamp);
    END rollback_changes;

    PROCEDURE rollback_changes(p_milliseconds NUMBER) IS
        v_timestamp TIMESTAMP;
    BEGIN
        v_timestamp := SYSTIMESTAMP - NUMTODSINTERVAL(p_milliseconds / 1000, 'SECOND');
        perform_rollback(v_timestamp);
    END rollback_changes;
END rollback_pkg;
/