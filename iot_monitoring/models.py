"""
Models for the IoT & Real-Time Monitoring module.

IMPORTANT: managed = False on every model below means Django will NOT
create, alter, or drop these tables. They already exist in the
smart_parking MySQL database (built in Assignment 1 / the SQL report).
Django is only used here to READ and WRITE rows through these tables,
never to change their structure.
"""
from django.db import models


# ---------------------------------------------------------------------------
# Dependency models (owned by other modules, but needed here so our
# tables' ForeignKeys have something to point to).
# ---------------------------------------------------------------------------

class ParkingFacility(models.Model):
    facility_id = models.AutoField(primary_key=True)
    facility_name = models.CharField(max_length=100)
    address_line = models.CharField(max_length=150)
    city = models.CharField(max_length=50)
    postal_code = models.CharField(max_length=10)
    total_capacity = models.SmallIntegerField()
    geo_latitude = models.DecimalField(max_digits=9, decimal_places=6)
    geo_longitude = models.DecimalField(max_digits=9, decimal_places=6)
    created_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'parking_facility'

    def __str__(self):
        return self.facility_name


class ParkingLevel(models.Model):
    level_id = models.AutoField(primary_key=True)
    facility = models.ForeignKey(ParkingFacility, on_delete=models.RESTRICT, db_column='facility_id')
    level_number = models.IntegerField()
    level_code = models.CharField(max_length=3)

    class Meta:
        managed = False
        db_table = 'parking_level'

    def __str__(self):
        return f"{self.facility.facility_name} - {self.level_code}"


class BayType(models.Model):
    bay_type_id = models.AutoField(primary_key=True)
    type_name = models.CharField(max_length=30)
    width_cm = models.SmallIntegerField()
    length_cm = models.SmallIntegerField()
    hourly_base_rate = models.DecimalField(max_digits=5, decimal_places=2)

    class Meta:
        managed = False
        db_table = 'bay_type'

    def __str__(self):
        return self.type_name


