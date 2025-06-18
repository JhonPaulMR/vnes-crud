<?php
// Inicia a sessão no topo do arquivo. Essencial para passar mensagens entre páginas.
session_start();

// Inclui funções e a conexão com o banco. Estes arquivos não devem gerar HTML.
require_once "includes/functions.php";
require_once "config/database.php"; // Adicionei a conexão aqui

// Handle form submission
if ($_SERVER["REQUEST_METHOD"] == "POST") {
    // Validações... (seu código de validação está bom)
    if (empty($_POST["name"])) {
        $message = "Cartridge name is required.";
        $messageType = "error";
    } elseif (!isset($_FILES["cover_image"]) || $_FILES["cover_image"]["error"] == UPLOAD_ERR_NO_FILE) {
        $message = "Cover image is required.";
        $messageType = "error";
    } elseif (!isset($_FILES["rom_file"]) || $_FILES["rom_file"]["error"] == UPLOAD_ERR_NO_FILE) {
        $message = "ROM file is required.";
        $messageType = "error";
    } else {
        // Lógica de upload... (seu código de upload está bom)
        $coverUpload = uploadFile($_FILES["cover_image"], "uploads/covers/", ["jpg", "jpeg", "png", "gif"]);
        
        if (!$coverUpload["success"]) {
            $message = $coverUpload["message"];
            $messageType = "error";
        } else {
            $romUpload = uploadFile($_FILES["rom_file"], "uploads/roms/", ["nes"]);
            
            if (!$romUpload["success"]) {
                deleteFile($coverUpload["path"]);
                $message = $romUpload["message"];
                $messageType = "error";
            } else {
                // Inserção no banco...
                $name = $_POST["name"];
                $coverPath = $coverUpload["path"];
                $romPath = $romUpload["path"];
                
                $sql = "INSERT INTO cartridges (name, cover_image, rom_path) VALUES (?, ?, ?)";
                $stmt = $conn->prepare($sql);
                $stmt->bind_param("sss", $name, $coverPath, $romPath);
                
                if ($stmt->execute()) {
                    // SUCESSO! Salva a mensagem na SESSÃO e redireciona.
                    $_SESSION['message'] = "Cartridge created successfully!";
                    $_SESSION['message_type'] = "success";
                    
                    header("Location: index.php");
                    exit(); // Garante que o script pare aqui e o redirecionamento ocorra.
                } else {
                    // Erro no banco...
                    deleteFile($coverUpload["path"]);
                    deleteFile($romUpload["path"]);
                    $message = "Error: " . $stmt->error;
                    $messageType = "error";
                }
            }
        }
    }
}

include "includes/header.php"; 
?>

<section class="create-cartridge">
    <h1>Add New Cartridge</h1>
    
    <?php if (!empty($message)): // Esta parte agora só exibirá mensagens de ERRO ?>
        <div class="message <?php echo $messageType; ?>">
            <?php echo htmlspecialchars($message); ?>
        </div>
    <?php endif; ?>
    
    <form action="create.php" method="post" enctype="multipart/form-data">
        <div class="form-group">
            <label for="name">Cartridge Name:</label>
            <input type="text" id="name" name="name" required>
        </div>
        
        <div class="form-group">
            <label for="cover_image">Cover Image:</label>
            <input type="file" id="cover_image" name="cover_image" accept="image/*" required>
            <small>Accepted formats: JPG, JPEG, PNG, GIF</small>
        </div>
        
        <div class="form-group">
            <label for="rom_file">ROM File:</label>
            <input type="file" id="rom_file" name="rom_file" accept=".nes" required>
            <small>Accepted format: NES</small>
        </div>
        
        <div class="form-group">
            <button type="submit" class="btn submit-btn">Create Cartridge</button>
            <a href="index.php" class="btn cancel-btn">Cancel</a>
        </div>
    </form>
</section>

<?php include "includes/footer.php"; ?>
