<?php
// Habilitar exibição de erros para depuração (REMOVER EM PRODUÇÃO)
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once "includes/functions.php";
include "includes/header.php";

// Validar e sanitizar ID
$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT, ["options" => ["min_range" => 1]]);

if ($id === false || $id === null) {
    echo "Erro: ID do cartucho inválido ou não fornecido.";
    include "includes/footer.php";
    exit();
}

if (!isset($conn)) {
    echo "Erro: Conexão com banco de dados não estabelecida.";
    include "includes/footer.php";
    exit();
}

$cartridge = getCartridgeById($conn, $id);

if (!$cartridge) {
    echo "Erro: Cartucho com ID $id não encontrado.";
    include "includes/footer.php";
    exit();
}

if (!isset($cartridge['rom_path']) || empty($cartridge['rom_path'])) {
    echo "Erro: Caminho da ROM não definido para o cartucho ID $id.";
    include "includes/footer.php";
    exit();
}

if (!isset($cartridge['name'])) {
    $cartridge['name'] = 'Nome Desconhecido';
}

if (!file_exists($cartridge['rom_path'])) {
    echo "<script>console.error('Arquivo ROM não encontrado no servidor: " . htmlspecialchars($cartridge['rom_path']) . "');</script>";
    echo "<p style='color:red;'>Erro: Arquivo ROM não encontrado no servidor.</p>";
    include "includes/footer.php";
    exit();
}
?>

<section class="play-cartridge">
    <h1>Jogando: <?php echo htmlspecialchars($cartridge['name']); ?></h1>

    <div class="game-container">
        <div id="emulator"><p>Carregando emulador...</p></div>
    </div>

    <div class="controls-info">
        <h3>Controles:</h3>
        <ul>
            <li>Setas: D-Pad</li>
            <li>Z: Botão B</li>
            <li>X: Botão A</li>
            <li>Enter: Start</li>
            <li>Shift: Select</li>
        </ul>
    </div>

    <div class="back-button">
        <a href="index.php" class="btn">Voltar para Cartuchos</a>
    </div>
</section>

