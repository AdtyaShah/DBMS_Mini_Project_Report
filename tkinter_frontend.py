###############################################################
# Weather App - FINAL Tkinter Version (FULLY CORRECTED)
# ✅ Full CRUD for all tables (Admin)
# ✅ Real-time notifications to users (popups + list view)
# ✅ Alerts, Metrics, Forecast, Report generation
# ✅ FIXED: CRUD operations and global thread scope error
# ✅ IMPROVED: Report viewer with "Open File" button (Download substitute)
###############################################################

import ttkbootstrap as ttk
from ttkbootstrap.constants import *
import tkinter as tk
from tkinter import messagebox, filedialog
from datetime import datetime, timedelta
import mysql.connector
import hashlib
import pandas as pd
import os
import threading
import time
from queue import Queue, Empty
import sys # Needed for os.startfile / os.system

# --------------------------------------------------------------
# DB Connection
# --------------------------------------------------------------
def db_connect():
    # IMPORTANT: CHANGE these credentials to match your MySQL setup
    return mysql.connector.connect(
        host="localhost",
        user="root",              
        password="Arihant@1008",  
        database="weather_app_db",
        port=3306
    )

# --------------------------------------------------------------
# Helpers
# --------------------------------------------------------------
def hash_password(password: str) -> str:
    # Use SHA256 for consistent password hashing
    return hashlib.sha256(password.encode()).hexdigest()

def fetch_all(query, params=()):
    try:
        db = db_connect()
        cur = db.cursor()
        cur.execute(query, params)
        rows = cur.fetchall()
        cur.close(); db.close()
        return rows
    except mysql.connector.Error as err:
        messagebox.showerror("Database Read Error", f"Error: {err}")
        return []

def execute(query, params=()):
    try:
        db = db_connect()
        cur = db.cursor()
        cur.execute(query, params)
        db.commit()
        lastid = cur.lastrowid
        cur.close(); db.close()
        return lastid
    except mysql.connector.Error as err:
        raise # Re-raise to stop the calling function (insert/update/delete)

# --------------------------------------------------------------
# TABLE DEFINITIONS FOR CRUD
# --------------------------------------------------------------
TABLE_CONFIG = {
    "Location":      {"pk": "location_id",      "columns": ["location_id","city","state","country","latitude","longitude","timezone"]},
    "Weather_Station":{"pk": "station_id",      "columns": ["station_id","station_name","location_id","api_id","installed_date","status"]},
    "Weather_Metrics":{"pk": "metric_id",       "columns": ["metric_id","station_id","timestamp","temperature","humidity","wind_speed","pressure","uv_index"]},
    "Forecast":      {"pk":"forecast_id",       "columns": ["forecast_id","location_id","forecast_date","high_temp","low_temp","weather_condition","precipitation_chance"]},
    "Alerts":        {"pk":"alert_id",          "columns": ["alert_id","alert_type","raised_by","severity","message","location_id","issue_time","expiry_time"]},
    "Admin_Role":    {"pk":"admin_role_id",     "columns": ["admin_role_id","user_id","email","permissions"]},
    "User":          {"pk":"user_id",           "columns": ["user_id","name","username","password","role"]},
    "Report":        {"pk":"report_id",         "columns": ["report_id","user_id","name","generated_date","report_type","file_path"]},
    "Notification":  {"pk":"notification_id",   "columns": ["notification_id","user_id","alert_id","date_time","status","delivery_method","string"]},
}

# --------------------------------------------------------------
# Global (login info + notification queue)
# --------------------------------------------------------------
LOGGED_IN_USER_ID = None
LOGGED_IN_ROLE = None
notif_thread_stop = threading.Event()
_notification_queue = Queue()
thread = threading.Thread() 


# --------------------------------------------------------------
# Background Notif Polling Thread
# --------------------------------------------------------------
def notification_poller(stop_flag):
    while not stop_flag.is_set():
        if LOGGED_IN_USER_ID and LOGGED_IN_ROLE == "standard":
            rows = fetch_all("""
                SELECT notification_id, string
                FROM Notification
                WHERE user_id=%s AND status='pending'
            """, (LOGGED_IN_USER_ID,))
            for nid, msg in rows:
                _notification_queue.put((nid, msg))
        time.sleep(2)