class ParkingBay(models.Model):
    bay_id = models.AutoField(primary_key=True)
    level = models.ForeignKey(ParkingLevel, on_delete=models.RESTRICT, db_column='level_id')
    bay_type = models.ForeignKey(BayType, on_delete=models.RESTRICT, db_column='bay_type_id')
    bay_number = models.CharField(max_length=6)
    is_active = models.IntegerField()
    sensor_id = models.CharField(max_length=20, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'parking_bay'

    def __str__(self):
        return f"Bay {self.bay_number} (id={self.bay_id})"


class EvChargingStation(models.Model):
    station_id = models.AutoField(primary_key=True)
    bay = models.OneToOneField(ParkingBay, on_delete=models.RESTRICT, db_column='bay_id')
    charger_type = models.CharField(max_length=20)
    max_power_kw = models.DecimalField(max_digits=5, decimal_places=1)
    connector_standard = models.CharField(max_length=20)
    is_operational = models.IntegerField()
    last_maintenance_date = models.DateField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'ev_charging_station'

    def __str__(self):
        return f"Station {self.station_id} ({self.charger_type})"


# ---------------------------------------------------------------------------
# MY MODULE: IoT & Real-Time Monitoring — the 6 tables this report covers
# ---------------------------------------------------------------------------

class BayOccupancyLog(models.Model):
    STATUS_CHOICES = [
        ('VACANT', 'Vacant'),
        ('OCCUPIED', 'Occupied'),
        ('RESERVED', 'Reserved'),
        ('UNKNOWN', 'Unknown'),
    ]

    log_id = models.BigAutoField(primary_key=True)
    bay = models.ForeignKey(ParkingBay, on_delete=models.RESTRICT, db_column='bay_id')
    status = models.CharField(max_length=10, choices=STATUS_CHOICES)
    detected_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = 'bay_occupancy_log'
        indexes = [
            models.Index(fields=['bay', 'detected_at'], name='idx_occupancy_bay_time'),
            models.Index(fields=['status', 'bay', 'detected_at'], name='idx_occupancy_status_bay_time'),
        ]

    def __str__(self):
        return f"Bay {self.bay_id} -> {self.status} @ {self.detected_at}"


class LicensePlateCapture(models.Model):
    CAPTURE_TYPE_CHOICES = [
        ('ENTRY', 'Entry'),
        ('EXIT', 'Exit'),
        ('SPOT_CHECK', 'Spot Check'),
        ('MANUAL', 'Manual'),
    ]

    capture_id = models.BigAutoField(primary_key=True)
    bay = models.ForeignKey(ParkingBay, on_delete=models.RESTRICT, db_column='bay_id')
    plate_number = models.CharField(max_length=15)
    confidence_score = models.DecimalField(max_digits=3, decimal_places=2)
    captured_at = models.DateTimeField()
    capture_type = models.CharField(max_length=10, choices=CAPTURE_TYPE_CHOICES)

    class Meta:
        managed = False
        db_table = 'license_plate_capture'
        indexes = [
            models.Index(fields=['plate_number'], name='idx_capture_plate'),
            models.Index(fields=['captured_at'], name='idx_capture_time'),
        ]

    def __str__(self):
        return f"{self.plate_number} ({self.capture_type})"


class EvChargingSession(models.Model):
    STATUS_CHOICES = [
        ('ACTIVE', 'Active'),
        ('COMPLETED', 'Completed'),
        ('INTERRUPTED', 'Interrupted'),
        ('PENDING', 'Pending'),
    ]

    session_id = models.AutoField(primary_key=True)
    station = models.ForeignKey(EvChargingStation, on_delete=models.RESTRICT, db_column='station_id')
    start_time = models.DateTimeField()
    end_time = models.DateTimeField(blank=True, null=True)
    energy_delivered_kwh = models.DecimalField(max_digits=6, decimal_places=2, blank=True, null=True)
    peak_power_kw = models.DecimalField(max_digits=5, decimal_places=1, blank=True, null=True)
    session_status = models.CharField(max_length=15, choices=STATUS_CHOICES)

    class Meta:
        managed = False
        db_table = 'ev_charging_session'
        indexes = [
            models.Index(fields=['station', 'start_time'], name='idx_charging_station_time'),
        ]

    def __str__(self):
        return f"Session {self.session_id} - {self.session_status}"


class AnomalyEvent(models.Model):
    EVENT_TYPE_CHOICES = [
        ('OVERSTAY', 'Overstay'),
        ('SENSOR_FAULT', 'Sensor Fault'),
        ('UNAUTHORIZED', 'Unauthorized'),
        ('POWER_SPIKE', 'Power Spike'),
    ]
    SEVERITY_CHOICES = [
        ('LOW', 'Low'),
        ('MEDIUM', 'Medium'),
        ('HIGH', 'High'),
        ('CRITICAL', 'Critical'),
    ]

    event_id = models.AutoField(primary_key=True)
    bay = models.ForeignKey(ParkingBay, on_delete=models.RESTRICT, db_column='bay_id')
    event_type = models.CharField(max_length=30, choices=EVENT_TYPE_CHOICES)
    severity = models.CharField(max_length=10, choices=SEVERITY_CHOICES, default='MEDIUM')
    detected_at = models.DateTimeField()
    resolved_at = models.DateTimeField(blank=True, null=True)
    resolution_notes = models.CharField(max_length=200, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'anomaly_event'
        indexes = [
            models.Index(fields=['resolved_at', 'severity'], name='idx_anomaly_status'),
            models.Index(fields=['event_type', 'resolved_at', 'detected_at'], name='idx_anomaly_type_resolved'),
        ]

    def __str__(self):
        return f"{self.event_type} ({self.severity}) - Bay {self.bay_id}"


class EnergyGridLoad(models.Model):
    STATUS_CHOICES = [
        ('NORMAL', 'Normal'),
        ('OVERLOAD', 'Overload'),
        ('REDUCED', 'Reduced'),
        ('MAINTENANCE', 'Maintenance'),
    ]

    load_id = models.AutoField(primary_key=True)
    facility = models.ForeignKey(ParkingFacility, on_delete=models.RESTRICT, db_column='facility_id')
    recorded_at = models.DateTimeField()
    total_load_kw = models.DecimalField(max_digits=6, decimal_places=2)
    available_capacity_kw = models.DecimalField(max_digits=6, decimal_places=2)
    grid_status = models.CharField(max_length=15, choices=STATUS_CHOICES)

    class Meta:
        managed = False
        db_table = 'energy_grid_load'
        indexes = [
            models.Index(fields=['facility', 'recorded_at'], name='idx_grid_facility_time'),
        ]

    def __str__(self):
        return f"{self.facility.facility_name} - {self.recorded_at}"


class MaintenanceLog(models.Model):
    ENTITY_TYPE_CHOICES = [
        ('BAY', 'Bay'),
        ('STATION', 'Station'),
        ('FACILITY', 'Facility'),
        ('SENSOR', 'Sensor'),
    ]

    maintenance_id = models.AutoField(primary_key=True)
    entity_type = models.CharField(max_length=20, choices=ENTITY_TYPE_CHOICES)
    entity_id = models.IntegerField()
    issue_description = models.CharField(max_length=200)
    reported_by = models.CharField(max_length=50, blank=True, null=True)
    reported_at = models.DateTimeField()
    resolved_at = models.DateTimeField(blank=True, null=True)
    resolution_notes = models.CharField(max_length=200, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'maintenance_log'
        indexes = [
            models.Index(fields=['entity_type', 'entity_id'], name='idx_maintenance_entity'),
            models.Index(fields=['resolved_at'], name='idx_maintenance_unresolved'),
        ]

    def __str__(self):
        return f"{self.entity_type} #{self.entity_id} - {self.issue_description[:30]}"
