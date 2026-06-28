"""
Views for the IoT & Real-Time Monitoring module.

Each table gets four views following the same pattern:
    <table>_list    -> READ   (search/list page)
    <table>_create  -> CREATE (add new row)
    <table>_update  -> UPDATE (edit existing row)
    <table>_delete  -> DELETE (confirm + remove row)

Plus one extra view, handle_critical_anomaly, which implements Task 4's
multi-table transaction.
"""
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.db import transaction, connection
from django.utils import timezone

from .models import (
    BayOccupancyLog, LicensePlateCapture, EvChargingSession,
    AnomalyEvent, EnergyGridLoad, MaintenanceLog, ParkingBay,
)
from .forms import (
    BayOccupancyLogForm, LicensePlateCaptureForm, EvChargingSessionForm,
    AnomalyEventForm, EnergyGridLoadForm, MaintenanceLogForm, CriticalAnomalyForm,
)


def home(request):
    """Dashboard landing page: quick counts for each table."""
    context = {
        'counts': {
            'Bay Occupancy Log': BayOccupancyLog.objects.count(),
            'License Plate Capture': LicensePlateCapture.objects.count(),
            'EV Charging Session': EvChargingSession.objects.count(),
            'Anomaly Event': AnomalyEvent.objects.count(),
            'Energy Grid Load': EnergyGridLoad.objects.count(),
            'Maintenance Log': MaintenanceLog.objects.count(),
        }
    }
    return render(request, 'iot_monitoring/home.html', context)


# ===========================================================================
# 1. BAY OCCUPANCY LOG
# ===========================================================================

def occupancy_list(request):
    q = request.GET.get('q', '').strip()
    rows = BayOccupancyLog.objects.select_related('bay').order_by('-detected_at')
    if q:
        rows = rows.filter(status__icontains=q) | rows.filter(bay__bay_number__icontains=q)
    rows = rows[:200]  # cap so the page stays fast on a 30,000+ row table
    return render(request, 'iot_monitoring/occupancy_list.html', {'rows': rows, 'q': q})


def occupancy_create(request):
    if request.method == 'POST':
        form = BayOccupancyLogForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, "Occupancy log entry added.")
            return redirect('occupancy_list')
    else:
        form = BayOccupancyLogForm(initial={'detected_at': timezone.now()})
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': 'Add Occupancy Log Entry'})


def occupancy_update(request, pk):
    obj = get_object_or_404(BayOccupancyLog, pk=pk)
    if request.method == 'POST':
        form = BayOccupancyLogForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            messages.success(request, "Occupancy log entry updated.")
            return redirect('occupancy_list')
    else:
        form = BayOccupancyLogForm(instance=obj)
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': f'Edit Occupancy Log #{pk}'})


def occupancy_delete(request, pk):
    obj = get_object_or_404(BayOccupancyLog, pk=pk)
    if request.method == 'POST':
        obj.delete()
        messages.success(request, "Occupancy log entry deleted.")
        return redirect('occupancy_list')
    return render(request, 'iot_monitoring/confirm_delete.html', {'object': obj, 'back_url': 'occupancy_list'})


# ===========================================================================
# 2. LICENSE PLATE CAPTURE
# ===========================================================================

def capture_list(request):
    q = request.GET.get('q', '').strip()
    rows = LicensePlateCapture.objects.select_related('bay').order_by('-captured_at')
    if q:
        rows = rows.filter(plate_number__icontains=q)
    rows = rows[:200]
    return render(request, 'iot_monitoring/capture_list.html', {'rows': rows, 'q': q})


def capture_create(request):
    if request.method == 'POST':
        form = LicensePlateCaptureForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, "Plate capture added.")
            return redirect('capture_list')
    else:
        form = LicensePlateCaptureForm(initial={'captured_at': timezone.now()})
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': 'Add Plate Capture'})


def capture_update(request, pk):
    obj = get_object_or_404(LicensePlateCapture, pk=pk)
    if request.method == 'POST':
        form = LicensePlateCaptureForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            messages.success(request, "Plate capture updated.")
            return redirect('capture_list')
    else:
        form = LicensePlateCaptureForm(instance=obj)
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': f'Edit Plate Capture #{pk}'})