def process_notification_queue():
    try:
        while True:
            nid, msg = _notification_queue.get_nowait()
            root.lift() 
            messagebox.showinfo("🔔 New Weather Alert", msg)
            execute("UPDATE Notification SET status='seen' WHERE notification_id=%s", (nid,))
    except Empty:
        pass
    root.after(400, process_notification_queue)


# --------------------------------------------------------------
# Register User Window (omitted for brevity)
# --------------------------------------------------------------
def open_register_window():
    win = ttk.Toplevel(root); win.title("Register User"); win.geometry("360x260")
    ttk.Label(win, text="Name").pack(anchor="w", padx=12)
    name = ttk.Entry(win); name.pack(fill="x", padx=12)

    ttk.Label(win, text="Username").pack(anchor="w", padx=12)
    username = ttk.Entry(win); username.pack(fill="x", padx=12)

    ttk.Label(win, text="Password").pack(anchor="w", padx=12)
    password = ttk.Entry(win, show="*"); password.pack(fill="x", padx=12)

    def submit():
        try:
            execute(
                "INSERT INTO User(name,username,password,role) VALUES (%s,%s,%s,%s)",
                (name.get(), username.get(), hash_password(password.get()), "standard")
            )
            messagebox.showinfo("✅ Success", "User Registered")
            win.destroy()
        except Exception as e:
            messagebox.showerror("Registration Error", f"Failed to register user: {e}")

    ttk.Button(win, text="Register", bootstyle="success", command=submit).pack(pady=10)


# --------------------------------------------------------------
# Register Admin Window (omitted for brevity)
# --------------------------------------------------------------
def open_admin_register_window():
    win = ttk.Toplevel(root); win.title("Register Admin"); win.geometry("360x310")

    ttk.Label(win, text="Name").pack(anchor="w", padx=12)
    name = ttk.Entry(win); name.pack(fill="x", padx=12)

    ttk.Label(win, text="Username").pack(anchor="w", padx=12)
    username = ttk.Entry(win); username.pack(fill="x", padx=12)

    ttk.Label(win, text="Password").pack(anchor="w", padx=12)
    password = ttk.Entry(win, show="*"); password.pack(fill="x", padx=12)

    ttk.Label(win, text="Email").pack(anchor="w", padx=12)
    email = ttk.Entry(win); email.pack(fill="x", padx=12)

    def submit():
        try:
            uid = execute(
                "INSERT INTO User(name,username,password,role) VALUES (%s,%s,%s,%s)",
                (name.get(), username.get(), hash_password(password.get()), "admin")
            )
            execute("INSERT INTO Admin_Role(user_id,email,permissions) VALUES (%s,%s,%s)",
                    (uid, email.get(), "FULL_CONTROL"))
            messagebox.showinfo("✅ Success", "Admin Registered")
            win.destroy()
        except Exception as e:
            messagebox.showerror("Registration Error", f"Failed to register admin: {e}")

    ttk.Button(win, text="Register Admin", bootstyle="danger", command=submit).pack(pady=10)


# --------------------------------------------------------------
# LOGIN - FIXED scope error (omitted for brevity)
# --------------------------------------------------------------
def login(username_entry, password_entry):
    global LOGGED_IN_USER_ID, LOGGED_IN_ROLE, notif_thread_stop
    global thread 

    rows = fetch_all(
        "SELECT user_id, role FROM User WHERE username=%s AND password=%s",
        (username_entry.get(), hash_password(password_entry.get()))
    )
    if not rows:
        messagebox.showerror("❌ Error", "Invalid credentials")
        return

    LOGGED_IN_USER_ID, LOGGED_IN_ROLE = rows[0]
    messagebox.showinfo("Login Success", f"Welcome, {LOGGED_IN_USER_ID} ({LOGGED_IN_ROLE})!")

    if thread.is_alive():
        notif_thread_stop.set()
        thread.join()

    if LOGGED_IN_ROLE == "standard":
        notif_thread_stop.clear()
        thread = threading.Thread(target=notification_poller, args=(notif_thread_stop,), daemon=True)
        thread.start()
        process_notification_queue()
        open_user_dashboard()

    elif LOGGED_IN_ROLE == "admin":
        open_admin_dashboard()
        
    password_entry.delete(0, tk.END)


