const { Events } = require('discord.js');
const logger = require('../utils/logger');

module.exports = {
  name: Events.InteractionCreate,
  async execute(interaction) {
    if (!interaction.isChatInputCommand()) return;

    const command = interaction.client.commands.get(interaction.commandName);

    if (!command) {
      logger.error(`未找到命令: ${interaction.commandName}`);
      return;
    }

    try {
      await command.execute(interaction);
      logger.info(`用户 ${interaction.user.tag} 执行了命令: ${interaction.commandName}`);
    } catch (error) {
      logger.error(`执行命令 ${interaction.commandName} 时出错:`, error);
      if (interaction.replied || interaction.deferred) {
        await interaction.followUp({
          content: '执行此命令时出错了！',
          ephemeral: true
        });
      } else {
        await interaction.reply({
          content: '执行此命令时出错了！',
          ephemeral: true
        });
      }
    }
  }
};
