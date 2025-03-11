SELECT * FROM FACULTIES;

INSERT INTO FACULTIES(NAME, ABBREVIATION) VALUES('Факультет компьютерных систем и сетей', 'ФКСиС');
INSERT INTO FACULTIES(NAME, ABBREVIATION) VALUES('Факультет компьютерного проектирования', 'ФКП');
INSERT INTO FACULTIES(NAME, ABBREVIATION) VALUES('Факультет информационных технологий и управления', 'ФИТУ');
INSERT INTO FACULTIES(NAME, ABBREVIATION) VALUES('Факультет радиотехники и электроники', 'ФРЭ');
INSERT INTO FACULTIES(NAME, ABBREVIATION) VALUES('Факультет информационной безопасности', 'ФИБ');
INSERT INTO FACULTIES(NAME, ABBREVIATION) VALUES('Инженерно-экономический факультет', 'ИЭФ');
INSERT INTO FACULTIES(NAME, ABBREVIATION) VALUES('Военный факультет', 'ВФ');


SELECT * FROM SPECIALTIES;

INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Информатика и технологии программирования','ИиТП',1);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Компьютерная инженерия','КИ',1);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Программная инженерия','ПИ',1);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Информационные системы и технологии','ИСиТ',2);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Компьютерная инженирея','КИ',2);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Программная инженирея','ПИ',2);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Электронные системы и технологии','ЭСиТ',2);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Электронное машиностроение','ЭМ',2);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Информационные системы и технологии','ИСиТ',3);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Искусственный интелект','ИТ',3);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Киберфизические системы','КС',3);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Системы управления информацией','СУИ',3);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Электронные системы и технологии','ЭСиТ',3);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Информационные и управляющие системы физических установок','ИиУСФУ',4);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Инженерно-педагогическая деятельность','ИПД',4);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Микро- и наноэлектроника','МиН',4);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Нанотехнологии и наноматериалы','НиН',4);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Радиосистемы и радиотехнологии','РиР',4);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Информационная безопасность','ИБ',5);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Системы и сети инфокоммуникаций','СиСИ',5);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Сверхвысокочастотные системы','СС',5);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Информационные системы и технологии','ИСиТ',6);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Цифровой маркетинг','ЦМ',6);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Электронная экономика','ЭЭ',6);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Радиосистемы и радиотехнологии','РиР',7);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Компьютерная инженерия','КИ',7);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Системы и сети инфокоммуникаций','СиСИ',7);
INSERT INTO SPECIALTIES(NAME, ABBREVIATION, FACULTY_ID) VALUES('Информационная безопасность','ИБ',7);


SELECT * FROM GROUPS;

INSERT INTO groups (name, specialty_id) VALUES ('101', 1);
INSERT INTO groups (name, specialty_id) VALUES ('201', 2);
INSERT INTO groups (name, specialty_id) VALUES ('301', 3);
INSERT INTO groups (name, specialty_id) VALUES ('401', 4);
INSERT INTO groups (name, specialty_id) VALUES ('501', 5);
INSERT INTO groups (name, specialty_id) VALUES ('601', 6);
INSERT INTO groups (name, specialty_id) VALUES ('701', 7);
INSERT INTO groups (name, specialty_id) VALUES ('801', 8);
INSERT INTO groups (name, specialty_id) VALUES ('901', 9);
INSERT INTO groups (name, specialty_id) VALUES ('1001', 10);
INSERT INTO groups (name, specialty_id) VALUES ('1101', 11);
INSERT INTO groups (name, specialty_id) VALUES ('1201', 12);
INSERT INTO groups (name, specialty_id) VALUES ('1301', 13);
INSERT INTO groups (name, specialty_id) VALUES ('1401', 14);
INSERT INTO groups (name, specialty_id) VALUES ('1501', 15);
INSERT INTO groups (name, specialty_id) VALUES ('1601', 16);
INSERT INTO groups (name, specialty_id) VALUES ('1701', 17);
INSERT INTO groups (name, specialty_id) VALUES ('1801', 18);
INSERT INTO groups (name, specialty_id) VALUES ('1901', 19);
INSERT INTO groups (name, specialty_id) VALUES ('2001', 20);
INSERT INTO groups (name, specialty_id) VALUES ('2101', 21);
INSERT INTO groups (name, specialty_id) VALUES ('2201', 22);
INSERT INTO groups (name, specialty_id) VALUES ('2301', 23);
INSERT INTO groups (name, specialty_id) VALUES ('2401', 24);
INSERT INTO groups (name, specialty_id) VALUES ('2501', 25);
INSERT INTO groups (name, specialty_id) VALUES ('2601', 26);
INSERT INTO groups (name, specialty_id) VALUES ('2701', 27);
INSERT INTO groups (name, specialty_id) VALUES ('2801', 28);


SELECT * FROM STUDENTS;

INSERT INTO students (first_name, last_name, group_id) VALUES ('Иван', 'Иванов', 1);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Петр', 'Петров', 2);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Алексей', 'Сидоров', 3);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Мария', 'Кузнецова', 4);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Ольга', 'Васильева', 5);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Анна', 'Смирнова', 6);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Дмитрий', 'Попов', 7);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Сергей', 'Лебедев', 8);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Елена', 'Козлова', 9);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Наталья', 'Новикова', 10);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Александр', 'Морозов', 11);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Владимир', 'Волков', 12);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Екатерина', 'Павлова', 13);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Татьяна', 'Семенова', 14);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Ирина', 'Голубева', 15);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Николай', 'Виноградов', 16);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Андрей', 'Богданов', 17);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Виктор', 'Воробьев', 18);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Юлия', 'Федорова', 19);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Людмила', 'Михайлова', 20);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Артем', 'Белов', 21);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Галина', 'Титова', 22);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Павел', 'Комаров', 23);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Светлана', 'Орлова', 24);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Валентина', 'Андреева', 25);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Константин', 'Макаров', 26);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Евгений', 'Николаев', 27);
INSERT INTO students (first_name, last_name, group_id) VALUES ('Анастасия', 'Захарова', 28);
