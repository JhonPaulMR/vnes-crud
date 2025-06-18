<?php
require_once "includes/functions.php";
include "includes/header.php";

$message = "";
$messageType = "";

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

// Handle form submission
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Validate input
    if (empty($_POST["name"])) {
        $message = "Cartridge name is required.";
        $messageType = "error";
    } else {
        $name = $_POST["name"];
        $coverPath = $cartridge["cover_image"];
        $romPath = $cartridge["rom_path"];
        $updateCover = false;
        $updateRom = false;
        
        // Check if new cover image is uploaded
        if (isset($_FILES["cover_image"]) && $_FILES["cover_image"]["error"] != UPLOAD_ERR_NO_FILE) {
            $coverUpload = uploadFile($_FILES["cover_image"], "uploads/covers/", ["jpg", "jpeg", "png", "gif"]);
            
            if (!$coverUpload["success"]) {
                $message = $coverUpload["message"];
                $messageType = "error";
            } else {
                $coverPath = $coverUpload["path"];
                $updateCover = true;
            }
        }
        
        // Check if new ROM file is uploaded
        if (isset($_FILES["rom_file"]) && $_FILES["rom_file"]["error"] != UPLOAD_ERR_NO_FILE) {
            $romUpload = uploadFile($_FILES["rom_file"], "uploads/roms/", ["nes"]);
            
            if (!$romUpload["success"]) {
                if ($updateCover) {
                    // Delete the newly uploaded cover image if ROM upload fails
                    deleteFile($coverPath);
                }
                $message = $romUpload["message"];
                $messageType = "error";
            } else {
                $romPath = $romUpload["path"];
                $updateRom = true;
            }
        }
        
        if (empty($message)) {
            // Update data in database
            $sql = "UPDATE cartridges SET name = ?, cover_image = ?, rom_path = ? WHERE id = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("sssi", $name, $coverPath, $romPath, $id);
            
            if ($stmt->execute()) {
                // Delete old files if new ones were uploaded
                if ($updateCover) {
                    deleteFile($cartridge["cover_image"]);
                }
                
                if ($updateRom) {
                    deleteFile($cartridge["rom_path"]);
                }
                
                $message = "Cartridge updated successfully!";
                $messageType = "success";
                
                // Redirect to home page after successful update
                header("Location: index.php");
                exit();
            } else {
                // Delete the newly uploaded files if database update fails
                if ($updateCover) {
                    deleteFile($coverPath);
                }
                
                if ($updateRom) {
                    deleteFile($romPath);
                }
                
                $message = "Error: " . $stmt->error;
                $messageType = "error";
            }
        }
    }
}
?>

<section class="edit-cartridge">
    <h1>Edit Cartridge</h1>
    
    <?php if (!empty($message)): ?>
        <div class="message <?php echo $messageType; ?>">
            <?php echo $message; ?>
        </div>
    <?php endif; ?>
    
    <form action="edit.php?id=<?php echo $id; ?>" method="post" enctype="multipart/form-data">
        <div class="form-group">
            <label for="name">Cartridge Name:</label>
            <input type="text" id="name" name="name" value="<?php echo htmlspecialchars($cartridge['name']); ?>" required>
        </div>
        
        <div class="form-group">
            <label for="current_cover">Current Cover Image:</label>
            <img src="<?php echo htmlspecialchars($cartridge['cover_image']); ?>" alt="Current Cover" class="current-image">
        </div>
        
        <div class="form-group">
            <label for="cover_image">New Cover Image (leave blank to keep current):</label>
            <input type="file" id="cover_image" name="cover_image" accept="image/*">
            <small>Accepted formats: JPG, JPEG, PNG, GIF</small>
        </div>
        
        <div class="form-group">
            <label for="current_rom">Current ROM File:</label>
            <p><?php echo basename($cartridge['rom_path']); ?></p>
        </div>
        
        <div class="form-group">
            <label for="rom_file">New ROM File (leave blank to keep current):</label>
            <input type="file" id="rom_file" name="rom_file" accept=".nes">
            <small>Accepted format: NES</small>
        </div>
        
        <div class="form-group">
            <button type="submit" class="btn submit-btn">Update Cartridge</button>
            <a href="index.php" class="btn cancel-btn">Cancel</a>
        </div>
    </form>
</section>

<?php include "includes/footer.php"; ?>
