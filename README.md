# RetroGames - NES Cartridge Manager

A web application for managing and playing NES game cartridges. This application allows users to upload, organize, and play their NES ROM collection directly in the browser.

## Features

- Create, Read, Update, and Delete (CRUD) operations for NES game cartridges
- Upload cover images for each cartridge
- Upload NES ROM files
- Play NES games directly in the browser with a JavaScript NES emulator
- Responsive design that works on desktop and mobile devices

## System Requirements

- Web Server VM:
  - Ubuntu Server 22.04 LTS
  - Apache 2.4+
  - PHP 7.4+
  - PHP GD extension
  - PHP MySQL extension

- Database VM:
  - Ubuntu Server 22.04 LTS
  - MySQL 5.7+ or MariaDB 10.3+

## Installation Instructions

### Database Setup

1. Install MySQL/MariaDB on the database VM
2. Create a database named `cartridge_manager`
3. Create a user with permissions to access this database
4. Import the SQL schema (or run the setup script)

### Web Server Setup

1. Install Apache and PHP on the web server VM
2. Configure a virtual host for the application
3. Clone or copy the application files to the web server
4. Update the database configuration in `config/database.php`
5. Ensure proper permissions for the uploads directories

### DNS Configuration

1. Add entries to your hosts file or DNS server:
   - `<db-vm-ip> db.retrogames.local`
   - `<web-vm-ip> www.retrogames.local retrogames.local`

## Usage

1. Access the application at http://www.retrogames.local
2. Click "Add New Cartridge" to upload a new game
3. Fill in the cartridge name, upload a cover image, and a NES ROM file
4. View your cartridge library on the main page
5. Use the "Play" button to launch the emulator and play the game
6. Use the "Edit" button to modify cartridge details
7. Use the "Delete" button to remove a cartridge

## Keyboard Controls for NES Emulator

- Arrow keys: D-Pad movement
- Z: A button
- X: B button
- Enter: Start button
- Shift: Select button

## Acknowledgements

- JSNES - JavaScript NES emulator library
- This application is for educational purposes only
- Users should only upload ROM files they legally own

## License

This project is licensed under the MIT License - see the LICENSE file for details.