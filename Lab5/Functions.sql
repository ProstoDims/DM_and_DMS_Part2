CREATE OR REPLACE PACKAGE rollback_pkg AS
    PROCEDURE rollback_changes(p_timestamp TIMESTAMP);

    PROCEDURE rollback_changes(p_milliseconds NUMBER);
END rollback_pkg;
/

CREATE OR REPLACE PACKAGE BODY rollback_pkg AS
    PROCEDURE perform_rollback(p_timestamp TIMESTAMP) IS
    BEGIN
        UPDATE triggers_state SET is_enabled = 0;
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


CREATE OR REPLACE PROCEDURE generate_report(p_start_time TIMESTAMP DEFAULT NULL) IS
    v_start_time TIMESTAMP;
    v_html CLOB;
    v_file UTL_FILE.FILE_TYPE;
BEGIN
    IF p_start_time IS NULL THEN
        SELECT NVL(MAX(last_time), TO_TIMESTAMP('1970-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS'))
        INTO v_start_time
        FROM last_report_time;
    ELSE
        v_start_time := p_start_time;
    END IF;

    v_html := '<html>' || CHR(10) ||
              '<head><title>Отчет об изменениях</title></head>' || CHR(10) ||
              '<body><h1>Отчет об изменениях</h1>' || CHR(10) ||
              '<p>Отчет с ' || TO_CHAR(v_start_time, 'YYYY-MM-DD HH24:MI:SS') ||
              ' по ' || TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') || '</p>' || CHR(10) ||
              '<table border="1"><tr><th>Таблица</th><th>INSERT</th><th>UPDATE</th><th>DELETE</th></tr>';

    FOR rec IN (
        SELECT 'faculties_log' AS table_name, 
               SUM(CASE WHEN action_type = 'INSERT' THEN 1 ELSE 0 END) AS insert_count,
               SUM(CASE WHEN action_type = 'UPDATE' THEN 1 ELSE 0 END) AS update_count,
               SUM(CASE WHEN action_type = 'DELETE' THEN 1 ELSE 0 END) AS delete_count
        FROM faculties_log
        WHERE timestamp > v_start_time
        UNION ALL
        SELECT 'specialties_log' AS table_name, 
               SUM(CASE WHEN action_type = 'INSERT' THEN 1 ELSE 0 END) AS insert_count,
               SUM(CASE WHEN action_type = 'UPDATE' THEN 1 ELSE 0 END) AS update_count,
               SUM(CASE WHEN action_type = 'DELETE' THEN 1 ELSE 0 END) AS delete_count
        FROM specialties_log
        WHERE timestamp > v_start_time
        UNION ALL
        SELECT 'groups_log' AS table_name, 
               SUM(CASE WHEN action_type = 'INSERT' THEN 1 ELSE 0 END) AS insert_count,
               SUM(CASE WHEN action_type = 'UPDATE' THEN 1 ELSE 0 END) AS update_count,
               SUM(CASE WHEN action_type = 'DELETE' THEN 1 ELSE 0 END) AS delete_count
        FROM groups_log
        WHERE timestamp > v_start_time
        UNION ALL
        SELECT 'students_log' AS table_name, 
               SUM(CASE WHEN action_type = 'INSERT' THEN 1 ELSE 0 END) AS insert_count,
               SUM(CASE WHEN action_type = 'UPDATE' THEN 1 ELSE 0 END) AS update_count,
               SUM(CASE WHEN action_type = 'DELETE' THEN 1 ELSE 0 END) AS delete_count
        FROM students_log
        WHERE timestamp > v_start_time
    ) LOOP
        v_html := v_html || '<tr><td>' || rec.table_name || '</td><td>' ||
                  rec.insert_count || '</td><td>' || rec.update_count || '</td><td>' ||
                  rec.delete_count || '</td></tr>' || CHR(10);
    END LOOP;

    v_html := v_html || '</table></body></html>' || CHR(10);

    v_file := UTL_FILE.FOPEN('REPORT_DIR', 'report.html', 'W');
    UTL_FILE.PUT_LINE(v_file, v_html);
    UTL_FILE.FCLOSE(v_file);

    INSERT INTO last_report_time (last_time) VALUES (SYSTIMESTAMP);
END;
/
