
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
import seaborn as sns
import pandas as pd
from typing import Dict, List, Optional


plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei']
plt.rcParams['axes.unicode_minus'] = False


class SupplyChainVisualizer:
    def __init__(self):
        sns.set_style("whitegrid")

    def plot_supply_chain_network(
        self,
        graph: nx.Graph,
        title: str = "跨境电商供应链网络",
        save_path: Optional[str] = None
    ):
        plt.figure(figsize=(14, 10))
        
        pos = nx.spring_layout(graph, k=2, iterations=50, seed=42)
        
        node_colors = []
        node_sizes = []
        for node in graph.nodes():
            node_type = graph.nodes[node].get('type', 'unknown')
            capacity = graph.nodes[node].get('capacity', 1000)
            if node_type == 'supplier':
                node_colors.append('#2ECC71')
            elif node_type == 'manufacturer':
                node_colors.append('#3498DB')
            elif node_type == 'distributor':
                node_colors.append('#9B59B6')
            elif node_type == 'retailer':
                node_colors.append('#E74C3C')
            else:
                node_colors.append('#95A5A6')
            node_sizes.append(capacity / 10)
        
        edge_weights = [graph[u][v].get('weight', 1) * 2 for u, v in graph.edges()]
        
        nx.draw_networkx_nodes(graph, pos, node_color=node_colors, node_size=node_sizes, alpha=0.8)
        nx.draw_networkx_edges(graph, pos, width=edge_weights, alpha=0.6, edge_color='#7F8C8D')
        nx.draw_networkx_labels(graph, pos, font_size=10, font_weight='bold')
        
        legend_elements = [
            plt.Line2D([0], [0], marker='o', color='w', markerfacecolor='#2ECC71', markersize=10, label='供应商'),
            plt.Line2D([0], [0], marker='o', color='w', markerfacecolor='#3498DB', markersize=10, label='制造商'),
            plt.Line2D([0], [0], marker='o', color='w', markerfacecolor='#9B59B6', markersize=10, label='分销商'),
            plt.Line2D([0], [0], marker='o', color='w', markerfacecolor='#E74C3C', markersize=10, label='零售商')
        ]
        plt.legend(handles=legend_elements, loc='upper right')
        
        plt.title(title, fontsize=16, fontweight='bold')
        plt.axis('off')
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
        plt.show()

    def plot_resilience_dimensions(
        self,
        resilience_result: Dict,
        title: str = "韧性各维度得分",
        save_path: Optional[str] = None
    ):
        dimensions = ['结构韧性', '运营韧性', '环境韧性']
        scores = [
            resilience_result['structural_index'],
            resilience_result['operational_index'],
            resilience_result['environmental_index']
        ]
        weights = [
            resilience_result['dimension_weights']['structural'],
            resilience_result['dimension_weights']['operational'],
            resilience_result['dimension_weights']['environmental']
        ]
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
        
        colors = ['#3498DB', '#2ECC71', '#9B59B6']
        bars = ax1.bar(dimensions, scores, color=colors, alpha=0.7)
        ax1.set_ylabel('得分', fontsize=12)
        ax1.set_title(title, fontsize=14, fontweight='bold')
        ax1.set_ylim([0, 1])
        
        for bar in bars:
            height = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.3f}',
                    ha='center', va='bottom')
        
        ax2.pie(weights, labels=dimensions, colors=colors, autopct='%1.1f%%', startangle=90)
        ax2.set_title('维度权重分布', fontsize=14, fontweight='bold')
        
        plt.tight_layout()
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
        plt.show()

    def plot_critical_nodes(
        self,
        critical_nodes: List,
        title: str = "关键节点重要性排名",
        save_path: Optional[str] = None
    ):
        nodes = [node[0] for node in critical_nodes]
        scores = [node[1] for node in critical_nodes]
        
        plt.figure(figsize=(10, 6))
        colors = plt.cm.Reds(np.linspace(0.4, 0.9, len(nodes)))
        bars = plt.barh(nodes[::-1], scores[::-1], color=colors[::-1])
        plt.xlabel('综合重要性得分', fontsize=12)
        plt.title(title, fontsize=14, fontweight='bold')
        
        for i, bar in enumerate(bars):
            width = bar.get_width()
            plt.text(width, bar.get_y() + bar.get_height()/2.,
                    f'{width:.4f}',
                    ha='left', va='center')
        
        plt.tight_layout()
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
        plt.show()

    def plot_time_series_trend(
        self,
        df: pd.DataFrame,
        metrics: Optional[List[str]] = None,
        title: str = "时序数据趋势",
        save_path: Optional[str] = None
    ):
        if metrics is None:
            metrics = [col for col in df.columns if col != 'year']
        
        plt.figure(figsize=(14, 8))
        
        for metric in metrics:
            if metric in df.columns:
                plt.plot(df['year'], df[metric], marker='o', label=metric, linewidth=2, markersize=6)
        
        plt.xlabel('年份', fontsize=12)
        plt.ylabel('数值', fontsize=12)
        plt.title(title, fontsize=14, fontweight='bold')
        plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
        plt.show()

    def plot_comprehensive_report(
        self,
        diagnosis_report: Dict,
        save_path: Optional[str] = None
    ):
        fig = plt.figure(figsize=(16, 12))
        gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)
        
        ax1 = fig.add_subplot(gs[0, :])
        overall = diagnosis_report['overall_assessment']
        ax1.text(0.5, 0.5, f'综合韧性指数: {overall["score"]:.3f}\n等级: {overall["level"]}',
                ha='center', va='center', fontsize=18, fontweight='bold',
                bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.3))
        ax1.axis('off')
        ax1.set_title('整体评估', fontsize=14, fontweight='bold')
        
        ax2 = fig.add_subplot(gs[1, 0])
        dim_analysis = diagnosis_report['dimension_analysis']
        dimensions = ['结构', '运营', '环境']
        scores = [dim_analysis['dimension_scores'][d] for d in ['structural', 'operational', 'environmental']]
        colors = ['#3498DB', '#2ECC71', '#9B59B6']
        ax2.bar(dimensions, scores, color=colors, alpha=0.7)
        ax2.set_ylim([0, 1])
        ax2.set_title('各维度得分', fontsize=12, fontweight='bold')
        ax2.tick_params(axis='x', rotation=45)
        
        ax3 = fig.add_subplot(gs[1, 1])
        ax3.text(0.5, 0.5, f'最弱维度: {dim_analysis["weakest_dimension"]}\n最强维度: {dim_analysis["strongest_dimension"]}',
                ha='center', va='center', fontsize=12,
                bbox=dict(boxstyle='round', facecolor='lightyellow', alpha=0.3))
        ax3.axis('off')
        ax3.set_title('维度分析', fontsize=12, fontweight='bold')
        
        ax4 = fig.add_subplot(gs[1, 2])
        recommendations = '\n'.join([f'• {rec}' for rec in diagnosis_report['recommendations']])
        ax4.text(0.05, 0.5, recommendations, ha='left', va='center', fontsize=10,
                bbox=dict(boxstyle='round', facecolor='lightgreen', alpha=0.3))
        ax4.axis('off')
        ax4.set_title('优化建议', fontsize=12, fontweight='bold')
        
        ax5 = fig.add_subplot(gs[2, :])
        weaknesses = diagnosis_report.get('key_weaknesses', [])
        if weaknesses:
            weakness_text = '关键弱点:\n' + '\n'.join([f'• {w["dimension"]} - {w["metric"]}: {w["value"]:.3f}' for w in weaknesses[:5]])
            ax5.text(0.05, 0.5, weakness_text, ha='left', va='center', fontsize=10,
                    bbox=dict(boxstyle='round', facecolor='#FFE4E1', alpha=0.5))
        ax5.axis('off')
        ax5.set_title('关键弱点识别', fontsize=12, fontweight='bold')
        
        if save_path:
            plt.savefig(save_path, dpi=300, bbox_inches='tight')
        plt.show()
