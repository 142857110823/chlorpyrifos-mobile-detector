require('dotenv').config({ path: './config/.env' });
const { REST, Routes } = require('discord.js');
const fs = require('fs');
const path = require('path');
const logger = require('./src/utils/logger');

if (!process.env.DISCORD_TOKEN) {
  logger.error('错误：未找到DISCORD_TOKEN环境变量！请检查config/.env文件');
  process.exit(1);
}

if (!process.env.CLIENT_ID) {
  logger.error('错误：未找到CLIENT_ID环境变量！请检查config/.env文件');
  process.exit(1);
}

const commands = [];
const commandsPath = path.join(__dirname, 'src', 'commands');
const commandFiles = fs.readdirSync(commandsPath).filter(file => file.endsWith('.js'));

for (const file of commandFiles) {
  const filePath = path.join(commandsPath, file);
  const command = require(filePath);
  commands.push(command.data.toJSON());
}

const rest = new REST().setToken(process.env.DISCORD_TOKEN);

(async () => {
  try {
    logger.info(`开始部署 ${commands.length} 个应用程序（/）命令`);

    let data;
    if (process.env.GUILD_ID) {
      logger.info(`使用GUILD_ID进行快速部署（仅在指定服务器生效）`);
      data = await rest.put(
        Routes.applicationGuildCommands(process.env.CLIENT_ID, process.env.GUILD_ID),
        { body: commands }
      );
    } else {
      logger.info(`进行全局部署（最多需要1小时同步）`);
      data = await rest.put(
        Routes.applicationCommands(process.env.CLIENT_ID),
        { body: commands }
      );
    }

    logger.info(`成功部署 ${data.length} 个应用程序（/）命令`);
  } catch (error) {
    logger.error('部署命令时出错:', error);
  }
})();
