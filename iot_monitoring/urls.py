from django.urls import path
from . import views

urlpatterns = [
    path('', views.home, name='home'),

    # 1. Bay Occupancy Log
    path('occupancy/', views.occupancy_list, name='occupancy_list'),
    path('occupancy/add/', views.occupancy_create, name='occupancy_create'),
    path('occupancy/<int:pk>/edit/', views.occupancy_update, name='occupancy_update'),
    path('occupancy/<int:pk>/delete/', views.occupancy_delete, name='occupancy_delete'),

    # 2. License Plate Capture
    path('captures/', views.capture_list, name='capture_list'),
    path('captures/add/', views.capture_create, name='capture_create'),
    path('captures/<int:pk>/edit/', views.capture_update, name='capture_update'),
    path('captures/<int:pk>/delete/', views.capture_delete, name='capture_delete'),

    # 3. EV Charging Session
    path('sessions/', views.session_list, name='session_list'),
    path('sessions/add/', views.session_create, name='session_create'),
    path('sessions/<int:pk>/edit/', views.session_update, name='session_update'),
    path('sessions/<int:pk>/delete/', views.session_delete, name='session_delete'),

    # 4. Anomaly Event
    path('anomalies/', views.anomaly_list, name='anomaly_list'),
    path('anomalies/add/', views.anomaly_create, name='anomaly_create'),
    path('anomalies/<int:pk>/edit/', views.anomaly_update, name='anomaly_update'),
    path('anomalies/<int:pk>/delete/', views.anomaly_delete, name='anomaly_delete'),

    # 5. Energy Grid Load
    path('gridload/', views.gridload_list, name='gridload_list'),
    path('gridload/add/', views.gridload_create, name='gridload_create'),
    path('gridload/<int:pk>/edit/', views.gridload_update, name='gridload_update'),
    path('gridload/<int:pk>/delete/', views.gridload_delete, name='gridload_delete'),

    # 6. Maintenance Log
    path('maintenance/', views.maintenance_list, name='maintenance_list'),
    path('maintenance/add/', views.maintenance_create, name='maintenance_create'),
    path('maintenance/<int:pk>/edit/', views.maintenance_update, name='maintenance_update'),
    path('maintenance/<int:pk>/delete/', views.maintenance_delete, name='maintenance_delete'),

    # Task 4 — Transaction
    path('critical-anomaly/', views.handle_critical_anomaly, name='handle_critical_anomaly'),
]
