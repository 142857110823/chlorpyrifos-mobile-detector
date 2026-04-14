const { Events } = require('discord.js');
const logger = require('../utils/logger');

module.exports = {
  name: Events.ClientReady,
  once: true,
  execute(client) {
    logger.info(`已登录为 ${client.user.tag}`);
    logger.info(`✨ Bot已上线！`);
    logger.info(`📱 用户: ${client.user.tag}`);
    logger.info(`🌐 服务器数量: ${client.guilds.cache.size}`);
    logger.info(`Bot已准备好接收命令！`);
  }
};
