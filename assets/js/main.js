document.addEventListener('DOMContentLoaded', function() {
    // Toggle mobile navigation menu
    const menuToggle = document.querySelector('.menu-toggle');
    const navMenu = document.querySelector('nav ul');
    
    if (menuToggle) {
        menuToggle.addEventListener('click', function() {
            navMenu.classList.toggle('show');
        });
    }
    
    // File input preview for cover images
    const coverInput = document.getElementById('cover_image');
    const coverPreview = document.getElementById('cover_preview');
    
    if (coverInput && coverPreview) {
        coverInput.addEventListener('change', function() {
            const file = this.files[0];
            if (file) {
                const reader = new FileReader();
                reader.onload = function(e) {
                    coverPreview.src = e.target.result;
                    coverPreview.style.display = 'block';
                }
                reader.readAsDataURL(file);
            }
        });
    }
    
    // Confirm deletion
    const deleteButtons = document.querySelectorAll('.delete-btn');
    
    deleteButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            if (!confirm('Are you sure you want to delete this cartridge? This action cannot be undone.')) {
                e.preventDefault();
            }
        });
    });
});