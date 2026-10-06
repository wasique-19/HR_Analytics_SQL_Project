/* ==========================================================
   File    : 01_create_database.sql
   Purpose : Creates the HR_Analytics database from scratch
   WARNING : Drops the database if it already exists
   ========================================================== */
USE master;
GO

IF DB_ID('HR_Analytics') IS NOT NULL
BEGIN
    -- Kick out any open connections so the drop doesn't fail
    ALTER DATABASE HR_Analytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HR_Analytics;
END
GO

CREATE DATABASE HR_Analytics;
GO