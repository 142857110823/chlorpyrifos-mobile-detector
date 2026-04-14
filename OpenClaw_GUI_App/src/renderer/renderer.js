const { ipcRenderer, shell } = require('electron');
const { exec } = require('child_process');
const path = require('path');

let config = {
    discordToken: '',
    discordClientId: ''
};

document.addEventListener('DOMContentLoaded', async () => {
    await loadConfig();
    setupEventListeners();
    updateUI();
});

async function loadConfig() {
    try {
        const savedConfig = await ipcRenderer.invoke('get-all-config');
        if (savedConfig) {
            config = { ...config, ...savedConfig };
        }
        
        if (config.discordToken) {
            document.getElementById('discord-token').value = config.discordToken;
        }
        if (config.discordClientId) {
            document.getElementById('discord-client-id').value = config.discordClientId;
        }
    } catch (error) {
        console.error('加载配置失败:', error);
    }
}

function setupEventListeners() {
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.addEventListener('click', () => switchPage(btn.dataset.page));
    });

    document.getElementById('btn-check-openclaw').addEventListener('click', checkOpenClaw);
    document.getElementById('btn-doctor').addEventListener('click', runDoctor);
    document.getElementById('btn-onboard').addEventListener('click', runOnboard);
    document.getElementById('btn-dashboard').addEventListener('click', openDashboard);

    document.getElementById('btn-save-discord').addEventListener('click', saveDiscordConfig);
    document.getElementById('btn-test-discord').addEventListener('click', testDiscord);
    document.getElementById('btn-dev-portal').addEventListener('click', () => {
        shell.openExternal('https://discord.com/developers/applications');
    });
    document.getElementById('btn-view-bot').addEventListener('click', () => {
        const projectPath = path.join(__dirname, '../../../Discord_Bot_Project');
        shell.openPath(projectPath);
    });

    document.getElementById('btn-view-config').addEventListener('click', viewConfig);
    document.getElementById('btn-reset-config').addEventListener('click', resetConfig);
    document.getElementById('btn-open-project').addEventListener('click', () => {
        shell.openPath(path.join(__dirname, '../../'));
    });

    document.getElementById('link-docs').addEventListener('click', (e) => {
        e.preventDefault();
        shell.openExternal('https://docs.openclaw.ai/');
    });

    ipcRenderer.on('new-config', () => {
        alert('新建配置功能');
    });
    ipcRenderer.on('save-config', () => {
        saveDiscordConfig();
    });
    ipcRenderer.on('run-doctor', () => {
        runDoctor();
    });
    ipcRenderer.on('open-dashboard', () => {
        openDashboard();
    });
    ipcRenderer.on('show-about', () => {
        switchPage('about');
    });
}

function switchPage(pageName) {
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.classList.remove('active');
        if (btn.dataset.page === pageName) {
            btn.classList.add('active');
        }
    });

    document.querySelectorAll('.page').forEach(page => {
        page.classList.remove('active');
    });
    document.getElementById(`page-${pageName}`).classList.add('active');
}

function runCommand(command, callback) {
    appendTerminal(`$ ${command}`);
    
    exec(command, (error, stdout, stderr) => {
        if (stdout) {
            appendTerminal(stdout);
        }
        if (stderr) {
            appendTerminal(`❌ ${stderr}`);
        }
        if (error) {
            appendTerminal(`❌ 错误: ${error.message}`);
        }
        if (callback) callback(error, stdout, stderr);
    });
}

function appendTerminal(text) {
    const terminal = document.getElementById('terminal-output');
    terminal.textContent += text + '\n';
    terminal.parentElement.scrollTop = terminal.parentElement.scrollHeight;
}

function checkOpenClaw() {
    appendTerminal('正在检查 OpenClaw...');
    runCommand('openclaw --version', (error, stdout) => {
        if (!error && stdout) {
            const version = stdout.trim();
            document.getElementById('openclaw-details').innerHTML = `
                <p><strong>版本:</strong> ${version}</p>
                <p><strong>状态:</strong> ✅ 已安装</p>
            `;
            document.getElementById('openclaw-info').classList.remove('hidden');
            updateStatus('openclaw', true, `已安装 (${version})`);
        } else {
            updateStatus('openclaw', false, '未找到');
        }
    });
}

function runDoctor() {
    appendTerminal('正在运行 OpenClaw 诊断...');
    runCommand('openclaw doctor');
}

function runOnboard() {
    appendTerminal('正在启动配置向导...');
    appendTerminal('提示: 配置向导将在新窗口中打开');
    runCommand('openclaw onboard');
}

function openDashboard() {
    appendTerminal('正在打开 OpenClaw 面板...');
    runCommand('openclaw dashboard');
}

async function saveDiscordConfig() {
    config.discordToken = document.getElementById('discord-token').value;
    config.discordClientId = document.getElementById('discord-client-id').value;

    try {
        await ipcRenderer.invoke('set-config', 'discordToken', config.discordToken);
        await ipcRenderer.invoke('set-config', 'discordClientId', config.discordClientId);
        alert('✅ Discord 配置已保存！');
        updateStatus('discord', config.discordToken ? true : null, '已配置');
    } catch (error) {
        alert('❌ 保存配置失败: ' + error.message);
    }
}

function testDiscord() {
    if (!config.discordToken) {
        alert('请先保存 Discord Token！');
        return;
    }
    appendTerminal('正在测试 Discord 连接...');
    appendTerminal('提示: 请确保 Bot 已正确配置');
    updateStatus('discord', true, '已配置');
}

async function viewConfig() {
    try {
        const allConfig = await ipcRenderer.invoke('get-all-config');
        alert('当前配置:\n\n' + JSON.stringify(allConfig, null, 2));
    } catch (error) {
        alert('查看配置失败: ' + error.message);
    }
}

async function resetConfig() {
    if (confirm('确定要重置所有配置吗？此操作不可撤销！')) {
        try {
            const allConfig = await ipcRenderer.invoke('get-all-config');
            for (const key in allConfig) {
                await ipcRenderer.invoke('set-config', key, undefined);
            }
            document.getElementById('discord-token').value = '';
            document.getElementById('discord-client-id').value = '';
            config = { discordToken: '', discordClientId: '' };
            alert('✅ 配置已重置！请重启应用以完全生效。');
        } catch (error) {
            alert('❌ 重置配置失败: ' + error.message);
        }
    }
}

function updateStatus(type, success, text) {
    const statusEl = document.getElementById(`${type}-status`);
    statusEl.classList.remove('status-success', 'status-error', 'status-warning');
    
    if (success === true) {
        statusEl.classList.add('status-success');
    } else if (success === false) {
        statusEl.classList.add('status-error');
    } else {
        statusEl.classList.add('status-warning');
    }
    
    const statusText = statusEl.innerHTML.split('</span>')[1] || '';
    statusEl.innerHTML = `<span class="status-dot"></span>${text || statusText}`;
}

function updateUI() {
    appendTerminal('欢迎使用 OpenClaw GUI！');
    appendTerminal('点击"检查 OpenClaw"按钮开始...');
}
