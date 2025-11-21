-- ##########################################################################
-- # FULL SQL: Weather App DB (20 rows per table — realistic sample data)
-- ##########################################################################

CREATE DATABASE IF NOT EXISTS weather_app_db;
USE weather_app_db;

-- disable foreign key checks while dropping/creating to avoid ordering issues
SET FOREIGN_KEY_CHECKS = 0;

-- drop existing tables (safe to re-run)
DROP TABLE IF EXISTS Notification;
DROP TABLE IF EXISTS Alerts;
DROP TABLE IF EXISTS Forecast;
DROP TABLE IF EXISTS Historical_Data;
DROP TABLE IF EXISTS Weather_Metrics;
DROP TABLE IF EXISTS Weather_Station;
DROP TABLE IF EXISTS API_Integration;
DROP TABLE IF EXISTS Dashboard_Config;
DROP TABLE IF EXISTS User_Activity_Log;
DROP TABLE IF EXISTS Location;
DROP TABLE IF EXISTS Admin_Role;
DROP TABLE IF EXISTS Report;
DROP TABLE IF EXISTS `User`;

-- ##########################################################################
-- # SECTION 1: DDL (Table Creation)
-- ##########################################################################

-- 1. User Table
CREATE TABLE `User` (
    user_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'standard',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Admin Role Table (maps to a User)
CREATE TABLE Admin_Role (
    admin_role_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    permissions VARCHAR(255),
    CONSTRAINT fk_admin_user FOREIGN KEY (user_id) REFERENCES `User`(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Location Table
CREATE TABLE Location (
    location_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    country VARCHAR(100) NOT NULL,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL,
    timezone VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. User Activity Log
CREATE TABLE User_Activity_Log (
    log_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    activity_type VARCHAR(100) NOT NULL,
    action_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    active_item_id INT,
    CONSTRAINT fk_activity_user FOREIGN KEY (user_id) REFERENCES `User`(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Dashboard Config
CREATE TABLE Dashboard_Config (
    config_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL UNIQUE,
    preferred_units VARCHAR(20) DEFAULT 'C',
    theme VARCHAR(50) DEFAULT 'light',
    refresh_interval INT DEFAULT 5,
    CONSTRAINT fk_dashboard_user FOREIGN KEY (user_id) REFERENCES `User`(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. API Integration
CREATE TABLE API_Integration (
    api_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    provider_name VARCHAR(100) UNIQUE NOT NULL,
    api_key VARCHAR(255) NOT NULL,
    data_format VARCHAR(50) DEFAULT 'JSON',
    refresh_rate INT DEFAULT 60 -- minutes
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. Weather Station
CREATE TABLE Weather_Station (
    station_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    station_name VARCHAR(255) NOT NULL,
    location_id INT NOT NULL,
    api_id INT,
    installed_date DATE,
    status VARCHAR(50) DEFAULT 'Inactive',
    CONSTRAINT fk_station_location FOREIGN KEY (location_id) REFERENCES Location(location_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_station_api FOREIGN KEY (api_id) REFERENCES API_Integration(api_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. Weather Metrics
CREATE TABLE Weather_Metrics (
    metric_id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    station_id INT NOT NULL,
    `timestamp` DATETIME NOT NULL,
    temperature FLOAT,
    humidity FLOAT,
    wind_speed FLOAT,
    pressure FLOAT,
    uv_index INT,
    CONSTRAINT fk_metrics_station FOREIGN KEY (station_id) REFERENCES Weather_Station(station_id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_station_time (station_id, `timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 9. Historical Data
CREATE TABLE Historical_Data (
    history_id BIGINT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    station_id INT NOT NULL,
    record_date DATE NOT NULL,
    max_temp FLOAT,
    min_temp FLOAT,
    avg_humidity FLOAT,
    avg_wind_speed FLOAT,
    total_rainfall FLOAT,
    CONSTRAINT fk_history_station FOREIGN KEY (station_id) REFERENCES Weather_Station(station_id) ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE KEY ux_history_station_date (station_id, record_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 10. Forecast
CREATE TABLE Forecast (
    forecast_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    location_id INT NOT NULL,
    forecast_date DATE NOT NULL,
    high_temp FLOAT,
    low_temp FLOAT,
    weather_condition VARCHAR(100),
    precipitation_chance FLOAT,
    CONSTRAINT fk_forecast_location FOREIGN KEY (location_id) REFERENCES Location(location_id) ON DELETE CASCADE ON UPDATE CASCADE,
    UNIQUE KEY ux_location_forecast_date (location_id, forecast_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 11. Alerts
CREATE TABLE Alerts (
    alert_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    alert_type VARCHAR(100) NOT NULL,
    raised_by INT NULL,
    severity VARCHAR(50) NOT NULL,
    message TEXT,
    location_id INT,
    issue_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expiry_time DATETIME,
    CONSTRAINT fk_alerts_user FOREIGN KEY (raised_by) REFERENCES `User`(user_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_alerts_location FOREIGN KEY (location_id) REFERENCES Location(location_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 12. Notification
CREATE TABLE Notification (
    notification_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    alert_id INT,
    date_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',
    delivery_method VARCHAR(50) DEFAULT 'in-app',
    `string` TEXT,
    CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES `User`(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_notification_alert FOREIGN KEY (alert_id) REFERENCES Alerts(alert_id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_notification_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 13. Report
CREATE TABLE Report (
    report_id INT NOT NULL PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    generated_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    report_type VARCHAR(100),
    file_path VARCHAR(255),
    CONSTRAINT fk_report_user FOREIGN KEY (user_id) REFERENCES `User`(user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ##########################################################################
-- # SECTION 2: Insert Sample Data (20 rows per table)
-- ##########################################################################

-- Temporarily disable FK checks to insert sample data in any order
SET FOREIGN_KEY_CHECKS = 0;

-- --------------------
-- Users (20)
-- --------------------
INSERT INTO `User` (user_id, name, username, password, role, created_at)
VALUES
(1, 'System Admin', 'sys.admin', 'hashed_pw_admin', 'admin', NOW() - INTERVAL 400 DAY),
(2, 'Report Manager', 'rep.manager', 'hashed_pw_report', 'admin', NOW() - INTERVAL 300 DAY),
(3, 'Alice Smith', 'alice.s', 'hashed_pw_1', 'standard', NOW() - INTERVAL 120 DAY),
(4, 'Bob Johnson', 'bob.j', 'hashed_pw_2', 'standard', NOW() - INTERVAL 110 DAY),
(5, 'Carla Mendes', 'carla.m', 'hashed_pw_3', 'standard', NOW() - INTERVAL 100 DAY),
(6, 'Deepak Rao', 'deepak.r', 'hashed_pw_4', 'standard', NOW() - INTERVAL 90 DAY),
(7, 'Eleni Petro', 'eleni.p', 'hashed_pw_5', 'standard', NOW() - INTERVAL 80 DAY),
(8, 'Faisal Khan', 'faisal.k', 'hashed_pw_6', 'standard', NOW() - INTERVAL 70 DAY),
(9, 'Grace Lee', 'grace.l', 'hashed_pw_7', 'standard', NOW() - INTERVAL 60 DAY),
(10, 'Hiro Tanaka', 'hiro.t', 'hashed_pw_8', 'standard', NOW() - INTERVAL 50 DAY),
(11, 'Isha Patel', 'isha.p', 'hashed_pw_9', 'standard', NOW() - INTERVAL 40 DAY),
(12, 'Jamal Edwards', 'jamal.e', 'hashed_pw_10', 'standard', NOW() - INTERVAL 35 DAY),
(13, 'Kavya Nair', 'kavya.n', 'hashed_pw_11', 'standard', NOW() - INTERVAL 30 DAY),
(14, 'Liam O''Connor', 'liam.o', 'hashed_pw_12', 'standard', NOW() - INTERVAL 25 DAY),
(15, 'Maya Ortiz', 'maya.o', 'hashed_pw_13', 'standard', NOW() - INTERVAL 20 DAY),
(16, 'Noah Becker', 'noah.b', 'hashed_pw_14', 'standard', NOW() - INTERVAL 15 DAY),
(17, 'Olivia Gomez', 'olivia.g', 'hashed_pw_15', 'standard', NOW() - INTERVAL 10 DAY),
(18, 'Pankaj Singh', 'pankaj.s', 'hashed_pw_16', 'standard', NOW() - INTERVAL 9 DAY),
(19, 'Qi Wang', 'qi.w', 'hashed_pw_17', 'standard', NOW() - INTERVAL 8 DAY),
(20, 'Rita Fernandez', 'rita.f', 'hashed_pw_18', 'standard', NOW() - INTERVAL 7 DAY)
ON DUPLICATE KEY UPDATE username = VALUES(username), name = VALUES(name);

-- --------------------
-- Admin_Role (20)
-- --------------------
INSERT INTO Admin_Role (admin_role_id, user_id, email, permissions)
VALUES
(1, 1, 'sysadmin@weather.com','FULL_CONTROL'),
(2, 2, 'reports@weather.com','MANAGE_REPORTS'),
(3, 3, 'alice.admin@weather.com','VIEW_REPORTS'),
(4, 4, 'bob.admin@weather.com','VIEW_REPORTS'),
(5, 5, 'carla.admin@weather.com','VIEW_REPORTS'),
(6, 6, 'deepak.admin@weather.com','MANAGE_STATIONS'),
(7, 7, 'eleni.admin@weather.com','VIEW_REPORTS'),
(8, 8, 'faisal.admin@weather.com','VIEW_REPORTS'),
(9, 9, 'grace.admin@weather.com','VIEW_REPORTS'),
(10, 10, 'hiro.admin@weather.com','MANAGE_DATA'),
(11, 11, 'isha.admin@weather.com','VIEW_REPORTS'),
(12, 12, 'jamal.admin@weather.com','VIEW_REPORTS'),
(13, 13, 'kavya.admin@weather.com','VIEW_REPORTS'),
(14, 14, 'liam.admin@weather.com','VIEW_REPORTS'),
(15, 15, 'maya.admin@weather.com','VIEW_REPORTS'),
(16, 16, 'noah.admin@weather.com','VIEW_REPORTS'),
(17, 17, 'olivia.admin@weather.com','VIEW_REPORTS'),
(18, 18, 'pankaj.admin@weather.com','MANAGE_STATIONS'),
(19, 19, 'qi.admin@weather.com','VIEW_REPORTS'),
(20, 20, 'rita.admin@weather.com','VIEW_REPORTS')
ON DUPLICATE KEY UPDATE email = VALUES(email), permissions = VALUES(permissions);

-- --------------------
-- Locations (20) - mix of Indian + global
-- --------------------
INSERT INTO Location (location_id, city, state, country, latitude, longitude, timezone)
VALUES
(1, 'Bengaluru', 'Karnataka', 'India', 12.9716, 77.5946, 'Asia/Kolkata'),
(2, 'New York', 'NY', 'USA', 40.7128, -74.0060, 'America/New_York'),
(3, 'Mumbai', 'Maharashtra', 'India', 19.0760, 72.8777, 'Asia/Kolkata'),
(4, 'Chennai', 'Tamil Nadu', 'India', 13.0827, 80.2707, 'Asia/Kolkata'),
(5, 'Delhi', 'Delhi', 'India', 28.7041, 77.1025, 'Asia/Kolkata'),
(6, 'Kolkata', 'West Bengal', 'India', 22.5726, 88.3639, 'Asia/Kolkata'),
(7, 'Hyderabad', 'Telangana', 'India', 17.3850, 78.4867, 'Asia/Kolkata'),
(8, 'Pune', 'Maharashtra', 'India', 18.5204, 73.8567, 'Asia/Kolkata'),
(9, 'Jaipur', 'Rajasthan', 'India', 26.9124, 75.7873, 'Asia/Kolkata'),
(10, 'Ahmedabad', 'Gujarat', 'India', 23.0225, 72.5714, 'Asia/Kolkata'),
(11, 'London', 'England', 'UK', 51.5074, -0.1278, 'Europe/London'),
(12, 'Sydney', 'NSW', 'Australia', -33.8688, 151.2093, 'Australia/Sydney'),
(13, 'Tokyo', 'Tokyo', 'Japan', 35.6762, 139.6503, 'Asia/Tokyo'),
(14, 'Singapore', 'Central', 'Singapore', 1.3521, 103.8198, 'Asia/Singapore'),
(15, 'Dubai', 'Dubai', 'UAE', 25.2048, 55.2708, 'Asia/Dubai'),
(16, 'San Francisco', 'CA', 'USA', 37.7749, -122.4194, 'America/Los_Angeles'),
(17, 'Toronto', 'ON', 'Canada', 43.6532, -79.3832, 'America/Toronto'),
(18, 'Berlin', 'Berlin', 'Germany', 52.5200, 13.4050, 'Europe/Berlin'),
(19, 'Mysuru', 'Karnataka', 'India', 12.2958, 76.6394, 'Asia/Kolkata'),
(20, 'Alleppey', 'Kerala', 'India', 9.4981, 76.3388, 'Asia/Kolkata')
ON DUPLICATE KEY UPDATE city = VALUES(city);

-- --------------------
-- Dashboard_Config (20) - one per user
-- --------------------
INSERT INTO Dashboard_Config (config_id, user_id, preferred_units, theme, refresh_interval)
VALUES
(1,1,'C','dark',5),
(2,2,'C','light',10),
(3,3,'C','dark',5),
(4,4,'F','light',15),
(5,5,'C','dark',5),
(6,6,'C','light',5),
(7,7,'C','dark',10),
(8,8,'C','light',5),
(9,9,'C','dark',5),
(10,10,'F','light',10),
(11,11,'C','dark',5),
(12,12,'C','light',5),
(13,13,'C','dark',5),
(14,14,'C','light',5),
(15,15,'C','dark',5),
(16,16,'F','light',10),
(17,17,'C','dark',5),
(18,18,'C','light',5),
(19,19,'C','dark',5),
(20,20,'C','light',5)
ON DUPLICATE KEY UPDATE preferred_units = VALUES(preferred_units), theme = VALUES(theme);

-- --------------------
-- API_Integration (20)
-- --------------------
INSERT INTO API_Integration (api_id, provider_name, api_key, data_format, refresh_rate)
VALUES
(1, 'OpenWeatherMap', 'owm_key_001', 'JSON', 10),
(2, 'WeatherStack', 'ws_key_002', 'JSON', 15),
(3, 'ClimaCell', 'climacell_key_003', 'JSON', 20),
(4, 'MeteoGroup', 'meteogroup_key_004', 'JSON', 30),
(5, 'AccuWeather', 'accuweather_key_005', 'JSON', 60),
(6, 'DarkSkyMock', 'darksky_key_006', 'JSON', 120),
(7, 'WeatherAPI', 'weatherapi_key_007', 'JSON', 60),
(8, 'NOAA_Mock', 'noaa_key_008', 'XML', 60),
(9, 'YR_NO', 'yrno_key_009', 'JSON', 180),
(10, 'CustomStationFeed', 'custom_key_010', 'JSON', 5),
(11, 'IndianMet', 'imdp_key_011', 'JSON', 60),
(12, 'ForecastIO', 'fio_key_012', 'JSON', 30),
(13, 'ClimeX', 'climex_key_013', 'JSON', 45),
(14, 'SkyCast', 'skycast_key_014', 'JSON', 20),
(15, 'RainWatch', 'rainwatch_key_015', 'JSON', 90),
(16, 'SunTrack', 'suntrack_key_016', 'JSON', 1440),
(17, 'WindSense', 'windsense_key_017', 'JSON', 30),
(18, 'PressureNet', 'pressure_key_018', 'JSON', 60),
(19, 'UVIndexAPI', 'uv_key_019', 'JSON', 120),
(20, 'HydroCast', 'hydro_key_020', 'JSON', 60)
ON DUPLICATE KEY UPDATE api_key = VALUES(api_key), refresh_rate = VALUES(refresh_rate);

-- --------------------
-- Weather_Station (20)
-- --------------------
INSERT INTO Weather_Station (station_id, station_name, location_id, api_id, installed_date, status)
VALUES
(1, 'BGL_Station_01', 1, 1, '2024-01-15', 'Active'),
(2, 'NYC_Station_A', 2, 2, '2023-08-20', 'Active'),
(3, 'MUM_Station_03', 3, 11, '2024-03-12', 'Active'),
(4, 'CHN_Station_02', 4, 1, '2022-05-10', 'Active'),
(5, 'DEL_Station_Main', 5, 11, '2021-11-01', 'Active'),
(6, 'KOL_Station_01', 6, 11, '2023-07-22', 'Active'),
(7, 'HYD_Station_07', 7, 10, '2022-12-05', 'Active'),
(8, 'PUN_Station_05', 8, 10, '2024-02-01', 'Active'),
(9, 'JPR_Station_01', 9, 15, '2024-04-10', 'Active'),
(10, 'AMD_Station_01', 10, 1, '2024-05-18', 'Active'),
(11, 'LON_Station_01', 11, 8, '2020-09-01', 'Active'),
(12, 'SYD_Station_01', 12, 12, '2019-06-15', 'Active'),
(13, 'TKY_Station_N', 13, 13, '2023-03-20', 'Active'),
(14, 'SGP_Station_05', 14, 7, '2022-01-10', 'Active'),
(15, 'DXB_Station_01', 15, 5, '2021-04-25', 'Active'),
(16, 'SF_Station_09', 16, 16, '2018-10-02', 'Active'),
(17, 'TOR_Station_04', 17, 17, '2020-02-11', 'Active'),
(18, 'BER_Station_01', 18, 18, '2019-12-01', 'Active'),
(19, 'MYS_Station_01', 19, 11, '2024-06-05', 'Active'),
(20, 'ALLP_Station_01', 20, 11, '2023-11-09', 'Active')
ON DUPLICATE KEY UPDATE station_name = VALUES(station_name), status = VALUES(status);

-- --------------------
-- Weather_Metrics (20) - one sample per station (realistic-ish values)
-- --------------------
INSERT INTO Weather_Metrics (metric_id, station_id, `timestamp`, temperature, humidity, wind_speed, pressure, uv_index)
VALUES
(1,1,NOW() - INTERVAL 2 HOUR,26.3,60.5,4.8,1013.2,7),
(2,2,NOW() - INTERVAL 1 HOUR,18.1,55.0,8.5,1018.6,3),
(3,3,NOW() - INTERVAL 30 MINUTE,31.2,72.0,3.2,1008.4,9),
(4,4,NOW() - INTERVAL 3 HOUR,29.4,78.1,2.5,1005.9,10),
(5,5,NOW() - INTERVAL 4 HOUR,33.0,45.2,5.1,1009.1,8),
(6,6,NOW() - INTERVAL 90 MINUTE,27.2,81.5,1.8,1006.7,6),
(7,7,NOW() - INTERVAL 15 MINUTE,30.0,59.0,4.0,1011.0,8),
(8,8,NOW() - INTERVAL 45 MINUTE,25.5,66.0,3.0,1012.5,7),
(9,9,NOW() - INTERVAL 5 HOUR,35.1,22.5,6.2,1007.3,11),
(10,10,NOW() - INTERVAL 20 MINUTE,34.0,35.0,5.5,1008.9,9),
(11,11,NOW() - INTERVAL 6 HOUR,12.3,80.0,12.2,1020.1,2),
(12,12,NOW() - INTERVAL 2 DAY,22.0,65.0,10.5,1015.5,1),
(13,13,NOW() - INTERVAL 90 MINUTE,20.1,60.2,6.0,1016.0,4),
(14,14,NOW() - INTERVAL 10 MINUTE,30.5,78.5,3.5,1009.7,8),
(15,15,NOW() - INTERVAL 7 HOUR,34.8,40.0,7.5,1006.2,9),
(16,16,NOW() - INTERVAL 1 HOUR,16.2,68.0,5.0,1019.9,3),
(17,17,NOW() - INTERVAL 2 HOUR,8.3,76.2,9.2,1021.4,1),
(18,18,NOW() - INTERVAL 12 HOUR,10.9,73.5,4.2,1017.6,2),
(19,19,NOW() - INTERVAL 30 MINUTE,28.6,60.3,2.8,1010.0,7),
(20,20,NOW() - INTERVAL 20 MINUTE,29.0,88.0,1.2,1004.5,5)
ON DUPLICATE KEY UPDATE temperature = VALUES(temperature), humidity = VALUES(humidity);

-- --------------------
-- Historical_Data (20) - sample last-days summary per station
-- --------------------
INSERT INTO Historical_Data (history_id, station_id, record_date, max_temp, min_temp, avg_humidity, avg_wind_speed, total_rainfall)
VALUES
(1,1,DATE_SUB(CURDATE(), INTERVAL 1 DAY),31.0,22.4,65.2,3.5,5.2),
(2,2,DATE_SUB(CURDATE(), INTERVAL 1 DAY),20.1,12.5,60.1,6.8,0.0),
(3,3,DATE_SUB(CURDATE(), INTERVAL 1 DAY),34.5,28.0,74.3,2.5,12.0),
(4,4,DATE_SUB(CURDATE(), INTERVAL 1 DAY),32.0,27.1,80.0,2.0,20.5),
(5,5,DATE_SUB(CURDATE(), INTERVAL 1 DAY),35.2,25.1,48.4,4.3,0.0),
(6,6,DATE_SUB(CURDATE(), INTERVAL 1 DAY),29.0,23.3,82.1,1.9,15.0),
(7,7,DATE_SUB(CURDATE(), INTERVAL 1 DAY),33.1,26.7,60.5,3.8,3.0),
(8,8,DATE_SUB(CURDATE(), INTERVAL 1 DAY),28.0,20.0,67.0,2.5,4.2),
(9,9,DATE_SUB(CURDATE(), INTERVAL 1 DAY),40.0,27.0,25.0,5.5,0.0),
(10,10,DATE_SUB(CURDATE(), INTERVAL 1 DAY),38.5,26.1,33.5,4.8,0.0),
(11,11,DATE_SUB(CURDATE(), INTERVAL 1 DAY),16.0,6.0,82.5,10.2,8.0),
(12,12,DATE_SUB(CURDATE(), INTERVAL 1 DAY),25.0,18.5,66.0,9.3,2.0),
(13,13,DATE_SUB(CURDATE(), INTERVAL 1 DAY),22.0,14.0,59.0,6.0,0.0),
(14,14,DATE_SUB(CURDATE(), INTERVAL 1 DAY),31.5,25.0,79.0,3.4,10.0),
(15,15,DATE_SUB(CURDATE(), INTERVAL 1 DAY),42.0,28.0,30.0,7.8,0.0),
(16,16,DATE_SUB(CURDATE(), INTERVAL 1 DAY),19.0,11.0,72.0,5.0,0.0),
(17,17,DATE_SUB(CURDATE(), INTERVAL 1 DAY),12.0,2.5,80.0,8.5,10.0),
(18,18,DATE_SUB(CURDATE(), INTERVAL 1 DAY),15.0,5.0,78.0,4.1,5.0),
(19,19,DATE_SUB(CURDATE(), INTERVAL 1 DAY),30.5,22.0,63.0,2.8,6.0),
(20,20,DATE_SUB(CURDATE(), INTERVAL 1 DAY),31.0,24.0,88.0,1.2,22.0)
ON DUPLICATE KEY UPDATE max_temp = VALUES(max_temp), min_temp = VALUES(min_temp);

-- --------------------
-- Forecast (20) - next-day forecasts per location
-- --------------------
INSERT INTO Forecast (forecast_id, location_id, forecast_date, high_temp, low_temp, weather_condition, precipitation_chance)
VALUES
(1,1,DATE_ADD(CURDATE(), INTERVAL 1 DAY),29.0,21.0,'Partly Cloudy',0.2),
(2,2,DATE_ADD(CURDATE(), INTERVAL 1 DAY),19.0,12.0,'Rain',0.6),
(3,3,DATE_ADD(CURDATE(), INTERVAL 1 DAY),33.0,27.0,'Thunderstorms',0.7),
(4,4,DATE_ADD(CURDATE(), INTERVAL 1 DAY),30.0,25.0,'Hot',0.1),
(5,5,DATE_ADD(CURDATE(), INTERVAL 1 DAY),36.0,28.0,'Sunny',0.0),
(6,6,DATE_ADD(CURDATE(), INTERVAL 1 DAY),28.0,22.0,'Heavy Rain',0.8),
(7,7,DATE_ADD(CURDATE(), INTERVAL 1 DAY),32.0,26.0,'Partly Cloudy',0.2),
(8,8,DATE_ADD(CURDATE(), INTERVAL 1 DAY),27.0,19.0,'Cloudy',0.3),
(9,9,DATE_ADD(CURDATE(), INTERVAL 1 DAY),41.0,29.0,'Heat Wave',0.0),
(10,10,DATE_ADD(CURDATE(), INTERVAL 1 DAY),39.0,27.0,'Sunny',0.05),
(11,11,DATE_ADD(CURDATE(), INTERVAL 1 DAY),15.0,7.0,'Overcast',0.4),
(12,12,DATE_ADD(CURDATE(), INTERVAL 1 DAY),24.0,17.0,'Showers',0.5),
(13,13,DATE_ADD(CURDATE(), INTERVAL 1 DAY),23.0,16.0,'Cloudy',0.1),
(14,14,DATE_ADD(CURDATE(), INTERVAL 1 DAY),31.0,26.0,'Thunderstorms',0.6),
(15,15,DATE_ADD(CURDATE(), INTERVAL 1 DAY),43.0,29.0,'Hot',0.0),
(16,16,DATE_ADD(CURDATE(), INTERVAL 1 DAY),18.0,11.0,'Fog',0.15),
(17,17,DATE_ADD(CURDATE(), INTERVAL 1 DAY),10.0,1.0,'Snow',0.5),
(18,18,DATE_ADD(CURDATE(), INTERVAL 1 DAY),14.0,6.0,'Cloudy',0.2),
(19,19,DATE_ADD(CURDATE(), INTERVAL 1 DAY),29.5,21.0,'Partly Cloudy',0.1),
(20,20,DATE_ADD(CURDATE(), INTERVAL 1 DAY),30.0,24.0,'Heavy Rain',0.75)
ON DUPLICATE KEY UPDATE high_temp = VALUES(high_temp), low_temp = VALUES(low_temp);

-- --------------------
-- Alerts (20)
-- --------------------
INSERT INTO Alerts (alert_id, alert_type, raised_by, severity, message, location_id, issue_time, expiry_time)
VALUES
(1, 'HEAT_ALERT', 1, 'HIGH', 'Temperatures expected to exceed safe thresholds.', 9, NOW() - INTERVAL 2 HOUR, DATE_ADD(NOW(), INTERVAL 6 HOUR)),
(2, 'FLOOD_WARNING', 6, 'CRITICAL', 'Heavy rainfall and possible flooding in low-lying areas.', 6, NOW() - INTERVAL 3 HOUR, DATE_ADD(NOW(), INTERVAL 12 HOUR)),
(3, 'WIND_GUST_ALERT', 11, 'MEDIUM', 'Strong gusts expected, secure loose items.', 11, NOW() - INTERVAL 4 HOUR, DATE_ADD(NOW(), INTERVAL 8 HOUR)),
(4, 'WILDFIRE_ALERT', 5, 'HIGH', 'Increased fire risk due to dry conditions.', 10, NOW() - INTERVAL 1 HOUR, DATE_ADD(NOW(), INTERVAL 24 HOUR)),
(5, 'HAIL_ALERT', 13, 'MEDIUM', 'Hail possible with thunderstorms.', 13, NOW() - INTERVAL 30 MINUTE, DATE_ADD(NOW(), INTERVAL 6 HOUR)),
(6, 'RAIN_HEAVY', 12, 'HIGH', 'Extended heavy rain expected.', 12, NOW() - INTERVAL 5 HOUR, DATE_ADD(NOW(), INTERVAL 18 HOUR)),
(7, 'UV_ALERT', 19, 'LOW', 'Very high UV index; use protection.', 14, NOW() - INTERVAL 6 HOUR, DATE_ADD(NOW(), INTERVAL 10 HOUR)),
(8, 'COLD_SNAP', 17, 'HIGH', 'Sharp temperature drop expected overnight.', 17, NOW() - INTERVAL 8 HOUR, DATE_ADD(NOW(), INTERVAL 20 HOUR)),
(9, 'STORM_WARNING', 2, 'CRITICAL', 'Severe storm approaching.', 2, NOW() - INTERVAL 10 MINUTE, DATE_ADD(NOW(), INTERVAL 5 HOUR)),
(10, 'AIR_QUALITY', 4, 'MEDIUM', 'Moderate air quality degradation expected.', 5, NOW() - INTERVAL 2 DAY, DATE_ADD(NOW(), INTERVAL 6 HOUR)),
(11, 'TIDE_ALERT', 7, 'LOW', 'Higher than normal tides expected.', 20, NOW() - INTERVAL 3 HOUR, DATE_ADD(NOW(), INTERVAL 12 HOUR)),
(12, 'FROST_WARNING', 17, 'LOW', 'Early morning frost possible; protect sensitive plants.', 18, NOW() - INTERVAL 1 HOUR, DATE_ADD(NOW(), INTERVAL 16 HOUR)),
(13, 'LIGHTNING_ALERT', 3, 'HIGH', 'Frequent lightning with thunderstorms.', 3, NOW() - INTERVAL 40 MINUTE, DATE_ADD(NOW(), INTERVAL 4 HOUR)),
(14, 'DUST_STORM', 15, 'MEDIUM', 'Reduced visibility due to dust.', 15, NOW() - INTERVAL 9 HOUR, DATE_ADD(NOW(), INTERVAL 10 HOUR)),
(15, 'HEAT_INDEX_ALERT', 1, 'HIGH', 'Extremely high heat index, avoid outdoor exertion.', 5, NOW() - INTERVAL 15 MINUTE, DATE_ADD(NOW(), INTERVAL 8 HOUR)),
(16, 'WATER_LOGGING', 6, 'MEDIUM', 'Localized water logging expected after heavy showers.', 6, NOW() - INTERVAL 2 HOUR, DATE_ADD(NOW(), INTERVAL 10 HOUR)),
(17, 'AVALANCHE_RISK', 17, 'LOW', 'Increased avalanche risk in higher altitudes.', 17, NOW() - INTERVAL 6 HOUR, DATE_ADD(NOW(), INTERVAL 72 HOUR)),
(18, 'STREET_FLOOD', 6, 'HIGH', 'Streets likely to be flooded in certain areas.', 6, NOW() - INTERVAL 2 HOUR, DATE_ADD(NOW(), INTERVAL 14 HOUR)),
(19, 'TROPICAL_CYCLONE', 2, 'CRITICAL', 'Tropical cyclone expected in coastal regions.', 2, NOW() - INTERVAL 4 HOUR, DATE_ADD(NOW(), INTERVAL 72 HOUR)),
(20, 'LOCAL_ADVISORY', 8, 'LOW', 'Local advisory: road closures near station maintenance.', 8, NOW() - INTERVAL 1 HOUR, DATE_ADD(NOW(), INTERVAL 5 HOUR))
ON DUPLICATE KEY UPDATE message = VALUES(message), severity = VALUES(severity);

-- --------------------
-- Notification (20)
-- --------------------
INSERT INTO Notification (notification_id, user_id, alert_id, date_time, status, delivery_method, `string`)
VALUES
(1,3,1,NOW() - INTERVAL 1 HOUR,'pending','in-app','New Weather Alert: HEAT_ALERT - Temperatures expected to exceed safe thresholds.'),
(2,6,2,NOW() - INTERVAL 2 HOUR,'sent','sms','New Weather Alert: FLOOD_WARNING - Heavy rainfall and possible flooding.'),
(3,11,3,NOW() - INTERVAL 3 HOUR,'pending','email','New Weather Alert: WIND_GUST_ALERT - Strong gusts expected.'),
(4,5,4,NOW() - INTERVAL 50 MINUTE,'pending','in-app','New Weather Alert: WILDFIRE_ALERT - Increased fire risk.'),
(5,13,5,NOW() - INTERVAL 20 MINUTE,'pending','in-app','New Weather Alert: HAIL_ALERT - Hail possible with thunderstorms.'),
(6,12,6,NOW() - INTERVAL 4 HOUR,'sent','email','New Weather Alert: RAIN_HEAVY - Extended heavy rain expected.'),
(7,19,7,NOW() - INTERVAL 7 HOUR,'pending','in-app','New Weather Alert: UV_ALERT - Very high UV index.'),
(8,17,8,NOW() - INTERVAL 9 HOUR,'pending','in-app','New Weather Alert: COLD_SNAP - Sharp temperature drop expected.'),
(9,2,9,NOW() - INTERVAL 15 MINUTE,'sent','sms','New Weather Alert: STORM_WARNING - Severe storm approaching.'),
(10,4,10,NOW() - INTERVAL 2 DAY,'pending','email','New Weather Alert: AIR_QUALITY - Moderate air quality degradation.'),
(11,20,11,NOW() - INTERVAL 3 HOUR,'pending','in-app','New Weather Alert: TIDE_ALERT - Higher than normal tides.'),
(12,17,12,NOW() - INTERVAL 20 MINUTE,'pending','in-app','New Weather Alert: FROST_WARNING - Early morning frost possible.'),
(13,3,13,NOW() - INTERVAL 30 MINUTE,'sent','sms','New Weather Alert: LIGHTNING_ALERT - Frequent lightning expected.'),
(14,15,14,NOW() - INTERVAL 10 HOUR,'pending','in-app','New Weather Alert: DUST_STORM - Reduced visibility.'),
(15,1,15,NOW() - INTERVAL 5 MINUTE,'pending','in-app','New Weather Alert: HEAT_INDEX_ALERT - Extremely high heat index.'),
(16,6,16,NOW() - INTERVAL 3 HOUR,'pending','in-app','New Weather Alert: WATER_LOGGING - Localized water logging.'),
(17,17,17,NOW() - INTERVAL 6 HOUR,'pending','email','New Weather Alert: AVALANCHE_RISK - Increased avalanche risk.'),
(18,6,18,NOW() - INTERVAL 2 HOUR,'pending','in-app','New Weather Alert: STREET_FLOOD - Streets likely to be flooded.'),
(19,2,19,NOW() - INTERVAL 4 HOUR,'pending','sms','New Weather Alert: TROPICAL_CYCLONE - Tropical cyclone expected.'),
(20,8,20,NOW() - INTERVAL 40 MINUTE,'pending','in-app','New Weather Alert: LOCAL_ADVISORY - Road closures near station maintenance.')
ON DUPLICATE KEY UPDATE status = VALUES(status), date_time = VALUES(date_time);

-- --------------------
-- Report (20)
-- --------------------
INSERT INTO Report (report_id, user_id, name, generated_date, report_type, file_path)
VALUES
(1,1,'Weekly System Health','2025-10-28 08:00:00','SYSTEM','/reports/sys_weekly_20251028.pdf'),
(2,2,'Monthly Rainfall Summary','2025-10-01 09:00:00','CLIMATE','/reports/rainfall_oct_2025.pdf'),
(3,3,'Station 1 Daily','2025-11-01 07:00:00','DAILY','/reports/station1_daily_20251101.pdf'),
(4,4,'City Forecast Pack','2025-11-02 06:30:00','FORECAST','/reports/forecast_pack_20251102.pdf'),
(5,5,'Air Quality Report','2025-10-15 10:00:00','ENV','/reports/airq_20251015.pdf'),
(6,6,'Rainfall Archive','2025-09-20 11:10:00','ARCHIVE','/reports/rain_archive_20250920.pdf'),
(7,7,'UV Summary','2025-08-05 14:00:00','HEALTH','/reports/uv_summary_20250805.pdf'),
(8,8,'Heat Index Alerts','2025-07-22 13:20:00','ALERTS','/reports/heat_alerts_20250722.pdf'),
(9,9,'Extreme Events','2025-06-01 12:00:00','EVENTS','/reports/extreme_20250601.pdf'),
(10,10,'Wind Patterns','2025-05-18 09:45:00','CLIMATE','/reports/wind_patterns_20250518.pdf'),
(11,11,'London Forecast','2025-04-10 08:10:00','FORECAST','/reports/london_forecast_20250410.pdf'),
(12,12,'Sydney Rain Stats','2025-03-08 07:50:00','CLIMATE','/reports/sydney_rain_20250308.pdf'),
(13,13,'Tokyo Station Log','2025-02-14 06:00:00','DAILY','/reports/tokyo_log_20250214.pdf'),
(14,14,'Singapore UV Log','2025-01-30 15:00:00','HEALTH','/reports/sg_uv_20250130.pdf'),
(15,15,'Dubai Heat Study','2024-12-20 10:30:00','STUDY','/reports/dubai_heat_20241220.pdf'),
(16,16,'SF Fog Patterns','2024-11-11 09:00:00','CLIMATE','/reports/sf_fog_20241111.pdf'),
(17,17,'Toronto Winter','2024-10-01 08:00:00','SEASONAL','/reports/toronto_winter_20241001.pdf'),
(18,18,'Berlin Air Quality','2024-09-05 07:30:00','ENV','/reports/berlin_air_20240905.pdf'),
(19,19,'Mysuru Rain Archive','2024-08-22 06:45:00','ARCHIVE','/reports/mysuru_rain_20240822.pdf'),
(20,20,'Alleppey Tide Report','2024-07-12 05:20:00','TIDES','/reports/alleppey_tides_20240712.pdf')
ON DUPLICATE KEY UPDATE name = VALUES(name), generated_date = VALUES(generated_date);

-- --------------------
-- User_Activity_Log (20)
-- --------------------
INSERT INTO User_Activity_Log (log_id, user_id, activity_type, action_time, active_item_id)
VALUES
(1001,3,'LOGIN',NOW() - INTERVAL 12 HOUR, NULL),
(1002,4,'VIEW_LOCATION',NOW() - INTERVAL 11 HOUR,2),
(1003,5,'VIEW_STATION',NOW() - INTERVAL 10 HOUR,1),
(1004,6,'DOWNLOAD_REPORT',NOW() - INTERVAL 9 HOUR,1),
(1005,7,'LOGIN',NOW() - INTERVAL 8 HOUR,NULL),
(1006,8,'VIEW_FORECAST',NOW() - INTERVAL 7 HOUR,8),
(1007,9,'ACK_ALERT',NOW() - INTERVAL 6 HOUR,3),
(1008,10,'UPDATE_CONFIG',NOW() - INTERVAL 5 HOUR,10),
(1009,11,'VIEW_LOCATION',NOW() - INTERVAL 4 HOUR,11),
(1010,12,'VIEW_STATION',NOW() - INTERVAL 3 HOUR,12),
(1011,13,'LOGIN',NOW() - INTERVAL 2 HOUR,NULL),
(1012,14,'VIEW_FORECAST',NOW() - INTERVAL 90 MINUTE,14),
(1013,15,'DOWNLOAD_REPORT',NOW() - INTERVAL 80 MINUTE,5),
(1014,16,'VIEW_LOCATION',NOW() - INTERVAL 70 MINUTE,16),
(1015,17,'ACK_ALERT',NOW() - INTERVAL 60 MINUTE,8),
(1016,18,'LOGIN',NOW() - INTERVAL 50 MINUTE,NULL),
(1017,19,'UPDATE_CONFIG',NOW() - INTERVAL 40 MINUTE,19),
(1018,20,'VIEW_STATION',NOW() - INTERVAL 30 MINUTE,20),
(1019,1,'SYSTEM_CHECK',NOW() - INTERVAL 20 MINUTE,NULL),
(1020,2,'VIEW_ALERTS',NOW() - INTERVAL 10 MINUTE,2)
ON DUPLICATE KEY UPDATE activity_type = VALUES(activity_type), action_time = VALUES(action_time);

-- ##########################################################################
-- # SECTION 3: Functions, Triggers, Procedures (unchanged logic but safer)
-- ##########################################################################

-- drop existing objects if present
DROP TRIGGER IF EXISTS after_alert_insert_create_notification;
-- ✅ TRIGGER: Notify all STANDARD users when an admin inserts an alert
DELIMITER $$

CREATE TRIGGER after_alert_insert_notify_users
AFTER INSERT ON Alerts
FOR EACH ROW
BEGIN
    INSERT INTO Notification (user_id, alert_id, status, delivery_method, string)
    SELECT U.user_id, NEW.alert_id, 'pending', 'in-app',
           CONCAT('New Weather Alert: ', NEW.alert_type, ' - ', NEW.message)
    FROM User U
    WHERE U.role = 'standard';
END$$

DELIMITER ;

DROP PROCEDURE IF EXISTS Archive_Old_Metrics;
DROP FUNCTION IF EXISTS Calculate_UV_Risk_Level;

-- UV FUNCTION
DELIMITER $$
CREATE FUNCTION Calculate_UV_Risk_Level (uv_index_val INT)
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    DECLARE risk_level VARCHAR(50);

    IF uv_index_val >= 11 THEN SET risk_level = 'Extreme';
    ELSEIF uv_index_val >= 8 THEN SET risk_level = 'Very High';
    ELSEIF uv_index_val >= 6 THEN SET risk_level = 'High';
    ELSEIF uv_index_val >= 3 THEN SET risk_level = 'Moderate';
    ELSE SET risk_level = 'Low';
    END IF;

    RETURN risk_level;
END$$
DELIMITER ;

-- TRIGGER: AUTO NOTIFICATION ON ALERT INSERT
DELIMITER $$
CREATE TRIGGER after_alert_insert_create_notification
AFTER INSERT ON Alerts
FOR EACH ROW
BEGIN
    DECLARE v_receiving_user_id INT;

    -- find the most recently active standard user for that location (if any)
    SELECT U.user_id INTO v_receiving_user_id
    FROM `User` U
    INNER JOIN User_Activity_Log L ON U.user_id = L.user_id
    WHERE L.active_item_id = NEW.location_id
      AND U.role = 'standard'
    ORDER BY L.action_time DESC
    LIMIT 1;

    IF v_receiving_user_id IS NOT NULL THEN
        INSERT INTO Notification (user_id, alert_id, date_time, status, delivery_method, `string`)
        VALUES (v_receiving_user_id, NEW.alert_id, NOW(), 'pending', 'in-app',
                CONCAT('New Weather Alert: ', NEW.alert_type, ' - ', NEW.message));
    END IF;
END$$
DELIMITER ;

-- STORED PROCEDURE: ARCHIVE RAW WEATHER METRICS
DELIMITER $$
CREATE PROCEDURE Archive_Old_Metrics (IN p_days_old INT)
BEGIN
    DECLARE cutoff_date DATETIME;
    DECLARE v_deleted INT DEFAULT 0;

    SET cutoff_date = DATE_SUB(NOW(), INTERVAL p_days_old DAY);
    SET SQL_SAFE_UPDATES = 0;

    INSERT INTO Historical_Data (station_id, record_date, max_temp, min_temp, avg_humidity, avg_wind_speed, total_rainfall)
    SELECT station_id, DATE(`timestamp`), MAX(temperature), MIN(temperature),
           AVG(humidity), AVG(wind_speed), NULL
    FROM Weather_Metrics
    WHERE `timestamp` < cutoff_date
    GROUP BY station_id, DATE(`timestamp`);

    DELETE FROM Weather_Metrics WHERE `timestamp` < cutoff_date;
    SET v_deleted = ROW_COUNT();

    SET SQL_SAFE_UPDATES = 1;

    SELECT CONCAT(v_deleted, ' metric records archived and deleted.') AS Result_Message;
END$$
DELIMITER ;

-- ##########################################################################
-- # SECTION 4: Test Run / Example Inserts (already done above)
-- ##########################################################################

-- Example: check UV function
SELECT 'UV Risk Level Example:' AS Info, Calculate_UV_Risk_Level(7) AS Risk;

-- Example: insert an alert (id 210) using explicit columns - kept for compatibility/testing
INSERT INTO Alerts (alert_id, alert_type, raised_by, severity, message, location_id, issue_time, expiry_time)
VALUES (210, 'WILDFIRE_TEST', 1, 'HIGH', 'Test Trigger...', 2, NOW(), DATE_ADD(NOW(), INTERVAL 4 HOUR))
ON DUPLICATE KEY UPDATE message = VALUES(message);

-- Example: Call archive procedure for older metrics (set p_days_old to 365 to archive 1-year-old metrics)
-- CALL Archive_Old_Metrics(365);

-- Re-enable foreign key checks
SET FOREIGN_KEY_CHECKS = 1;

-- ##########################################################################
-- # END OF FILE
-- ##########################################################################
