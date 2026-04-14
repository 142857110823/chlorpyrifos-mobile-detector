require('dotenv').config({ path: './config/.env' });
const { Client, GatewayIntentBits, Collection, Events } = require('discord.js');
const fs = require('fs');
const path = require('path');
const logger = require('./utils/logger');

if (!process.env.DISCORD_TOKEN) {
  logger.error('错误：未找到DISCORD_TOKEN环境变量！请检查config/.env文件');
  process.exit(1);
}

if (!process.env.CLIENT_ID) {
  logger.error('错误：未找到CLIENT_ID环境变量！请检查config/.env文件');
  process.exit(1);
}

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
    GatewayIntentBits.GuildMembers
  ]
});

client.commands = new Collection();

const commandsPath = path.join(__dirname, 'commands');
const commandFiles = fs.readdirSync(commandsPath).filter(file => file.endsWith('.js'));

for (const file of commandFiles) {
  const filePath = path.join(commandsPath, file);
  const command = require(filePath);
  if ('data' in command && 'execute' in command) {
    client.commands.set(command.data.name, command);
    logger.info(`加载命令: ${command.data.name}`);
  } else {
    logger.warn(`命令文件 ${file} 缺少必要的 "data" 或 "execute" 属性`);
  }
}

const eventsPath = path.join(__dirname, 'events');
const eventFiles = fs.readdirSync(eventsPath).filter(file => file.endsWith('.js'));

for (const file of eventFiles) {
  const filePath = path.join(eventsPath, file);
  const event = require(filePath);
  if (event.once) {
    client.once(event.name, (...args) => event.execute(...args));
  } else {
    client.on(event.name, (...args) => event.execute(...args));
  }
}

process.on('uncaughtException', (error) => {
  logger.error('未捕获的异常:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('未处理的Promise拒绝:', reason);
});

client.login(process.env.DISCORD_TOKEN).catch(error => {
  logger.error('登录失败:', error);
});