<script type="text/javascript" src="node_modules/jsnes/dist/jsnes.min.js"></script>
<script>
    console.log('Tentando carregar jsnes.min.js...');
    if (typeof jsnes === 'undefined' || typeof jsnes.NES === 'undefined') {
        console.log('jsnes ou jsnes.NES não está definido.');
        document.getElementById('emulator').innerHTML = '<p style="color:red; font-weight: bold;">Erro Crítico: Biblioteca JSNES não carregada. Verifique o caminho do arquivo /js/jsnes.min.js.</p>';
        console.error('jsnes não está definido. Verifique se /js/jsnes.min.js está acessível.');
    } else {
        console.log('jsnes está definido.');
    }

    document.addEventListener('DOMContentLoaded', function() {
        console.log('Iniciando inicialização do emulador...');

        function startEmulator() {
            var romPath = "<?php echo htmlspecialchars($cartridge['rom_path'], ENT_QUOTES, 'UTF-8'); ?>";
            console.log("Tentando carregar ROM de:", romPath);

            var nes = null;
            try {
                nes = new jsnes.NES({
                    onFrame: function(framebuffer_24) {
                        if (!framebuffer_u32) return;
                        for (var i = 0; i < FRAMEBUFFER_SIZE; i++) {
                            framebuffer_u32[i] = 0xFF000000 | framebuffer_24[i];
                        }
                    },
                    onAudioSample: function(l, r) {
                        if (!audio_samples_L) return;
                        audio_samples_L[audio_write_cursor] = l;
                        audio_samples_R[audio_write_cursor] = r;
                        audio_write_cursor = (audio_write_cursor + 1) & SAMPLE_MASK;
                    }
                });
                console.log('Instância jsnes.NES criada com sucesso.');
            } catch (e) {
                document.getElementById('emulator').innerHTML = '<p style="color:red; font-weight: bold;">Erro ao inicializar JSNES. Verifique o console.</p>';
                console.error('Erro ao criar instância jsnes.NES:', e);
                return;
            }

	    let lastTime = 0;
            let accumulator = 0;
	    const dt = 1 / 50;
            var SCREEN_WIDTH = 256;
            var SCREEN_HEIGHT = 240;
            var FRAMEBUFFER_SIZE = SCREEN_WIDTH * SCREEN_HEIGHT;
            var canvas_ctx, image;
            var framebuffer_u8, framebuffer_u32;
            var AUDIO_BUFFERING = 512;
            var SAMPLE_COUNT = 4 * 1024;
            var SAMPLE_MASK = SAMPLE_COUNT - 1;
            var audio_samples_L = new Float32Array(SAMPLE_COUNT);
            var audio_samples_R = new Float32Array(SAMPLE_COUNT);
            var audio_write_cursor = 0, audio_read_cursor = 0;

	function onAnimationFrame(timestamp) {
    	if (!lastTime) {
        	lastTime = timestamp / 1000; // Inicializa lastTime na primeira chamada
    	}
    	window.requestAnimationFrame(onAnimationFrame);

    	let currentTime = timestamp / 1000; // Converte para segundos
    	let frameTime = currentTime - lastTime;
    	lastTime = currentTime;

    	accumulator += frameTime;

    	while (accumulator >= dt) {
        	nes.frame(); // Avança a emulação
        	accumulator -= dt;
    	}

    	// Renderiza o frame mais recente
    	if (framebuffer_u8) {
        	image.data.set(framebuffer_u8);
        	canvas_ctx.putImageData(image, 0, 0);
    	     }
	    }

            function audio_remain() {
                return (audio_write_cursor - audio_read_cursor) & SAMPLE_MASK;
            }

            function audio_callback(event) {
                var dst = event.outputBuffer;
                var len = dst.length;
                if (audio_remain() < len) return;
                var dst_l = dst.getChannelData(0);
                var dst_r = dst.getChannelData(1);
                for (var i = 0; i < len; i++) {
                    var src_idx = (audio_read_cursor + i) & SAMPLE_MASK;
                    dst_l[i] = audio_samples_L[src_idx];
                    dst_r[i] = audio_samples_R[src_idx];
                }
                audio_read_cursor = (audio_read_cursor + len) & SAMPLE_MASK;
            }

            function keyboard(callback, event) {
                if (!nes) return;
                var player = 1;
		// Prevenir o comportamento padrão para as setas (e outras teclas, se desejado)
    		if ([38, 40, 37, 39].includes(event.keyCode)) {
        		event.preventDefault();
    		}
                switch (event.keyCode) {
                    case 38: callback(player, jsnes.Controller.BUTTON_UP); break;
                    case 40: callback(player, jsnes.Controller.BUTTON_DOWN); break;
                    case 37: callback(player, jsnes.Controller.BUTTON_LEFT); break;
                    case 39: callback(player, jsnes.Controller.BUTTON_RIGHT); break;
                    case 88: callback(player, jsnes.Controller.BUTTON_A); break;
                    case 90: callback(player, jsnes.Controller.BUTTON_B); break;
                    case 13: callback(player, jsnes.Controller.BUTTON_START); break;
                    case 16: callback(player, jsnes.Controller.BUTTON_SELECT); break;
                    default: break;
                }
            }

            function nes_init(canvas_id) {
                var canvas = document.getElementById(canvas_id);
                if (!canvas) {
                    console.error("Elemento canvas com ID '" + canvas_id + "' não encontrado!");
                    document.getElementById('emulator').innerHTML = '<p style="color:red;">Erro: Elemento canvas não encontrado.</p>';
                    return false;
                }
                canvas_ctx = canvas.getContext("2d");
                if (!canvas_ctx) {
                    console.error("Não foi possível obter o contexto 2D do canvas.");
                    document.getElementById('emulator').innerHTML = '<p style="color:red;">Erro: Não foi possível inicializar o gráfico.</p>';
                    return false;
                }
                try {
                    image = canvas_ctx.createImageData(SCREEN_WIDTH, SCREEN_HEIGHT);
                } catch (e) {
                    console.error("Erro ao criar ImageData:", e);
                    try {
                        image = canvas_ctx.getImageData(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
                    } catch (e2) {
                        console.error("Erro ao obter ImageData:", e2);
                        document.getElementById('emulator').innerHTML = '<p style="color:red;">Erro: Não foi possível criar/obter ImageData do canvas.</p>';
                        return false;
                    }
                }
                canvas_ctx.fillStyle = "black";
                canvas_ctx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
                var buffer = new ArrayBuffer(image.data.length);
                framebuffer_u8 = new Uint8ClampedArray(buffer);
                framebuffer_u32 = new Uint32Array(buffer);
                try {
                    var AudioContext = window.AudioContext || window.webkitAudioContext;
                    if (!AudioContext) {
                        console.warn("Web Audio API não suportada neste navegador.");
                        return true;
                    }
                    var audio_ctx = new AudioContext({ sampleRate: 44100 });
                    var script_processor = audio_ctx.createScriptProcessor(AUDIO_BUFFERING, 0, 2);
                    script_processor.onaudioprocess = audio_callback;
                    script_processor.connect(audio_ctx.destination);
                } catch (e) {
                    console.error("Erro ao inicializar Web Audio API:", e);
                }
                return true;
            }

            function nes_boot(rom_data) {
                if (!nes) return;
                try {
                    nes.loadROM(rom_data);
                    window.requestAnimationFrame(onAnimationFrame);
                } catch (e) {
                    console.error("Erro ao carregar ROM no JSNES:", e);
                    document.getElementById('emulator').innerHTML = '<p style="color:red;">Erro ao processar o arquivo ROM. Formato inválido?</p>';
                }
            }

            function nes_load_data(rom_data) {
                nes_boot(rom_data);
            }

            function nes_load_url(url) {
                var req = new XMLHttpRequest();
                req.open("GET", url);
                req.overrideMimeType("text/plain; charset=x-user-defined");
                var errorMsg = `Erro ${req.status} ao carregar ROM: ${url}. Verifique se o caminho está correto e o arquivo existe no servidor.`;
                req.onerror = () => {
                    console.error(errorMsg + ' (Erro de Rede)');
                    document.getElementById('emulator').innerHTML = `<p style="color:red;">Falha ao carregar ROM (Erro de Rede). Verifique a URL e a conexão.</p>`;
                };
                req.onload = function() {
                    if (req.status === 200) {
                        console.log("ROM carregada com sucesso via XHR.");
                        nes_load_data(req.responseText);
                    } else {
                        console.error(errorMsg + ` Status: ${req.statusText} (${req.status})`);
                        document.getElementById('emulator').innerHTML = `<p style="color:red;">Falha ao carregar ROM (${req.status} ${req.statusText}).<br>Verifique se o arquivo existe em '${url}' no servidor.</p>`;
                    }
                };
                req.send();
            }

            var container = document.getElementById('emulator');
            container.innerHTML = '<canvas id="nes-canvas" width="' + SCREEN_WIDTH + '" height="' + SCREEN_HEIGHT + '" style="width: 100%; image-rendering: pixelated; background-color: black;"></canvas>';
            if (nes_init('nes-canvas')) {
                document.addEventListener('keydown', (event) => { keyboard(nes.buttonDown, event); });
                document.addEventListener('keyup', (event) => { keyboard(nes.buttonUp, event); });
                nes_load_url(romPath);
            }
        }

        if (typeof jsnes === 'undefined' || typeof jsnes.NES === 'undefined') {
            document.getElementById('emulator').innerHTML = '<p style="color:red; font-weight: bold;">Erro Crítico: Biblioteca JSNES não carregada. Verifique o caminho do arquivo /js/jsnes.min.js.</p>';
            console.error('jsnes não está definido. Verifique se /js/jsnes.min.js está acessível.');
        } else {
            startEmulator();
        }
    });
</script>

<?php include "includes/footer.php"; ?>