# --------------------------------------------------------------
# CRUD Screen (Auto generated) - FIXED (omitted for brevity)
# --------------------------------------------------------------
def open_crud_screen(table_name):
    cfg = TABLE_CONFIG[table_name]
    pk = cfg["pk"]
    cols = cfg["columns"]

    win = ttk.Toplevel(root); win.title(f"Manage {table_name}"); win.geometry("1050x620")
    left = ttk.Frame(win, padding=10); left.pack(side="left", fill="y")

    tree = ttk.Treeview(win, columns=cols, show="headings")
    tree.pack(fill="both", expand=True)

    for c in cols:
        tree.heading(c, text=c)
        tree.column(c, width=130)

    entries = {}
    for c in cols:
        ttk.Label(left, text=c).pack(anchor="w")
        e = ttk.Entry(left)
        if c == pk:
             e.config(state='readonly')
        e.pack(fill="x")
        entries[c] = e
        
    def clear_entries():
        for c, e in entries.items():
            state = e.cget("state")
            e.config(state='normal')
            e.delete(0, tk.END)
            if c == pk:
                 e.config(state='readonly')
            else:
                 e.config(state=state)


    def refresh():
        tree.delete(*tree.get_children())
        clear_entries()
        for r in fetch_all(f"SELECT * FROM {table_name}"):
            tree.insert("", tk.END, values=r)


    def insert():
        try:
            no_pk_cols = [c for c in cols if c != pk]
            vals_for_db = []
            
            for c in no_pk_cols:
                val = entries[c].get()
                if c == "password" and table_name == "User" and val:
                    vals_for_db.append(hash_password(val))
                elif val.strip() == "":
                    vals_for_db.append(None)
                else:
                    vals_for_db.append(val)

            execute(
                f"INSERT INTO {table_name} ({','.join(no_pk_cols)}) VALUES ({','.join(['%s']*len(no_pk_cols))})",
                vals_for_db
            )
            refresh()
        except Exception as e:
            messagebox.showerror("Insert Error", str(e))


    def update():
        try:
            set_cols = [c for c in cols if c != pk]
            set_vals = []
            
            for c in set_cols:
                val = entries[c].get()
                if c == "password" and table_name == "User" and val and not (val.startswith("hashed_pw") or len(val) == 64):
                    set_vals.append(hash_password(val))
                elif val.strip() == "":
                    set_vals.append(None)
                else:
                    set_vals.append(val)

            pk_val = entries[pk].get()
            if not pk_val:
                messagebox.showerror("Update Error", "Primary Key value is required for update.")
                return

            all_vals = set_vals + [pk_val]

            execute(
                f"UPDATE {table_name} SET {','.join([c+'=%s' for c in set_cols])} WHERE {pk}=%s",
                all_vals
            )
            refresh()
        except Exception as e:
            messagebox.showerror("Update Error", str(e))


    def delete():
        try:
            pk_val = entries[pk].get()
            if not pk_val:
                messagebox.showerror("Delete Error", "Primary Key value is required for delete.")
                return
            
            confirm = messagebox.askyesno("Confirm Delete", f"Are you sure you want to delete {table_name} with ID {pk_val}?")
            if confirm:
                execute(f"DELETE FROM {table_name} WHERE {pk}=%s", (pk_val,))
                refresh()
        except Exception as e:
            messagebox.showerror("Delete Error", str(e))


    def select_row(_):
        try:
            selected_item = tree.selection()
            if not selected_item:
                clear_entries()
                return

            vals = tree.item(selected_item[0])["values"]
            clear_entries()

            for i, c in enumerate(cols):
                e = entries[c]
                e.config(state='normal')
                e.insert(0, vals[i])
                if c == pk:
                    e.config(state='readonly')

        except Exception as e:
             messagebox.showerror("Selection Error", str(e))


    tree.bind("<<TreeviewSelect>>", select_row)

    ttk.Button(left, text="Add", bootstyle="success", command=insert).pack(pady=3, fill="x")
    ttk.Button(left, text="Update", bootstyle="warning", command=update).pack(pady=3, fill="x")
    ttk.Button(left, text="Delete", bootstyle="danger", command=delete).pack(pady=3, fill="x")
    ttk.Button(left, text="Refresh", bootstyle="secondary", command=refresh).pack(pady=3, fill="x")

    refresh()


