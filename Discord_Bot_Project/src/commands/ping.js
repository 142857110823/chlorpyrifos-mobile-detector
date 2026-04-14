const { SlashCommandBuilder } = require('discord.js');

module.exports = {
  data: new SlashCommandBuilder()
    .setName('ping')
    .setDescription('查看Bot的延迟'),
  async execute(interaction) {
    const sent = await interaction.reply({
      content: '正在测量延迟...',
      fetchReply: true
    });
    const latency = sent.createdTimestamp - interaction.createdTimestamp;
    const apiLatency = Math.round(interaction.client.ws.ping);
    
    await interaction.editReply(`🏓 Pong!\n消息延迟: ${latency}ms\nAPI延迟: ${apiLatency}ms`);
  }
};
