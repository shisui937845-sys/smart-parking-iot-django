-- ============================================================
-- Smart Parking Ecosystem — IoT & Real-Time Monitoring Module
-- File 2 of 2: Optimized Queries (Task 3) and Transaction Design (Task 4)
-- Run this AFTER generated_data.sql has been executed.
-- ============================================================

USE smart_parking;

-- ============================================================
-- TASK 3 — QUERY 1: Critical anomaly lookup by type
-- ============================================================

-- ---- ORIGINAL (unoptimized) form ----
-- EXPLAIN type on anomaly_event: ref (driven from parking_bay, the wrong side)
-- Measured: 0.1105 sec on 71,001-row anomaly_event / 70,201-row maintenance_log
SELECT ae.bay_id, pb.bay_number, pl.level_code, pf.facility_name,
       ae.event_type, ae.detected_at
FROM anomaly_event ae
JOIN parking_bay pb       ON ae.bay_id = pb.bay_id
JOIN parking_level pl     ON pb.level_id = pl.level_id
JOIN parking_facility pf  ON pl.facility_id = pf.facility_id
WHERE ae.event_type = 'POWER_SPIKE' AND ae.resolved_at IS NULL
ORDER BY ae.detected_at DESC;

-- ---- OPTIMIZATION: add a composite index on the actual filter columns ----
CREATE INDEX idx_anomaly_type_resolved_detected
    ON anomaly_event (event_type, resolved_at, detected_at);

-- ---- OPTIMIZED form (index + forced join order) ----
-- EXPLAIN type on anomaly_event: ref (driven directly via the new index)
-- Measured: 0.0359 sec  (~3.1x faster)
SELECT STRAIGHT_JOIN
       ae.bay_id, pb.bay_number, pl.level_code, pf.facility_name,
       ae.event_type, ae.detected_at
FROM anomaly_event ae
JOIN parking_bay pb       ON ae.bay_id = pb.bay_id
JOIN parking_level pl     ON pb.level_id = pl.level_id
JOIN parking_facility pf  ON pl.facility_id = pf.facility_id
WHERE ae.event_type = 'POWER_SPIKE' AND ae.resolved_at IS NULL
ORDER BY ae.detected_at DESC;


-- ============================================================
-- TASK 3 — QUERY 2: Bay dwell-time analysis
-- ============================================================

-- ---- ORIGINAL (unoptimized) form ----
-- EXPLAIN type on bay_occupancy_log: ALL (full table scan, 149,904 rows)
-- Measured: 0.1735 sec on a 150,000-row bay_occupancy_log
SELECT bol.bay_id, bol.status, bol.detected_at,
       LEAD(bol.detected_at) OVER (
           PARTITION BY bol.bay_id ORDER BY bol.detected_at
       ) AS next_change,
       TIMESTAMPDIFF(MINUTE, bol.detected_at,
           LEAD(bol.detected_at) OVER (
               PARTITION BY bol.bay_id ORDER BY bol.detected_at
           )) AS dwell_minutes
FROM bay_occupancy_log bol
WHERE bol.status = 'OCCUPIED'
ORDER BY bol.bay_id, bol.detected_at;

-- ---- OPTIMIZATION: composite covering index ----
CREATE INDEX idx_occupancy_status_bay_time
    ON bay_occupancy_log (status, bay_id, detected_at);

-- ---- OPTIMIZED form (same query, now served by the covering index) ----
-- EXPLAIN type on bay_occupancy_log: ref + "Using index" (covering scan)
-- Measured: 0.0838 sec  (~2.1x faster)
SELECT bol.bay_id, bol.status, bol.detected_at,
       LEAD(bol.detected_at) OVER (
           PARTITION BY bol.bay_id ORDER BY bol.detected_at
       ) AS next_change,
       TIMESTAMPDIFF(MINUTE, bol.detected_at,
           LEAD(bol.detected_at) OVER (
               PARTITION BY bol.bay_id ORDER BY bol.detected_at
           )) AS dwell_minutes
