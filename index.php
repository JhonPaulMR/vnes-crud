<?php
require_once "includes/functions.php";
include "includes/header.php";

// Get all cartridges
$cartridges = getAllCartridges($conn);
?>

<section class="cartridges-list">
    <h1>NES Game Cartridges</h1>
    
    <?php if (empty($cartridges)): ?>
        <p>No cartridges found. <a href="create.php">Add your first cartridge</a>.</p>
    <?php else: ?>
        <div class="cartridges-grid">
            <?php foreach ($cartridges as $cartridge): ?>
                <div class="cartridge-item">
                    <img src="<?php echo htmlspecialchars($cartridge['cover_image']); ?>" alt="<?php echo htmlspecialchars($cartridge['name']); ?> cover">
                    <h3><?php echo htmlspecialchars($cartridge['name']); ?></h3>
                    <div class="cartridge-actions">
                        <a href="play.php?id=<?php echo $cartridge['id']; ?>" class="btn play-btn">Play</a>
                        <a href="edit.php?id=<?php echo $cartridge['id']; ?>" class="btn edit-btn">Edit</a>
                        <a href="delete.php?id=<?php echo $cartridge['id']; ?>" class="btn delete-btn" onclick="return confirm('Are you sure you want to delete this cartridge?');">Delete</a>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</section>

<?php include "includes/footer.php"; ?>