def capture_delete(request, pk):
    obj = get_object_or_404(LicensePlateCapture, pk=pk)
    if request.method == 'POST':
        obj.delete()
        messages.success(request, "Plate capture deleted.")
        return redirect('capture_list')
    return render(request, 'iot_monitoring/confirm_delete.html', {'object': obj, 'back_url': 'capture_list'})


# ===========================================================================
# 3. EV CHARGING SESSION
# ===========================================================================

def session_list(request):
    q = request.GET.get('q', '').strip()
    rows = EvChargingSession.objects.select_related('station').order_by('-start_time')
    if q:
        rows = rows.filter(session_status__icontains=q)
    rows = rows[:200]
    return render(request, 'iot_monitoring/session_list.html', {'rows': rows, 'q': q})


def session_create(request):
    if request.method == 'POST':
        form = EvChargingSessionForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, "Charging session added.")
            return redirect('session_list')
    else:
        form = EvChargingSessionForm(initial={'start_time': timezone.now()})
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': 'Add Charging Session'})


def session_update(request, pk):
    obj = get_object_or_404(EvChargingSession, pk=pk)
    if request.method == 'POST':
        form = EvChargingSessionForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            messages.success(request, "Charging session updated.")
            return redirect('session_list')
    else:
        form = EvChargingSessionForm(instance=obj)
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': f'Edit Charging Session #{pk}'})


def session_delete(request, pk):
    obj = get_object_or_404(EvChargingSession, pk=pk)
    if request.method == 'POST':
        obj.delete()
        messages.success(request, "Charging session deleted.")
        return redirect('session_list')
    return render(request, 'iot_monitoring/confirm_delete.html', {'object': obj, 'back_url': 'session_list'})


# ===========================================================================
# 4. ANOMALY EVENT
# ===========================================================================

def anomaly_list(request):
    q = request.GET.get('q', '').strip()
    rows = AnomalyEvent.objects.select_related('bay').order_by('-detected_at')
    if q:
        rows = rows.filter(event_type__icontains=q) | rows.filter(severity__icontains=q)
    rows = rows[:200]
    return render(request, 'iot_monitoring/anomaly_list.html', {'rows': rows, 'q': q})


def anomaly_create(request):
    if request.method == 'POST':
        form = AnomalyEventForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, "Anomaly event added.")
            return redirect('anomaly_list')
    else:
        form = AnomalyEventForm(initial={'detected_at': timezone.now()})
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': 'Add Anomaly Event'})


def anomaly_update(request, pk):
    obj = get_object_or_404(AnomalyEvent, pk=pk)
    if request.method == 'POST':
        form = AnomalyEventForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            messages.success(request, "Anomaly event updated.")
            return redirect('anomaly_list')
    else:
        form = AnomalyEventForm(instance=obj)
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': f'Edit Anomaly Event #{pk}'})


def anomaly_delete(request, pk):
    obj = get_object_or_404(AnomalyEvent, pk=pk)
    if request.method == 'POST':
        obj.delete()
        messages.success(request, "Anomaly event deleted.")
        return redirect('anomaly_list')
    return render(request, 'iot_monitoring/confirm_delete.html', {'object': obj, 'back_url': 'anomaly_list'})


# ===========================================================================
# 5. ENERGY GRID LOAD
# ===========================================================================

def gridload_list(request):
    q = request.GET.get('q', '').strip()
    rows = EnergyGridLoad.objects.select_related('facility').order_by('-recorded_at')
    if q:
        rows = rows.filter(grid_status__icontains=q)
    rows = rows[:200]
    return render(request, 'iot_monitoring/gridload_list.html', {'rows': rows, 'q': q})


def gridload_create(request):
    if request.method == 'POST':
        form = EnergyGridLoadForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, "Grid load reading added.")
            return redirect('gridload_list')
    else:
        form = EnergyGridLoadForm(initial={'recorded_at': timezone.now()})
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': 'Add Grid Load Reading'})


def gridload_update(request, pk):
    obj = get_object_or_404(EnergyGridLoad, pk=pk)
    if request.method == 'POST':
        form = EnergyGridLoadForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            messages.success(request, "Grid load reading updated.")
            return redirect('gridload_list')
    else:
        form = EnergyGridLoadForm(instance=obj)
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': f'Edit Grid Load #{pk}'})


