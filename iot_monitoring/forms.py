from django import forms
from .models import (
    BayOccupancyLog, LicensePlateCapture, EvChargingSession,
    AnomalyEvent, EnergyGridLoad, MaintenanceLog,
)

# A shared widget style so every form field looks consistent without
# repeating the same CSS class on every single field.
WIDGET_ATTRS = {'class': 'form-control'}


class BayOccupancyLogForm(forms.ModelForm):
    class Meta:
        model = BayOccupancyLog
        fields = ['bay', 'status', 'detected_at']
        widgets = {
            'bay': forms.Select(attrs=WIDGET_ATTRS),
            'status': forms.Select(attrs=WIDGET_ATTRS),
            'detected_at': forms.DateTimeInput(attrs={**WIDGET_ATTRS, 'type': 'datetime-local'}),
        }


class LicensePlateCaptureForm(forms.ModelForm):
    class Meta:
        model = LicensePlateCapture
        fields = ['bay', 'plate_number', 'confidence_score', 'captured_at', 'capture_type']
        widgets = {
            'bay': forms.Select(attrs=WIDGET_ATTRS),
            'plate_number': forms.TextInput(attrs=WIDGET_ATTRS),
            'confidence_score': forms.NumberInput(attrs={**WIDGET_ATTRS, 'step': '0.01', 'min': '0', 'max': '1'}),
            'captured_at': forms.DateTimeInput(attrs={**WIDGET_ATTRS, 'type': 'datetime-local'}),
            'capture_type': forms.Select(attrs=WIDGET_ATTRS),
        }


class EvChargingSessionForm(forms.ModelForm):
    class Meta:
        model = EvChargingSession
        fields = ['station', 'start_time', 'end_time', 'energy_delivered_kwh', 'peak_power_kw', 'session_status']
        widgets = {
            'station': forms.Select(attrs=WIDGET_ATTRS),
            'start_time': forms.DateTimeInput(attrs={**WIDGET_ATTRS, 'type': 'datetime-local'}),
            'end_time': forms.DateTimeInput(attrs={**WIDGET_ATTRS, 'type': 'datetime-local'}),
            'energy_delivered_kwh': forms.NumberInput(attrs={**WIDGET_ATTRS, 'step': '0.01'}),
            'peak_power_kw': forms.NumberInput(attrs={**WIDGET_ATTRS, 'step': '0.1'}),
            'session_status': forms.Select(attrs=WIDGET_ATTRS),
        }


class AnomalyEventForm(forms.ModelForm):
    class Meta:
        model = AnomalyEvent
        fields = ['bay', 'event_type', 'severity', 'detected_at', 'resolved_at', 'resolution_notes']
        widgets = {
            'bay': forms.Select(attrs=WIDGET_ATTRS),
            'event_type': forms.Select(attrs=WIDGET_ATTRS),
            'severity': forms.Select(attrs=WIDGET_ATTRS),
            'detected_at': forms.DateTimeInput(attrs={**WIDGET_ATTRS, 'type': 'datetime-local'}),
            'resolved_at': forms.DateTimeInput(attrs={**WIDGET_ATTRS, 'type': 'datetime-local'}),
            'resolution_notes': forms.Textarea(attrs={**WIDGET_ATTRS, 'rows': 3}),
        }


class EnergyGridLoadForm(forms.ModelForm):
    class Meta:
        model = EnergyGridLoad
        fields = ['facility', 'recorded_at', 'total_load_kw', 'available_capacity_kw', 'grid_status']
        widgets = {
            'facility': forms.Select(attrs=WIDGET_ATTRS),
            'recorded_at': forms.DateTimeInput(attrs={**WIDGET_ATTRS, 'type': 'datetime-local'}),
            'total_load_kw': forms.NumberInput(attrs={**WIDGET_ATTRS, 'step': '0.01'}),
            'available_capacity_kw': forms.NumberInput(attrs={**WIDGET_ATTRS, 'step': '0.01'}),
            'grid_status': forms.Select(attrs=WIDGET_ATTRS),
        }


class MaintenanceLogForm(forms.ModelForm):
    class Meta:
        model = MaintenanceLog
        fields = ['entity_type', 'entity_id', 'issue_description', 'reported_by',
                  'reported_at', 'resolved_at', 'resolution_notes']
        widgets = {
            'entity_type': forms.Select(attrs=WIDGET_ATTRS),
            'entity_id': forms.NumberInput(attrs=WIDGET_ATTRS),
            'issue_description': forms.Textarea(attrs={**WIDGET_ATTRS, 'rows': 2}),
            'reported_by': forms.TextInput(attrs=WIDGET_ATTRS),
            'reported_at': forms.DateTimeInput(attrs={**WIDGET_ATTRS, 'type': 'datetime-local'}),
            'resolved_at': forms.DateTimeInput(attrs={**WIDGET_ATTRS, 'type': 'datetime-local'}),
            'resolution_notes': forms.Textarea(attrs={**WIDGET_ATTRS, 'rows': 2}),
        }


class CriticalAnomalyForm(forms.Form):
    """
    Plain (non-ModelForm) form for Task 4's transaction: it doesn't map to
    one single model, since the transaction writes to FOUR tables at once.
    """
    bay = forms.ModelChoiceField(
        queryset=None, widget=forms.Select(attrs=WIDGET_ATTRS),
        label="Affected bay"
    )
    event_type = forms.ChoiceField(
        choices=AnomalyEvent.EVENT_TYPE_CHOICES, widget=forms.Select(attrs=WIDGET_ATTRS)
    )
    issue_description = forms.CharField(
        widget=forms.Textarea(attrs={**WIDGET_ATTRS, 'rows': 3}),
        max_length=200, label="Issue description (for the maintenance ticket)"
    )
    reported_by = forms.CharField(
        widget=forms.TextInput(attrs=WIDGET_ATTRS), max_length=50,
        label="Technician / reporter ID"
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        from .models import ParkingBay
        self.fields['bay'].queryset = ParkingBay.objects.filter(is_active=1).order_by('bay_id')
