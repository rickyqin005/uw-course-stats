SELECT
    courses.subject, courses.code,
    units, title,
    curr_enroll_total,
    prev_hour_enroll_total,
    prev_day_enroll_total,
    prev_week_enroll_total,
    prev_month_enroll_total,
    hour_change,
    day_change,
    week_change,
    month_change
FROM courses
INNER JOIN course_changes
ON course_changes.subject = courses.subject AND course_changes.code = courses.code
ORDER BY %SQL1
%SQL2;
