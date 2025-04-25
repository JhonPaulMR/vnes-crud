<?php
require_once "includes/functions.php";
require_once "config/database.php";

// Check if ID is provided
if (!isset($_GET["id"]) || empty($_GET["id"])) {
    header("Location: index.php");
    exit();
}

$id = $_GET["id"];
$cartridge = getCartridgeById($conn, $id);

// Check if cartridge exists
if (!$cartridge) {
    header("Location: index.php");
    exit();
}

// Delete files from server
deleteFile($cartridge["cover_image"]);
deleteFile($cartridge["rom_path"]);

// Delete cartridge from database
$sql = "DELETE FROM cartridges WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $id);

if ($stmt->execute()) {
    // Redirect to home page after successful deletion
    header("Location: index.php");
    exit();
} else {
    echo "Error deleting cartridge. <a href='index.php'>Return to Home</a>";
}
?>