-- code to setup the db structure, should only be run once

DROP MATERIALIZED VIEW IF EXISTS section_changes;
DROP MATERIALIZED VIEW IF EXISTS course_changes;
DROP TABLE IF EXISTS timeslots;
DROP TABLE IF EXISTS enrollment;
DROP TABLE IF EXISTS sections;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS components;
DROP TABLE IF EXISTS subjects;

CREATE TABLE subjects (
    subject     VARCHAR(6)  PRIMARY KEY,
    faculty     VARCHAR(11) CHECK(faculty IN ('Math', 'Engineering', 'Arts', 'Science', 'Health', 'Environment'))
);
INSERT INTO subjects VALUES
('ACC', NULL),
('ACINTY', NULL),
('ACTSC', 'Math'),
('AE', 'Engineering'),
('AFM', NULL),
('AMATH', 'Math'),
('ANTH', NULL),
('APPLS', NULL),
('ARABIC', NULL),
('ARBUS', NULL),
('ARCH', 'Engineering'),
('ARTS', NULL),
('ASL', NULL),
('ASTRN', NULL),
('AVIA', NULL),
('BASE', NULL),
('BE', 'Engineering'),
('BET', NULL),
('BIOL', NULL),
('BLKST', NULL),
('BME', 'Engineering'),
('BUS', NULL),
('CC', NULL),
('CDNST', NULL),
('CFM', 'Math'),
('CHE', 'Engineering'),
('CHEM', NULL),
('CHINA', NULL),
('CI', NULL),
('CIVE', NULL),
('CLAS', NULL),
('CM', NULL),
('CMW', NULL),
('CO', 'Math'),
('COGSCI', NULL),
('COMM', 'Math'),
('COMMST', NULL),
('COOP', NULL),
('CROAT', NULL),
('CS', 'Math'),
('CT', NULL),
('CULT', NULL),
('DAC', NULL),
('DATSC', NULL),
('DEI', NULL),
('DEVP', NULL),
('DUTCH', NULL),
('EARTH', NULL),
('EASIA', NULL),
('ECDEV', NULL),
('ECE', 'Engineering'),
('ECON', NULL),
('EDMI', NULL),
('EMLS', NULL),
('ENBUS', NULL),
('ENGL', NULL),
('ENTR', NULL),
('ENVE', 'Engineering'),
('ENVS', NULL),
('ERS', NULL),
('EVST', NULL),
('FCIT', NULL),
('FILM', NULL),
('FINE', NULL),
('FR', NULL),
('GBDA', NULL),
('GC', NULL),
('GEMCC', NULL),
('GENE', 'Engineering'),
('GEOE', 'Engineering'),
('GEOG', NULL),
('GER', NULL),
('GERON', NULL),
('GESC', NULL),
('GGOV', NULL),
('GLST', NULL),
('GRK', NULL),
('GS', NULL),
('GSJ', NULL),
('HEALTH', NULL),
('HHUM', NULL),
('HIST', NULL),
('HLTH', NULL),
('HRM', NULL),
('HRTS', NULL),
('HUMSC', NULL),
('INDENT', NULL),
('INDEV', NULL),
('INDG', NULL),
('INNOV', NULL),
('INTEG', NULL),
('INTST', NULL),
('ITAL', NULL),
('ITALST', NULL),
('JAPAN', NULL),
('JS', NULL),
('KIN', NULL),
('KOREA', NULL),
('LANG', NULL),
('LAT', NULL),
('LS', NULL),
('MATBUS', 'Math'),
('MATH', 'Math'),
('ME', 'Engineering'),
('MEDVL', NULL),
('MGMT', NULL),
('MISC', NULL),
('MNS', 'Engineering'),
('MSE', 'Engineering'),
('MTE', 'Engineering'),
('MTHEL', 'Math'),
('MUSIC', NULL),
('NANO', NULL),
('NE', 'Engineering'),
('OLRD', NULL),
('OPTOM', NULL),
('PACS', NULL),
('PD', NULL),
('PDARCH', NULL),
('PDPHRM', NULL),
('PHARM', NULL),
('PHIL', NULL),
('PHYS', NULL),
('PLAN', NULL),
('PMATH', 'Math'),
('PS', NULL),
('PSCI', NULL),
('PSYCH', NULL),
('QIC', NULL),
('REC', NULL),
('REES', NULL),
('RELC', NULL),
('RS', NULL),
('RSCH', NULL),
('RUSS', NULL),
('SCBUS', NULL),
('SCI', NULL),
('SDS', NULL),
('SE', 'Engineering'),
('SEQ', NULL),
('SFM', NULL),
('SI', NULL),
('SMF', NULL),
('SOC', NULL),
('SOCWK', NULL),
('SPAN', NULL),
('STAT', 'Math'),
('STV', NULL),
('SUSM', NULL),
('SWK', NULL),
('SWREN', NULL),
('SYDE', 'Engineering'),
('TAX', NULL),
('THPERF', NULL),
('TN', NULL),
('TPM', NULL),
('TS', NULL),
('UCR', NULL),
('UN', NULL),
('UNDC', NULL),
('UNIV', NULL),
('UU', NULL),
('VCULT', NULL),
('WATER', NULL),
('WIL', NULL),
('WKRPT', NULL),
('YC', NULL);

CREATE TABLE components (
    component   VARCHAR(3)  PRIMARY KEY
);
INSERT INTO components VALUES
('LEC'),
('TUT'),
('LAB'),
('TST'),
('CLN'),
('DIS'),
('ENS'),
('ESS'),
('FLD'),
('FLT'),
('OLN'),
('ORL'),
('PRA'),
('PRJ'),
('RDG'),
('SEM'),
('STU'),
('WRK'),
('WSP');

