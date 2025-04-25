<?php
// Database connection configuration
define('DB_HOST', '');  // Fill with your database host IP
define('DB_USER', 'cruduser');
define('DB_PASS', 'crud123');
define('DB_NAME', 'cartridges');

// Create connection
$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
?>
