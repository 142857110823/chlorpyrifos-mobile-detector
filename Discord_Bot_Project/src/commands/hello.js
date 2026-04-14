const { SlashCommandBuilder } = require('discord.js');

module.exports = {
  data: new SlashCommandBuilder()
    .setName('hello')
    .setDescription('向Bot打招呼'),
  async execute(interaction) {
    await interaction.reply(`👋 你好，${interaction.user}！很高兴见到你！`);
  }
};
