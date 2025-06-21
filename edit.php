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
    // 1. Valida se o nome foi enviado
    if (empty($_POST["name"])) {
        $message = "Cartridge name is required.";
        $messageType = "error";
    } else {
        // 2. Prepara as variáveis com os dados atuais e novos
        $name = $_POST["name"];
        $coverPath = $cartridge["cover_image"]; // Começa com o caminho da imagem atual
        $romPath = $cartridge["rom_path"];       // Começa com o caminho da ROM atual
        
        $uploadError = false;

        // 3. Verifica se uma NOVA imagem de capa foi enviada
        if (isset($_FILES["cover_image"]) && $_FILES["cover_image"]["error"] == UPLOAD_ERR_OK) {
            $coverUpload = uploadFile($_FILES["cover_image"], "uploads/covers/", ["jpg", "jpeg", "png", "gif"]);
            
            if ($coverUpload["success"]) {
                // Deleta a imagem antiga se o novo upload deu certo
                deleteFile($cartridge["cover_image"]); 
                $coverPath = $coverUpload["path"]; // Atualiza a variável com o novo caminho
            } else {
                $message = $coverUpload["message"];
                $messageType = "error";
                $uploadError = true;
            }
        }
        
        // 4. Verifica se uma NOVA ROM foi enviada (só se não houve erro antes)
        if (!$uploadError && isset($_FILES["rom_file"]) && $_FILES["rom_file"]["error"] == UPLOAD_ERR_OK) {
            $romUpload = uploadFile($_FILES["rom_file"], "uploads/roms/", ["nes"]);

            if ($romUpload["success"]) {
                // Deleta a ROM antiga se o novo upload deu certo
                deleteFile($cartridge["rom_path"]);
                $romPath = $romUpload["path"]; // Atualiza a variável com o novo caminho
            } else {
                $message = $romUpload["message"];
                $messageType = "error";
                $uploadError = true;
                // Se a ROM falhou, mas a capa foi enviada, deleta a capa nova também
                if (isset($coverUpload) && $coverUpload["success"]) {
                    deleteFile($coverUpload["path"]);
                }
            }
        }

        // 5. Se não houve nenhum erro de upload, atualiza o banco de dados
        if (!$uploadError) {
            // A query é estática e sempre correta. Nós só mudamos os valores nas variáveis.
            $sql = "UPDATE cartridges SET name = ?, cover_image = ?, rom_path = ? WHERE id = ?";
            $stmt = $conn->prepare($sql);
            
            // Verificação para garantir que o prepare() funcionou (boa prática)
            if ($stmt) {
                $stmt->bind_param("sssi", $name, $coverPath, $romPath, $id);
                
                if ($stmt->execute()) {
                    // Define a mensagem de sucesso na sessão e redireciona
                    session_start();
                    $_SESSION['message'] = "Cartridge updated successfully!";
                    $_SESSION['message_type'] = "success";
                    header("Location: index.php");
                    exit();
                } else {
                    $message = "Database update failed: " . $stmt->error;
                    $messageType = "error";
                }
            } else {
                $message = "Failed to prepare the SQL statement: " . $conn->error;
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