# --------------------------------------------------------------
# ALERT QUICK CREATE (Admin) (omitted for brevity)
# --------------------------------------------------------------
def open_raise_alert():
    win = ttk.Toplevel(root); win.title("Raise Alert"); win.geometry("350x420")

    ttk.Label(win, text="Alert Type").pack(anchor="w")
    t = ttk.Entry(win); t.pack(fill="x")

    ttk.Label(win, text="Severity").pack(anchor="w")
    sev = ttk.Entry(win); sev.pack(fill="x")

    ttk.Label(win, text="Message").pack(anchor="w")
    txt = tk.Text(win, height=4); txt.pack(fill="x")

    ttk.Label(win, text="Location").pack(anchor="w")
    locations = fetch_all("SELECT location_id, city, country FROM Location")
    loc_options = [f"{r[0]} - {r[1]}, {r[2]}" for r in locations]
    loc = ttk.Combobox(win, values=loc_options, state="readonly")
    loc.pack(fill="x")

    def create():
        try:
            location_id = loc.get().split(" - ")[0]
            if not location_id:
                 messagebox.showerror("Input Error", "Please select a location.")
                 return
                 
            execute("""
                INSERT INTO Alerts(alert_type, raised_by, severity, message, location_id, issue_time, expiry_time)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
            """, (t.get(), LOGGED_IN_USER_ID, sev.get(), txt.get("1.0","end").strip(),
                  location_id, datetime.now(), datetime.now() + timedelta(hours=3)))
            messagebox.showinfo("✅ Alert Created", "Users will be notified!")
            win.destroy()
        except Exception as e:
            messagebox.showerror("Alert Creation Error", str(e))

    ttk.Button(win, text="Create Alert", bootstyle="danger", command=create).pack(pady=12)


# --------------------------------------------------------------
# USER NOTIFICATION VIEW (omitted for brevity)
# --------------------------------------------------------------
def view_notifications_window():
    win = ttk.Toplevel(root); win.title("Notifications"); win.geometry("700x420")

    cols = ["ID","Alert Type","Status","Time","Delivery"]
    tree = ttk.Treeview(win, columns=cols, show="headings")
    tree.pack(fill="both", expand=True)

    for c in cols:
        tree.heading(c, text=c)
        tree.column(c, width=120 if c!="Alert Type" else 200)

    rows = fetch_all("""
        SELECT N.notification_id, A.alert_type, N.status, N.date_time, N.delivery_method
        FROM Notification N
        JOIN Alerts A ON N.alert_id = A.alert_id
        WHERE N.user_id=%s ORDER BY N.date_time DESC
    """, (LOGGED_IN_USER_ID,))
    for r in rows: tree.insert("", tk.END, values=r)


# --------------------------------------------------------------
# VIEWER FUNCTIONS (omitted for brevity)
# --------------------------------------------------------------
def view_alerts_window():
    win = ttk.Toplevel(root); win.title("Active Alerts"); win.geometry("750x400")
    cols = ["Type","Severity","Message","Location","Issued","Expires"]
    tree = ttk.Treeview(win, columns=cols, show="headings")
    tree.pack(fill="both", expand=True)
    for c in cols: tree.heading(c, text=c)
    rows = fetch_all("""
        SELECT A.alert_type, A.severity, A.message,
               IFNULL(L.city, CONCAT('id:',A.location_id)),
               A.issue_time, A.expiry_time
        FROM Alerts A
        LEFT JOIN Location L ON A.location_id=L.location_id
        WHERE A.expiry_time > NOW()
        ORDER BY A.issue_time DESC;
    """)
    for r in rows: tree.insert("", tk.END, values=r)