def gridload_delete(request, pk):
    obj = get_object_or_404(EnergyGridLoad, pk=pk)
    if request.method == 'POST':
        obj.delete()
        messages.success(request, "Grid load reading deleted.")
        return redirect('gridload_list')
    return render(request, 'iot_monitoring/confirm_delete.html', {'object': obj, 'back_url': 'gridload_list'})


# ===========================================================================
# 6. MAINTENANCE LOG
# ===========================================================================

def maintenance_list(request):
    q = request.GET.get('q', '').strip()
    rows = MaintenanceLog.objects.order_by('-reported_at')
    if q:
        rows = rows.filter(entity_type__icontains=q) | rows.filter(issue_description__icontains=q)
    rows = rows[:200]
    return render(request, 'iot_monitoring/maintenance_list.html', {'rows': rows, 'q': q})


def maintenance_create(request):
    if request.method == 'POST':
        form = MaintenanceLogForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, "Maintenance ticket added.")
            return redirect('maintenance_list')
    else:
        form = MaintenanceLogForm(initial={'reported_at': timezone.now()})
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': 'Add Maintenance Ticket'})


def maintenance_update(request, pk):
    obj = get_object_or_404(MaintenanceLog, pk=pk)
    if request.method == 'POST':
        form = MaintenanceLogForm(request.POST, instance=obj)
        if form.is_valid():
            form.save()
            messages.success(request, "Maintenance ticket updated.")
            return redirect('maintenance_list')
    else:
        form = MaintenanceLogForm(instance=obj)
    return render(request, 'iot_monitoring/generic_form.html',
                  {'form': form, 'title': f'Edit Maintenance Ticket #{pk}'})


def maintenance_delete(request, pk):
    obj = get_object_or_404(MaintenanceLog, pk=pk)
    if request.method == 'POST':
        obj.delete()
        messages.success(request, "Maintenance ticket deleted.")
        return redirect('maintenance_list')
    return render(request, 'iot_monitoring/confirm_delete.html', {'object': obj, 'back_url': 'maintenance_list'})


# ===========================================================================
# TASK 4 — TRANSACTION: Critical Anomaly Response
#
# Writes to FOUR tables as one atomic unit:
#   1. anomaly_event      (insert)
#   2. maintenance_log    (insert)
#   3. parking_bay        (update - take bay offline)
#   4. bay_occupancy_log  (insert - forced status change)
#
# transaction.atomic() is Django's wrapper around SQL's
# START TRANSACTION / COMMIT / ROLLBACK. If anything inside this block
# raises an exception, every write inside it is rolled back automatically.
# ===========================================================================

def handle_critical_anomaly(request):
    if request.method == 'POST':
        form = CriticalAnomalyForm(request.POST)
        if form.is_valid():
            bay = form.cleaned_data['bay']
            event_type = form.cleaned_data['event_type']
            issue_description = form.cleaned_data['issue_description']
            reported_by = form.cleaned_data['reported_by']

            try:
                with transaction.atomic():
                    # 1) Record the anomaly event
                    anomaly = AnomalyEvent.objects.create(
                        bay=bay, event_type=event_type, severity='CRITICAL',
                        detected_at=timezone.now()
                    )
                    # 2) Open a maintenance ticket
                    MaintenanceLog.objects.create(
                        entity_type='BAY', entity_id=bay.bay_id,
                        issue_description=issue_description,
                        reported_by=reported_by, reported_at=timezone.now()
                    )
                    # 3) Take the bay out of service immediately
                    bay.is_active = 0
                    bay.save()
                    # 4) Log the forced status change
                    BayOccupancyLog.objects.create(
                        bay=bay, status='UNKNOWN', detected_at=timezone.now()
                    )

                messages.success(
                    request,
                    f"Critical anomaly #{anomaly.event_id} logged for Bay {bay.bay_number}. "
                    f"Maintenance ticket opened and bay taken offline. (All 4 writes committed together.)"
                )
                return redirect('handle_critical_anomaly')
            except Exception as e:
                messages.error(request, f"Transaction failed and was rolled back: {e}")
    else:
        form = CriticalAnomalyForm()

    recent_responses = AnomalyEvent.objects.filter(severity='CRITICAL').select_related('bay').order_by('-detected_at')[:10]
    return render(request, 'iot_monitoring/critical_anomaly.html',
                  {'form': form, 'recent_responses': recent_responses})
