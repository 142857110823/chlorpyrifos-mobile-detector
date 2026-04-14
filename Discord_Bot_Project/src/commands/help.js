const { SlashCommandBuilder, EmbedBuilder } = require('discord.js');

module.exports = {
  data: new SlashCommandBuilder()
    .setName('help')
    .setDescription('获取帮助信息'),
  async execute(interaction) {
    const embed = new EmbedBuilder()
      .setColor('#0099ff')
      .setTitle('🤖 Bot帮助')
      .setDescription('以下是可用的命令列表：')
      .addFields(
        { name: '/ping', value: '查看Bot的网络延迟' },
        { name: '/hello', value: '向Bot打招呼' },
        { name: '/help', value: '显示此帮助信息' }
      )
      .setFooter({ text: '使用 /命令名 来执行命令' });

    await interaction.reply({ embeds: [embed] });
  }
};