CREATE TABLE courses (
    subject     VARCHAR(6)      NOT NULL REFERENCES subjects(subject),
    code        VARCHAR(5)      NOT NULL CHECK(code ~ '[0-9][A-Z]*'),
    units       REAL            NOT NULL CHECK(units BETWEEN 0 AND 3),
    title       VARCHAR(255)    NOT NULL,
    PRIMARY KEY(subject, code)
);

CREATE TABLE sections (
    section_id      INT             PRIMARY KEY,
    course_subject  VARCHAR(6)      NOT NULL,
    course_code     VARCHAR(5)      NOT NULL,
    component       CHAR(7)         NOT NULL CHECK(component ~ '[A-Z]{3} [0-9]{3}'),
    location        VARCHAR(20)     NOT NULL CHECK(location ~ '[A-Z]+ [A-Z]+'),
    enroll_cap      INT             NOT NULL CHECK(enroll_cap >= 1),
    FOREIGN KEY(course_subject, course_code) REFERENCES courses(subject, code)
);

CREATE TABLE enrollment (
    section_id      INT         NOT NULL REFERENCES sections(section_id),
    check_time      TIMESTAMP   NOT NULL CHECK(check_time = date_trunc('day', check_time)) DEFAULT date_trunc('day', NOW()::timestamp),
    enroll_total    INT         NOT NULL CHECK(enroll_total >= 0),
    PRIMARY KEY(section_id, check_time)
);
	
CREATE TABLE timeslots (
    section_id      INT         NOT NULL REFERENCES sections(section_id),
    start_time      TIME        CHECK('08:30'::time <= start_time),
    end_time        TIME        CHECK(end_time <= '22:00'::time AND start_time < end_time AND
                                    ((start_time IS NOT NULL AND end_time IS NOT NULL) OR (start_time IS NULL AND end_time IS NULL))),
    -- encodes which days of the week a timeslot runs as bits: 1 Mon, 2 Tue, 4 Wed, 8 Thu, ...
    days_of_week    INT         NOT NULL CHECK(days_of_week BETWEEN 0 AND 127),
    start_date      DATE,
    end_date        DATE        CHECK(start_date <= end_date AND
                                    ((start_date IS NOT NULL AND end_date IS NOT NULL) OR (start_date IS NULL AND end_date IS NULL))),
    CHECK(start_time IS NOT NULL OR start_date IS NOT NULL)
);

CREATE MATERIALIZED VIEW course_changes AS
SELECT *,
	curr_enroll_total - prev_day_enroll_total as day_change,
    curr_enroll_total - prev_week_enroll_total as week_change,
    curr_enroll_total - prev_month_enroll_total as month_change
FROM(
	SELECT course_subject as subject, course_code as code,
		MAX(curr_enroll_total) as curr_enroll_total,
		MAX(prev_day_enroll_total) as prev_day_enroll_total,
        MAX(prev_week_enroll_total) as prev_week_enroll_total,
        MAX(prev_month_enroll_total) as prev_month_enroll_total
	FROM(
		SELECT course_subject, course_code,
			LEFT(component, 3) as component_type,
			SUM(t1.enroll_total)::integer as curr_enroll_total,
            SUM(t2.enroll_total)::integer as prev_day_enroll_total,
            SUM(t3.enroll_total)::integer as prev_week_enroll_total,
            SUM(t4.enroll_total)::integer as prev_month_enroll_total
		FROM sections
		INNER JOIN enrollment t1
		ON sections.section_id = t1.section_id AND t1.check_time = date_trunc('day', NOW())
		LEFT OUTER JOIN enrollment t2
		ON sections.section_id = t2.section_id AND t2.check_time = date_trunc('day', NOW() - '1 day'::interval)
        LEFT OUTER JOIN enrollment t3
		ON sections.section_id = t3.section_id AND t3.check_time = date_trunc('day', NOW() - '1 week'::interval)
        LEFT OUTER JOIN enrollment t4
		ON sections.section_id = t4.section_id AND t4.check_time = date_trunc('day', NOW() - '1 month'::interval)
		GROUP BY course_subject, course_code, LEFT(component, 3)
	)
	GROUP BY course_subject, course_code
)
ORDER BY subject, code;

CREATE MATERIALIZED VIEW section_changes AS
SELECT *,
	curr_enroll_total - prev_day_enroll_total as day_change,
    curr_enroll_total - prev_week_enroll_total as week_change,
    curr_enroll_total - prev_month_enroll_total as month_change
FROM(
	SELECT course_subject, course_code, component,
		t1.enroll_total::integer as curr_enroll_total,
		t2.enroll_total::integer as prev_day_enroll_total,
		t3.enroll_total::integer as prev_week_enroll_total,
		t4.enroll_total::integer as prev_month_enroll_total
	FROM sections
	INNER JOIN enrollment t1
	ON sections.section_id = t1.section_id AND t1.check_time = date_trunc('day', NOW())
	LEFT OUTER JOIN enrollment t2
	ON sections.section_id = t2.section_id AND t2.check_time = date_trunc('day', NOW() - '1 day'::interval)
	LEFT OUTER JOIN enrollment t3
	ON sections.section_id = t3.section_id AND t3.check_time = date_trunc('day', NOW() - '1 week'::interval)
	LEFT OUTER JOIN enrollment t4
	ON sections.section_id = t4.section_id AND t4.check_time = date_trunc('day', NOW() - '1 month'::interval)
)
ORDER BY course_subject, course_code, LEFT(component, 3) = 'TST', component;
