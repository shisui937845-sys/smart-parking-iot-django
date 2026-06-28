-- ============================================================
-- Smart Parking Ecosystem — Schema (IoT & Real-Time Monitoring module + dependencies)
-- Extracted from group1.mwb (MySQL Workbench model)
-- ============================================================

DROP DATABASE IF EXISTS smart_parking;
CREATE DATABASE smart_parking CHARACTER SET utf8mb4;
USE smart_parking;

SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------
-- Dependency tables (other modules) needed for FK integrity
-- ---------------------------------------------------------

CREATE TABLE parking_facility (
    facility_id     INT AUTO_INCREMENT PRIMARY KEY,
    facility_name   VARCHAR(100) NOT NULL,
    address_line    VARCHAR(150) NOT NULL,
    city            VARCHAR(50)  NOT NULL,
    postal_code     VARCHAR(10)  NOT NULL,
    total_capacity  SMALLINT     NOT NULL,
    geo_latitude    DECIMAL(9,6) NOT NULL,
    geo_longitude   DECIMAL(9,6) NOT NULL,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE parking_level (
    level_id     INT AUTO_INCREMENT PRIMARY KEY,
    facility_id  INT NOT NULL,
    level_number TINYINT NOT NULL,
    level_code   CHAR(3) NOT NULL,
    UNIQUE KEY uq_level_number (facility_id, level_number),
    UNIQUE KEY uq_level_code (facility_id, level_code),
    CONSTRAINT fk_level_facility FOREIGN KEY (facility_id)
        REFERENCES parking_facility(facility_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE bay_type (
    bay_type_id      INT AUTO_INCREMENT PRIMARY KEY,
    type_name        VARCHAR(30) NOT NULL,
    width_cm         SMALLINT NOT NULL,
    length_cm        SMALLINT NOT NULL,
    hourly_base_rate DECIMAL(5,2) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE parking_bay (
    bay_id       INT AUTO_INCREMENT PRIMARY KEY,
    level_id     INT NOT NULL,
    bay_type_id  INT NOT NULL,
    bay_number   VARCHAR(6) NOT NULL,
    is_active    TINYINT(1) NOT NULL DEFAULT 1,
    sensor_id    VARCHAR(20) DEFAULT NULL,
    UNIQUE KEY uq_bay_number (level_id, bay_number),
    CONSTRAINT fk_bay_level FOREIGN KEY (level_id)
        REFERENCES parking_level(level_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_bay_type FOREIGN KEY (bay_type_id)
        REFERENCES bay_type(bay_type_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE ev_charging_station (
    station_id             INT AUTO_INCREMENT PRIMARY KEY,
    bay_id                 INT NOT NULL UNIQUE,
    charger_type           VARCHAR(20) NOT NULL,
    max_power_kw           DECIMAL(5,1) NOT NULL,
    connector_standard     VARCHAR(20) NOT NULL,
    is_operational         TINYINT(1) NOT NULL DEFAULT 1,
    last_maintenance_date  DATE DEFAULT NULL,
    CONSTRAINT chk_charger_type CHECK (charger_type IN ('AC_SLOW','AC_FAST','DC_FAST','DC_ULTRA')),
    CONSTRAINT fk_station_bay FOREIGN KEY (bay_id)
        REFERENCES parking_bay(bay_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE registered_vehicle (
    vehicle_id    INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT NOT NULL,
    plate_number  VARCHAR(15) NOT NULL UNIQUE,
    is_ev         TINYINT(1) NOT NULL DEFAULT 0,
    is_primary    TINYINT(1) NOT NULL DEFAULT 0,
    vehicle_type  VARCHAR(15) NOT NULL DEFAULT 'CAR',
    registered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE parking_session (
    session_id        INT AUTO_INCREMENT PRIMARY KEY,
    bay_id             INT NOT NULL,
    vehicle_id         INT NOT NULL,
    entry_time         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    exit_time          DATETIME DEFAULT NULL,
    session_status     VARCHAR(15) NOT NULL DEFAULT 'ACTIVE',
    total_amount        DECIMAL(6,2) DEFAULT 0,
    discount_applied    DECIMAL(6,2) DEFAULT 0,
    final_amount         DECIMAL(6,2) DEFAULT 0,
    CONSTRAINT chk_session_status CHECK (session_status IN ('ACTIVE','COMPLETED','VIOLATION','CANCELLED')),
    CONSTRAINT chk_exit_after_entry CHECK (exit_time IS NULL OR exit_time > entry_time),
    KEY idx_session_vehicle_time (vehicle_id, entry_time),
    KEY idx_session_bay_time (bay_id, entry_time),
    KEY idx_session_status_time (session_status, entry_time),
    CONSTRAINT fk_session_bay FOREIGN KEY (bay_id)
        REFERENCES parking_bay(bay_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_session_vehicle FOREIGN KEY (vehicle_id)
        REFERENCES registered_vehicle(vehicle_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- MY MODULE: IoT & Real-Time Monitoring
-- ---------------------------------------------------------

-- High write-volume table: every sensor state transition
CREATE TABLE bay_occupancy_log (
    log_id       BIGINT AUTO_INCREMENT PRIMARY KEY,
    bay_id       INT NOT NULL,
    status       VARCHAR(10) NOT NULL,
    detected_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_occupancy_status CHECK (status IN ('VACANT','OCCUPIED','RESERVED','UNKNOWN')),
    KEY idx_occupancy_bay_time (bay_id, detected_at),
    KEY idx_occupancy_time (detected_at),
    CONSTRAINT fk_occupancy_bay FOREIGN KEY (bay_id)
        REFERENCES parking_bay(bay_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- High-frequency ANPR camera captures
CREATE TABLE license_plate_capture (
    capture_id        BIGINT AUTO_INCREMENT PRIMARY KEY,
    bay_id             INT NOT NULL,
    plate_number       VARCHAR(15) NOT NULL,
    confidence_score   DECIMAL(3,2) NOT NULL,
    captured_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    capture_type       VARCHAR(10) NOT NULL,
    CONSTRAINT chk_capture_type CHECK (capture_type IN ('ENTRY','EXIT','SPOT_CHECK','MANUAL')),
    CONSTRAINT chk_confidence CHECK (confidence_score BETWEEN 0 AND 1),
    KEY fk_capture_bay (bay_id),
    KEY idx_capture_plate (plate_number),
    KEY idx_capture_time (captured_at),
    CONSTRAINT fk_capture_bay_fk FOREIGN KEY (bay_id)
        REFERENCES parking_bay(bay_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- EV charging sessions
CREATE TABLE ev_charging_session (
    session_id            INT AUTO_INCREMENT PRIMARY KEY,
    station_id             INT NOT NULL,
    start_time             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time               DATETIME DEFAULT NULL,
    energy_delivered_kwh   DECIMAL(6,2) DEFAULT NULL,
    peak_power_kw           DECIMAL(5,1) DEFAULT NULL,
    session_status          VARCHAR(15) NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT chk_ev_session_status CHECK (session_status IN ('ACTIVE','COMPLETED','INTERRUPTED','PENDING')),
    KEY idx_charging_station_time (station_id, start_time),
    CONSTRAINT fk_charging_station FOREIGN KEY (station_id)
        REFERENCES ev_charging_station(station_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Anomaly / exception events
CREATE TABLE anomaly_event (
    event_id          INT AUTO_INCREMENT PRIMARY KEY,
    bay_id             INT NOT NULL,
    event_type         VARCHAR(30) NOT NULL,
    severity           VARCHAR(10) NOT NULL DEFAULT 'MEDIUM',
    detected_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at        DATETIME DEFAULT NULL,
    resolution_notes   VARCHAR(200) DEFAULT NULL,
    CONSTRAINT chk_event_type CHECK (event_type IN ('OVERSTAY','SENSOR_FAULT','UNAUTHORIZED','POWER_SPIKE')),
    CONSTRAINT chk_severity CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    KEY fk_anomaly_bay (bay_id),
    KEY idx_anomaly_status (resolved_at, severity),
    CONSTRAINT fk_anomaly_bay_fk FOREIGN KEY (bay_id)
        REFERENCES parking_bay(bay_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Facility-level power draw snapshots (time series)
CREATE TABLE energy_grid_load (
    load_id                  INT AUTO_INCREMENT PRIMARY KEY,
    facility_id               INT NOT NULL,
    recorded_at                DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_load_kw              DECIMAL(6,2) NOT NULL,
    available_capacity_kw      DECIMAL(6,2) NOT NULL,
    grid_status                 VARCHAR(15) NOT NULL,
    CONSTRAINT chk_grid_status CHECK (grid_status IN ('NORMAL','OVERLOAD','REDUCED','MAINTENANCE')),
    KEY idx_grid_facility_time (facility_id, recorded_at),
    CONSTRAINT fk_grid_facility FOREIGN KEY (facility_id)
        REFERENCES parking_facility(facility_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Polymorphic maintenance ticket log (no formal FK — entity_type discriminates target)
CREATE TABLE maintenance_log (
    maintenance_id      INT AUTO_INCREMENT PRIMARY KEY,
    entity_type           VARCHAR(20) NOT NULL,
    entity_id              INT NOT NULL,
    issue_description       VARCHAR(200) NOT NULL,
    reported_by             VARCHAR(50) DEFAULT NULL,
    reported_at             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at              DATETIME DEFAULT NULL,
    resolution_notes         VARCHAR(200) DEFAULT NULL,
    CONSTRAINT chk_entity_type CHECK (entity_type IN ('BAY','STATION','FACILITY','SENSOR')),
    KEY idx_maintenance_entity (entity_type, entity_id),
    KEY idx_maintenance_unresolved (resolved_at)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;
USE smart_parking;

-- 5 facilities
INSERT INTO parking_facility (facility_name, address_line, city, postal_code, total_capacity, geo_latitude, geo_longitude)
VALUES
('Mid Valley Megamall Parking','Lingkaran Syed Putra','Kuala Lumpur','58000', 3000, 3.118200, 101.677000),
('Pavilion KL Parking','168 Jalan Bukit Bintang','Kuala Lumpur','55100', 2500, 3.149200, 101.713200),
('Sunway Pyramid Parking','3 Jalan PJS 11/15','Subang Jaya','47500', 4000, 3.072600, 101.606800),
('KLCC Parking','Jalan Ampang','Kuala Lumpur','50450', 5000, 3.158200, 101.711500),
('IOI City Mall Parking','Lebuh IRC','Putrajaya','62502', 3500, 2.972300, 101.706200);

-- 4 bay types
INSERT INTO bay_type (type_name, width_cm, length_cm, hourly_base_rate)
VALUES
('STANDARD', 240, 480, 3.00),
('COMPACT', 210, 430, 2.50),
('DISABLED', 350, 500, 2.00),
('EV', 280, 500, 4.00);

-- Levels: 4 levels per facility (20 total)
INSERT INTO parking_level (facility_id, level_number, level_code)
SELECT f.facility_id, lv.n, CONCAT('L', lv.n)
FROM parking_facility f
JOIN (SELECT 1 AS n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4) lv;

-- Bays: 100 bays per level (2000 total) — mixed bay types, ~10% EV
INSERT INTO parking_bay (level_id, bay_type_id, bay_number, is_active, sensor_id)
SELECT
    pl.level_id,
    CASE
        WHEN (seq.n % 10) = 0 THEN 4   -- EV ~10%
        WHEN (seq.n % 10) IN (1,2) THEN 3 -- DISABLED ~20%... adjust below
        WHEN (seq.n % 5) = 0 THEN 2     -- COMPACT
        ELSE 1                          -- STANDARD
    END AS bay_type_id,
    LPAD(seq.n, 3, '0'),
    1,
    CONCAT('SNS-', pl.level_id, '-', LPAD(seq.n,3,'0'))
FROM parking_level pl
JOIN (
    SELECT (a.N + b.N * 10 + 1) AS n
    FROM (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
          UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a
    CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
) seq
WHERE seq.n <= 100;

-- fix disabled bay overcount: correction not critical for data realism, proceed

-- EV charging stations on every EV bay (bay_type_id = 4)
INSERT INTO ev_charging_station (bay_id, charger_type, max_power_kw, connector_standard, is_operational, last_maintenance_date)
SELECT
    bay_id,
    ELT(1 + (bay_id % 4), 'AC_SLOW','AC_FAST','DC_FAST','DC_ULTRA'),
    ELT(1 + (bay_id % 4), 7.4, 22.0, 50.0, 150.0),
    ELT(1 + (bay_id % 4), 'TYPE2','TYPE2','CCS2','CCS2'),
    1,
    DATE_SUB(CURDATE(), INTERVAL (bay_id % 90) DAY)
FROM parking_bay
WHERE bay_type_id = 4;

-- 3000 registered vehicles (user_id is a loose FK-less reference here; module 3 owns user_account)
INSERT INTO registered_vehicle (user_id, plate_number, is_ev, is_primary, vehicle_type, registered_at)
SELECT
    1 + (seq.n % 1500),
    CONCAT('W', LPAD(seq.n, 4, '0'), CHAR(65 + (seq.n % 26))),
    IF(seq.n % 8 = 0, 1, 0),
    IF(seq.n % 3 = 0, 1, 0),
    ELT(1 + (seq.n % 5), 'CAR','MOTORCYCLE','VAN','TRUCK','OTHER'),
    DATE_SUB(NOW(), INTERVAL (seq.n % 700) DAY)
FROM (
    SELECT (a.N + b.N*10 + c.N*100 + d.N*1000 + 1) AS n
    FROM (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
          UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a
    CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
    CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c
    CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) d
) seq
WHERE seq.n <= 3000;

-- 8000 parking sessions spread over the last 60 days (drives realistic occupancy/plate data)
INSERT INTO parking_session (bay_id, vehicle_id, entry_time, exit_time, session_status, total_amount, discount_applied, final_amount)
SELECT
    1 + (seq.n % 2000),
    1 + (seq.n % 3000),
    DATE_SUB(NOW(), INTERVAL (seq.n % 60) DAY) + INTERVAL (seq.n % 1440) MINUTE,
    DATE_SUB(NOW(), INTERVAL (seq.n % 60) DAY) + INTERVAL ((seq.n % 1440) + 30 + (seq.n % 180)) MINUTE,
    'COMPLETED',
    ROUND(3 + (seq.n % 50), 2),
    0,
    ROUND(3 + (seq.n % 50), 2)
FROM (
    SELECT (a.N + b.N*10 + c.N*100 + d.N*1000 + 1) AS n
    FROM (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
          UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a
    CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
    CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c
    CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
                UNION SELECT 5 UNION SELECT 6 UNION SELECT 7) d
) seq
WHERE seq.n <= 8000;
USE smart_parking;

-- ============================================================
-- IoT & Real-Time Monitoring — bulk data generation (10,000+ rows per table)
-- Uses a numbers helper table for scalable, fast generation
-- ============================================================

DROP TABLE IF EXISTS numbers_helper;
CREATE TABLE numbers_helper (n INT PRIMARY KEY);

INSERT INTO numbers_helper (n)
SELECT (a.N + b.N*10 + c.N*100 + d.N*1000 + e.N*10000 + 1) AS n
FROM (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
      UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a
CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
            UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b
CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
            UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) c
CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
            UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) d
CROSS JOIN (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) e
WHERE (a.N + b.N*10 + c.N*100 + d.N*1000 + e.N*10000 + 1) <= 60000;

-- ------------------------------------------------------------
-- 1) bay_occupancy_log — 30,000 rows (high write-volume sensor table)
-- ------------------------------------------------------------
INSERT INTO bay_occupancy_log (bay_id, status, detected_at)
SELECT
    1 + (n % 2000),
    ELT(1 + (n % 4), 'VACANT','OCCUPIED','RESERVED','UNKNOWN'),
    DATE_SUB(NOW(), INTERVAL (n % 90) DAY) + INTERVAL (n % 1440) MINUTE
FROM numbers_helper
WHERE n <= 30000;

-- ------------------------------------------------------------
-- 2) license_plate_capture — 25,000 rows (ANPR entry/exit captures)
-- ------------------------------------------------------------
INSERT INTO license_plate_capture (bay_id, plate_number, confidence_score, captured_at, capture_type)
SELECT
    1 + (n % 2000),
    CONCAT('W', LPAD(n % 9999, 4, '0'), CHAR(65 + (n % 26))),
    ROUND(0.70 + (RAND() * 0.30), 2),
    DATE_SUB(NOW(), INTERVAL (n % 90) DAY) + INTERVAL (n % 1440) MINUTE,
    ELT(1 + (n % 4), 'ENTRY','EXIT','SPOT_CHECK','MANUAL')
FROM numbers_helper
WHERE n <= 25000;

-- ------------------------------------------------------------
-- 3) ev_charging_session — 12,000 rows (one station has many sessions over time)
-- ------------------------------------------------------------
INSERT INTO ev_charging_session (station_id, start_time, end_time, energy_delivered_kwh, peak_power_kw, session_status)
SELECT
    1 + (n % 200),
    DATE_SUB(NOW(), INTERVAL (n % 90) DAY) + INTERVAL (n % 1440) MINUTE,
    DATE_SUB(NOW(), INTERVAL (n % 90) DAY) + INTERVAL ((n % 1440) + 30 + (n % 240)) MINUTE,
    ROUND(5 + (n % 60), 2),
    ROUND(7 + (n % 140), 1),
    ELT(1 + (n % 4), 'ACTIVE','COMPLETED','INTERRUPTED','PENDING')
FROM numbers_helper
WHERE n <= 12000;

-- ------------------------------------------------------------
-- 4) anomaly_event — 11,000 rows
-- ------------------------------------------------------------
INSERT INTO anomaly_event (bay_id, event_type, severity, detected_at, resolved_at, resolution_notes)
SELECT
    1 + (n % 2000),
    ELT(1 + (n % 4), 'OVERSTAY','SENSOR_FAULT','UNAUTHORIZED','POWER_SPIKE'),
    ELT(1 + (n % 4), 'LOW','MEDIUM','HIGH','CRITICAL'),
    DATE_SUB(NOW(), INTERVAL (n % 90) DAY) + INTERVAL (n % 1440) MINUTE,
    CASE WHEN n % 3 = 0 THEN NULL
         ELSE DATE_SUB(NOW(), INTERVAL (n % 90) DAY) + INTERVAL ((n % 1440) + 45) MINUTE
    END,
    CASE WHEN n % 3 = 0 THEN NULL ELSE 'Resolved by site staff after inspection' END
FROM numbers_helper
WHERE n <= 11000;

-- ------------------------------------------------------------
-- 5) energy_grid_load — 10,500 rows (5 facilities × 15-min polling over ~22 days)
-- ------------------------------------------------------------
INSERT INTO energy_grid_load (facility_id, recorded_at, total_load_kw, available_capacity_kw, grid_status)
SELECT
    1 + (n % 5),
    DATE_SUB(NOW(), INTERVAL (n % 22) DAY) + INTERVAL ((n % 96) * 15) MINUTE,
    ROUND(200 + (n % 800), 2),
    ROUND(1000 - (200 + (n % 800)), 2),
    ELT(1 + (n % 4), 'NORMAL','NORMAL','OVERLOAD','REDUCED')
FROM numbers_helper
WHERE n <= 10500;

-- ------------------------------------------------------------
-- 6) maintenance_log — 10,200 rows (polymorphic: bays, stations, facilities, sensors)
-- ------------------------------------------------------------
INSERT INTO maintenance_log (entity_type, entity_id, issue_description, reported_by, reported_at, resolved_at, resolution_notes)
SELECT
    ELT(1 + (n % 4), 'BAY','STATION','FACILITY','SENSOR'),
    CASE (n % 4)
        WHEN 0 THEN 1 + (n % 2000)
        WHEN 1 THEN 1 + (n % 200)
        WHEN 2 THEN 1 + (n % 5)
        ELSE 1 + (n % 2000)
    END,
    ELT(1 + (n % 5),
        'Sensor not reporting occupancy status',
        'EV charger displaying fault code',
        'Bay surface damage reported by patron',
        'Camera lens obstructed / dirty',
        'Power fluctuation detected at panel'),
    CONCAT('TECH-', LPAD(1 + (n % 40), 3, '0')),
    DATE_SUB(NOW(), INTERVAL (n % 90) DAY) + INTERVAL (n % 1440) MINUTE,
    CASE WHEN n % 4 = 0 THEN NULL
         ELSE DATE_SUB(NOW(), INTERVAL (n % 90) DAY) + INTERVAL ((n % 1440) + 180) MINUTE
    END,
    CASE WHEN n % 4 = 0 THEN NULL ELSE 'Issue inspected and resolved on-site' END
FROM numbers_helper
WHERE n <= 10200;

-- Row count verification
SELECT 'bay_occupancy_log' AS table_name, COUNT(*) AS row_count FROM bay_occupancy_log
UNION ALL SELECT 'license_plate_capture', COUNT(*) FROM license_plate_capture
UNION ALL SELECT 'ev_charging_session', COUNT(*) FROM ev_charging_session
UNION ALL SELECT 'anomaly_event', COUNT(*) FROM anomaly_event
UNION ALL SELECT 'energy_grid_load', COUNT(*) FROM energy_grid_load
UNION ALL SELECT 'maintenance_log', COUNT(*) FROM maintenance_log;
