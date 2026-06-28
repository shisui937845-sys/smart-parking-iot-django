# Smart Parking — IoT & Real-Time Monitoring Django App

This is a working Django web application providing full CRUD (Create, Read,
Update, Delete) pages for the 6 tables in the IoT & Real-Time Monitoring
module, plus a multi-table transaction page (Task 4).

It connects to your EXISTING `smart_parking` MySQL database — it does not
create or modify any table structure. `managed = False` on every model in
`iot_monitoring/models.py` guarantees Django only reads/writes rows, never
touches schema.

## What's included

| Feature | Where |
|---|---|
| Models (6 tables + dependencies) | `iot_monitoring/models.py` |
| Forms | `iot_monitoring/forms.py` |
| CRUD views (24 views: 4 per table x 6 tables) | `iot_monitoring/views.py` |
| Task 4 transaction view | `handle_critical_anomaly` in `views.py` |
| URL routes | `iot_monitoring/urls.py` |
| Templates (list, form, delete-confirm, dashboard) | `iot_monitoring/templates/iot_monitoring/` |

## Pages

- `/` — dashboard with live row counts
- `/occupancy/`, `/captures/`, `/sessions/`, `/anomalies/`, `/gridload/`, `/maintenance/` — list + search pages
- `.../add/` — create form for each table
- `.../<id>/edit/` — update form for each table
- `.../<id>/delete/` — delete confirmation for each table
- `/critical-anomaly/` — **Task 4 transaction**: one form submission writes
  to 4 tables (anomaly_event, maintenance_log, parking_bay, bay_occupancy_log)
  atomically using Django's `transaction.atomic()`

## Setup (first time only)

1. Install Python packages:
   ```
   pip install django mysqlclient --break-system-packages
   ```
   (On Windows/Mac without `--break-system-packages`, just `pip install django mysqlclient`.
   If `mysqlclient` fails to install, you can swap to `pymysql` instead — ask if you hit this.)

2. Make sure your MySQL/MariaDB server is running and the `smart_parking`
   database (from your Assignment 1 / report SQL files) already exists with
   data loaded.

3. Check `parking_system/settings.py` → `DATABASES` block matches your local
   MySQL username/password (default assumes `root` with no password on
   `localhost:3306` — change this if yours differs).

## Running it

```
cd parking_system
python manage.py runserver
```

Then open **http://127.0.0.1:8000/** in your browser.

## For your demo (2nd July)

Suggested order to show the class:
1. Open `/` — show the live dashboard pulling real counts from MySQL.
2. Open `/anomalies/` — show search, then click "Edit" on a row to show Update.
3. Click "+ Add Anomaly" — show Create.
4. Click "Delete" on a row — show the confirm-delete page, then confirm.
5. Open `/critical-anomaly/` — explain it writes to 4 tables in one
   transaction, submit it, then immediately show in MySQL (or refresh
   `/anomalies/`, `/maintenance/`, `/occupancy/`) that all 4 tables changed
   together.

## Notes on design choices (useful if asked questions in the demo)

- **Why `managed = False`?** These tables already exist with data from
  Assignment 1; Django must not try to create or alter them.
- **Why `select_related()` in the list views?** Avoids the N+1 query
  problem — e.g. `occupancy_list` would otherwise run one extra query per
  row just to fetch each row's bay number.
- **Why is the list capped at 200 rows?** Some tables have 25,000–30,000+
  rows; rendering all of them in one HTML page would be slow. Production
  systems would paginate; this caps results and relies on the search box
  to narrow down further.
- **Why `transaction.atomic()` for the critical anomaly form?** It wraps
  all 4 writes so that if any one of them fails, all are rolled back —
  the bay should never end up "offline" without a matching anomaly record
  and maintenance ticket, or vice versa.