def view_metrics_dashboard():
    win = ttk.Toplevel(root); win.title("Weather Metrics"); win.geometry("900x600")
    ttk.Label(win, text="Choose Location").pack(pady=5)
    loc_data = fetch_all("SELECT location_id, city FROM Location")
    loc_options = [f"{r[0]} - {r[1]}" for r in loc_data]
    loc = ttk.Combobox(win, values=loc_options, state="readonly")
    loc.pack(fill="x", padx=10, pady=5)
    if loc_options: loc.set(loc_options[0])
    container = ttk.Frame(win); container.pack(fill="both", expand=True, padx=10, pady=10)
    canvas = tk.Canvas(container); canvas.pack(side="left", fill="both", expand=True)
    scroll = ttk.Scrollbar(container, orient="vertical", command=canvas.yview)
    scroll.pack(side="right", fill="y")
    canvas.configure(yscrollcommand=scroll.set)
    inner = ttk.Frame(canvas); canvas.create_window((0, 0), window=inner, anchor="nw")
    inner.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))

    def load():
        for w in inner.winfo_children(): w.destroy()
        if not loc.get(): return
        locid = loc.get().split(" - ")[0]
        stations = fetch_all("SELECT station_id, station_name FROM Weather_Station WHERE location_id=%s",(locid,))
        if not stations:
             ttk.Label(inner, text="No active stations for this location.", font=("Segoe UI", 12)).pack(pady=20)
             return
        for sid, nm in stations:
            data = fetch_all("""
                SELECT temperature,humidity,wind_speed,pressure,uv_index,timestamp
                FROM Weather_Metrics WHERE station_id=%s ORDER BY timestamp DESC LIMIT 1
            """, (sid,))
            f = ttk.LabelFrame(inner, text=f"{nm} (ID:{sid})", padding=10); f.pack(fill="x", pady=6, padx=5)
            f.columnconfigure(0, weight=1); f.columnconfigure(1, weight=1)
            if data:
                t,h,w,p,uv,ts = data[0]
                ttk.Label(f, text=f"Updated: {ts}").grid(row=0,column=0,sticky="w", columnspan=2)
                ttk.Label(f, text=f"Temperature: {t} °C", bootstyle="primary").grid(row=1,column=0, sticky="w")
                ttk.Label(f, text=f"Humidity: {h}%", bootstyle="info").grid(row=1,column=1, sticky="w")
                ttk.Label(f, text=f"Wind: {w} m/s", bootstyle="info").grid(row=2,column=0, sticky="w")
                ttk.Label(f, text=f"Pressure: {p} hPa", bootstyle="info").grid(row=2,column=1, sticky="w")
                ttk.Label(f, text=f"UV Index: {uv}", bootstyle="danger").grid(row=3,column=0, sticky="w")
            else:
                ttk.Label(f, text="No recent metrics available").pack()
    ttk.Button(win, text="Load Metrics", bootstyle="primary", command=load).pack(pady=8)
    if loc.get(): load()


def view_forecast_window():
    win = ttk.Toplevel(root); win.title("Forecast"); win.geometry("700x400")
    ttk.Label(win, text="Choose Location").pack(pady=5)
    loc_data = fetch_all("SELECT location_id, city FROM Location")
    loc_options = [f"{r[0]} - {r[1]}" for r in loc_data]
    loc = ttk.Combobox(win, values=loc_options, state="readonly")
    loc.pack(fill="x", padx=10, pady=5)
    if loc_options: loc.set(loc_options[0])
    cols=["Date","Location","High","Low","Condition","Chance"]
    tree = ttk.Treeview(win, columns=cols, show="headings"); tree.pack(fill="both", expand=True)
    for c in cols: tree.heading(c, text=c)
    def load():
        tree.delete(*tree.get_children())
        if not loc.get(): return
        locid = loc.get().split(" - ")[0]
        rows = fetch_all("""
            SELECT F.forecast_date, L.city, F.high_temp, F.low_temp, F.weather_condition, F.precipitation_chance
            FROM Forecast F LEFT JOIN Location L ON F.location_id=L.location_id
            WHERE F.location_id=%s AND F.forecast_date >= CURDATE()
            ORDER BY F.forecast_date ASC
        """,(locid,))
        for r in rows: tree.insert("", tk.END, values=r)
    ttk.Button(win, text="Load Forecast", bootstyle="primary", command=load).pack(pady=8)
    if loc.get(): load()


