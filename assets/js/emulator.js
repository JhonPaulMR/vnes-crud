/**
 * RetroGames Emulator Controller
 * This file handles the NES emulator functionality and keyboard controls
 */

class EmulatorController {
    constructor(romPath, canvasId) {
        this.romPath = romPath;
        this.canvasId = canvasId;
        this.nes = null;
        this.initialized = false;
        
        // Screen dimensions
        this.SCREEN_WIDTH = 256;
        this.SCREEN_HEIGHT = 240;
        this.FRAMEBUFFER_SIZE = this.SCREEN_WIDTH * this.SCREEN_HEIGHT;
        
        // Audio settings
        this.AUDIO_BUFFERING = 512;
        this.SAMPLE_COUNT = 4*1024;
        this.SAMPLE_MASK = this.SAMPLE_COUNT - 1;
        
        // Audio buffers
        this.audio_samples_L = new Float32Array(this.SAMPLE_COUNT);
        this.audio_samples_R = new Float32Array(this.SAMPLE_COUNT);
        this.audio_write_cursor = 0;
        this.audio_read_cursor = 0;
        
        // Graphics context
        this.canvas_ctx = null;
        this.image = null;
        this.framebuffer_u8 = null;
        this.framebuffer_u32 = null;
        
        // Bind methods
        this.onAnimationFrame = this.onAnimationFrame.bind(this);
        this.keyboard = this.keyboard.bind(this);
        this.buttonDown = this.buttonDown.bind(this);
        this.buttonUp = this.buttonUp.bind(this);
    }
    
    /**
     * Initialize the emulator
     */
    init() {
        // Set up canvas
        const canvas = document.getElementById(this.canvasId);
        if (!canvas) {
            console.error(`Canvas with ID ${this.canvasId} not found`);
            return false;
        }
        
        this.canvas_ctx = canvas.getContext("2d");
        this.image = this.canvas_ctx.getImageData(0, 0, this.SCREEN_WIDTH, this.SCREEN_HEIGHT);
        
        // Draw black background
        this.canvas_ctx.fillStyle = "black";
        this.canvas_ctx.fillRect(0, 0, this.SCREEN_WIDTH, this.SCREEN_HEIGHT);
        
        // Allocate framebuffer array
        const buffer = new ArrayBuffer(this.image.data.length);
        this.framebuffer_u8 = new Uint8ClampedArray(buffer);
        this.framebuffer_u32 = new Uint32Array(buffer);
        
        // Initialize JSNES
        this.nes = new JSNES({
            onFrame: (framebuffer_24) => {
                for (let i = 0; i < this.FRAMEBUFFER_SIZE; i++) {
                    const pixel = framebuffer_24[i];
                    this.framebuffer_u32[i] = 0xFF000000 | pixel;
                }
            },
            onAudioSample: (l, r) => {
                this.audio_samples_L[this.audio_write_cursor] = l;
                this.audio_samples_R[this.audio_write_cursor] = r;
                this.audio_write_cursor = (this.audio_write_cursor + 1) & this.SAMPLE_MASK;
            }
        });
        
        // Set up audio
        try {
            const audio_ctx = new window.AudioContext();
            const script_processor = audio_ctx.createScriptProcessor(this.AUDIO_BUFFERING, 0, 2);
            script_processor.onaudioprocess = this.audioCallback.bind(this);
            script_processor.connect(audio_ctx.destination);
        } catch (e) {
            console.error("Audio initialization failed:", e);
        }
        
        // Set up keyboard listeners
        document.addEventListener('keydown', (e) => {
            this.keyboard(this.buttonDown, e);
        });
        
        document.addEventListener('keyup', (e) => {
            this.keyboard(this.buttonUp, e);
        });
        
        this.initialized = true;
        return true;
    }
    
    /**
     * Load ROM from URL
     */
    loadROM() {
        if (!this.initialized) {
            if (!this.init()) {
                return;
            }
        }
        
        const req = new XMLHttpRequest();
        req.open("GET", this.romPath);
        req.overrideMimeType("text/plain; charset=x-user-defined");
        req.onerror = () => console.error(`Error loading ROM ${this.romPath}: ${req.statusText}`);
        
        req.onload = () => {
            if (req.status === 200) {
                this.nes.loadROM(req.responseText);
                window.requestAnimationFrame(this.onAnimationFrame);
                console.log("ROM loaded successfully");
            } else {
                console.error(`Error loading ROM ${this.romPath}: ${req.statusText}`);
            }
        };
        
        req.send();
    }
    
    /**
     * Animation frame handler
     */
    onAnimationFrame() {
        window.requestAnimationFrame(this.onAnimationFrame);
        
        this.image.data.set(this.framebuffer_u8);
        this.canvas_ctx.putImageData(this.image, 0, 0);
    }
    
    /**
     * Audio processing callback
     */
    audioCallback(event) {
        const dst = event.outputBuffer;
        const len = dst.length;
        
        // Avoid underruns
        if (this.audioRemain() < this.AUDIO_BUFFERING) return;
        
        const dst_l = dst.getChannelData(0);
        const dst_r = dst.getChannelData(1);
        for (let i = 0; i < len; i++) {
            const src_idx = (this.audio_read_cursor + i) & this.SAMPLE_MASK;
            dst_l[i] = this.audio_samples_L[src_idx];
            dst_r[i] = this.audio_samples_R[src_idx];
        }
        
        this.audio_read_cursor = (this.audio_read_cursor + len) & this.SAMPLE_MASK;
    }
    
    /**
     * Calculate remaining audio samples
     */
    audioRemain() {
        return (this.audio_write_cursor - this.audio_read_cursor) & this.SAMPLE_MASK;
    }
    
    /**
     * Keyboard event handler
     */
    keyboard(callback, event) {
        const player = 1;
        switch(event.keyCode) {
            case 38: // UP
                callback(player, jsnes.Controller.BUTTON_UP); break;
            case 40: // Down
                callback(player, jsnes.Controller.BUTTON_DOWN); break;
            case 37: // Left
                callback(player, jsnes.Controller.BUTTON_LEFT); break;
            case 39: // Right
                callback(player, jsnes.Controller.BUTTON_RIGHT); break;
            case 90: // Z
                callback(player, jsnes.Controller.BUTTON_A); break;
            case 88: // X
                callback(player, jsnes.Controller.BUTTON_B); break;
            case 13: // Enter
                callback(player, jsnes.Controller.BUTTON_START); break;
            case 16: // Shift
                callback(player, jsnes.Controller.BUTTON_SELECT); break;
            default: break;
        }
    }
    
    /**
     * Button down event
     */
    buttonDown(player, button) {
        this.nes.buttonDown(player, button);
    }
    
    /**
     * Button up event
     */
    buttonUp(player, button) {
        this.nes.buttonUp(player, button);
    }
}

// Expose the emulator controller globally
window.EmulatorController = EmulatorController;