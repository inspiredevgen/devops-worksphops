-- File: backend/seed.sql
-- Sample data for the Pacific Learning Co. student registry.
-- Re-runnable: it drops and recreates the tables.

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW  IF EXISTS v_course_stats;
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS courses;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE courses (
  id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code   VARCHAR(20)  NOT NULL UNIQUE,
  title  VARCHAR(120) NOT NULL,
  track  VARCHAR(40)  NOT NULL,
  hours  SMALLINT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE students (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name  VARCHAR(100) NOT NULL,
  email      VARCHAR(120) NOT NULL UNIQUE,
  city       VARCHAR(60)  NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE enrollments (
  student_id  INT UNSIGNED NOT NULL,
  course_id   INT UNSIGNED NOT NULL,
  status      ENUM('ENROLLED','COMPLETED','DROPPED') NOT NULL DEFAULT 'ENROLLED',
  enrolled_on DATE NOT NULL,
  PRIMARY KEY (student_id, course_id),
  CONSTRAINT fk_enr_student FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
  CONSTRAINT fk_enr_course  FOREIGN KEY (course_id)  REFERENCES courses(id)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO courses (code, title, track, hours) VALUES
  ('AWS-101', 'Cloud Foundations & Global Infrastructure', 'Foundations', 12),
  ('AWS-IAM', 'Identity & Access Management',              'Security',    10),
  ('AWS-NET', 'VPC Networking Deep Dive',                  'Networking',  16),
  ('AWS-CMP', 'EC2, Auto Scaling & Load Balancing',        'Compute',     14),
  ('AWS-STO', 'S3 & Storage Services',                     'Storage',     10),
  ('AWS-DB',  'RDS, Aurora & DynamoDB',                    'Database',    12),
  ('AWS-IAC', 'Infrastructure as Code with CloudFormation','Automation',  12),
  ('AWS-OPS', 'CloudWatch & CloudTrail Operations',        'Operations',   8);

INSERT INTO students (full_name, email, city, created_at) VALUES
  ('Amara Okafor',       'amara.okafor@example.com',      'Lagos',      '2026-09-01 09:15:00'),
  ('Jean-Pierre Mbuyi',  'jp.mbuyi@example.com',          'Kinshasa',   '2026-09-01 10:02:00'),
  ('Sofia Martinez',     'sofia.martinez@example.com',    'Toronto',    '2026-09-02 14:30:00'),
  ('Liam Chen',          'liam.chen@example.com',         'Vancouver',  '2026-09-03 08:45:00'),
  ('Fatou Diallo',       'fatou.diallo@example.com',      'Dakar',      '2026-09-03 16:20:00'),
  ('Noah Tremblay',      'noah.tremblay@example.com',     'Montréal',   '2026-09-04 11:05:00'),
  ('Priya Sharma',       'priya.sharma@example.com',      'Toronto',    '2026-09-05 13:40:00'),
  ('Grace Mukendi',      'grace.mukendi@example.com',     'Lubumbashi', '2026-09-06 09:55:00'),
  ('Ethan Brown',        'ethan.brown@example.com',       'Ottawa',     '2026-09-08 15:10:00'),
  ('Wanjiru Kamau',      'wanjiru.kamau@example.com',     'Nairobi',    '2026-09-09 07:30:00'),
  ('Lucas Dubois',       'lucas.dubois@example.com',      'Paris',      '2026-09-10 12:00:00'),
  ('Mei Tanaka',         'mei.tanaka@example.com',        'Calgary',    '2026-09-11 17:25:00');

INSERT INTO enrollments (student_id, course_id, status, enrolled_on) VALUES
  (1, 1, 'COMPLETED', '2026-09-02'), (1, 3, 'ENROLLED',  '2026-09-20'), (1, 2, 'ENROLLED',  '2026-09-21'),
  (2, 1, 'COMPLETED', '2026-09-02'), (2, 3, 'COMPLETED', '2026-09-15'), (2, 7, 'ENROLLED',  '2026-10-01'),
  (3, 1, 'COMPLETED', '2026-09-03'), (3, 4, 'ENROLLED',  '2026-09-22'),
  (4, 1, 'COMPLETED', '2026-09-04'), (4, 6, 'ENROLLED',  '2026-09-25'), (4, 5, 'DROPPED',   '2026-09-12'),
  (5, 1, 'ENROLLED',  '2026-09-04'), (5, 2, 'ENROLLED',  '2026-09-10'),
  (6, 1, 'COMPLETED', '2026-09-05'), (6, 3, 'ENROLLED',  '2026-09-23'), (6, 8, 'ENROLLED',  '2026-10-02'),
  (7, 2, 'COMPLETED', '2026-09-06'), (7, 7, 'ENROLLED',  '2026-09-28'),
  (8, 1, 'ENROLLED',  '2026-09-07'), (8, 3, 'ENROLLED',  '2026-09-24'),
  (9, 4, 'ENROLLED',  '2026-09-09'), (9, 8, 'COMPLETED', '2026-09-30'),
  (10, 1, 'COMPLETED','2026-09-10'), (10, 6, 'ENROLLED', '2026-09-26'),
  (11, 5, 'ENROLLED', '2026-09-11'), (11, 1, 'COMPLETED','2026-09-11'),
  (12, 3, 'ENROLLED', '2026-09-12'), (12, 4, 'ENROLLED', '2026-09-27');

-- A reporting view you can query during the lab
CREATE VIEW v_course_stats AS
SELECT c.code,
       c.title,
       COUNT(e.student_id)                      AS total_enrolled,
       COALESCE(SUM(e.status = 'COMPLETED'), 0) AS completed,
       COALESCE(SUM(e.status = 'DROPPED'),   0) AS dropped
FROM courses c
LEFT JOIN enrollments e ON e.course_id = c.id
GROUP BY c.id, c.code, c.title;