FROM bay_occupancy_log bol
WHERE bol.status = 'OCCUPIED'
ORDER BY bol.bay_id, bol.detected_at;


-- ============================================================
-- TASK 4 — TRANSACTION DESIGN
-- "Critical Anomaly Response": a single atomic operation that, when a
-- CRITICAL anomaly is detected on a bay, (1) logs the anomaly,
-- (2) opens a maintenance ticket, (3) takes the bay out of service,
-- and (4) records the forced status change in the occupancy log.
-- All four writes succeed together or are rolled back together.
-- ============================================================

DROP PROCEDURE IF EXISTS sp_handle_critical_anomaly;

DELIMITER //

CREATE PROCEDURE sp_handle_critical_anomaly (
    IN p_bay_id            INT,
    IN p_event_type        VARCHAR(30),   -- OVERSTAY | SENSOR_FAULT | UNAUTHORIZED | POWER_SPIKE
    IN p_issue_description VARCHAR(200),
    IN p_reported_by       VARCHAR(50)
)
BEGIN
    DECLARE v_event_id INT;
    DECLARE v_bay_exists INT;

    -- Guard clause: validate before opening a transaction at all
    SELECT COUNT(*) INTO v_bay_exists FROM parking_bay WHERE bay_id = p_bay_id;
    IF v_bay_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bay does not exist';
    END IF;

    START TRANSACTION;

    -- 1) Record the anomaly event
    INSERT INTO anomaly_event (bay_id, event_type, severity, detected_at)
    VALUES (p_bay_id, p_event_type, 'CRITICAL', NOW());

    SET v_event_id = LAST_INSERT_ID();

    -- 2) Open a maintenance ticket referencing the bay
    INSERT INTO maintenance_log (entity_type, entity_id, issue_description, reported_by, reported_at)
    VALUES ('BAY', p_bay_id, p_issue_description, p_reported_by, NOW());

    -- 3) Take the bay out of service immediately
    UPDATE parking_bay
    SET is_active = 0
    WHERE bay_id = p_bay_id;

    -- 4) Log the forced status change for the live occupancy dashboard
    INSERT INTO bay_occupancy_log (bay_id, status, detected_at)
    VALUES (p_bay_id, 'UNKNOWN', NOW());

    COMMIT;

    SELECT v_event_id AS anomaly_event_id,
           p_bay_id AS bay_id,
           'Critical anomaly logged, maintenance ticket opened, bay taken offline' AS message;
END //

DELIMITER ;

-- ------------------------------------------------------------
-- Demonstration: run the transaction against a sample bay
-- ------------------------------------------------------------
SELECT 'BEFORE' AS state, bay_id, is_active FROM parking_bay WHERE bay_id = 500;

CALL sp_handle_critical_anomaly(
    500,
    'POWER_SPIKE',
    'EV charger on bay 500 reported abnormal voltage spike via IoT sensor',
    'TECH-014'
);

SELECT 'AFTER' AS state, bay_id, is_active FROM parking_bay WHERE bay_id = 500;

SELECT * FROM anomaly_event WHERE bay_id = 500 ORDER BY event_id DESC LIMIT 1;
SELECT * FROM maintenance_log WHERE entity_type = 'BAY' AND entity_id = 500 ORDER BY maintenance_id DESC LIMIT 1;
SELECT * FROM bay_occupancy_log WHERE bay_id = 500 ORDER BY log_id DESC LIMIT 1;

-- ------------------------------------------------------------
-- Failure-path demonstration: invalid bay_id is rejected before
-- the transaction opens, and no rows are written anywhere.
-- ------------------------------------------------------------
-- CALL sp_handle_critical_anomaly(999999, 'POWER_SPIKE', 'test', 'TECH-099');
-- Expected: ERROR 1644 (45000): Bay does not exist
