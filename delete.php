<?php
require_once "includes/functions.php";
require_once "config/database.php";

if (!isset($_GET["id"]) || empty($_GET["id"])) {
    header("Location: index.php");
    exit();
}

$id = $_GET["id"];
$cartridge = getCartridgeById($conn, $id);

if (!$cartridge) {
    header("Location: index.php");
    exit();
}

deleteFile($cartridge["cover_image"]);
deleteFile($cartridge["rom_path"]);

$sql = "DELETE FROM cartridges WHERE id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $id);

if ($stmt->execute()) {
    header("Location: index.php");
    exit();
} else {
    echo "Error deleting cartridge. <a href='index.php'>Return to Home</a>";
}
?>