def generate_report_window():
    win = ttk.Toplevel(root); win.title("Generate CSV Report"); win.geometry("450x350")
    ttk.Label(win, text="Report Name").pack(anchor="w", padx=10, pady=(5,0))
    rep = ttk.Entry(win); rep.pack(fill="x", padx=10)
    ttk.Label(win, text="Select Type").pack(anchor="w", padx=10, pady=(5,0))
    combo = ttk.Combobox(win, values=["metrics","forecast","alerts"], state="readonly")
    combo.pack(fill="x", padx=10)
    combo.set("metrics")
    ttk.Label(win, text="Select Location (Optional for Alerts)").pack(anchor="w", padx=10, pady=(5,0))
    loc_data = fetch_all("SELECT location_id, city FROM Location")
    loc_options = [f"{r[0]} - {r[1]}" for r in loc_data]
    loc = ttk.Combobox(win, values=loc_options)
    loc.pack(fill="x", padx=10)

    def generate():
        try:
            name, rtype = rep.get(), combo.get()
            loc_input = loc.get()
            locid = loc_input.split(" - ")[0] if loc_input else None
            
            if not name or not rtype:
                 messagebox.showerror("Input Error", "Report name and type are required.")
                 return

            db = db_connect(); cur = db.cursor()

            if rtype == "metrics":
                if not locid: raise ValueError("Location required for Metrics report.")
                cur.execute("""
                    SELECT WM.metric_id, WM.station_id, S.station_name, WM.timestamp, WM.temperature,
                           WM.humidity, WM.wind_speed, WM.pressure, WM.uv_index
                    FROM Weather_Metrics WM
                    JOIN Weather_Station S ON WM.station_id=S.station_id
                    WHERE S.location_id=%s ORDER BY WM.timestamp DESC
                """,(locid,))
            elif rtype == "forecast":
                if not locid: raise ValueError("Location required for Forecast report.")
                cur.execute("""
                    SELECT F.forecast_id, F.location_id, L.city, F.forecast_date, F.high_temp,
                           F.low_temp, F.weather_condition, F.precipitation_chance
                    FROM Forecast F JOIN Location L ON F.location_id=L.location_id
                    WHERE F.location_id=%s ORDER BY F.forecast_date ASC
                """,(locid,))
            else:
                cur.execute("""
                    SELECT A.alert_id, A.alert_type, A.severity, A.message, A.issue_time, L.city
                    FROM Alerts A LEFT JOIN Location L ON A.location_id=L.location_id
                    ORDER BY A.issue_time DESC
                """)

            rows = cur.fetchall()
            if not rows:
                 messagebox.showinfo("No Data", "No data found for the selected report criteria.")
                 cur.close(); db.close()
                 return
                 
            cols = [d[0] for d in cur.description]
            saveas = filedialog.asksaveasfilename(defaultextension=".csv", initialfile=f"{name}_{rtype}_{datetime.now().strftime('%Y%m%d')}")
            
            if saveas:
                pd.DataFrame(rows, columns=cols).to_csv(saveas, index=False)
    
                execute("INSERT INTO Report(user_id, name, generated_date, report_type, file_path) VALUES (%s,%s,%s,%s,%s)",
                        (LOGGED_IN_USER_ID, name, datetime.now(), rtype, saveas))
                
                # IMPROVED: Display the file path to the user
                messagebox.showinfo("✅ Done", f"Report successfully saved.\n\nFile Path:\n{saveas}")
            
            cur.close(); db.close()
            
        except Exception as e:
            messagebox.showerror("Report Error", str(e))

    ttk.Button(win, text="Generate", bootstyle="success", command=generate).pack(pady=10)


# --------------------------------------------------------------
# NEW: Report Viewer Window (for opening saved files)
# --------------------------------------------------------------
def open_reports_viewer():
    win = ttk.Toplevel(root); win.title("View Saved Reports"); win.geometry("800x450")
    
    cols = ["ID", "Name", "Generated Date", "Type", "File Path"]
    tree = ttk.Treeview(win, columns=cols, show="headings")
    tree.pack(fill="both", expand=True)

    for c in cols:
        tree.heading(c, text=c)
        if c == "File Path":
             tree.column(c, width=300)
        else:
             tree.column(c, width=120)

    def refresh_reports():
        tree.delete(*tree.get_children())
        rows = fetch_all("""
            SELECT report_id, name, generated_date, report_type, file_path
            FROM Report
            WHERE user_id = %s OR %s = 'admin'  -- Show all for admin, own for standard
            ORDER BY generated_date DESC
        """, (LOGGED_IN_USER_ID, LOGGED_IN_ROLE))
        for r in rows: 
            # Ensure path is handled as string, not None
            path = r[4] if r[4] else "N/A"
            tree.insert("", tk.END, values=(r[0], r[1], r[2], r[3], path))
    
    def open_selected_file():
        selected_item = tree.selection()
        if not selected_item:
            messagebox.showerror("Error", "Please select a report first.")
            return

        values = tree.item(selected_item[0])["values"]
        file_path = values[4] # File Path is the 5th column (index 4)
        
        if file_path == "N/A" or not os.path.exists(file_path):
             messagebox.showerror("File Error", f"File not found or path is invalid:\n{file_path}")
             return

        try:
            # Use appropriate command for opening file across OSes
            if sys.platform == "win32":
                os.startfile(file_path) # Windows
            elif sys.platform == "darwin":
                os.system(f'open "{file_path}"') # macOS
            else:
                os.system(f'xdg-open "{file_path}"') # Linux (generic)
        except Exception as e:
            messagebox.showerror("Error", f"Failed to open file: {e}")
            
    
    button_frame = ttk.Frame(win, padding=5); button_frame.pack(fill="x")
    ttk.Button(button_frame, text="Refresh List", command=refresh_reports).pack(side="left", padx=5)
    ttk.Button(button_frame, text="Open Selected File (Download)", bootstyle="success", command=open_selected_file).pack(side="left", padx=5)

    refresh_reports()


