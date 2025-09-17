-- database/init.sql
-- Initial Database Setup for Roblox Shop

-- Create Database
CREATE DATABASE IF NOT EXISTS roblox_shop;
USE roblox_shop;

-- Create Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Set timezone
SET timezone = 'Asia/Bangkok';