# --------------------------------------------------------------
# DASHBOARDS
# --------------------------------------------------------------
def open_admin_dashboard():
    win = ttk.Toplevel(root); win.title("Admin Dashboard"); win.geometry("470x650")

    ttk.Label(win, text="ADMIN DASHBOARD", font=("Segoe UI", 18)).pack(pady=10)

    for t in TABLE_CONFIG.keys():
        ttk.Button(win, text=f"Manage {t}", command=lambda x=t: open_crud_screen(x)).pack(fill="x", padx=40, pady=3)

    ttk.Separator(win).pack(fill="x", padx=40, pady=5)
    
    # NEW REPORT BUTTONS
    ttk.Button(win, text="Generate New Report (Save CSV)", bootstyle="success", command=generate_report_window).pack(fill="x", padx=40, pady=5)
    ttk.Button(win, text="View/Open Saved Reports 💾", bootstyle="info", command=open_reports_viewer).pack(fill="x", padx=40, pady=5)
    
    ttk.Separator(win).pack(fill="x", padx=40, pady=5)
    
    ttk.Button(win, text="Raise Alert", bootstyle="danger", command=open_raise_alert).pack(fill="x", padx=40, pady=10)
    ttk.Button(win, text="View Alerts", command=view_alerts_window).pack(fill="x", padx=40, pady=5)


def open_user_dashboard():
    win = ttk.Toplevel(root); win.title("User Dashboard"); win.geometry("380x400")

    ttk.Label(win, text="USER DASHBOARD", font=("Segoe UI", 18)).pack(pady=10)
    ttk.Button(win, text="Notifications 🔔", command=view_notifications_window).pack(fill="x", padx=40, pady=5)
    ttk.Button(win, text="Active Alerts", command=view_alerts_window).pack(fill="x", padx=40, pady=5)
    ttk.Button(win, text="Weather Metrics", command=view_metrics_dashboard).pack(fill="x", padx=40, pady=5)
    ttk.Button(win, text="Forecast", command=view_forecast_window).pack(fill="x", padx=40, pady=5)
    ttk.Button(win, text="Generate CSV Report", bootstyle="success", command=generate_report_window).pack(fill="x", padx=40, pady=5)


# --------------------------------------------------------------
# LOGIN SCREEN (MAIN)
# --------------------------------------------------------------
root = ttk.Window(themename="cosmo")
root.title("Weather App Login")
root.geometry("360x300")

frame = ttk.Frame(root, padding=20); frame.pack(expand=True)

ttk.Label(frame, text="🌤 Weather App", font=("Segoe UI", 22)).pack(pady=10)

username = ttk.Entry(frame, width=36)
username.pack()
username.insert(0, "sys.admin") 

password = ttk.Entry(frame, width=36, show="*")
password.pack(pady=10)
password.insert(0, "Arihant@1008") 

ttk.Button(frame, text="Login", bootstyle="success",
           command=lambda: login(username, password)).pack(pady=5)

ttk.Button(frame, text="Register User", bootstyle="secondary",
           command=open_register_window).pack(fill="x")

ttk.Button(frame, text="Register Admin", bootstyle="info",
           command=open_admin_register_window).pack(fill="x", pady=5)

root.mainloop()